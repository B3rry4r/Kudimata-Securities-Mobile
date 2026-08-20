// Kudimata Securities — shared API client.
//
// ═══════════════════════════════════════════════════════════════════════════
// CONVENTION FOR SCREEN-WIRING AGENTS — read lib/data/api/README.md in full
// first; this is a short mirror of it so it's visible from the file every
// repository imports.
//
// 0. There is exactly ONE ApiClient, owned by AppState (`AppState.apiClient`,
//    a `late final` field), constructed once in main.dart's
//    `_KudimataAppState.initState` and wired there so `onSessionExpired`
//    calls that same AppState's `forceSignOut()`. Reach it — NEVER construct
//    a second ApiClient — via the SAME AppScope this app already threads
//    AppState through, no second InheritedWidget:
//      AppScope.read(context).apiClient   // almost always this one
//      AppScope.of(context).apiClient     // only if already listening for other AppState fields
// 1. One repository per backend resource lives in lib/data/repositories/
//    (e.g. AssetRepository, PortfolioRepository), constructed with the
//    shared ApiClient, exposing Future<T>/Future<List<T>> methods named to
//    match the MockData accessor they replace (MockData.trending →
//    AssetRepository.trending()). See asset_repository.dart for the shape.
// 2. Repositories call `client.get/post/patch/delete` — NEVER `client.dio`
//    directly. Those verbs guarantee every failure arrives as one
//    lib/data/api/api_exception.dart `ApiException`, never a raw DioException.
// 3. Screens consume repositories with a plain `FutureBuilder` — no new
//    state-management dependency. Canonical shape (verbatim from README.md):
//
//      class _MyScreenState extends State<MyScreen> {
//        late final _repo = AssetRepository(AppScope.read(context).apiClient);
//        late Future<List<Asset>> _future = _repo.trending();
//
//        @override
//        Widget build(BuildContext context) {
//          return FutureBuilder<List<Asset>>(
//            future: _future,
//            builder: (context, snapshot) {
//              if (snapshot.connectionState == ConnectionState.waiting) {
//                return const KLoadingView();
//              }
//              if (snapshot.hasError) {
//                return KErrorView(
//                  onPrimary: () => setState(() => _future = _repo.trending()),
//                );
//              }
//              final data = snapshot.data!;
//              if (data.isEmpty) {
//                return const KEmptyView.watchlist(); // or the matching .xyz()
//              }
//              return /* the SAME widget tree the mock build() used, fed `data` */;
//            },
//          );
//        }
//      }
//
//    Pull-to-refresh: wrap in `RefreshIndicator(onRefresh: ..., child: ...)`
//    and re-run the same `setState(() => _future = _repo.x())` reassignment
//    on refresh. No caching layer — this is phase 1.
// 4. No offline/connectivity handling anywhere (.pipeline/conventions.md
//    runtime contract — always-online assumption). An ApiException just
//    renders the ordinary KErrorView; nothing fancier.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

import 'api_exception.dart';
import 'auth_token_store.dart';

/// Backend base URL. Override per build/run without touching code:
///
///   flutter run --dart-define=API_BASE_URL=https://api.kudimata.com
///   flutter build apk --dart-define=API_BASE_URL=https://api.kudimata.com
///
/// Defaults to a local Kudimata-Securities-Backend dev server
/// (`npm run start:dev`, NestJS default port 3000). Point this at a real
/// deployed backend by passing --dart-define at build time — no source
/// change needed, including in CI (.github/workflows/release-apk.yml can add
/// `--dart-define=API_BASE_URL=...` to its build step whenever a deployed
/// backend URL exists).
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

/// Endpoints with `"roles": []` in registry.json — the pre-auth surface
/// itself (the AuthSession resource, plus /public/legal-documents, the one
/// LegalDocument route with no roles). These must never receive an
/// Authorization header (there may be no valid token yet) and must never
/// trigger the 401-refresh dance (retrying a login/refresh call after
/// "refreshing" would loop forever).
const _preAuthPaths = <String>[
  '/auth/signup',
  '/auth/verify-email-otp',
  '/auth/login',
  '/auth/refresh',
  '/auth/request-password-reset',
  '/staff/auth/login',
  '/staff/auth/verify-totp',
  '/public/legal-documents',
];

bool _isPreAuth(String path) => _preAuthPaths.any((p) => path.contains(p));

/// Configured Dio instance + typed convenience verbs. Exactly ONE instance
/// exists app-wide — constructed in `main.dart`'s `_KudimataAppState.initState`
/// and assigned to `AppState.apiClient` — mirroring how `AppState` itself is a
/// single instance handed down via `AppScope`. Reach it via
/// `AppScope.read(context).apiClient`; do not construct a second one.
class ApiClient {
  ApiClient({AuthTokenStore? tokenStore, VoidCallback? onSessionExpired})
      : _tokenStore = tokenStore ?? AuthTokenStore(),
        // Kept as a public `onSessionExpired` named param mapped onto a
        // private field; renaming the param to match the field (as
        // prefer_initializing_formals suggests) would expose the leading
        // underscore in the public constructor API.
        // ignore: prefer_initializing_formals
        _onSessionExpired = onSessionExpired,
        dio = Dio(
          BaseOptions(
            baseUrl: kApiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            contentType: 'application/json',
          ),
        ) {
    dio.interceptors.add(_buildInterceptor());
  }

  /// The raw configured Dio instance. Repositories should prefer the
  /// [get]/[post]/[patch]/[delete] convenience verbs below, which guarantee
  /// ApiException on failure; [dio] is exposed for anything those don't cover
  /// (e.g. multipart KYC document uploads).
  final Dio dio;

  final AuthTokenStore _tokenStore;

  /// Coordinates concurrent 401s onto a SINGLE /auth/refresh exchange
  /// (2026-08-20 fix — reported: "why the heck would I be refreshed and
  /// logged out instead of passcode" / "few more details screen keeps
  /// happening", including once mid-meeting). Root cause: the backend's
  /// refresh token ROTATES (auth.service.ts's refresh() revokes the
  /// session behind the presented token the instant it's used
  /// successfully). This app now runs several independent polling timers
  /// (Home's KYC/portfolio polls, Wallet's balance poll) — when the
  /// ~15-minute access token expires while more than one of them is
  /// active, EACH one's 401 independently used to fire its own
  /// `/auth/refresh` call with the same not-yet-rotated refresh token.
  /// Whichever landed first rotated it successfully; every other
  /// concurrent call then presented an already-revoked refresh token and
  /// got a real 401 back — which this handler correctly treats as "the
  /// refresh token itself is dead", force-signing out (wiping the local
  /// passcode too, per forceSignOut()) a session that was actually still
  /// perfectly valid. Now only ONE refresh call is ever in flight at a
  /// time; any request that 401s while one is already running just awaits
  /// this SAME Future instead of starting a competing one. Reset back to
  /// null inside _performRefresh's own `finally`, so the next genuine
  /// expiry starts a fresh exchange rather than reusing a stale result.
  Future<({String? accessToken, bool sessionDead})>? _pendingRefresh;

  /// Invoked once when a 401 could not be silently resolved (refresh failed
  /// or no refresh token existed). Wire this to `AppState.forceSignOut` at
  /// app-root construction time so the gated router falls back to sign-in.
  final VoidCallback? _onSessionExpired;

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _guard(() => dio.get(path, queryParameters: queryParameters));

  /// [options] lets a caller override the default 15s connect/receive
  /// timeout for a single call — e.g. KycRepository.verifyDraftLiveness(),
  /// whose backend-side LumiID call now has its own longer, dedicated
  /// timeout (2026-08-20: "liveness works but... the timer is too low" —
  /// the backend timeout was raised, but this client's own 15s default was
  /// still cutting the wait short before that longer backend response ever
  /// arrived).
  Future<Response<dynamic>> post(String path, {Object? data, Options? options}) =>
      _guard(() => dio.post(path, data: data, options: options));

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _guard(() => dio.patch(path, data: data));

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _guard(() => dio.delete(path, data: data));

  /// Every raw Dio call that repositories make goes through here so a
  /// failure ALWAYS surfaces as [ApiException] — the interceptor below
  /// already attaches one to `DioException.error` for every failure shape
  /// (envelope error, refresh-failure, or a bare network/timeout error), so
  /// this is a thin, deliberately redundant safety net.
  Future<Response<dynamic>> _guard(Future<Response<dynamic>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final err = e.error;
      if (err is ApiException) throw err;
      throw ApiException(
        code: 'NETWORK_ERROR',
        message: e.message ?? 'Something went wrong. Please try again.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Interceptor _buildInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!_isPreAuth(options.path)) {
          final token = await _tokenStore.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final response = error.response;
        final path = error.requestOptions.path;

        // ── 401 handling ────────────────────────────────────────────────
        // Never for the pre-auth endpoints themselves (a bad login/refresh
        // is just a bad login/refresh, not a stale-session 401 to recover
        // from — recovering it would recurse).
        if (response?.statusCode == 401 && !_isPreAuth(path)) {
          final refreshToken = await _tokenStore.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            // Genuinely nothing to recover with — force sign-out.
            return handler.reject(await _forceSignOutAndReject(error));
          }

          // SINGLE-FLIGHT — see _pendingRefresh's doc comment. Whichever
          // concurrent 401 gets here FIRST starts the one real exchange;
          // every other one just awaits that same Future instead of
          // firing its own competing /auth/refresh call.
          _pendingRefresh ??= _performRefresh(refreshToken);
          final result = await _pendingRefresh!;

          if (result.sessionDead) {
            // The server explicitly rejected the refresh token itself
            // (expired/revoked) — genuinely a dead session.
            return handler.reject(await _forceSignOutAndReject(error));
          }
          if (result.accessToken == null) {
            // Transient failure (timeout, no connectivity, DNS failure, a
            // 5xx from the refresh endpoint, or a malformed 2xx body) —
            // the refresh token itself might be perfectly valid. Don't
            // sign out; just fail this one request so the caller's normal
            // error handling (KErrorView + retry) takes over, and the
            // NEXT 401 tries the refresh again with the same still-valid
            // refresh token.
            return handler.reject(_networkErrorReject(error));
          }

          // Retry the original request exactly once with the new token. A
          // failure here is whatever that request's own failure is (could be
          // unrelated to auth entirely, e.g. a 404/500 on THIS endpoint) —
          // not a session-expired signal either.
          try {
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer ${result.accessToken}';
            final retryResponse = await dio.fetch<dynamic>(retryOptions);
            return handler.resolve(retryResponse);
          } on DioException catch (retryError) {
            return handler.reject(_networkErrorReject(retryError));
          }
        }

        // ── Error envelope parsing ──────────────────────────────────────
        // {"error":{"code","message","details"}} — conventions.md.
        final data = response?.data;
        if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
          final envelope = data['error'] as Map<String, dynamic>;
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: ApiException(
                code: envelope['code'] as String? ?? 'UNKNOWN_ERROR',
                message: envelope['message'] as String? ?? 'Something went wrong.',
                details: envelope['details'] as List<dynamic>?,
                statusCode: response?.statusCode,
              ),
            ),
          );
        }

        // ── Anything else (timeout, no connectivity, 5xx with no body) ──
        return handler.reject(_networkErrorReject(error));
      },
    );
  }

  /// The one real /auth/refresh exchange for a batch of concurrent 401s —
  /// see [_pendingRefresh]'s doc comment for why this exists as its own
  /// single-flight-guarded method rather than running inline per-request.
  /// `sessionDead: true` means the server explicitly rejected this refresh
  /// token (expired/revoked/already-rotated-away) — a genuine dead
  /// session. `accessToken: null` with `sessionDead: false` means a
  /// transient failure (timeout, no connectivity, a 5xx, or a malformed
  /// 2xx body) that says nothing about whether the refresh token itself
  /// is still good.
  Future<({String? accessToken, bool sessionDead})> _performRefresh(String refreshToken) async {
    try {
      // Bare Dio (no interceptors) so this call can't recurse into this
      // same 401 handler. Same 15s timeouts as the main client — an
      // unset timeout here means Dio waits indefinitely on a bad
      // connection before this whole retry-or-fail decision even starts.
      final refreshDio = Dio(BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      late final Response<Map<String, dynamic>> refreshResponse;
      try {
        refreshResponse = await refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
      } on DioException catch (refreshError) {
        final refreshStatus = refreshError.response?.statusCode;
        if (refreshStatus == 401 || refreshStatus == 403) {
          return (accessToken: null, sessionDead: true);
        }
        return (accessToken: null, sessionDead: false);
      }

      final body = refreshResponse.data ?? const {};
      final newAccess = body['accessToken'] as String?;
      final newRefresh = (body['refreshToken'] as String?) ?? refreshToken;
      if (newAccess == null || newAccess.isEmpty) {
        // The server responded 2xx but with a malformed body — a server
        // bug, not proof this refresh token is invalid.
        return (accessToken: null, sessionDead: false);
      }
      await _tokenStore.saveTokens(newAccess, newRefresh);
      return (accessToken: newAccess, sessionDead: false);
    } finally {
      // Cleared BEFORE this Future actually completes (a `finally` runs
      // ahead of the function returning), so every concurrent awaiter
      // still reads the correct shared result — this only affects the
      // NEXT 401 that arrives afterward, which correctly starts a fresh
      // exchange instead of reusing this (already-resolved) one.
      _pendingRefresh = null;
    }
  }

  /// The genuine "this session is really dead" path — clears tokens and
  /// fires [_onSessionExpired]. Only call this when the SERVER has
  /// explicitly rejected the refresh token, or none was stored to begin
  /// with — never for a merely transient failure (see the 401 handler
  /// above's writeup).
  Future<DioException> _forceSignOutAndReject(DioException original) async {
    await _tokenStore.clearTokens();
    _onSessionExpired?.call();
    return DioException(
      requestOptions: original.requestOptions,
      response: original.response,
      type: DioExceptionType.badResponse,
      error: const ApiException(
        code: ApiException.sessionExpiredCode,
        message: 'Your session has expired. Please sign in again.',
        statusCode: 401,
      ),
    );
  }

  /// A plain, non-session-ending failure for this one request — tokens/
  /// passcode stay intact so the next attempt (or the next natural 401) can
  /// just try the refresh again.
  DioException _networkErrorReject(DioException original) {
    return DioException(
      requestOptions: original.requestOptions,
      response: original.response,
      type: original.type,
      error: ApiException(
        code: 'NETWORK_ERROR',
        message: original.message ?? 'Something went wrong. Please try again.',
        statusCode: original.response?.statusCode,
      ),
    );
  }
}
