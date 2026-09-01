// Defect A + B regression tests (2026-09-01).
//
// B — "the app restarts the whole flow for a single failed check". The
// backend's retry has isolated correctly for a while: it keeps every check
// that passed, keeps the ID document and the utility bill, and deletes only
// a stale liveness selfie. The app threw all of that away —
// outcome_not_approved.dart's "Try again" called KycFormState.reset() and
// went to /kyc/bvn no matter what had failed, so an investor whose BVN,
// NIN, name and date of birth had all verified was sent to re-enter a BVN
// the server had just confirmed.
//
// A — "a provider outage parks the investor forever". A submission left
// 'pending' because a verification provider never ANSWERED a check had no
// control anywhere in this app: kyc-submitted showed "we're reviewing your
// details" and polled a status nothing on the backend would ever change.
//
// Each test below fails against the pre-2026-09-01 app.
//
//   flutter test test/kyc_targeted_retry_test.dart
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

/// Mounts the real router with a real ApiClient in front of [adapter], on
/// [startRoute]. Returns both the router and the AppState, because half of
/// what these tests assert is what survives on KycFormState.
Future<(GoRouter, AppState)> _mount(
  WidgetTester tester,
  MockApiAdapter adapter, {
  String startRoute = Routes.kycOutcome,
}) async {
  _mockPlatformChannels();
  KColor.active = KPalette.light;
  final apiClient = ApiClient()..dio.httpClientAdapter = adapter;
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
  // Let Home's own async work settle before navigating away (see the same
  // note in kyc_outcome_retry_test.dart).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));

  router.go(startRoute);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return (router, state);
}

String _route(GoRouter router) => router.routerDelegate.currentConfiguration.uri.toString();

/// Taps a control after bringing it into view. kyc-outcome scrolls (its
/// copy can run long), so on a short test viewport the primary button can
/// sit below the fold — a tap there would silently land on nothing.
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The backend's own investor-facing sentence per signal, quoted from
/// `buildFailureReasons()` (Kudimata-Securities-Backend,
/// kyc-submissions.service.ts). Quoted here ON PURPOSE: this fixture is the
/// contract between the two repos, so if the backend rewords a sentence
/// without the app hearing about it, a test here fails rather than the app
/// silently rendering something nobody wrote.
const _backendFailureSentences = {
  'nin': 'Your NIN details could not be verified against the registry.',
  'bvn': 'Your BVN details could not be verified against the registry.',
  'name': 'The name on your documents did not match your BVN/NIN record.',
  'dob': 'Your date of birth did not match your BVN/NIN record.',
  'liveness': "Your selfie didn't match your ID photo.",
};

/// A flagged submission whose per-check signals say exactly what failed —
/// carrying the `failureReasons` a real response has carried since
/// 2026-09-01, derived from the same signals exactly as the backend does.
///
/// `structured: false` drops that field to reproduce the older response
/// shape, which is what the screen's safety fallback exists for.
Map<String, dynamic> _flaggedWith(
  Map<String, bool?> signals, {
  int attemptCount = 1,
  bool structured = true,
}) =>
    {
      'id': 'KYC-1',
      'status': 'flagged',
      'flagReason': 'vendor_verification_failed',
      'flagDetail': 'Verification provider immediate check failed.',
      'attemptCount': attemptCount,
      'maxAttempts': 5,
      'canRetry': true,
      'verificationSignals': {
        'nin': signals['nin'],
        'bvn': signals['bvn'],
        'name': signals['name'],
        'dob': signals['dob'],
        'liveness': signals['liveness'],
      },
      if (structured)
        'failureReasons': [
          for (final entry in _backendFailureSentences.entries)
            if (signals[entry.key] == false)
              {'code': entry.key, 'message': entry.value, 'retryable': true},
        ],
    };

void main() {
  // -------------------------------------------------------------------
  // CASE 1 — one check failed.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 1 — liveness alone failed: Try again lands on the selfie step, not back at BVN, '
      'and the draft the passed checks live on is kept', (tester) async {
    final (router, state) = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.flagged,
        kycMeOverride: _flaggedWith({
          'nin': true,
          'bvn': true,
          'name': true,
          'dob': true,
          'liveness': false,
        }),
      ),
    );

    expect(find.text('Try again'), findsOneWidget);
    await _tap(tester, 'Try again');

    // The one thing that failed — and nothing else.
    expect(_route(router), Routes.kycLiveness);
    // The submission row is REUSED server-side, so the id has to survive;
    // wiping it would orphan the next document upload.
    expect(state.kycForm.draftId, 'KYC-1');
    // Next of kin comes back seeded from the server's own copy, so
    // re-finalizing never asks for it again.
    expect(state.kycForm.nextOfKinName, 'Bola Obi');
    expect(state.kycForm.nextOfKinPhone, '+2348030000000');
  });

  // -------------------------------------------------------------------
  // CASE 2 — several checks failed.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 2 — BVN and liveness both failed: starts at the earlier of the two in the flow order',
      (tester) async {
    final (router, _) = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.flagged,
        kycMeOverride: _flaggedWith({
          'nin': true,
          'bvn': false,
          'name': false,
          'dob': true,
          'liveness': false,
        }),
      ),
    );

    await _tap(tester, 'Try again');

    // BVN & NIN is step 1, the selfie is step 4 — the investor walks them
    // in the flow's own order, and the checklist derivation (which sees the
    // selfie document deleted server-side) carries them on to the second.
    expect(_route(router), Routes.kycBvn);
  });

  testWidgets('CASE 2 — a name/DOB mismatch routes to BVN & NIN, the step that actually re-derives it',
      (tester) async {
    final (router, _) = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.flagged,
        kycMeOverride: _flaggedWith({
          'nin': true,
          'bvn': true,
          'name': false,
          'dob': false,
          'liveness': true,
        }),
      ),
    );

    await _tap(tester, 'Try again');

    expect(_route(router), Routes.kycBvn);
  });

  // -------------------------------------------------------------------
  // CASE 3 — provider unavailable, everything else passed.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 3 — a pending submission left open by an unreachable provider offers one button, '
      'says nothing is wrong with the details, and asks for no input', (tester) async {
    await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.rejected, // overridden wholesale below
        kycMeOverride: const {
          'id': 'KYC-1',
          'status': 'pending',
          'flagReason': null,
          'flagDetail': null,
          'vendorDecision': 'no_decision',
          'attemptCount': 0,
          'maxAttempts': 5,
          'canRetry': true,
          'verificationSignals': {
            'nin': null, // the provider never answered
            'bvn': true,
            'name': true,
            'dob': true,
            'liveness': true,
          },
        },
      ),
    );

    expect(find.text("We couldn't finish checking your ID"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Nothing is wrong with your details'), findsOneWidget);
    expect(find.textContaining("won't need to re-enter"), findsOneWidget);
    // Never dressed as a decision against the investor.
    expect(find.textContaining("We couldn't verify you"), findsNothing);
    expect(find.text('Contact support'), findsNothing);
  });

  testWidgets(
      'CASE 3 — pressing that one button re-runs the check server-side and returns to the '
      'status screen, with no collection step in between', (tester) async {
    final (router, _) = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.rejected,
        kycMeOverride: const {
          'id': 'KYC-1',
          'status': 'pending',
          'flagReason': null,
          'attemptCount': 0,
          'maxAttempts': 5,
          'canRetry': true,
          'verificationSignals': {'nin': null, 'bvn': true, 'name': true, 'dob': true, 'liveness': true},
        },
        // The retry resolved on its own: the server re-ran the lookup from
        // the BVN/NIN already on the row and the submission has a real
        // decision again. It never returns to 'draft'.
        kycRetryOverride: const {
          'status': 'approved',
          'canRetry': false,
          'verificationSignals': {'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': true},
        },
      ),
    );

    await _tap(tester, 'Try again');

    expect(_route(router), Routes.kycSubmitted);
    // Emphatically NOT sent to re-enter anything.
    expect(_route(router), isNot(Routes.kycBvn));
    expect(_route(router), isNot(Routes.kycLiveness));
  });

  testWidgets(
      'CASE 3 (defect A) — kyc-submitted stops parking that investor on "we\'re reviewing" '
      'and moves them to the screen that has the button', (tester) async {
    final (router, _) = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.rejected,
        kycMeOverride: const {
          'id': 'KYC-1',
          'status': 'pending',
          'flagReason': null,
          'attemptCount': 0,
          'maxAttempts': 5,
          'canRetry': true,
          'verificationSignals': {'nin': null, 'bvn': true, 'name': true, 'dob': true, 'liveness': true},
        },
      ),
      startRoute: Routes.kycSubmitted,
    );

    // Past kyc-submitted's first status check (1.4s).
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_route(router), Routes.kycOutcome);
    expect(find.textContaining("We're reviewing"), findsNothing);
  });

  testWidgets(
      'a genuinely ambiguous pending submission (canRetry false) still waits on kyc-submitted — '
      'no invented retry where the server would refuse one', (tester) async {
    final (router, _) = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.rejected,
        kycMeOverride: const {
          'id': 'KYC-1',
          'status': 'pending',
          'flagReason': null,
          'attemptCount': 0,
          'maxAttempts': 5,
          'canRetry': false,
          'verificationSignals': {'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': true},
        },
      ),
      startRoute: Routes.kycSubmitted,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_route(router), Routes.kycSubmitted);
    expect(find.textContaining("We're reviewing"), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // CASE 4 — provider unavailable AND a real failure.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 4 — an unanswered NIN alongside a failed selfie: the selfie is still the '
      'investor\'s to redo, and it is the only thing they are asked for', (tester) async {
    final (router, state) = await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.flagged,
        kycMeOverride: _flaggedWith({
          'nin': null, // provider never answered — the server re-runs this itself
          'bvn': true,
          'name': true,
          'dob': true,
          'liveness': false, // a real failure
        }),
      ),
    );

    await _tap(tester, 'Try again');

    // A null signal is not a step for the investor to walk — only `false` is.
    expect(_route(router), Routes.kycLiveness);
    expect(state.kycForm.draftId, 'KYC-1');
  });

  // -------------------------------------------------------------------
  // CASE 5 — a non-retryable decision is untouched by any of this.
  // -------------------------------------------------------------------
  testWidgets(
      'CASE 5 — a non-retryable (sanctions/AML) decision offers no retry and names no reason, '
      'even with attempts and passed signals on the row', (tester) async {
    await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.rejected,
        kycMeOverride: const {
          'id': 'KYC-1',
          'status': 'flagged',
          'flagReason': 'vendor_verification_failed',
          'attemptCount': 0,
          'maxAttempts': 5,
          'canRetry': true, // the SERVER would grant one; the reason says not to offer it
          'verificationSignals': {'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': true},
          'failureReasons': [
            {
              'code': 'compliance_hold',
              'message': 'Your verification could not be completed. Contact support for help.',
              'retryable': false,
            },
          ],
        },
      ),
    );

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Your verification could not be completed. Contact support for help.'),
        findsOneWidget);
    // Never a per-signal breakdown alongside it — inferring the match by
    // elimination is tipping off just as surely as naming it.
    expect(find.textContaining('sanctions'), findsNothing);
    expect(find.textContaining('AML'), findsNothing);
    expect(find.textContaining('BVN'), findsNothing);
    expect(find.textContaining('NIN'), findsNothing);
  });

  // -------------------------------------------------------------------
  // CASE 6 — attempts exhausted.
  // -------------------------------------------------------------------
  testWidgets('CASE 6 — attempts exhausted: no retry control at all, however specific the failure is',
      (tester) async {
    await _mount(
      tester,
      MockApiAdapter(
        kyc: MockKyc.flagged,
        kycMeOverride: {
          ..._flaggedWith({'nin': true, 'bvn': true, 'name': true, 'dob': true, 'liveness': false}),
          'attemptCount': 5,
          'maxAttempts': 5,
          'canRetry': false,
        },
      ),
    );

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // CASE 9 — expired is the one path that still starts over.
  // -------------------------------------------------------------------
  testWidgets('CASE 9 — an expired submission still restarts from step 1 and still clears the form',
      (tester) async {
    final (router, state) = await _mount(tester, MockApiAdapter(kyc: MockKyc.expired));

    expect(find.text('Start again'), findsOneWidget);
    await _tap(tester, 'Start again');

    expect(_route(router), Routes.kycBvn);
    expect(state.kycForm.draftId, isNull); // a real restart still wipes
  });
}
