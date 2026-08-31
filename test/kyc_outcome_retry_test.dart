// R-50 regression tests (DECISIONS.md, 2026-08-31 — "every failed KYC can
// be retried, and the app says what went wrong"). Drives the real
// kyc-outcome screen (outcome_not_approved.dart) for the three cases R-50
// distinguishes:
//
//   1. 'flagged' with attempts remaining — used to dead-end at "Back to
//      home" forever (the defect the owner hit: a flagged case is the
//      common one, and R-48 only ever covered a retry for 'rejected'). Now
//      offers "Try again" and shows attempts remaining, exactly like
//      'rejected' does.
//   2. A retryable failure with the attempts genuinely spent — "Contact
//      support", never a "Try again" that would just fail again.
//   3. A non-retryable reason (`retryable: false` — the sanctions/AML shape
//      BR-10 requests from the backend, docs/redesign/BACKEND_GAPS.md) —
//      the generic message only, never a specific reason alongside it, and
//      never a retry control regardless of attempts remaining.
//
//   flutter test test/kyc_outcome_retry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

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

Future<GoRouter> _mount(WidgetTester tester, MockApiAdapter adapter) async {
  _mockPlatformChannels();
  KColor.active = KPalette.light;
  final apiClient = ApiClient()..dio.httpClientAdapter = adapter;
  final state = AppState()
    ..signedIn = true
    ..passcodeSet = true
    ..biometricEnabled = false
    ..apiClient = apiClient
    // A real draftId, so a "Try again" tap's KycFormState.reset() is
    // provably doing something (see the first test below).
    ..kycForm = (KycFormState()..setDraftId('KYC-STALE'));
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
  // The initial frame lands on Home (splash's own signedIn redirect) before
  // this test ever navigates away — let its own async work (the "not
  // verified" banner's kycProgressSummary chain) fully settle before
  // leaving, or its underlying Dio request outlives the widget that
  // started it and trips flutter_test's "Timer still pending" teardown
  // check, unrelated to anything this test is actually about.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));

  router.go(Routes.kycOutcome);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

void main() {
  testWidgets('flagged, attempts remaining: offers Try again and shows tries left '
      '(R-50 — flagged used to dead-end here always)', (tester) async {
    // MockKyc.flagged's own fixture: attemptCount 2, maxAttempts 5 -> 3 left.
    final router = await _mount(tester, MockApiAdapter(kyc: MockKyc.flagged));

    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('3 tries left'), findsOneWidget);
    expect(find.text('Contact support'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycBvn);
  });

  testWidgets('rejected, attempts spent: Contact support only, honest about why, no dead button',
      (tester) async {
    final router = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.rejected,
        kycMeOverride: const {'attemptCount': 5, 'maxAttempts': 5},
      ),
    );

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.textContaining("used all 5 attempts"), findsOneWidget);

    await tester.tap(find.text('Contact support'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.acctHelp);
  });

  testWidgets(
      'a non-retryable reason (sanctions/AML shape): generic message only, '
      'never a specific reason, never a retry control regardless of attempts left',
      (tester) async {
    await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.rejected,
        kycMeOverride: const {
          // Attempts genuinely still available — proves the retry control
          // is withheld because of `retryable: false`, not the count.
          'attemptCount': 0,
          'maxAttempts': 5,
          'failureReasons': [
            {
              'code': 'compliance_hold',
              'message': "We couldn't approve your application. Please contact support.",
              'retryable': false,
            },
          ],
        },
      ),
    );

    expect(find.text("We couldn't approve your application. Please contact support."),
        findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
    // No enrichment: none of the ordinary per-signal phrasing this screen
    // uses elsewhere should appear alongside the backend's own generic text.
    expect(find.textContaining('BVN'), findsNothing);
    expect(find.textContaining('NIN'), findsNothing);
  });
}
