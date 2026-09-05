// Flow-walk tests for the 2026-08-29 product-owner audit's KYC findings
// (A-1, A-2, A-4, A-5) — driven by real taps through the real router, not
// just reading source. See docs/redesign/AUDIT-2026-08-29.md.
//
//   flutter test test/kyc_flow_walk_test.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/chn_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_checklist_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/screens/kyc/next_of_kin.dart';
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

Future<GoRouter> _mount(
  WidgetTester tester,
  String initialLocation, {
  HttpClientAdapter? adapter,
  KycFormState? kycForm,
}) async {
  _mockPlatformChannels();
  KColor.active = KPalette.light;
  final apiClient = ApiClient()..dio.httpClientAdapter = adapter ?? MockApiAdapter();
  final state = AppState()
    ..signedIn = true
    ..passcodeSet = true
    ..biometricEnabled = false
    ..apiClient = apiClient
    ..kycForm = kycForm ?? KycFormState();
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
  router.go(initialLocation);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  return router;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('A-1 — kyc_intro no longer detours through "a few more details"', () {
    testWidgets('Start never reaches onboarding/personal', (tester) async {
      final router = await _mount(tester, Routes.kycIntro);
      await _settle(tester);

      // The mock's /kyc-submissions/draft GET always returns an existing
      // draft, so a real resume lands on the checklist hub automatically —
      // see the A-9 group below for the "no tap needed, hero never shown"
      // assertion. The point here is it never routes through
      // Routes.onboardingPersonal on the way.
      final loc = router.routerDelegate.currentConfiguration.uri.toString();
      expect(loc, isNot(Routes.onboardingPersonal));
      expect(find.byType(KycChecklistScreen), findsOneWidget);
    });
  });

  group('A-9 — kyc_intro no longer reappears mid-flow', () {
    // Product-owner report: "that let's start verifying your kyc should not
    // be showing when user has begun and not completed... I click continue
    // and I still see that screen then the state screen again". kyc_intro.
    // dart used to always render its "Let's verify your identity" hero and
    // wait for a Start tap before checking for an in-progress draft — so a
    // resuming investor saw the hero every single time, then had to tap
    // through it. It now runs that same draft check automatically on entry
    // instead (see kyc_intro.dart's `_checkResume`).
    testWidgets('a resuming investor never sees the hero, lands on the checklist hub directly',
        (tester) async {
      await _mount(tester, Routes.kycIntro);
      await _settle(tester);

      expect(find.text("Let's verify your identity"), findsNothing);
      expect(find.text('Start'), findsNothing);
      expect(find.byType(KycChecklistScreen), findsOneWidget);
    });

    testWidgets('a genuine first-timer (no draft yet) still sees the hero and Start',
        (tester) async {
      _mockPlatformChannels();
      // No mocked /kyc-submissions/draft response returning a real draft —
      // a bare 404-ish null body reproduces "no draft exists yet".
      final apiClient = ApiClient()..dio.httpClientAdapter = _NoDraftAdapter();
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
      router.go(Routes.kycIntro);
      await _settle(tester);

      expect(find.text("Let's verify your identity"), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });
  });

  group('A-2 — BVN/NIN confirmation', () {
    testWidgets('shows real resolved name/dob/phone, not dashes', (tester) async {
      await _mount(tester, Routes.kycBvn);
      await tester.enterText(find.byType(TextField).at(0), '22143459901');
      await tester.enterText(find.byType(TextField).at(1), '77889012345');
      await tester.tap(find.text('Confirm BVN'));
      await _settle(tester);

      expect(find.text('Adebayo Okonkwo'), findsOneWidget);
      expect(find.text('+2348031234567'), findsOneWidget);
      expect(find.text('12 June 1994'), findsOneWidget);
      expect(find.text("Yes, that's me"), findsOneWidget);
      // The old placeholder behaviour — every row reading "—" — must be gone.
      expect(find.text('—'), findsNothing);
    });

    testWidgets('a real bvn/nin failure blocks continuing, with a retry', (tester) async {
      await _mount(tester, Routes.kycBvn);
      // Sentinel understood by MockApiAdapter (see its fetch() override) as
      // a real provider-verification failure, not merely unresolved.
      await tester.enterText(find.byType(TextField).at(0), '00000000000');
      await tester.enterText(find.byType(TextField).at(1), '00000000000');
      await tester.tap(find.text('Confirm BVN'));
      await _settle(tester);

      expect(find.text("We couldn't verify you"), findsOneWidget);
      // No way to advance past a real failure — the confirm screen's
      // primary action must not be reachable.
      expect(find.text("Yes, that's me"), findsNothing);

      await tester.tap(find.text('Try again'));
      await _settle(tester);
      // Back on the form, not silently past it.
      expect(find.text('Your BVN and NIN'), findsOneWidget);
    });
  });

  group('A-4 — a completed step advances to the next step, not the checklist hub', () {
    testWidgets('CHN "Continue" never lands on the checklist hub', (tester) async {
      final router = await _mount(tester, Routes.kycChn);
      // The mock's default draft already has a chn value, so chn_screen.dart
      // prefills `_hasChn = true` and its single footer button (see the A-8
      // single-action fix) reads "Continue" here, not "Skip" — see
      // kyc_chn_single_action_test.dart for the "no chn yet" / "Skip" case
      // this file doesn't need to re-cover.
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      // With the mock's fully-populated draft (chn/documents/selfie/bank/
      // source of funds/declarations all already done), the only real next
      // step is next of kin — proving this landed via the real per-step derivation
      // (nextKycStepRoute), not a hardcoded "always go to X".
      final loc = router.routerDelegate.currentConfiguration.uri.toString();
      expect(loc, Routes.kycNextOfKin);
      expect(find.byType(KycChecklistScreen), findsNothing);
      expect(find.byType(NextOfKinScreen), findsOneWidget);
    });
  });

  group('R-45 as amended — checklist hub tap targets (DECISIONS.md, 2026-08-29)', () {
    // "the draft screens should be properly disconnected... now on resume I
    // can now go back to old things I have done before" — the hub half of
    // the fix (the back-button half lives in gated_back_button_test.dart).
    testWidgets(
      'a step locked from a previous session shows done and non-tappable; only the outstanding step routes',
      (tester) async {
        // The mock's default draft has EVERY real per-item signal already
        // set (chn, id+utility documents, liveness, a primary bank account,
        // sourceOfFunds, pepSelfDeclared) except next-of-kin, which is never independently
        // "done" while status=='draft' (see kyc_checklist_screen.dart's own
        // header) — so this is the exact case the owner described: a draft
        // with documents and a selfie already recorded.
        final locked = {
          Routes.kycChn,
          Routes.kycId,
          Routes.kycLiveness,
          Routes.kycUtilityBill,
          Routes.kycBankDcs,
          Routes.kycSourceOfFunds,
          Routes.kycDeclarations,
        };
        await _mount(tester, Routes.kycChecklist, kycForm: KycFormState()..lockSteps(locked));

        // A locked, done row (CHN) has no tap target — tapping it must NOT
        // navigate away from the hub.
        await tester.tap(find.text('CHN'));
        await _settle(tester);
        expect(find.byType(KycChecklistScreen), findsOneWidget);

        // The one real outstanding step (Next of kin) still routes, via
        // either its own row or the footer "Continue" button. Scrolled into
        // view first: with the source-of-funds step added (2026-09-04) the
        // hub lists eight rows, and the last one falls below the 800x600 test
        // viewport — an off-screen row is a layout fact, not a tap target
        // that stopped working.
        await tester.scrollUntilVisible(find.text('Next of kin'), 120);
        await _settle(tester);
        await tester.tap(find.text('Next of kin'));
        await _settle(tester);
        expect(find.byType(KycChecklistScreen), findsNothing);
        expect(find.byType(NextOfKinScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a step done THIS session (nothing locked yet) stays tappable from the hub',
      (tester) async {
        // Fresh KycFormState — lockedStepRoutes empty, as it is before
        // kyc_intro.dart's resume check ever runs (a step finished during
        // the current session was never snapshotted as "already done
        // before this session", so it must not be treated as locked).
        await _mount(tester, Routes.kycChecklist, kycForm: KycFormState());

        await tester.tap(find.text('CHN'));
        await _settle(tester);
        expect(find.byType(KycChecklistScreen), findsNothing);
        expect(find.byType(ChnScreen), findsOneWidget);
      },
    );
  });

  group('A-5 — every KYC step screen agrees on "of 8"', () {
    for (final route in <String>[
      Routes.kycBvn,
      Routes.kycChn,
      Routes.kycId,
      Routes.kycLiveness,
      Routes.kycUtilityBill,
      Routes.kycBankDcs,
      // Source of funds — step 6, added 2026-09-04 (SEC No Objection
      // condition 2). It is in this list for the same reason every other
      // step is: a new step that forgot to state the right total is exactly
      // the defect this group exists to catch.
      Routes.kycSourceOfFunds,
      Routes.kycDeclarations,
      Routes.kycNextOfKin,
    ]) {
      testWidgets('$route shows "of 8"', (tester) async {
        await _mount(tester, route);
        // KycTopBar's stepLabel renders upper-cased ("VERIFICATION · 1 OF 8").
        expect(find.textContaining('OF 8'), findsWidgets);
        expect(find.textContaining('OF 7'), findsNothing);
      });
    }
  });
}

/// A minimal [HttpClientAdapter] reproducing "no draft exists yet" — a
/// genuine first-timer, as opposed to [MockApiAdapter]'s always-populated
/// draft (used everywhere else in this file). GET /kyc-submissions/draft
/// returns a bare `null` body, matching KycRepository.getDraft()'s own
/// "`if (data == null) return null;`" handling of that real backend
/// response shape. Nothing else this screen touches needs a real value.
class _NoDraftAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      'null',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
