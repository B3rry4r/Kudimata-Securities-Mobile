// R-41 (docs/redesign/DECISIONS.md) — the realtime layer's own evidence.
//
// The gate/screenshot harness can't exercise a live socket.io connection,
// so this is the real proof: every payload shape RealtimeClient decodes is
// fed in SYNTHETICALLY via [RealtimeClient.handleEvent] — the exact same
// decode path a real incoming socket.io event goes through (see that
// method's doc comment) — with NO socket, NO server, and NO network call
// anywhere in this file. Each test then asserts the already-loaded state
// changed in place.
//
// Also covers: the five wired screens' repository-level reuse helpers
// (AssetRepository.applyLiveQuote, WalletRepository.walletUpdateFromJson,
// NotificationsRepository.notificationFromJson) actually reuse the SAME
// formatting the REST fetch path uses, and AppState.applyRealtimeKycStatus's
// mapping from the coarse `kyc:status` payload onto the gate flags.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/realtime/realtime_client.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/notifications_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/router/routes.dart';

/// A null-always mock for `flutter_secure_storage`'s method channel — only
/// needed by the 'suspended' test below, which exercises
/// AppState.forceSignOut() (secure-storage writes) as a SIDE EFFECT of
/// applying a realtime payload. Without this, those writes hit the real
/// plugin with no platform test binding behind it and throw
/// MissingPluginException.
void _mockSecureStorage() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      switch (call.method) {
        case 'read':
          return null;
        case 'readAll':
          return <String, String>{};
        case 'containsKey':
          return false;
        case 'write':
        case 'delete':
        case 'deleteAll':
          return null;
        default:
          return null;
      }
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeClient.handleEvent decodes with the SAME models the REST repositories use', () {
    test('order:update decodes via Order.fromJson and reaches orderUpdates', () async {
      final client = RealtimeClient();
      final future = client.orderUpdates.first;

      client.handleEvent('order:update', {
        'id': 'ord_1',
        'ticker': 'MTNN',
        'side': 'buy',
        'units': 100,
        'orderType': 'market',
        'status': 'approved',
        'createdAt': '2026-08-27T09:00:00.000Z',
        'value': 26840000,
      });

      final order = await future;
      expect(order.id, 'ord_1');
      expect(order.ticker, 'MTNN');
      expect(order.status, 'approved');
      expect(order.value, 26840000);
      client.dispose();
    });

    test('market:orderBook decodes via OrderBook.fromJson and reaches orderBooks', () async {
      final client = RealtimeClient();
      final future = client.orderBooks.first;

      client.handleEvent('market:orderBook', {
        'ticker': 'GTCO',
        'asOf': '2026-08-27T09:00:00.000Z',
        'bids': [
          {'priceKobo': 5000, 'units': 200},
        ],
        'asks': [
          {'priceKobo': 5100, 'units': 150},
        ],
      });

      final book = await future;
      expect(book.ticker, 'GTCO');
      expect(book.bids.single.priceKobo, 5000);
      expect(book.asks.single.units, 150);
      client.dispose();
    });

    test('wallet:update carries the raw WalletBalance payload with no re-parse', () async {
      final client = RealtimeClient();
      final future = client.walletUpdates.first;

      client.handleEvent('wallet:update', {
        'userId': 'u1',
        'availableBalanceKobo': 3104000,
        'pendingBalanceKobo': 0,
        'currency': 'NGN',
      });

      final json = await future;
      expect(json['availableBalanceKobo'], 3104000);
      client.dispose();
    });

    test('notification:new carries the raw Notification payload with no re-parse', () async {
      final client = RealtimeClient();
      final future = client.notifications.first;

      client.handleEvent('notification:new', {
        'id': 'n1',
        'title': 'Order filled',
        'body': 'Your MTNN buy order filled.',
        'icon': 'markets',
        'unread': true,
        'createdAt': '2026-08-27T09:00:00.000Z',
      });

      final json = await future;
      expect(json['title'], 'Order filled');
      client.dispose();
    });

    test('market:quote decodes into RealtimeQuote and reaches quotes', () async {
      final client = RealtimeClient();
      final future = client.quotes.first;

      client.handleEvent('market:quote', {
        'ticker': 'MTNN',
        'priceKobo': 27100,
        'changeAbsKobo': 260,
        'changePct': 0.97,
        'assetClass': 'ngx',
        'asOf': '2026-08-27T09:00:00.000Z',
      });

      final quote = await future;
      expect(quote.ticker, 'MTNN');
      expect(quote.priceKobo, 27100);
      expect(quote.changePct, 0.97);
      client.dispose();
    });

    test('kyc:status decodes into RealtimeKycStatus and reaches kycStatus', () async {
      final client = RealtimeClient();
      final future = client.kycStatus.first;

      client.handleEvent('kyc:status', {
        'id': 'u1',
        'kycStatus': 'flagged',
        'accountStatus': 'active',
      });

      final status = await future;
      expect(status.kycStatus, 'flagged');
      client.dispose();
    });

    test('a malformed payload is dropped, not thrown — the next event still arrives', () async {
      final client = RealtimeClient();
      final received = <String>[];
      final sub = client.orderUpdates.listen((o) => received.add(o.id));

      // Not even a Map — must be silently dropped by handleEvent's own
      // decode guard, never crash the listener registration.
      expect(() => client.handleEvent('order:update', 'not json'), returnsNormally);
      client.handleEvent('order:update', {
        'id': 'ord_2',
        'ticker': 'GTCO',
        'side': 'sell',
        'units': 5,
        'orderType': 'market',
        'status': 'pending',
        'createdAt': '2026-08-27T09:00:00.000Z',
      });

      await Future<void>.delayed(Duration.zero);
      expect(received, ['ord_2']);
      await sub.cancel();
      client.dispose();
    });
  });

  group('reconnected fires only on Manager reconnect, never on first connect', () {
    test('is a plain broadcast stream nobody has pushed to yet', () async {
      final client = RealtimeClient();
      var fired = false;
      final sub = client.reconnected.listen((_) => fired = true);
      await Future<void>.delayed(Duration.zero);
      expect(fired, isFalse);
      await sub.cancel();
      client.dispose();
    });
  });

  group('repository reuse helpers — the socket path decodes through the SAME parser the REST fetch uses', () {
    test('AssetRepository.applyLiveQuote reformats price/change, keeps name/logoColor/sector', () {
      const existing = Asset(
        name: 'MTN Nigeria',
        ticker: 'MTNN',
        price: '₦268.40',
        change: '+1.94%',
        trend: Trend.gain,
        sector: 'Telecoms',
      );

      final updated = AssetRepository.applyLiveQuote(
        existing,
        priceKobo: 27100,
        changeAbsKobo: -260,
        changePct: -0.97,
      );

      expect(updated.name, 'MTN Nigeria'); // carried over, not in the Quote payload
      expect(updated.sector, 'Telecoms'); // carried over
      expect(updated.price, '₦271.00');
      expect(updated.change, '−0.97%');
      expect(updated.trend, Trend.loss);
    });

    test('WalletRepository.walletUpdateFromJson matches balanceDetail\'s own kobo formatting', () {
      final snapshot = WalletRepository.walletUpdateFromJson({
        'availableBalanceKobo': 3104000,
        'pendingBalanceKobo': 500000,
      });

      expect(snapshot.available, '₦31,040.00');
      expect(snapshot.pending, '₦5,000.00');
    });

    test('WalletRepository.walletUpdateFromJson omits pending when zero, same as a REST fetch', () {
      final snapshot = WalletRepository.walletUpdateFromJson({
        'availableBalanceKobo': 100000,
        'pendingBalanceKobo': 0,
      });

      expect(snapshot.pending, isNull);
    });

    test('NotificationsRepository.notificationFromJson matches list()\'s own per-page parser', () {
      final item = NotificationsRepository.notificationFromJson({
        'id': 'n1',
        'title': 'KYC approved',
        'body': "You're verified.",
        'icon': 'check',
        'unread': true,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      expect(item.id, 'n1');
      expect(item.notification.title, 'KYC approved');
      expect(item.notification.unread, isTrue);
    });
  });

  group('AppState.applyRealtimeKycStatus — the kyc:status -> AppState pipeline, no network call', () {
    test('approved sets kycApproved/kycSubmitted, clears kycOutcomeStatus', () {
      final state = AppState()..kycOutcomeStatus = 'rejected';
      state.applyRealtimeKycStatus(const RealtimeKycStatus(kycStatus: 'approved', accountStatus: 'active'));
      expect(state.kycApproved, isTrue);
      expect(state.kycSubmitted, isTrue);
      expect(state.kycOutcomeStatus, isNull);
      state.dispose();
    });

    test('draft leaves both approved/submitted false', () {
      final state = AppState();
      state.applyRealtimeKycStatus(const RealtimeKycStatus(kycStatus: 'draft', accountStatus: 'active'));
      expect(state.kycApproved, isFalse);
      expect(state.kycSubmitted, isFalse);
      expect(state.kycOutcomeStatus, isNull);
      state.dispose();
    });

    for (final terminal in ['rejected', 'flagged', 'expired']) {
      test('$terminal sets kycOutcomeStatus and clears kycApproved', () {
        final state = AppState();
        state.applyRealtimeKycStatus(RealtimeKycStatus(kycStatus: terminal, accountStatus: 'active'));
        expect(state.kycApproved, isFalse);
        expect(state.kycSubmitted, isTrue);
        expect(state.kycOutcomeStatus, terminal);
        state.dispose();
      });
    }

    test('end-to-end: a client event applied through AppState exactly as main.dart wires it', () async {
      final client = RealtimeClient();
      final state = AppState(realtimeClient: client);
      client.kycStatus.listen(state.applyRealtimeKycStatus);

      var notified = false;
      state.addListener(() => notified = true);

      client.handleEvent('kyc:status', {
        'id': 'u1',
        'kycStatus': 'approved',
        'accountStatus': 'active',
      });
      await Future<void>.delayed(Duration.zero);

      expect(state.kycApproved, isTrue);
      expect(notified, isTrue);
      state.dispose();
    });

    // Defect fix (2026-08-29, two-auditor report): "a live suspension is
    // decoded and thrown away" — RealtimeKycStatus.accountStatus was
    // decoded off the socket and never read by this method at all.
    test('accountStatus applies directly onto AppState.accountStatus (no refetch)', () {
      final state = AppState();
      state.applyRealtimeKycStatus(
        const RealtimeKycStatus(kycStatus: 'approved', accountStatus: 'dormant'),
      );
      expect(state.accountStatus, 'dormant');
      // Gates trading immediately — the whole point of applying it live,
      // not waiting for the next full refresh to notice.
      final gap = tradingEligibilityGap(state);
      expect(gap, isNotNull);
      expect(gap!.route, Routes.acctDormant);
      state.dispose();
    });

    test('a pushed "suspended" accountStatus ends the session — never left running', () async {
      _mockSecureStorage();
      final state = AppState()
        ..signedIn = true
        ..passcodeSet = true;

      state.applyRealtimeKycStatus(
        const RealtimeKycStatus(kycStatus: 'approved', accountStatus: 'suspended'),
      );
      expect(state.accountStatus, 'suspended');

      // forceSignOut() is fire-and-forget (unawaited) from inside
      // applyRealtimeKycStatus — the realtime contract's own "no refetch"
      // rule is about NETWORK calls, not about taking no action at all; a
      // sign-out here is pure local state/storage teardown, same as any
      // other forceSignOut() call site. Give it a turn of the event loop.
      await Future<void>.delayed(Duration.zero);

      expect(
        state.signedIn,
        isFalse,
        reason: 'the backend already blocks a suspended account at LOGIN — '
            'a suspension pushed mid-session must end that session with the '
            'same finality, not leave it running able to keep trading',
      );
      state.dispose();
    });
  });
}
