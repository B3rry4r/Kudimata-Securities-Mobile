// Screenshot harness for Flow A (Getting in — screens 01-12), NOT covered by
// test/shots.dart, which hardcodes signedIn/kycApproved to true and
// therefore redirects every onboarding/auth route straight to Home. This
// harness mounts a signed-OUT AppState so those router guards
// let the onboarding screens actually render.
//   flutter test test/shots_onboarding.dart
// Renders to /tmp/shots_onboarding/<name>.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

// (route, signedIn) — signedIn matches the real state a user has BY THE
// TIME they reach that screen in the actual flow, not just "false for
// everything pre-KYC". confirm_passcode_screen.dart / biometric_screen.dart
// call setSignedIn(true) partway through onboarding (screens 08/09), so
// screen 10 onward is reached with signedIn already true — deep-linking
// there with signedIn still false doesn't reflect a real user's path and
// wrongly triggers the "any deep link → splash" fallback redirect.
const _routes = <String, (String, bool)>{
  '01_splash': (Routes.splash, false),
  '02_welcome': (Routes.welcome, false),
  '03_signup': (Routes.signup, false),
  '04_otp': (Routes.otp, false),
  // '05_06_terms' (Routes.termsOfService) no longer exists (R-51,
  // DECISIONS.md, 2026-08-31) — otp above hands straight to passcode
  // creation below now, same as this table's own numbering already skips
  // '11_document_summary' and other removed screens elsewhere.
  '07_passcode_create': (Routes.createPasscode, false),
  '08_passcode_confirm': (Routes.confirmPasscode, false),
  '09_biometric': (Routes.biometric, false),
  '10_onboarding_personal': (Routes.onboardingPersonal, true),
  '11_login': (Routes.login, false),
  '12_reset': (Routes.reset, false),
};

Future<void> _loadFonts() async {
  final display = FontLoader('Nunito');
  for (final p in const [
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-Black.ttf',
  ]) {
    display.addFont(rootBundle.load(p));
  }
  await display.load();

  final core = FontLoader('Nunito Sans');
  for (final p in const [
    'assets/fonts/NunitoSans-Regular.ttf',
    'assets/fonts/NunitoSans-Medium.ttf',
    'assets/fonts/NunitoSans-SemiBold.ttf',
    'assets/fonts/NunitoSans-Bold.ttf',
  ]) {
    core.addFont(rootBundle.load(p));
  }
  await core.load();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

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
    (call) async {
      if (call.method == 'getAll') return <String, dynamic>{};
      return null;
    },
  );
}

typedef _Mounted = ({AppState state, GoRouter router, GlobalKey key});

Future<_Mounted> _mount(WidgetTester tester, {required bool signedIn}) async {
  // screen-specs.md: "Screens 01–66 are 390×880 phone frames." Without this,
  // every capture rendered at flutter_test's default ~800×600 desktop-shaped
  // surface instead — understates width-constrained problems and can
  // misrepresent anything sized relative to screen width.
  tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = KPalette.light;
  final apiClient = ApiClient();
  apiClient.dio.httpClientAdapter = MockApiAdapter();
  final state = AppState()
    ..signedIn = signedIn
    ..biometricEnabled = false
    ..passcodeSet = false
    ..kycSubmitted = false
    ..kycApproved = false
    ..apiClient = apiClient;
  final router = buildRouter(state);
  final key = GlobalKey();

  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: AppScope(
      state: state,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: KTheme.light(),
        routerConfig: router,
      ),
    ),
  ));
  await tester.pump();
  return (state: state, router: router, key: key);
}

String? _currentRouteLabel;
final _layoutErrors = <String, String>{};

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  for (final entry in _routes.entries) {
    testWidgets('capture ${entry.key}', (tester) async {
      _mockPlatformChannels();
      Directory('/tmp/shots_onboarding').createSync(recursive: true);
      _currentRouteLabel = entry.key;

      FlutterError.onError = (details) {
        final label = _currentRouteLabel ?? 'unknown';
        _layoutErrors[label] = (_layoutErrors[label] ?? '') + details.exceptionAsString();
      };

      // Fresh mount per screen — avoids animation/timer bleed between
      // routes (e.g. splash's own auto-navigate timer firing early during
      // a later screen's pump cycle when a single router/tester is reused
      // across the whole sequence).
      final (route, signedIn) = entry.value;
      final mounted = await _mount(tester, signedIn: signedIn);
      if (route != Routes.splash) {
        mounted.router.go(route);
      }
      // Fixed, bounded pumps — NOT pumpAndSettle, which advances the
      // fake-clock's pending Timers (e.g. splash's delayed auto-nav) far
      // enough to skip straight past the screen we're trying to capture.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _capture(tester, mounted.key, '/tmp/shots_onboarding/${entry.key}.png');
    });
  }

  tearDownAll(() {
    if (_layoutErrors.isNotEmpty) {
      // ignore: avoid_print
      print('LAYOUT ERRORS:\n${_layoutErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n---\n')}');
    }
  });
}
