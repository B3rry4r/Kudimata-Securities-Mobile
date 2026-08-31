// Screenshot harness for the screens-76-97 canvas expansion (2026-08-23),
// NOT covered by test/shots.dart. Routes needing an `extra` (statement
// detail, complaint tracked) are pushed via a tap sequence in their own
// test below rather than router.go(), same reasoning as shots.dart's
// "capture add money flows" test.
//   flutter test test/shots_expansion.dart
// Renders to /tmp/shots_expansion/<name>.png
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
  '76_statements_hub': Routes.acctStatements,
  '85_tax_documents': Routes.acctTax,
  '86_price_alerts': Routes.priceAlerts,
  '81_corporate_actions': Routes.corpActions,
  '82_rights_issue': Routes.corpActionsRightsIssue,
  '83_agm_vote': Routes.corpActionsAgm,
  '84_dividends': Routes.corpActionsDividends,
  '87_file_complaint': Routes.acctComplaint,
  '89_dormant_account': Routes.acctDormant,
  '90_close_account': Routes.acctClose,
  '91_data_privacy': Routes.acctDataPrivacy,
  '92_locked_out': Routes.lockedOut,
  '94_partner_disclosures': Routes.acctLegalPartnerDisclosures,
  '95_referral_terms': Routes.acctLegalReferralTerms,
  '96_data_notice': Routes.acctLegalDataNotice,
  '97_closure_terms': Routes.acctLegalClosureTerms,
  '45_account_hub': Routes.account, // Data & privacy row spot-check
  // '52_legal_hub' (Routes.acctLegal) no longer exists (R-51, DECISIONS.md,
  // 2026-08-31) — legal_screen.dart and its route are gone; the screens
  // 94-97 rows this used to spot-check from now have no in-app entry point
  // through that hub any more (see legal_reference_screens.dart's own
  // header on which of those four are still reachable elsewhere).
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
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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
    ..apiClient = apiClient;
  final router = buildRouter(state);
  final key = GlobalKey();

  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: AppScope(
        state: state,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: KTheme.light(),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pump();
  return (state: state, router: router, key: key);
}

String? _currentRouteLabel;
final _layoutErrors = <String, String>{};

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  setUp(_mockPlatformChannels);

  testWidgets('capture screens-76-97 expansion', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_currentRouteLabel != null) {
        _layoutErrors[_currentRouteLabel!] = details.summary.toString();
      }
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Directory('/tmp/shots_expansion').createSync(recursive: true);

    final mounted = await _mount(tester);
    final router = mounted.router;
    final key = mounted.key;

    for (final entry in _routes.entries) {
      _currentRouteLabel = entry.key;
      router.go(entry.value);
      try {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        await _capture(tester, key, '/tmp/shots_expansion/${entry.key}.png');
      } on Object catch (e) {
        // ignore: avoid_print
        print(
          'shots_expansion: ${entry.key} raised $e — capturing whatever rendered anyway',
        );
        await _capture(tester, key, '/tmp/shots_expansion/${entry.key}.png');
      }
    }
    _currentRouteLabel = null;

    if (_layoutErrors.isNotEmpty) {
      // ignore: avoid_print
      print(
        'shots_expansion: LAYOUT ERRORS found on ${_layoutErrors.length} route(s):',
      );
      _layoutErrors.forEach((route, summary) {
        // ignore: avoid_print
        print('  [$route] $summary');
      });
    }

    mounted.state.dispose();
  });
}
