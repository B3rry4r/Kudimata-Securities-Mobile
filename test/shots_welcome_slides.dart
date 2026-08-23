// One-off check: capture all 3 welcome-slider pages (not just index 0) to
// verify the card frame stays the same size across slides of different
// title/body length — the bug test/shots_onboarding.dart couldn't catch
// since it only ever captures whatever page a fresh mount lands on (index 0).
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

void main() {
  setUpAll(() async => _loadFonts());

  testWidgets('capture all 3 welcome slides', (tester) async {
    _mockPlatformChannels();
    Directory('/tmp/shots_onboarding').createSync(recursive: true);

    // screen-specs.md: 390×880 phone frames — flutter_test's ~800×600
    // default desktop-shaped surface misrepresents width-relative sizing.
    tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    KColor.active = KPalette.light;
    final apiClient = ApiClient()..dio.httpClientAdapter = MockApiAdapter();
    final state = AppState()
      ..signedIn = false
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
    router.go(Routes.welcome);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('/tmp/shots_onboarding/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await capture('welcome_slide_0');

    // Swipe left twice to reach slides 1 and 2.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capture('welcome_slide_1');

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capture('welcome_slide_2');
  });
}
