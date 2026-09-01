// The KYC failure-reason wire contract, from the app's side.
//
// The defect these cover, fixed 2026-09-01: the backend computed an
// investor-facing explanation (`buildFailureReasons`, kyc-submissions.
// service.ts) and shipped it under a key nothing read, while this app
// re-derived its own sentences from `verificationSignals` using a second
// copy of the same strings — and stamped `retryable: true` on every one.
// So the backend's tip-off rule for a sanctions/AML match (one generic
// sentence, every other signal withheld, no retry) never reached a screen,
// and the two sentence tables were free to drift apart.
//
// Also covered here: the shapes this app must survive without a provider
// being switched on — a signal that is null, a `failureReasons` that is
// absent entirely, and a `code` this build has never heard of.
//
//   flutter test test/kyc_failure_reasons_test.dart
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
    (call) async => switch (call.method) {
      'read' => null,
      'readAll' => <String, String>{},
      'containsKey' => false,
      _ => null,
    },
  );
}

Future<GoRouter> _mountOutcome(WidgetTester tester, Map<String, dynamic> kycMe) async {
  _mockPlatformChannels();
  KColor.active = KPalette.light;
  final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter(kyc: MockKyc.rejected, kycMeOverride: kycMe);
  final state = AppState()
    ..signedIn = true
    ..passcodeSet = true
    ..biometricEnabled = false
    ..apiClient = apiClient
    ..kycForm = (KycFormState()..setDraftId('KYC-1'));
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  router.go(Routes.kycOutcome);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

/// Every string this screen currently renders — the only way to assert that
/// something is absent from ALL of it, rather than absent from one widget.
String _allText(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join('\n');

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// A vendor-flagged submission carrying the backend's own structured
/// reasons. `reasons` is passed through verbatim, so a test can post the
/// exact JSON a real response would.
Map<String, dynamic> _flagged({
  required List<Map<String, dynamic>> reasons,
  Map<String, bool?>? signals,
  int attemptCount = 1,
}) =>
    {
      'id': 'KYC-1',
      'status': 'flagged',
      'flagReason': 'vendor_verification_failed',
      'attemptCount': attemptCount,
      'maxAttempts': 5,
      'canRetry': true,
      'verificationSignals': ?signals,
      'failureReasons': reasons,
    };

void main() {
  // -------------------------------------------------------------------
  // CASE 1 — one failed check.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 1 — one failed check: the BACKEND\'s sentence, a retry, and the selfie step',
      (tester) async {
    final router = await _mountOutcome(
      tester,
      _flagged(
        signals: const {'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': false},
        reasons: const [
          {
            'code': 'liveness',
            'message': "Your selfie didn't match your ID photo.",
            'retryable': true,
          },
        ],
      ),
    );

    // The full stop is part of the assertion: the reason sentence and the
    // attempts sentence used to run together as "…didn't pass You can try
    // again", because the app composed the first one itself without one.
    expect(
      find.text("Your selfie didn't match your ID photo. You can try again — 4 tries left."),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);

    await _tap(tester, 'Try again');
    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycLiveness);
  });

  // -------------------------------------------------------------------
  // CASE 2 — several failed checks.
  // -------------------------------------------------------------------
  testWidgets('CASE 2 — several failed checks: one sentence each, all retryable, routing unchanged',
      (tester) async {
    final router = await _mountOutcome(
      tester,
      _flagged(
        signals: const {'nin': false, 'bvn': true, 'name': true, 'dob': true, 'liveness': false},
        reasons: const [
          {
            'code': 'nin',
            'message': 'Your NIN details could not be verified against the registry.',
            'retryable': true,
          },
          {
            'code': 'liveness',
            'message': "Your selfie didn't match your ID photo.",
            'retryable': true,
          },
        ],
      ),
    );

    final text = _allText(tester);
    expect(text, contains('Your NIN details could not be verified against the registry.'));
    expect(text, contains("Your selfie didn't match your ID photo."));
    // Two sentences, one space, no run-on.
    expect(
      text,
      contains(
        'Your NIN details could not be verified against the registry. '
        "Your selfie didn't match your ID photo.",
      ),
    );
    expect(find.text('Try again'), findsOneWidget);

    await _tap(tester, 'Try again');
    // BVN & NIN is the earlier of the two steps in the flow's own order.
    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycBvn);
  });

  // -------------------------------------------------------------------
  // CASE 3 — the tip-off case. Correct TODAY, with screening switched off.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 3 — a compliance hold: one generic sentence, no retry control, and not one '
      'word about any other signal', (tester) async {
    await _mountOutcome(
      tester,
      _flagged(
        attemptCount: 0, // attempts to spare — the reason is what withholds the retry
        // Signals that DID fail sit on the row; the backend withheld their
        // messages, and this app must not reconstruct them from the booleans.
        signals: const {'nin': false, 'bvn': true, 'name': false, 'dob': true, 'liveness': false},
        reasons: const [
          {
            'code': 'compliance_hold',
            'message': 'Your verification could not be completed. Contact support for help.',
            'retryable': false,
          },
        ],
      ),
    );

    expect(
      find.text('Your verification could not be completed. Contact support for help.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
    // Nothing that names a list, and nothing that lets a careful reader
    // infer the hit by elimination from the signals still on the row.
    final text = _allText(tester).toLowerCase();
    for (final leak in ['sanction', 'aml', 'pep', 'watchlist', 'screening', 'nin', 'bvn', 'selfie', 'name did']) {
      expect(text, isNot(contains(leak)), reason: 'tip-off leak: "$leak"');
    }
    // No attempts line either — that would say "you can try again" in prose
    // while the button says otherwise.
    expect(text, isNot(contains('tries left')));
  });

  // -------------------------------------------------------------------
  // CASE 7 — screening switched off. The live case today.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 7 — AML screening is off, so `sanctions` is null: completely invisible. No row, '
      'no placeholder, no "pending check", and the real reason still shows', (tester) async {
    await _mountOutcome(
      tester,
      _flagged(
        // Exactly what the live backend sends today: the sixth signal is
        // present on the wire and null, because nothing populates it.
        signals: const {
          'nin': true,
          'bvn': true,
          'name': false,
          'dob': true,
          'liveness': true,
          'sanctions': null,
        },
        reasons: const [
          {
            'code': 'name',
            'message': 'The name on your documents did not match your BVN/NIN record.',
            'retryable': true,
          },
        ],
      ),
    );

    expect(
      find.text(
        'The name on your documents did not match your BVN/NIN record. '
        'You can try again — 4 tries left.',
      ),
      findsOneWidget,
    );
    // A null signal is not a failure, not a warning, and not a waiting state.
    final text = _allText(tester).toLowerCase();
    for (final ghost in ['sanction', 'aml', 'screening', 'compliance', 'pending', 'checking', 'awaiting']) {
      expect(text, isNot(contains(ghost)), reason: 'a switched-off check leaked as "$ghost"');
    }
    // And the retry is still offered — a check nobody ran cannot take it away.
    expect(find.text('Try again'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // CASE 8 — a code this build has never seen.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 8 — an unknown future code: its sentence is shown as-is, it routes to no step, '
      'and nothing crashes', (tester) async {
    final router = await _mountOutcome(
      tester,
      _flagged(
        signals: const {'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': true},
        reasons: const [
          {
            'code': 'address_verification',
            'message': 'We could not confirm your home address.',
            'retryable': true,
          },
        ],
      ),
    );

    expect(
      find.text('We could not confirm your home address. You can try again — 4 tries left.'),
      findsOneWidget,
    );
    // The code names no step in this flow, so the retry hands the investor
    // to the checklist hub rather than guessing a step for them.
    await _tap(tester, 'Try again');
    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycChecklist);
    // The hub loads its own steps on arrival — let that finish, or its Dio
    // request outlives the widget and trips the pending-timer teardown
    // check, which has nothing to do with what this test asserts.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('CASE 8 — an unknown code that is NOT retryable still removes the retry control',
      (tester) async {
    await _mountOutcome(
      tester,
      _flagged(
        attemptCount: 0,
        reasons: const [
          {'code': 'future_hold', 'message': 'We cannot continue with your application.', 'retryable': false},
        ],
      ),
    );

    expect(find.text('We cannot continue with your application.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
  });

  testWidgets('CASE 8 — a reason carrying no sentence renders no blank line, and its retryable still counts',
      (tester) async {
    await _mountOutcome(
      tester,
      _flagged(
        attemptCount: 0,
        reasons: const [
          {'code': 'future_hold', 'message': '', 'retryable': false},
        ],
      ),
    );

    // Generic copy rather than an empty message, and the non-retryable
    // entry still governs the control.
    expect(find.textContaining("We weren't able to verify your details."), findsNothing);
    expect(find.textContaining('One of our team needs to take a closer look'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // CASE 6 — no failure information at all, and the safety fallback.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 6 — no failureReasons, no signals, no detail: a sane screen, a live button, no crash',
      (tester) async {
    final router = await _mountOutcome(
      tester,
      const {
        'id': 'KYC-1',
        'status': 'flagged',
        'flagReason': 'vendor_verification_failed',
        'flagDetail': null,
        'attemptCount': 1,
        'maxAttempts': 5,
        'canRetry': true,
      },
    );

    expect(
      find.text(
        'One of our team needs to take a closer look at your submission. '
        'You can try again — 4 tries left.',
      ),
      findsOneWidget,
    );
    // The internal enum is never shown to an investor.
    expect(_allText(tester), isNot(contains('vendor_verification_failed')));

    // The button is real: no signals to narrow by means the flow's start.
    await _tap(tester, 'Try again');
    expect(router.routerDelegate.currentConfiguration.uri.toString(), Routes.kycBvn);
  });

  testWidgets(
      'the fallback composes NO per-signal sentence of its own — the strings live in the '
      'backend, and a response without failureReasons has none to show', (tester) async {
    await _mountOutcome(
      tester,
      const {
        'id': 'KYC-1',
        'status': 'flagged',
        'flagReason': 'vendor_verification_failed',
        'flagDetail': null,
        'attemptCount': 1,
        'maxAttempts': 5,
        'canRetry': true,
        // A failed selfie the app can SEE, and still must not narrate: it
        // used to keep its own copy of the sentence for exactly this.
        'verificationSignals': {'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': false},
      },
    );

    final text = _allText(tester);
    expect(text, isNot(contains('liveness')));
    expect(text, isNot(contains('selfie')));
    expect(text, isNot(contains('Your face liveness check')));
    expect(text, contains('One of our team needs to take a closer look at your submission.'));
    // Honest in both directions: the fallback asserts nothing about
    // retryability, so the server's own attempt count still governs.
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('staff free text in flagDetail is still shown, and still gets its full stop',
      (tester) async {
    await _mountOutcome(
      tester,
      const {
        'id': 'KYC-1',
        'status': 'rejected',
        'flagReason': 'document_unclear',
        'flagDetail': 'The photo page of your passport was too dark to read',
        'attemptCount': 1,
        'maxAttempts': 5,
      },
    );

    expect(
      find.text(
        'The photo page of your passport was too dark to read. '
        'You can try again — 4 tries left.',
      ),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------
  // CASE 5 — attempts exhausted outranks any retryable reason.
  // -------------------------------------------------------------------
  testWidgets('CASE 5 — attempts exhausted: no retry however retryable the reason says it is',
      (tester) async {
    await _mountOutcome(
      tester,
      _flagged(
        attemptCount: 5,
        reasons: const [
          {
            'code': 'liveness',
            'message': "Your selfie didn't match your ID photo.",
            'retryable': true,
          },
        ],
      ),
    );

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
    expect(
      find.textContaining("Your selfie didn't match your ID photo. You've used all 5 attempts"),
      findsOneWidget,
    );
  });

  testWidgets('a reason missing `retryable` altogether is treated as a decision, never as a retry',
      (tester) async {
    await _mountOutcome(
      tester,
      _flagged(
        attemptCount: 0,
        reasons: const [
          {'code': 'compliance_hold', 'message': 'Your verification could not be completed.'},
        ],
      ),
    );

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
  });
}
