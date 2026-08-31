// R-44 — the avatar picker is reached from onboarding, never KYC.
//
// This file used to be onboarding_avatar_and_risk_disclosure_test.dart and
// also drove a real-tap walk through the legal-documents screen's risk-
// disclosure row. That screen (legal_acceptance_screen.dart /
// Routes.termsOfService) is gone — R-51, DECISIONS.md, 2026-08-31: the whole
// suitability/legal-acceptance chain was removed from onboarding. Risk-
// disclosure acknowledgement moved to the trade-confirmation checkbox
// instead (trade_flows.dart, exercised by test/shots_flows.dart's
// 'I have read the' taps) — there is no equivalent onboarding screen left
// for this file to drive. Only the avatar-picker walk survives, renamed to
// match.
//
// Driven by real taps through the real router, not just asserting on
// routes — a prior ruling in this repo was reported done four times by
// agents who only read the route table.
//
//   flutter test test/onboarding_avatar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/screens/onboarding/avatar_screen.dart';
import 'package:kudimata_invest/screens/onboarding/biometric_screen.dart';
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
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => call.method == 'getAll' ? <String, dynamic>{} : null,
  );
}

/// Bounded polling — this app has periodic timers that never let
/// `pumpAndSettle` return, so every wait here is a short, named condition
/// instead (same helper as test/interrupted_signup_gate_test.dart).
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

Future<GoRouter> _mount(
  WidgetTester tester,
  String initialLocation, {
  Size physicalSize = const Size(1170, 2640),
}) async {
  _mockPlatformChannels();
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = KPalette.light;
  final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter();
  final state = AppState()
    ..signedIn = false
    ..passcodeSet = true
    ..apiClient = apiClient;
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
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

void main() {
  group('R-44 — the avatar picker is reached from onboarding, never KYC', () {
    testWidgets(
      'biometric_screen.dart\'s two exits both route through the avatar '
      'picker before Home, and the picker is fully skippable',
      (tester) async {
        final router = await _mount(tester, Routes.biometric);
        expect(find.byType(BiometricScreen), findsOneWidget);

        await tester.tap(find.text('Maybe later'));
        await pumpUntil(
          tester,
          () => find.byType(OnboardingAvatarScreen).evaluate().isNotEmpty,
          'biometric\'s "Maybe later" to land on the avatar picker',
        );
        expect(find.byType(HomeScreen), findsNothing);
        // Let the page-transition animation finish before tapping again —
        // mid-transition, the outgoing screen's widgets can still be found
        // (byType) but sit at an off-screen render position.
        await tester.pump(const Duration(milliseconds: 500));

        // Skippable: nothing is chosen, "Skip" still proceeds — and now
        // (2026-08-31, owner: "remove the screen that says start... user
        // should just go to the home page after onboarding") lands directly
        // on Home. "Your account is ready" (whats_next_screen.dart, s07)
        // used to sit between this and Home; it's gone, and both of the
        // avatar screen's own exits (`_skip()`/`_continue()`) now go
        // straight to Routes.home — see avatar_screen.dart.
        //
        // Home's "not verified" feature cards used to overflow the instant
        // they painted here — two hardcoded CTA strings ("Check your
        // readiness"/"Take the quiz") laid out in a Row with no
        // Flexible/Expanded around the label, so a Row measures a bare Text
        // child at its full unwrapped width regardless of the card's own
        // width. Fixed by promoting the card to `KGrowCard`
        // (lib/widgets/surfaces.dart) with the CTA label wrapped in a
        // Flexible + ellipsis — see that class's own doc comment. Asserting
        // zero render errors now, rather than tolerating a known overflow.
        final homeRenderErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = homeRenderErrors.add;
        try {
          await tester.tap(find.text('Skip'));
          await pumpUntil(
            tester,
            () => find.byType(HomeScreen).evaluate().isNotEmpty,
            'skipping the avatar picker to land directly on Home',
          );
          await tester.pump(const Duration(milliseconds: 50));
        } finally {
          FlutterError.onError = previousOnError;
        }
        expect(homeRenderErrors, isEmpty,
            reason: 'Home should render with no layout/paint errors, '
                'including on its not-verified body');

        final loc = router.routerDelegate.currentConfiguration.uri.toString();
        expect(loc, Routes.home);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });
}
