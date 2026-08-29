// B-1 regression test (2026-08-29 audit): "where is the ask for biometrics
// step on onboarding? and new sign in?" Walks the REAL confirm_passcode_
// screen.dart -> Routes.biometric hand-off (not just reading source) for
// both moments the owner named:
//   1. Onboarding — a fresh signup's first-ever local passcode.
//   2. A new sign-in — AppState.loginPasscodeSetup (log_in_screen.dart's
//      `_completeLogin`, a device with no local passcode for this email).
// Before this pass, confirm_passcode_screen.dart's `_evaluate()` sent case 2
// straight to `hydrateGatingStateAndRoute` (Home), skipping Biometric
// entirely — see that file's diff for the fix.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/onboarding/biometric_screen.dart';
import 'package:kudimata_invest/screens/onboarding/confirm_passcode_screen.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/theme/app_theme.dart';

import 'fixtures/mock_api_adapter.dart';

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

Future<GoRouter> _mount(
  WidgetTester tester, {
  required bool loginPasscodeSetup,
}) async {
  _mockSecureStorage();
  final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter();
  final state = AppState()
    ..apiClient = apiClient
    ..loginPasscodeSetup = loginPasscodeSetup;
  final router = buildRouter(state);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp.router(theme: KTheme.light(), routerConfig: router),
    ),
  );
  // Land directly on Confirm, exactly as create_passcode_screen.dart's
  // context.go(Routes.confirmPasscode, extra: args) does.
  router.go(
    Routes.confirmPasscode,
    extra: const ConfirmPasscodeArgs(code: '135790', reentry: false),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return router;
}

/// Types the 6 digits create_passcode_screen.dart chose ('135790') into
/// ConfirmPasscodeScreen's real keypad, one KKeypad key at a time — the
/// same interaction a real investor makes, not a direct AppState mutation.
Future<void> _typeMatchingPasscode(WidgetTester tester) async {
  for (final digit in '135790'.split('')) {
    final finder = find.text(digit);
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'Moment 1 — onboarding: a fresh signup passcode reaches Biometric',
    (tester) async {
      await _mount(tester, loginPasscodeSetup: false);
      expect(find.byType(ConfirmPasscodeScreen), findsOneWidget);

      await _typeMatchingPasscode(tester);

      expect(
        find.byType(BiometricScreen),
        findsOneWidget,
        reason: 'onboarding is not web/reentry/loginPasscodeSetup, so '
            'confirm_passcode_screen.dart should go(Routes.biometric)',
      );
    },
  );

  testWidgets(
    'Moment 2 — a new sign-in on this device (AppState.loginPasscodeSetup) also reaches Biometric',
    (tester) async {
      await _mount(tester, loginPasscodeSetup: true);
      expect(find.byType(ConfirmPasscodeScreen), findsOneWidget);

      await _typeMatchingPasscode(tester);

      expect(
        find.byType(BiometricScreen),
        findsOneWidget,
        reason: 'B-1 fix: this used to skip straight to '
            'hydrateGatingStateAndRoute (Home) here, never offering '
            'biometrics on a fresh sign-in device',
      );
      expect(find.byType(HomeScreen), findsNothing);
    },
  );
}
