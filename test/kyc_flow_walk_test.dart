// Flow-walk tests for the 2026-08-29 product-owner audit's KYC findings
// (A-1, A-2, A-4, A-5) — driven by real taps through the real router, not
// just reading source. See docs/redesign/AUDIT-2026-08-29.md.
//
//   flutter test test/kyc_flow_walk_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
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

Future<GoRouter> _mount(WidgetTester tester, String initialLocation) async {
  _mockPlatformChannels();
  KColor.active = KPalette.light;
  final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter();
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
      await tester.tap(find.text('Start'));
      await _settle(tester);

      // The mock's /kyc-submissions/draft GET always returns an existing
      // draft, so a real resume lands on the checklist hub — the point is
      // it never routes through Routes.onboardingPersonal on the way.
      final loc = router.routerDelegate.currentConfiguration.uri.toString();
      expect(loc, isNot(Routes.onboardingPersonal));
      expect(find.byType(KycChecklistScreen), findsOneWidget);
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
    testWidgets('CHN "Skip" never lands on the checklist hub', (tester) async {
      final router = await _mount(tester, Routes.kycChn);
      await tester.tap(find.text('Skip — create one for me'));
      await _settle(tester);

      // With the mock's fully-populated draft (chn/documents/selfie/bank/
      // declarations all already done), the only real next step is next of
      // kin — proving this landed via the real per-step derivation
      // (nextKycStepRoute), not a hardcoded "always go to X".
      final loc = router.routerDelegate.currentConfiguration.uri.toString();
      expect(loc, Routes.kycNextOfKin);
      expect(find.byType(KycChecklistScreen), findsNothing);
      expect(find.byType(NextOfKinScreen), findsOneWidget);
    });
  });

  group('A-5 — every KYC step screen agrees on "of 7"', () {
    for (final route in <String>[
      Routes.kycBvn,
      Routes.kycChn,
      Routes.kycId,
      Routes.kycLiveness,
      Routes.kycUtilityBill,
      Routes.kycBankDcs,
      Routes.kycDeclarations,
      Routes.kycNextOfKin,
    ]) {
      testWidgets('$route shows "of 7"', (tester) async {
        await _mount(tester, route);
        // KycTopBar's stepLabel renders upper-cased ("VERIFICATION · 1 OF 7").
        expect(find.textContaining('OF 7'), findsWidgets);
        expect(find.textContaining('OF 8'), findsNothing);
      });
    }
  });
}
