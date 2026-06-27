// Screenshot harness (run by path, not part of CI):
//   flutter test test/shots.dart
// Renders the real app (router) across key screens in BOTH light and dark to
// /tmp/shots/<mode>_<name>.png so we can visually verify the dark theme.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/app_router.dart';
import 'package:kudimata_securities/theme/app_theme.dart';
import 'package:kudimata_securities/theme/tokens.dart';

const _routes = <String, String>{
  'login': '/login',
  'signup': '/signup',
  'kyc_intro': '/kyc',
  'kyc_personal': '/kyc/personal',
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
};

Future<void> _loadFonts() async {
  final loader = FontLoader('Space Grotesk');
  for (final p in const [
    'assets/fonts/SpaceGrotesk-Regular.ttf',
    'assets/fonts/SpaceGrotesk-Medium.ttf',
    'assets/fonts/SpaceGrotesk-SemiBold.ttf',
    'assets/fonts/SpaceGrotesk-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(p));
  }
  await loader.load();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('capture light + dark', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Directory('/tmp/shots').createSync(recursive: true);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final dark = mode == ThemeMode.dark;
      KColor.active = dark ? KPalette.dark : KPalette.light;
      final tag = dark ? 'dark' : 'light';

      final state = AppState()
        ..signedIn = true
        ..biometricEnabled = true
        ..passcodeSet = true
        ..kycApproved = true
        ..suitabilityComplete = true
        ..themeMode = mode;
      final router = buildRouter(state);
      final key = GlobalKey();

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: AppScope(
          state: state,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: KTheme.light(),
            darkTheme: KTheme.dark(),
            themeMode: mode,
            routerConfig: router,
          ),
        ),
      ));
      await tester.pump();

      for (final entry in _routes.entries) {
        router.go(entry.value);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        await _capture(tester, key, '/tmp/shots/${tag}_${entry.key}.png');
      }
      state.dispose();
    }
    // restore for any later tests in the same run
    KColor.active = KPalette.light;
  });
}
