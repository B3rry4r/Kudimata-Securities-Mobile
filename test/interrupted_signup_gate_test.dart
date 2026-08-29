// Defect 1 regression test (two-auditor report, 2026-08-29): "an
// interrupted signup produces a funded account with no device lock."
//
// The trace that was reported: otp_screen.dart:135 persists the auth token
// the moment OTP verifies — BEFORE passcode creation runs. Kill the app
// anywhere between OTP verify and passcode confirm (a phone call, low
// battery) and the next cold start hydrates signedIn=true (a token exists)
// with passcodeSet=false (no local credential was ever created). Before
// this fix, app_router.dart's `_gateRedirect` had no branch for that
// combination: the cold-start-unlock force required passcodeSet==true (so
// it never fired), and /splash + /welcome are both preAuthOnly, so a
// signed-in investor there was sent straight to Home — skipping
// suitability, risk disclosure, legal terms, passcode and biometric
// entirely.
//
// This test drives the ACTUAL interruption, not a description of it: seeds
// real (mocked) secure storage with an access token and NOTHING else — no
// passcode hash — exactly the state a device is left in when it dies
// before create_passcode_screen.dart/confirm_passcode_screen.dart ever run.
// A brand-new AppState then runs the SAME cold-start hydration main.dart's
// real bootstrap runs, and the router's `_gateRedirect` is exercised for
// real (buildRouter, no short-circuiting) — this asserts on the ACTUAL
// rendered screen, same discipline as biometric_reachability_test.dart, not
// on the route table (a prior ruling in this repo was reported done four
// times by agents who only read routes).
//
//   flutter test test/interrupted_signup_gate_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/screens/onboarding/create_passcode_screen.dart';
import 'package:kudimata_invest/screens/onboarding/welcome_slider_screen.dart';
import 'package:kudimata_invest/screens/suitability/terms_and_privacy_screen.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

/// Bounded polling — this app has periodic timers (splash's own beat,
/// otp_screen.dart's resend countdown, elsewhere) that never let
/// `pumpAndSettle` return, so every wait here is a short, named condition
/// instead. Mirrors integration_test/live_gate_test.dart's helper of the
/// same name and shape.
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
  fail('Timed out after ${timeout.inSeconds}s waiting for $what');
}

/// A REAL in-memory backing for `flutter_secure_storage`'s method channel —
/// same pattern as test/security_persistence_test.dart's helper of the same
/// name — so a seeded token (and an absent passcode) is genuinely readable
/// back by a real AuthTokenStore/PasscodeStore, not a null-always stub that
/// would just describe the bug rather than reproduce it.
void _mockSecureStorage({Map<String, String>? seed}) {
  final store = <String, String>{...?seed};
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'read':
          return store[args['key'] as String?];
        case 'write':
          final key = args['key'] as String?;
          final value = args['value'] as String?;
          if (key != null && value != null) store[key] = value;
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        case 'containsKey':
          return store.containsKey(args['key'] as String?);
        case 'delete':
          store.remove(args['key'] as String?);
          return null;
        case 'deleteAll':
          store.clear();
          return null;
        default:
          return null;
      }
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => call.method == 'getAll' ? <String, dynamic>{} : null,
  );
}

void main() {
  testWidgets(
    'token saved but passcode never created + cold start: resumes at Create '
    'passcode, never reaches Home unlocked',
    (tester) async {
      // A phone-shaped surface (flutter_test's desktop-shaped default trips
      // unrelated overflow warnings on width-sensitive screens elsewhere in
      // the app, same reasoning as security_persistence_test.dart).
      tester.view.physicalSize = const Size(1170, 2640);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      KColor.active = KPalette.light;

      // THE INTERRUPTION: otp_screen.dart:135 saves a real access token the
      // instant OTP verifies. The device died before create_passcode_screen
      // .dart ever ran — no passcode hash was ever written to the store.
      _mockSecureStorage(seed: {
        'kudimata.auth.accessToken': 'the-token-otp-verify-already-saved',
        'kudimata.auth.refreshToken': 'a-refresh-token',
      });

      final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter();
      final state = AppState()..apiClient = apiClient;

      // The SAME hydration main.dart's real bootstrap runs on every cold
      // start (kicked off by AppState's own constructor; `ready` resolves
      // once signedIn/passcodeSet/biometricEnabled have all settled).
      await state.ready;
      expect(
        state.signedIn,
        isTrue,
        reason: 'a stored access token means this must be treated as a '
            'real, existing account — not a stranger',
      );
      expect(
        state.passcodeSet,
        isFalse,
        reason: 'the exact interruption under test: no passcode was ever '
            'created for this account',
      );

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

      await pumpUntil(
        tester,
        () => find.byType(CreatePasscodeScreen).evaluate().isNotEmpty,
        'the app to resume onboarding at Create passcode',
      );

      // The defect this test guards: this exact state used to skip
      // suitability, risk disclosure, legal terms, passcode and biometric
      // entirely and land signed-in-but-unlocked straight on Home.
      expect(
        find.byType(HomeScreen),
        findsNothing,
        reason: 'DEFECT: a signed-in session with no local passcode must '
            'never reach Home unlocked',
      );
      // Nor should it be bounced back through fresh sign-up — a token
      // already exists for a real, registered account.
      expect(find.byType(WelcomeSliderScreen), findsNothing);
      expect(find.text('Create a passcode'), findsOneWidget);
    },
  );

  testWidgets(
    'the invariant does not hijack the LEGITIMATE fresh-signup flow: '
    'termsOfService itself sets signedIn TRUE (when its documents include '
    'risk_disclosure), still ahead of passcode creation — that hop must '
    'still render, not bounce back to Create passcode',
    (tester) async {
      // A first version of this fix used a hand-picked allowlist of just
      // {createPasscode, confirmPasscode} for the signedIn-without-passcode
      // exemption — and broke exactly this: termsOfService's own accept
      // handler (legal_acceptance_screen.dart's `_accept()`, when `kinds`
      // includes 'risk_disclosure' — every run of the onboarding legal
      // screen since 2026-08-29, see risk_disclaimer_screen.dart's header)
      // flips AppState.signedIn to true BEFORE passcode/biometric ever run,
      // so a signedIn=true + passcodeSet=false moment is legitimately
      // reached mid-flow, not just as a bug. This state is built directly
      // (not via real hydration/secure storage) to isolate the router's OWN
      // decision from that unrelated screen's behaviour — same style as
      // test/gate_redirect_test.dart's `pumpAt`.
      final state = AppState()
        ..signedIn = true
        ..passcodeSet = false
        ..apiClient = (ApiClient()..dio.httpClientAdapter = MockApiAdapter());
      final router = buildRouter(state);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp.router(theme: KTheme.light(), routerConfig: router),
        ),
      );
      await tester.pump();

      router.go(Routes.termsOfService);
      await pumpUntil(
        tester,
        () => find.byType(TermsAndPrivacyScreen).evaluate().isNotEmpty,
        'the terms hop to resolve',
      );
      expect(
        find.byType(TermsAndPrivacyScreen),
        findsOneWidget,
        reason: 'the legitimate mid-signup hop must render, not be bounced '
            'back to Create passcode',
      );

      // The invariant itself must still hold for this exact state: Home is
      // still unreachable.
      router.go(Routes.home);
      await pumpUntil(
        tester,
        () => find.byType(CreatePasscodeScreen).evaluate().isNotEmpty,
        'a deep-link to Home to still be redirected to Create passcode',
      );
      expect(find.byType(HomeScreen), findsNothing);
    },
  );
}
