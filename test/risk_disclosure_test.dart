// Coverage for the risk-disclosure checkbox on the order-confirmation step
// (trade_flows.dart's `_BuyReviewSheet`, `KLinkedCheckbox` reading "I have
// read the Risk Disclosure") becoming a ONE-TIME-PER-INVESTOR
// acknowledgement rather than a per-order one — see docs/redesign/
// DECISIONS.md's R-5x follow-up to R-51, and RiskDisclosureStore
// (lib/data/api/risk_disclosure_store.dart), which backs it.
//
// test/shots_flows.dart's buy specs (buy_pin_s30, buy_placed_s31,
// buy_market_closed_interstitial_s29c) already exercise — and now describe
// ONLY — the first-order case: their `_mockPlatformChannels()` seeds a
// fresh in-memory secure store per test with no risk-disclosure record, so
// the checkbox they tap is genuinely the first-ever one for that fixture
// investor. This file adds the three cases that pass brief calls out:
//
//   1. an investor who has never traded sees the checkbox and cannot place
//      until it's ticked
//   2. an investor who has already traded sees no checkbox and can place
//      directly
//   3. a failed order, and separately a passcode prompt the investor backs
//      out of, do NOT record acceptance — the next attempt still asks
//
//   flutter test test/risk_disclosure_test.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/data/api/risk_disclosure_store.dart';
import 'package:kudimata_invest/data/repositories/market_status_repository.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart' show KErrorView;
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart' show KButton;

import 'fixtures/mock_api_adapter.dart';

/// Loads the real display/body fonts, same as shots_flows.dart — without
/// this, fallback font metrics render `_PriceSheet`/`_BuySharesSheet`'s
/// fixed-width summary rows wide enough to overflow, which flutter_test
/// treats as a genuine (test-failing) rendering exception even though it
/// has nothing to do with what this file is checking.
Future<void> _loadFonts() async {
  final display = FontLoader('Nunito');
  for (final p in const [
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-Black.ttf',
  ]) {
    display.addFont(rootBundle.load(p));
  }
  await display.load();

  final core = FontLoader('Nunito Sans');
  for (final p in const [
    'assets/fonts/NunitoSans-Regular.ttf',
    'assets/fonts/NunitoSans-Medium.ttf',
    'assets/fonts/NunitoSans-SemiBold.ttf',
    'assets/fonts/NunitoSans-Bold.ttf',
  ]) {
    core.addFont(rootBundle.load(p));
  }
  await core.load();
}

const _kTestPasscode = '135790';
const _kTestSalt = 'risk-disclosure-fixed-salt';
String _testPasscodeHash() =>
    sha256.convert(utf8.encode('$_kTestSalt:$_kTestPasscode')).toString();

/// Same real in-memory `flutter_secure_storage` backing security_persistence_
/// test.dart / shots_flows.dart use — needs to actually persist writes (not
/// a null-always mock) so `RiskDisclosureStore.hasAccepted`/`recordAccepted`
/// and `PasscodeStore.verifyPasscode`/`.owner` have something real to read
/// back, and this file's own assertions can inspect the same backing map a
/// widget under test just wrote to.
Map<String, String> _mockSecureStorage({Map<String, String>? seed}) {
  final store = <String, String>{...?seed};
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'read':
          return store[args['key'] as String?];
        case 'write':
          final key = args['key'] as String?;
          final value = args['value'] as String?;
          if (key != null && value != null) store[key] = value;
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        case 'containsKey':
          return store.containsKey(args['key'] as String?);
        case 'delete':
          store.remove(args['key'] as String?);
          return null;
        case 'deleteAll':
          store.clear();
          return null;
        default:
          return null;
      }
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => call.method == 'getAll' ? <String, dynamic>{} : null,
  );
  return store;
}

/// Wraps a real [MockApiAdapter] but answers `POST /orders` with a genuine
/// error envelope instead — the same `{"error": {...}}` shape
/// MockNetwork.error's own 500 uses (mock_api_adapter.dart), which
/// ApiClient's interceptor parses into a real [ApiException]. Deliberately
/// NOT `MockNetwork.error`: that fails EVERY request this adapter answers,
/// including the ones needed just to reach the review screen (market
/// status, the asset itself, /users/me) — this needs everything ELSE to
/// keep working and only order placement to fail, the same way a real
/// backend rejecting one order while staying reachable for everything else
/// would.
class _OrderFailsAdapter implements HttpClientAdapter {
  _OrderFailsAdapter(this._inner);
  final MockApiAdapter _inner;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path == '/orders') {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {
            'code': 'MOCK_ORDER_REJECTED',
            'message': 'Mock order rejection (test/risk_disclosure_test.dart).',
          },
        }),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }
}

/// Mounts the app already signed in and fully eligible to trade (same
/// baseline shots_flows.dart's own `_mount` uses), routed straight to
/// MTNN's asset-detail screen so `Buy` is one tap away.
Future<GoRouter> _mountAtAssetDetail(WidgetTester tester, {required HttpClientAdapter adapter}) async {
  tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = KPalette.light;

  final apiClient = ApiClient()..dio.httpClientAdapter = adapter;
  final state = AppState()
    ..signedIn = true
    ..biometricEnabled = true
    ..passcodeSet = true
    ..kycSubmitted = true
    ..kycApproved = true
    ..apiClient = apiClient
    ..kycForm = KycFormState();

  // Deterministic "market open" — see shots_flows.dart's identical comment
  // for why this must run inside runAsync under testWidgets's FakeAsync
  // zone.
  await tester.runAsync(() => state.refreshMarketStatus(MarketStatusRepository(apiClient)));

  final router = buildRouter(state);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  router.go(Routes.assetDetail('MTNN'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  return router;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Drives Buy → "Name your price" → Continue (the price sheet starts
/// pre-filled with the live quote) → 60 shares → Review order. Lands on
/// `_BuyReviewSheet` — same steps test/shots_flows.dart's `buy_review_s29`
/// spec uses.
Future<void> _driveToReview(WidgetTester tester) async {
  await _tapText(tester, 'Buy');
  await _tapText(tester, 'Name your price');
  await _tapText(tester, 'Continue');
  await tester.enterText(find.byType(TextField).first, '60');
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await _tapText(tester, 'Review order');
}

KButton _findButton(WidgetTester tester, String label) =>
    tester.widget<KButton>(find.widgetWithText(KButton, label).first);

void main() {
  setUpAll(_loadFonts);

  group('never-traded investor', () {
    testWidgets('sees the checkbox and cannot place until it is ticked', (tester) async {
      _mockSecureStorage(seed: {
        'kudimata.passcode.hash': _testPasscodeHash(),
        'kudimata.passcode.salt': _kTestSalt,
        'kudimata.passcode.owner': 'first-timer@example.com',
        // Deliberately no 'kudimata.riskDisclosure.acceptedOwner' key —
        // a fresh install/never-traded investor.
      });
      await _mountAtAssetDetail(tester, adapter: MockApiAdapter());
      await _driveToReview(tester);

      expect(find.text('I have read the'), findsOneWidget,
          reason: 'first order ever must still show the risk-disclosure checkbox');
      expect(_findButton(tester, 'Place order').onPressed, isNull,
          reason: 'Place order must stay disabled until the checkbox is ticked');

      await _tapText(tester, 'I have read the');
      expect(_findButton(tester, 'Place order').onPressed, isNotNull,
          reason: 'ticking the checkbox unlocks Place order, unchanged from before this pass');
    });
  });

  group('investor who has already traded', () {
    testWidgets('sees no checkbox and can place directly', (tester) async {
      _mockSecureStorage(seed: {
        'kudimata.passcode.hash': _testPasscodeHash(),
        'kudimata.passcode.salt': _kTestSalt,
        'kudimata.passcode.owner': 'returning@example.com',
        'kudimata.riskDisclosure.acceptedOwner': 'returning@example.com',
      });
      await _mountAtAssetDetail(tester, adapter: MockApiAdapter());
      await _driveToReview(tester);

      expect(find.text('I have read the'), findsNothing,
          reason: 'a repeat order must not show the checkbox at all, not even ticked-and-disabled');
      expect(_findButton(tester, 'Place order').onPressed, isNotNull,
          reason: 'Place order must be enabled on its own for a returning investor');

      await _tapText(tester, 'Place order');
      expect(find.text('Confirm your purchase'), findsOneWidget,
          reason: 'tapping Place order with no checkbox present must still reach the real '
              'passcode confirmation, i.e. it placed directly');
    });
  });

  group('a first order that never actually succeeds', () {
    testWidgets('failing at order placement does not record acceptance', (tester) async {
      final backing = _mockSecureStorage(seed: {
        'kudimata.passcode.hash': _testPasscodeHash(),
        'kudimata.passcode.salt': _kTestSalt,
        'kudimata.passcode.owner': 'unlucky@example.com',
      });
      await _mountAtAssetDetail(
        tester,
        adapter: _OrderFailsAdapter(MockApiAdapter()),
      );
      await _driveToReview(tester);
      await _tapText(tester, 'I have read the');
      await _tapText(tester, 'Place order');

      for (final digit in _kTestPasscode.split('')) {
        await tester.tap(find.text(digit).last);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(KErrorView), findsOneWidget,
          reason: 'the mocked adapter rejects POST /orders — this must land on the real '
              'order-failed error view, not a placed screen');
      expect(backing['kudimata.riskDisclosure.acceptedOwner'], isNull,
          reason: 'a failed order must never write the acceptance record');
      expect(await RiskDisclosureStore().hasAccepted('unlucky@example.com'), isFalse,
          reason: 'the next attempt by this same investor must still see the checkbox');
    });

    testWidgets('backing out at the passcode prompt does not record acceptance', (tester) async {
      final backing = _mockSecureStorage(seed: {
        'kudimata.passcode.hash': _testPasscodeHash(),
        'kudimata.passcode.salt': _kTestSalt,
        'kudimata.passcode.owner': 'cold-feet@example.com',
      });
      await _mountAtAssetDetail(tester, adapter: MockApiAdapter());
      await _driveToReview(tester);
      await _tapText(tester, 'I have read the');
      await _tapText(tester, 'Place order');

      expect(find.text('Confirm your purchase'), findsOneWidget,
          reason: 'ticking + Place order must reach the passcode prompt before anything is placed');

      // Dismiss the modal passcode sheet without entering a code — a tap on
      // the barrier well above the sheet's own content, same as an
      // investor backing out with a swipe-down/back gesture.
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text('Confirm your purchase'), findsNothing,
          reason: 'the passcode sheet must actually be dismissed for this to be a real test '
              'of backing out');
      expect(backing['kudimata.riskDisclosure.acceptedOwner'], isNull,
          reason: 'backing out before the order is ever placed must never record acceptance');
      expect(await RiskDisclosureStore().hasAccepted('cold-feet@example.com'), isFalse);
    });
  });
}
