// BUG-04 regression test: an already-signed-in investor navigating (however
// it happens — stale browser history, a lingering deep link) to a pre-auth-
// only screen must be bounced to Home, not shown that screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/screens/onboarding/sign_up_screen.dart';
import 'package:kudimata_invest/screens/onboarding/otp_screen.dart';
import 'package:kudimata_invest/screens/onboarding/splash_screen.dart';
import 'package:kudimata_invest/screens/onboarding/reset_passcode_screen.dart';
import 'package:kudimata_invest/screens/onboarding/log_in_screen.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, String location) async {
    final state = AppState()
      ..passcodeSet = true
      ..biometricEnabled = true
      ..kycSubmitted = true
      ..kycApproved = true
      ..suitabilityComplete = true
      ..signedIn = true;
    final router = buildRouter(state);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp.router(theme: KTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();
    router.go(location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('signed-in + /signup redirects to Home, never renders SignUpScreen', (tester) async {
    await pumpAt(tester, Routes.signup);
    expect(find.byType(SignUpScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('signed-in + /otp redirects to Home, never renders OtpScreen', (tester) async {
    await pumpAt(tester, Routes.otp);
    expect(find.byType(OtpScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('signed-in + /splash redirects to Home, never renders SplashScreen', (tester) async {
    await pumpAt(tester, Routes.splash);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('signed-in + /reset redirects to Home, never renders ResetPasscodeScreen', (tester) async {
    await pumpAt(tester, Routes.reset);
    expect(find.byType(ResetPasscodeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('signed-in + /login is NOT blocked — LogInScreen (local unlock mode) still renders', (tester) async {
    // Routes.login is deliberately dual-purpose (see app_router.dart's
    // _gateRedirect header comment) — a signed-in investor legitimately
    // lands here for the passcode-unlock screen, so this must NOT redirect.
    await pumpAt(tester, Routes.login);
    expect(find.byType(LogInScreen), findsOneWidget);
  });
}
