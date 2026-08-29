// Regression test for the gap flagged in price_alerts_screen.dart's own
// header: s49 ("Set a price alert") has TWO designed entry points — the
// asset page's bell icon (already wired) and the "Market closed" banner's
// (s39) own "Set a price alert" footer button, which had no tap target at
// all. KMarketClosedBanner (market_hours.dart) now takes an optional
// `onSetAlert` callback; this drives the ACTUAL tap and asserts the real
// SetPriceAlertScreen comes up (not just that a callback fired), same
// discipline as this repo's other gate-driven regression tests.
//
//   flutter test test/market_closed_banner_alert_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/screens/markets/market_hours.dart';
import 'package:kudimata_invest/screens/markets/price_alerts_screen.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

import 'fixtures/mock_api_adapter.dart';

/// Bounded polling — this app has periodic timers that never let
/// pumpAndSettle return, so every wait here is a short, named condition
/// instead (same helper/shape as interrupted_signup_gate_test.dart's).
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  } while (DateTime.now().isBefore(deadline));
  fail('Timed out waiting for: $what');
}

/// SetPriceAlertScreen's repositories go through ApiClient's interceptor,
/// which reads the auth token store — undmocked, that hits a real
/// flutter_secure_storage platform channel with no test-harness handler and
/// the request just never resolves. Same setup biometric_reachability_test.
/// dart's `_mockSecureStorage` uses.
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
  testWidgets(
    'tapping "Set a price alert" on the market-closed banner opens SetPriceAlertScreen',
    (tester) async {
      _mockSecureStorage();
      final state = AppState()
        ..apiClient = (ApiClient()..dio.httpClientAdapter = MockApiAdapter());

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: KTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: KMarketClosedBanner(
                  onSetAlert: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetPriceAlertScreen(ticker: 'MTNN')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Set a price alert'), findsOneWidget);
      expect(find.byType(SetPriceAlertScreen), findsNothing);

      await tester.tap(find.text('Set a price alert'));
      await tester.pump();

      await pumpUntil(
        tester,
        () => find.byType(SetPriceAlertScreen).evaluate().isNotEmpty,
        'SetPriceAlertScreen to be pushed',
      );

      expect(find.byType(SetPriceAlertScreen), findsOneWidget);

      await pumpUntil(
        tester,
        () => find.textContaining('MTNN hits a price').evaluate().isNotEmpty,
        'the real MTNN asset to load onto the screen',
      );
    },
  );

  testWidgets(
    'a null onSetAlert omits the affordance instead of showing a dead control',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KTheme.light(),
          home: const Scaffold(body: KMarketClosedBanner()),
        ),
      );
      await tester.pump();

      expect(find.text('The market is closed'), findsOneWidget);
      expect(find.text('Set a price alert'), findsNothing);
    },
  );
}
