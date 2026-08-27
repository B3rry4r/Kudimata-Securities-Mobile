// Kudimata Securities — realtime client (R-41, docs/redesign/DECISIONS.md).
//
// One socket.io connection, wired app-wide via `AppState.realtimeClient`
// (constructed once in main.dart alongside `AppState.apiClient` — same
// convention, see lib/data/api/README.md). Reach it via
// `AppScope.read(context).realtimeClient` / `AppScope.of(context).realtimeClient`;
// never construct a second one.
//
// AUTH: the same investor access token ApiClient already attaches as a
// Bearer header goes into the socket.io handshake's `auth.token` instead
// (`setAuthFn` below re-reads it from the SAME AuthTokenStore on every
// (re)connection attempt, so a token rotated by ApiClient's 401-refresh
// dance while the socket was down is picked up on the next reconnect,
// rather than replaying a now-stale one). A bad/expired token is rejected
// at the handshake server-side (`connect_error`, never `connect`) — this
// client does not treat that specially: socket.io's own Manager already
// retries with backoff exactly as it would for a network drop, and the
// next attempt presents whatever token is stored at that moment.
//
// RECONNECTION: configured via socket.io's own Manager (reconnection
// delay/backoff), never reimplemented — see connect() below.
//
// PAYLOADS: every event carries the SAME wire shape its matching REST
// endpoint returns (Order, WalletBalance, Notification, User, Quote,
// OrderBook — src/common/types on the backend). Each is decoded ONCE here,
// reusing the SAME parser the matching repository already uses for its own
// REST fetch (Order.fromJson, OrderBook.fromJson, or a small public
// wrapper added to that repository — see asset_repository.dart's
// `applyLiveQuote`, wallet_repository.dart's `walletUpdateFromJson`,
// notifications_repository.dart's `notificationFromJson`) — never a second,
// competing parser of a shape lib/data/ already parses. [RealtimeQuote] and
// [RealtimeKycStatus] below are the two exceptions, and only because no
// existing parser covers their exact (narrower) wire shape — see each
// class's doc comment.
//
// THE RULE THAT MATTERS MOST: an event arriving is the update — the
// decoded payload is applied directly to already-loaded state, with NO
// network call triggered by receiving it. Push is an optimisation, never
// the only path: every wired screen's own REST fetch is untouched and is
// still what puts it on screen the first time, and still works with this
// socket permanently down. The ONE legitimate fetch in this whole path is
// on [reconnected] — events that fired while disconnected cannot be
// replayed, so a screen refetches once when this fires, not on every event.
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../api/api_client.dart' show kApiBaseUrl;
import '../api/auth_token_store.dart';
import '../models.dart';

/// `market:quote`'s wire shape (backend `Quote`,
/// src/common/types/asset.types.ts) — ticker/priceKobo/changeAbsKobo/
/// changePct/assetClass/asOf, WITHOUT name/logoColor/sector. That's
/// narrower than the merged `Asset&Quote` REST shape `AssetRepository`
/// already parses (GET /assets/:ticker etc.), so this is a first parse of
/// this exact shape, not a duplicate of one that already exists. Screens
/// combine it with an already-loaded [Asset] via
/// `AssetRepository.applyLiveQuote` — see that method's doc comment.
class RealtimeQuote {
  const RealtimeQuote({
    required this.ticker,
    required this.priceKobo,
    this.changeAbsKobo,
    required this.changePct,
    required this.assetClass,
    required this.asOf,
  });

  final String ticker;
  final int priceKobo;
  final int? changeAbsKobo;
  final double changePct;
  final String assetClass; // 'ngx' | 'us' | 'etf'
  final String asOf; // ISO-8601 timestamp

  factory RealtimeQuote.fromJson(Map<String, dynamic> json) => RealtimeQuote(
        ticker: json['ticker'] as String? ?? '',
        priceKobo: (json['priceKobo'] as num?)?.toInt() ?? 0,
        changeAbsKobo: (json['changeAbsKobo'] as num?)?.toInt(),
        changePct: (json['changePct'] as num?)?.toDouble() ?? 0.0,
        assetClass: json['assetClass'] as String? ?? 'ngx',
        asOf: json['asOf'] as String? ?? '',
      );
}

/// `kyc:status`'s wire shape is the full backend `User`
/// (src/common/types/user.types.ts) — "carries the full User so the
/// client's gate can update in place" per the gateway's own doc comment.
/// Only the two fields this app's gate actually reacts to are parsed here
/// (kycStatus/accountStatus); every other User field (name, portfolio
/// value, ...) already has its own home (UserRepository) this event isn't
/// replacing. See AppState.applyRealtimeKycStatus for how these two flow
/// into the gate flags — coarser than the full REST gating check
/// (refreshKycGatingState, log_in_screen.dart) since the User payload
/// carries no flagReason/suitability/risk-disclosure fields, but applied
/// with NO network call, unlike that REST check.
class RealtimeKycStatus {
  const RealtimeKycStatus({required this.kycStatus, required this.accountStatus});

  /// 'draft' | 'pending' | 'review' | 'approved' | 'rejected' | 'flagged' | 'expired'
  final String kycStatus;

  /// 'active' | 'suspended' | 'dormant'
  final String accountStatus;

  factory RealtimeKycStatus.fromJson(Map<String, dynamic> json) => RealtimeKycStatus(
        kycStatus: json['kycStatus'] as String? ?? 'draft',
        accountStatus: json['accountStatus'] as String? ?? 'active',
      );
}

/// One socket.io connection to the backend's `RealtimeGateway`
/// (Kudimata-Securities-Backend src/realtime/realtime.gateway.ts) — see this
/// file's header for the full auth/reconnect/payload contract.
class RealtimeClient {
  RealtimeClient({AuthTokenStore? tokenStore}) : _tokenStore = tokenStore ?? AuthTokenStore();

  final AuthTokenStore _tokenStore;
  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  final _orderUpdates = StreamController<Order>.broadcast();
  final _walletUpdates = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _kycStatus = StreamController<RealtimeKycStatus>.broadcast();
  final _quotes = StreamController<RealtimeQuote>.broadcast();
  final _orderBooks = StreamController<OrderBook>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// `order:update` — already decoded via the SAME [Order.fromJson] the
  /// REST `OrdersRepository` uses. Per-user event; no subscribe call needed
  /// (the server joins every authenticated socket to its own room).
  Stream<Order> get orderUpdates => _orderUpdates.stream;

  /// `wallet:update` — raw decoded JSON (a `WalletBalance`); callers pass it
  /// straight to `WalletRepository.walletUpdateFromJson` to reuse that
  /// repository's own kobo->display-string formatting rather than a second
  /// copy of it living in this file.
  Stream<Map<String, dynamic>> get walletUpdates => _walletUpdates.stream;

  /// `notification:new` — raw decoded JSON (a `Notification`); callers pass
  /// it to `NotificationsRepository.notificationFromJson` for the same
  /// reason as [walletUpdates].
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  /// `kyc:status` — see [RealtimeKycStatus].
  Stream<RealtimeKycStatus> get kycStatus => _kycStatus.stream;

  /// `market:quote` — see [RealtimeQuote]. Public rooms; requires
  /// [subscribeMarket] first.
  Stream<RealtimeQuote> get quotes => _quotes.stream;

  /// `market:orderBook` — already decoded via [OrderBook.fromJson], the
  /// same parser `AssetRepository.orderBook`'s REST fetch uses. Rides the
  /// same `market:subscribe` room as [quotes] (no separate subscribe call).
  Stream<OrderBook> get orderBooks => _orderBooks.stream;

  /// Fires once per successful RE-connection — never on the very first
  /// connect (nothing was missed then; a screen's own initial fetch already
  /// covers that). This is the one place a screen should refetch: events
  /// that fired while disconnected are gone and cannot be replayed.
  Stream<void> get reconnected => _reconnected.stream;

  /// Connects (or resumes an existing, already-constructed socket — safe to
  /// call repeatedly, e.g. on every app foreground resume). No-ops if no
  /// access token is stored yet (not signed in) — the caller is expected to
  /// call this again once sign-in completes.
  Future<void> connect() async {
    final existing = _socket;
    if (existing != null) {
      existing.connect();
      return;
    }
    final token = await _tokenStore.getAccessToken();
    if (token == null || token.isEmpty) return;

    final socket = IO.io(
      kApiBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          // Re-read the stored token on EVERY (re)connection attempt,
          // rather than baking today's token into a static auth map — a
          // long-lived app can sit disconnected for longer than the
          // ~15-minute access-token TTL, and ApiClient's own refresh dance
          // (api_client.dart) may have rotated the stored token in the
          // meantime. This is the one place that matters for.
          .setAuthFn((callback) {
            _tokenStore.getAccessToken().then((t) => callback({'token': t ?? ''}));
          })
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .build(),
    );
    _socket = socket;
    _wireListeners(socket);
    socket.connect();
  }

  /// Disconnects and discards the socket — call on sign-out. The next
  /// [connect] call (a fresh sign-in) builds a brand-new socket authed with
  /// whatever token is stored at that point, rather than resuming a socket
  /// that may have been authenticated as a different investor.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  /// App-teardown only (AppState.dispose) — [disconnect]s, then closes
  /// every stream so nothing keeps this client alive after the app itself
  /// is gone. Not called on ordinary sign-out — that's [disconnect] alone,
  /// since a later sign-in re-lists on the same, still-open streams.
  void dispose() {
    disconnect();
    _orderUpdates.close();
    _walletUpdates.close();
    _notifications.close();
    _kycStatus.close();
    _quotes.close();
    _orderBooks.close();
    _reconnected.close();
  }

  /// `market:subscribe` — public room, safe to pass any ticker list; the
  /// server enforces nothing extra here (see class header). Call on screen
  /// entry.
  void subscribeMarket(List<String> tickers) {
    if (tickers.isEmpty) return;
    _socket?.emit('market:subscribe', tickers);
  }

  /// `market:unsubscribe` — call on screen exit, mirroring [subscribeMarket].
  void unsubscribeMarket(List<String> tickers) {
    if (tickers.isEmpty) return;
    _socket?.emit('market:unsubscribe', tickers);
  }

  /// Every event name this client decodes — [_wireListeners] registers one
  /// real socket.io handler per entry, all forwarding to [handleEvent]. The
  /// same list a test iterates to exercise every surface.
  static const handledEvents = <String>[
    'order:update',
    'wallet:update',
    'notification:new',
    'kyc:status',
    'market:quote',
    'market:orderBook',
  ];

  void _wireListeners(IO.Socket socket) {
    socket.onReconnect((_) => _reconnected.add(null));
    for (final event in handledEvents) {
      socket.on(event, (data) => handleEvent(event, data));
    }
  }

  /// Decodes one event's raw payload and pushes it onto the matching
  /// stream — the single place every payload in this class is parsed,
  /// reused by both the real socket ([_wireListeners]) and tests, which
  /// call this directly to feed a synthetic event with no live socket
  /// involved at all. Exactly mirrors what a real incoming socket.io event
  /// does: decode via the SAME parser [_wireListeners] would use, then
  /// [StreamController.add] — no network call either way.
  @visibleForTesting
  void handleEvent(String event, dynamic data) {
    final json = _asMap(data);
    if (json == null) return;
    try {
      switch (event) {
        case 'order:update':
          _orderUpdates.add(Order.fromJson(json));
        case 'wallet:update':
          _walletUpdates.add(json);
        case 'notification:new':
          _notifications.add(json);
        case 'kyc:status':
          _kycStatus.add(RealtimeKycStatus.fromJson(json));
        case 'market:quote':
          _quotes.add(RealtimeQuote.fromJson(json));
        case 'market:orderBook':
          _orderBooks.add(OrderBook.fromJson(json));
      }
    } catch (_) {
      // A malformed single event must never take the socket down — the
      // next event (or the next reconnect refetch) still arrives.
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
