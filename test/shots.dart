// Screenshot harness (run by path, not part of CI):
//   flutter test test/shots.dart
// Renders the real app (router) across key screens to /tmp/shots/<name>.png
// so we can visually verify the design. Light-only (2026-08-22 "Soft
// Landing" redesign removed dark mode — see main.dart's header comment).
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
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

const _routes = <String, String>{
  'login': '/login',
  'signup': '/signup',
  'onboarding_personal': '/onboarding/personal',
  'kyc_intro': '/kyc',
  'kyc_bvn': '/kyc/bvn',
  'suitability': '/suitability',
  'home': '/home',
  'markets': '/markets',
  'asset_detail': '/asset/MTNN',
  'watchlist': '/watchlist',
  'notifications': '/notifications',
  'search': '/search',
  'portfolio': '/portfolio',
  'holding': '/portfolio/holding/MTNN',
  'orders': '/orders',
  'wallet': '/wallet',
  'txn': '/wallet/txn/TX1042',
  'account': '/account',
  'security': '/account/security',
  'freeze': '/account/security/freeze',
  'security_alert': '/security-alert',
  'plans': '/account/plans',
  'explain': '/explain/MTNN',
  'welcome': '/welcome',
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

/// Neither plugin has a native implementation in a `flutter test` process —
/// every call throws MissingPluginException unless mocked here. Channel
/// names/methods are the exact ones the real MissingPluginException
/// messages name (PasscodeStore.hasPasscode() on /login,
/// search_screen.dart's recents on /search).
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

Future<_Mounted> _mount(WidgetTester tester) async {
  // screen-specs.md: "Screens 01–66 are 390×880 phone frames." None of these
  // harnesses were setting this — every capture rendered at flutter_test's
  // default ~800×600 desktop-shaped surface instead, which understates
  // width-constrained problems (text/buttons have ~2x the real width to
  // work with) and can misrepresent anything sized relative to screen width
  // (e.g. a maxWidth-capped keypad looks stranded with huge margins on an
  // 800-wide canvas but properly fills a 390-wide phone).
  tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = KPalette.light;
  final apiClient = ApiClient();
  // Without this, every API-backed screen just renders its generic
  // KErrorView — Flutter's test binding synthesizes a bare 400 for any real
  // HttpClient call, so there's no real backend for ApiClient to reach. See
  // mock_api_adapter.dart's header for the full rationale.
  apiClient.dio.httpClientAdapter = MockApiAdapter();
  final state = AppState()
    ..signedIn = true
    ..biometricEnabled = true
    ..passcodeSet = true
    ..kycSubmitted = true
    ..kycApproved = true
    ..suitabilityComplete = true
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

/// Set to the route currently being captured so a layout error caught by
/// [FlutterError.onError] (RenderFlex overflow, etc.) can be attributed to
/// the screen that produced it — without this, the default test reporter
/// only shows a disposed-widget element chain with no route name attached.
String? _currentRouteLabel;
final _layoutErrors = <String, String>{};

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  setUp(_mockPlatformChannels);

  testWidgets('capture screens', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_currentRouteLabel != null) {
        _layoutErrors[_currentRouteLabel!] = details.summary.toString();
      }
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Directory('/tmp/shots').createSync(recursive: true);

    final mounted = await _mount(tester);
    final router = mounted.router;
    final key = mounted.key;

    for (final entry in _routes.entries) {
      _currentRouteLabel = entry.key;
      router.go(entry.value);
      // A screen whose FutureBuilder rejects with something other than a
      // clean 404 (asset_detail_screen.dart's holding lookup against this
      // harness's fake network client, which always answers 400) surfaces
      // as a zone-level test failure not on ITS OWN pump but on a LATER
      // route's _capture() call — _capture() uses tester.runAsync() to
      // bridge into real async for boundary.toImage(), and that's the first
      // point after the rejection where the fake-async test zone actually
      // drains it. This whole run is a visual-QA tool, not a correctness
      // assertion, so a screen's own backend-error handling isn't what it's
      // checking — swallow broadly so one flaky screen doesn't take out
      // every capture after it.
      try {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        await _capture(tester, key, '/tmp/shots/${entry.key}.png');
      } on Object catch (e) {
        // ignore: avoid_print
        print('shots: ${entry.key} raised $e — capturing whatever rendered anyway');
        await _capture(tester, key, '/tmp/shots/${entry.key}.png');
      }
    }
    _currentRouteLabel = null;

    if (_layoutErrors.isNotEmpty) {
      // ignore: avoid_print
      print('shots: LAYOUT ERRORS found on ${_layoutErrors.length} route(s):');
      _layoutErrors.forEach((route, summary) {
        // ignore: avoid_print
        print('  [$route] $summary');
      });
    }

    mounted.state.dispose();
  });

  // Kept as its OWN test (own fresh mount) rather than appended to the loop
  // above — asset_detail's flaky fake-network rejection (see the loop's own
  // comment) only actually surfaces during a LATER tester.runAsync() call
  // (used by _capture() to bridge into real async for boundary.toImage()),
  // which made it take out these unrelated captures too when they ran in
  // the same test after the /asset/MTNN route had already been visited.
  testWidgets('capture add money flows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Directory('/tmp/shots').createSync(recursive: true);

    final mounted = await _mount(tester);
    final router = mounted.router;
    final key = mounted.key;

    // Add money's two funding paths (2026-08-23) are showKSheet overlays,
    // not routes — router.go() alone never reaches them, so they need an
    // actual tap sequence from the Wallet tab.
    router.go('/wallet');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Add money').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _capture(tester, key, '/tmp/shots/add_money_chooser.png');

    await tester.tap(find.text('Bank transfer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _capture(tester, key, '/tmp/shots/add_money_bank_transfer.png');

    // Dismiss by tapping the barrier (above the sheet, still inside the
    // 390x844 surface) — KSheet has no close affordance of its own.
    await tester.tapAt(const Offset(195, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Add money').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Debit or credit card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _capture(tester, key, '/tmp/shots/add_money_card.png');

    mounted.state.dispose();
  });

  // Screen 42 (Withdraw) — same showKSheet-overlay reasoning as "capture add
  // money flows" above: not a route, needs a real tap from the Wallet tab.
  // Never previously captured (confirmed: absent from _routes above and from
  // every existing screenshot in /tmp/shots).
  testWidgets('capture withdraw flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Directory('/tmp/shots').createSync(recursive: true);

    final mounted = await _mount(tester);
    final router = mounted.router;
    final key = mounted.key;

    router.go('/wallet');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Withdraw').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _capture(tester, key, '/tmp/shots/withdraw.png');

    mounted.state.dispose();
  });
}
