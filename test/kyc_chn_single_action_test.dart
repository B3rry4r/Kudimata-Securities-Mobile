// A-8 regression test (2026-08-29 product-owner audit): "on KYC if user has
// no CHN they can't skip and two buttons are confusing on a no or yes
// thing." chn_screen.dart used to draw a "Continue" button AND a ghost
// "Skip — create one for me" button — with "No" selected, both called the
// identical `_goToNextStep()`, so one control was labelled "Skip" for a tap
// that behaved exactly like the other. Fixed to ONE footer action whose
// label names what THIS tap does for the current radio selection. This file
// drives the real screen (not just reading source) to prove there is
// exactly one control in the footer, and that its label/behaviour tracks
// the radio selection correctly in both directions.
//
//   flutter test test/kyc_chn_single_action_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/chn_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

import 'fixtures/mock_api_adapter.dart';

void _mockPlatformChannels() {
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
        default:
          return null;
      }
    },
  );
}

Future<GoRouter> _mount(WidgetTester tester, {String? kycChn}) async {
  _mockPlatformChannels();
  final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter(kycChn: kycChn);
  final state = AppState()
    ..signedIn = true
    ..passcodeSet = true
    ..biometricEnabled = false
    ..apiClient = apiClient
    ..kycForm = KycFormState();
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
  router.go(Routes.kycChn);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  return router;
}

void main() {
  testWidgets('no CHN on the draft: exactly one footer button, labelled "Skip"', (tester) async {
    await _mount(tester, kycChn: null);
    expect(find.byType(ChnScreen), findsOneWidget);

    // Exactly one action in the footer — never a second "Continue" sitting
    // alongside it.
    expect(find.text('Skip — create one for me'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('a draft that already has a CHN: exactly one footer button, labelled "Continue"',
      (tester) async {
    await _mount(tester, kycChn: '1234567890');
    expect(find.byType(ChnScreen), findsOneWidget);

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip — create one for me'), findsNothing);
  });

  testWidgets('selecting "Yes, I have a CHN" flips the single button to "Continue"', (tester) async {
    await _mount(tester, kycChn: null);
    expect(find.text('Skip — create one for me'), findsOneWidget);

    await tester.tap(find.text('Yes, I have a CHN'));
    await tester.pump();

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip — create one for me'), findsNothing);
  });

  testWidgets('selecting "No, or I\'m not sure" flips the single button back to "Skip"', (tester) async {
    await _mount(tester, kycChn: '1234567890');
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text("No, or I'm not sure — request one for me"));
    await tester.pump();

    expect(find.text('Skip — create one for me'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('tapping the single "Skip" button (no CHN) is not blocked and advances the flow',
      (tester) async {
    // Owner's words: "if user has no CHN they can't skip" — this proves
    // there is no real blocker: the button is enabled and a tap advances
    // past this screen (Continue is never disabled for the "No" state, and
    // no hidden validation fires for an empty field the investor was never
    // asked to fill).
    final router = await _mount(tester, kycChn: null);

    await tester.tap(find.text('Skip — create one for me'));
    await pumpUntil(
      tester,
      () => router.routerDelegate.currentConfiguration.uri.toString() != Routes.kycChn,
      'navigation away from /kyc/chn after Skip',
    );
    // The location changes as soon as context.go() is called, but the old
    // page can still be mid-transition-out in the Navigator for a couple
    // more frames — settle those before asserting it's gone, same pattern
    // every other flow-walk test in this suite uses after a tap.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final loc = router.routerDelegate.currentConfiguration.uri.toString();
    expect(loc, isNot(Routes.kycChn));
    expect(find.byType(ChnScreen), findsNothing);
  });
}

/// Bounded polling — this app has periodic timers that never let
/// pumpAndSettle return, so every wait here is a short, named condition
/// instead (same helper/shape as market_closed_banner_alert_test.dart's).
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
