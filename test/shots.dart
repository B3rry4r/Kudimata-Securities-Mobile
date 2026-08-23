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

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

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

void main() {
  testWidgets('capture screens', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Directory('/tmp/shots').createSync(recursive: true);

    KColor.active = KPalette.light;

    final state = AppState()
      ..signedIn = true
      ..biometricEnabled = true
      ..passcodeSet = true
      ..kycApproved = true
      ..suitabilityComplete = true
      ..apiClient = ApiClient();
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

    for (final entry in _routes.entries) {
      router.go(entry.value);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await _capture(tester, key, '/tmp/shots/${entry.key}.png');
    }
    state.dispose();
  });
}
