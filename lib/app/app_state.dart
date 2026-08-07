// Kudimata Securities — minimal app session state. Drives the gated-flow router
// (passcode → biometric → KYC → suitability → tabs) and the live watchlist set.
// SEAM: real auth/KYC/suitability outcomes flip these flags; here they are flipped
// by the demo flows.
// Persistence: `signedIn` is now backed by AuthTokenStore (flutter_secure_storage)
// — the secure store this comment used to say "plugs in later". See
// _hydrateSignedIn() and forceSignOut() below. Every other flag here is still
// in-memory only.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import '../data/api/api_client.dart';
import '../data/api/auth_token_store.dart';
import '../data/api/passcode_store.dart';
import '../router/routes.dart';
import '../screens/kyc/kyc_form_state.dart';

class AppState extends ChangeNotifier {
  AppState({
    Set<String>? watchlistTickers,
    AuthTokenStore? tokenStore,
    PasscodeStore? passcodeStore,
  })  : _watchlist = watchlistTickers ?? {'MTNN', 'GTCO', 'ZENITHBANK', 'DANGCEM'},
        _tokenStore = tokenStore ?? AuthTokenStore(),
        _passcodeStore = passcodeStore ?? PasscodeStore() {
    ready = _hydrate();
  }

  /// Resolves once startup hydration ([_hydrateSignedIn] +
  /// [_hydratePasscodeSet]) has completed. [signedIn] and [passcodeSet]
  /// both start `false` synchronously (before the secure-storage reads that
  /// back them return) — callers that need a startup-correct read of either
  /// flag, rather than just reacting to a later [notifyListeners] call, must
  /// await this first. See splash_screen.dart's routing decision.
  late final Future<void> ready;

  Future<void> _hydrate() async {
    await Future.wait([_hydrateSignedIn(), _hydratePasscodeSet()]);
  }

  final AuthTokenStore _tokenStore;
  final PasscodeStore _passcodeStore;

  /// The single shared [ApiClient] — assigned exactly once, at app startup,
  /// by `main.dart`'s `_KudimataAppState.initState` (which wires this same
  /// AppState's [forceSignOut] as the client's `onSessionExpired` callback).
  /// `late final`: unset reads before that assignment throw a clear
  /// LateInitializationError rather than silently returning null.
  ///
  /// Every screen/repository reaches it via the SAME `AppScope` this app
  /// already threads `AppState` through — no second InheritedWidget:
  ///   `AppScope.read(context).apiClient`  (event handlers, initState, repo construction)
  ///   `AppScope.of(context).apiClient`    (only if the widget already listens to AppState)
  /// See lib/data/api/README.md.
  late final ApiClient apiClient;

  /// The single shared [KycFormState] — assigned exactly once, at app
  /// startup, by `main.dart`'s `_KudimataAppState.initState`, alongside
  /// [apiClient]. Holds every field the 5 KYC screens (personal-details →
  /// bvn → id-upload → liveness → next-of-kin) collect, since only the last
  /// of those screens makes the real `POST /kyc-submissions` call — see
  /// lib/screens/kyc/kyc_form_state.dart for the field list and usage.
  /// Reached the same way as [apiClient]:
  ///   `AppScope.read(context).kycForm`  (event handlers, initState)
  ///   `AppScope.of(context).kycForm`    (only if already listening to AppState)
  late final KycFormState kycForm;

  // Onboarding / gate flags.
  bool passcodeSet = false;
  bool biometricEnabled = false;
  bool kycSubmitted = false;
  bool kycApproved = false;
  bool suitabilityComplete = false;
  bool signedIn = false;

  /// True while a fresh email+password login (log_in_screen.dart) is
  /// walking its device through first-time LOCAL passcode creation, so
  /// confirm_passcode_screen.dart can tell that case apart from both
  /// first-time signup onboarding (reentry=false, continues to Biometric)
  /// and Security's change-passcode reentry (reentry=true, pops back to
  /// Security) — neither of which the existing `reentry` bool alone can
  /// distinguish. Threaded via AppState rather than GoRouter `extra` because
  /// app_router.dart's CreatePasscode/ConfirmPasscode route builders only
  /// ever forward `reentry`/`created` out of `extra`, not a third value.
  /// Consumed (set back to false) by confirm_passcode_screen.dart the
  /// instant it acts on it, so it never leaks into a later, unrelated
  /// security-reentry passcode change.
  bool loginPasscodeSetup = false;

  // Appearance — System / Light / Dark (SEAM: persist to a store later).
  ThemeMode themeMode = ThemeMode.system;

  // Live watchlist (tickers).
  final Set<String> _watchlist;
  Set<String> get watchlistTickers => Set.unmodifiable(_watchlist);
  bool isWatched(String ticker) => _watchlist.contains(ticker);

  void setPasscode(bool v) {
    passcodeSet = v;
    notifyListeners();
  }

  void setBiometric(bool v) {
    biometricEnabled = v;
    notifyListeners();
  }

  void setKycSubmitted(bool v) {
    kycSubmitted = v;
    notifyListeners();
  }

  void setKycApproved(bool v) {
    kycApproved = v;
    notifyListeners();
  }

  void setSuitabilityComplete(bool v) {
    suitabilityComplete = v;
    notifyListeners();
  }

  void setSignedIn(bool v) {
    signedIn = v;
    notifyListeners();
  }

  void setLoginPasscodeSetup(bool v) {
    loginPasscodeSetup = v;
    notifyListeners();
  }

  /// On construction, read the secure token store to decide the initial
  /// [signedIn] value — a LOCAL presence check only (an access token was
  /// persisted from a prior session), not a server-side validation. If that
  /// token has since expired, the first real API call still 401s and
  /// ApiClient's refresh-then-force-sign-out path (see lib/data/api/api_client.dart)
  /// takes over from there.
  Future<void> _hydrateSignedIn() async {
    final token = await _tokenStore.getAccessToken();
    if (token != null && token.isNotEmpty) {
      signedIn = true;
      notifyListeners();
    }
  }

  /// On construction, read the secure passcode store to decide the initial
  /// [passcodeSet] value — mirrors [_hydrateSignedIn] but checks local
  /// passcode-hash presence via [PasscodeStore.hasPasscode] instead of a
  /// stored access token. Without this, [passcodeSet] stays at its `false`
  /// default for the whole process, and splash_screen.dart would route every
  /// cold launch to sign-up — even a returning investor with a valid stored
  /// session and a stored passcode.
  Future<void> _hydratePasscodeSet() async {
    final has = await _passcodeStore.hasPasscode();
    if (has) {
      passcodeSet = true;
      notifyListeners();
    }
  }

  /// Called by ApiClient when a 401 could not be silently resolved (refresh
  /// attempt failed or no refresh token was stored) — clears persisted
  /// tokens and flips [signedIn] off so the gated router falls back to the
  /// sign-in flow. Also clears the locally stored passcode hash (PasscodeStore)
  /// — a forced sign-out routes back to Routes.signup (see log_in_screen.dart),
  /// so any stale local passcode should go with it rather than surviving to
  /// (mis)gate a future session on this device.
  Future<void> forceSignOut() async {
    await _tokenStore.clearTokens();
    await _passcodeStore.clearPasscode();
    signedIn = false;
    loginPasscodeSetup = false;
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    if (m == themeMode) return;
    themeMode = m;
    notifyListeners();
  }

  /// Force theme-dependent rebuilds (e.g. when the OS brightness changes while
  /// in System mode). No state change — just nudges listeners to re-read KColor.
  void refreshTheme() => notifyListeners();

  void toggleWatch(String ticker) {
    if (!_watchlist.remove(ticker)) _watchlist.add(ticker);
    notifyListeners();
  }

  void addWatch(String ticker) {
    if (_watchlist.add(ticker)) notifyListeners();
  }

  void removeWatch(String ticker) {
    if (_watchlist.remove(ticker)) notifyListeners();
  }
}

/// Where an investor should go next to become eligible to trade/fund, or
/// null if they already can ([AppState.kycApproved] &&
/// [AppState.suitabilityComplete]). Browsing itself is never gated —
/// this only matters at the specific points that need it: home_screen.dart's
/// prompt card, and the Buy/Sell/Add money/Withdraw entry points
/// (trade_flows.dart, wallet_flows.dart), which all call this so the copy
/// and routing stay consistent everywhere it's surfaced. Purely a UX
/// convenience — the real enforcement is server-side (OrdersService/
/// TransactionsService in the backend both re-check this before acting).
class TradingEligibilityGap {
  const TradingEligibilityGap({required this.title, required this.message, required this.route});
  final String title;
  final String message;
  final String route;
}

TradingEligibilityGap? tradingEligibilityGap(AppState app) {
  if (!app.kycSubmitted) {
    return const TradingEligibilityGap(
      title: 'Complete your KYC',
      message: 'Verify your identity to start investing',
      route: Routes.kycIntro,
    );
  }
  if (!app.kycApproved) {
    return const TradingEligibilityGap(
      title: 'Your KYC is under review',
      message: "We'll notify you once it's approved",
      route: Routes.kycSubmitted,
    );
  }
  if (!app.suitabilityComplete) {
    return const TradingEligibilityGap(
      title: 'Complete your risk profile',
      message: 'A few questions before you can start investing',
      route: Routes.questionnaire,
    );
  }
  return null;
}

/// InheritedNotifier exposing the single [AppState]. Wrap the app once; read it
/// with `AppScope.of(context)` (rebuilds on change) or `AppScope.read(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Listening read — rebuilds the caller when [AppState] notifies.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }

  /// Non-listening read — for event handlers that only mutate.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}
