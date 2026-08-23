// Screenshot harness for Flow D screens never captured by test/shots.dart:
// screen 30 (Home · not verified yet) and the Buy sheets 35/36/37, reached
// by actually tapping through the trade flow from asset_detail_screen.dart.
//   flutter test test/shots_flowd.dart
// Renders to /tmp/shots_flowd/<name>.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

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

Future<GlobalKey> _mountAt(WidgetTester tester, String route, {required bool kycApproved}) async {
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
    ..kycApproved = kycApproved
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
  router.go(route);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return key;
}

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('capture 30_home_not_verified', (tester) async {
    _mockPlatformChannels();
    Directory('/tmp/shots_flowd').createSync(recursive: true);
    final key = await _mountAt(tester, Routes.home, kycApproved: false);
    await _capture(tester, key, '/tmp/shots_flowd/30_home_not_verified.png');
  });

  testWidgets('capture 35_36_37 buy flow', (tester) async {
    _mockPlatformChannels();
    Directory('/tmp/shots_flowd').createSync(recursive: true);
    final key = await _mountAt(tester, Routes.assetDetail('MTNN'), kycApproved: true);

    final buyButton = find.widgetWithText(GestureDetector, 'Buy').evaluate().isNotEmpty
        ? find.widgetWithText(GestureDetector, 'Buy')
        : find.text('Buy');
    expect(buyButton, findsWidgets);
    await tester.tap(buyButton.first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _capture(tester, key, '/tmp/shots_flowd/35_buy_amount.png');

    final reviewButton = find.text('Review order');
    if (reviewButton.evaluate().isEmpty) {
      // ignore: avoid_print
      print('35_36_37: "Review order" button not found after opening Buy sheet — screens 36/37 not captured.');
      return;
    }
    await tester.tap(reviewButton.first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _capture(tester, key, '/tmp/shots_flowd/36_buy_review.png');

    final placeButton = find.text('Place order');
    if (placeButton.evaluate().isEmpty) {
      // ignore: avoid_print
      print('35_36_37: "Place order" button not found after review sheet — screen 37 not captured.');
      return;
    }
    await tester.tap(placeButton.first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await _capture(tester, key, '/tmp/shots_flowd/37_order_placed.png');
  });
}
