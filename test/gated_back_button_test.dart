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
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/onboarding/otp_screen.dart';
import 'package:kudimata_invest/screens/onboarding/sign_up_screen.dart';
import 'package:kudimata_invest/screens/onboarding/biometric_screen.dart';
import 'package:kudimata_invest/screens/kyc/kyc_intro.dart';
import 'package:kudimata_invest/screens/kyc/bvn_nin.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

Future<GoRouter> _mount(WidgetTester tester, String location) async {
  final state = AppState();
  final router = buildRouter(state);
  await tester.pumpWidget(
    AppScope(
      state: state,
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
