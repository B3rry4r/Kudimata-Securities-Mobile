// Screenshot harness for Flow F (Account, security and support — screens
// 47-59) plus the Flow-G-labeled-but-actually-built screens 64-66 (bank
// accounts, withdraw mandate, contract note), none of which test/shots.dart
// captures. Renders to /tmp/shots_flowf/<name>.png.
//   flutter test test/shots_flowf.dart
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

const _routes = <String, String>{
  '47_notifications': Routes.notifications,
  '48_notification_settings': Routes.acctNotifications,
  '49_personal_info': Routes.acctPersonal,
  '50_security': Routes.acctSecurity,
  '51_security_alert': Routes.securityAlert,
  '52_statements': Routes.acctStatements,
  '53_plans': Routes.acctPlans,
  '55_refer_earn': Routes.acctRefer,
  '56_help_support': Routes.acctHelp,
  '57_faq': Routes.acctFaq,
  '64_bank_accounts': Routes.acctBanks,
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

Future<_Mounted> _mount(WidgetTester tester) async {
  // screen-specs.md: 390×880 phone frames — flutter_test's ~800×600 default
  // desktop-shaped surface misrepresents anything sized relative to width.
  tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = KPalette.light;
  final apiClient = ApiClient();
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

String? _currentRouteLabel;
final _layoutErrors = <String, String>{};

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  for (final entry in _routes.entries) {
    testWidgets('capture ${entry.key}', (tester) async {
      _mockPlatformChannels();
      Directory('/tmp/shots_flowf').createSync(recursive: true);
      _currentRouteLabel = entry.key;

      FlutterError.onError = (details) {
        final label = _currentRouteLabel ?? 'unknown';
        _layoutErrors[label] = (_layoutErrors[label] ?? '') + details.exceptionAsString();
      };

      final mounted = await _mount(tester);
      mounted.router.go(entry.value);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _capture(tester, mounted.key, '/tmp/shots_flowf/${entry.key}.png');
    });
  }

  tearDownAll(() {
    if (_layoutErrors.isNotEmpty) {
      // ignore: avoid_print
      print('LAYOUT ERRORS:\n${_layoutErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n---\n')}');
    }
  });
}
