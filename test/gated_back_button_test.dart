// B-2 regression test (2026-08-29 audit): "why is my own phone back button
// designed to remove the app and not go back?" Walks the ACTUAL system-back
// path (Navigator.maybePop() on the route's own Navigator — the same
// load-bearing check security_persistence_test.dart's A-6 resume-lock test
// already uses, which is what canPop/onPopInvokedWithResult actually gate)
// through several stages of the gated flow and asserts it navigates
// deliberately instead of falling through to the OS. See app_router.dart's
// `themedGated`/`_handleGatedBack` and routes.dart's
// `gatedBackTarget`/`backExitAllowed`/`backBlockedMessage`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/chn_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_checklist_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/screens/onboarding/otp_screen.dart';
import 'package:kudimata_invest/screens/onboarding/sign_up_screen.dart';
import 'package:kudimata_invest/screens/onboarding/biometric_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_intro.dart';
import 'package:kudimata_invest/screens/kyc/bvn_nin.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

import 'fixtures/mock_api_adapter.dart';

Future<GoRouter> _mount(WidgetTester tester, String location, {AppState? state}) async {
  // A phone-shaped surface — flutter_test's ~800×600 desktop-shaped default
  // triggers unrelated pre-existing overflow warnings on width/height-
  // sensitive screens (e.g. sign_up_screen.dart's name step, three KInputs
  // tall since the 2026-08-30 middle-name addition), which have nothing to
  // do with what this test is checking (hardware-back routing). Same fix
  // security_persistence_test.dart's A-6 mountUnlocked already applies, for
  // the same documented reason.
  tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final appState = state ?? AppState();
  final router = buildRouter(appState);
  await tester.pumpWidget(
    AppScope(
      state: appState,
      child: MaterialApp.router(theme: KTheme.light(), routerConfig: router),
    ),
  );
  router.go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return router;
}

/// Simulates the Android hardware back button / iOS edge swipe on the
/// currently-showing [themedGated] screen — the exact mechanism
/// canPop/onPopInvokedWithResult gate (see PopScope's own doc comment: an
/// explicit context.pop()/context.go() is NOT gated by canPop, only this
/// is), same pattern security_persistence_test.dart's A-6 test already
/// uses for the resume-lock's PopScope.
Future<void> _pressHardwareBack(WidgetTester tester) async {
  // find.byType(PopScope) only matches the bare PopScope<dynamic>
  // instantiation via exact Type equality — themedGated's PopScope infers
  // PopScope<Object> instead (from its typed onPopInvokedWithResult
  // callback), a difference with no runtime behavior implication but which
  // find.byType's generic-blind matching misses. A predicate finder (`is`,
  // which respects generic covariance) finds it either way.
  final popScopeElement =
      find.byWidgetPredicate((w) => w is PopScope).evaluate().first;
  final navigator = Navigator.of(popScopeElement);
  await navigator.maybePop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('hardware back on /otp goes to /signup, not the OS', (tester) async {
    await _mount(tester, Routes.otp);
    expect(find.byType(OtpScreen), findsOneWidget);

    await _pressHardwareBack(tester);

    expect(find.byType(OtpScreen), findsNothing);
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets('hardware back on /kyc/bvn goes to /kyc (kycIntro), not the OS', (tester) async {
    await _mount(tester, Routes.kycBvn);
    expect(find.byType(BvnNinScreen), findsOneWidget);

    await _pressHardwareBack(tester);

    expect(find.byType(BvnNinScreen), findsNothing);
    expect(find.byType(KycIntroScreen), findsOneWidget);
  });

  testWidgets(
    'hardware back on /biometric (no back arrow by design) blocks with a message, does not exit or navigate away',
    (tester) async {
      await _mount(tester, Routes.biometric);
      expect(find.byType(BiometricScreen), findsOneWidget);

      await _pressHardwareBack(tester);

      // Still on BiometricScreen — neither silently closed nor bounced
      // elsewhere — and the reason is on screen, not just absent. Material's
      // SnackBar renders its content Text twice (content + an offstage/
      // semantics duplicate) — findsWidgets, not findsOneWidget, is correct
      // here.
      expect(find.byType(BiometricScreen), findsOneWidget);
      expect(find.text(Routes.backBlockedMessage[Routes.biometric]!), findsWidgets);
    },
  );

  group('R-45 as amended — session-lock-aware KYC back (DECISIONS.md, 2026-08-29)', () {
    // "the draft screens should be properly disconnected... now on resume I
    // can now go back to old things I have done before by pressing the back
    // button" — corrected by the owner to: "they can go back but on restart
    // they shouldn't be able to do so... on the flow they can go back."
    testWidgets(
      'a step locked from a PREVIOUS session sends hardware back to the checklist hub, not its predecessor',
      (tester) async {
        final state = AppState()
          ..signedIn = true
          ..passcodeSet = true
          ..apiClient = (ApiClient()..dio.httpClientAdapter = MockApiAdapter())
          ..kycForm = (KycFormState()..lockSteps({Routes.kycChn}));
        await _mount(tester, Routes.kycChn, state: state);
        expect(find.byType(ChnScreen), findsOneWidget);

        await _pressHardwareBack(tester);

        expect(find.byType(ChnScreen), findsNothing);
        expect(find.byType(KycChecklistScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a step finished DURING this session still sends hardware back to its normal predecessor',
      (tester) async {
        final state = AppState()
          ..signedIn = true
          ..passcodeSet = true
          ..apiClient = (ApiClient()..dio.httpClientAdapter = MockApiAdapter())
          ..kycForm = KycFormState(); // lockedStepRoutes empty — nothing locked yet.
        await _mount(tester, Routes.kycChn, state: state);
        expect(find.byType(ChnScreen), findsOneWidget);

        await _pressHardwareBack(tester);

        // Routes.gatedBackTarget[kycChn] == kycBvn — the ordinary linear
        // predecessor, unaffected when nothing is locked.
        expect(find.byType(ChnScreen), findsNothing);
        expect(find.byType(BvnNinScreen), findsOneWidget);
        expect(find.byType(KycChecklistScreen), findsNothing);
      },
    );

    testWidgets(
      "chn_screen.dart's own on-screen back arrow agrees with hardware back for a locked step",
      (tester) async {
        final state = AppState()
          ..signedIn = true
          ..passcodeSet = true
          ..apiClient = (ApiClient()..dio.httpClientAdapter = MockApiAdapter())
          ..kycForm = (KycFormState()..lockSteps({Routes.kycChn}));
        await _mount(tester, Routes.kycChn, state: state);

        // The visible back chevron — KycTopBar's GestureDetector, found via
        // its own KIcon('back', ...) child rather than assumed tree order
        // (an unscoped/first-of-type GestureDetector lookup can land on an
        // unrelated one). A real tap, not the hardware-back simulation
        // above, so this drives the SAME
        // `onBack: () => context.go(kycBackTarget(...))` a finger tap would.
        await tester.tap(
          find.ancestor(
            of: find.byWidgetPredicate((w) => w is KIcon && w.name == 'back'),
            matching: find.byType(GestureDetector),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ChnScreen), findsNothing);
        expect(find.byType(KycChecklistScreen), findsOneWidget);
      },
    );
  });

  test('welcome (a true entry point) has nothing to go back to — exit is correct there', () {
    // welcome has nothing to go back TO — Routes.backExitAllowed — so
    // _handleGatedBack calls SystemNavigator.pop() rather than navigating.
    // A real app-exit call isn't observable from a widget test (it's a
    // platform channel invocation with no visible effect), so this asserts
    // the map membership _handleGatedBack actually branches on instead.
    expect(Routes.gatedBackTarget.containsKey(Routes.welcome), isFalse);
    expect(Routes.backExitAllowed.contains(Routes.welcome), isTrue);
  });
}
