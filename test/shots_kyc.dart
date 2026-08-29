// Screenshot harness for Flow B (KYC) + Flow C (Suitability), NOT covered by
// test/shots.dart (which only captures kyc_intro, kyc_bvn, and suitability —
// 3 of the ~9 real screens in these two flows). Router gating only checks
// state.signedIn (see app_router.dart's _gateRedirect) — once true, KYC and
// suitability routes free-roam regardless of kycSubmitted/kycApproved/
// suitabilityComplete, so those three flags are set per-screen to match what
// a real user actually has AT that screen (kycSubmitted flips true on
// next_of_kin.dart itself; kycApproved on approved.dart itself;
// suitabilityComplete on suitability_result_screen.dart itself).
//   flutter test test/shots_kyc.dart
// Renders to /tmp/shots_kyc/<name>.png
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
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

// (route, kycSubmitted, kycApproved, suitabilityComplete) — signedIn is
// always true for this flow (set once in _mount).
const _routes = <String, (String, bool, bool, bool)>{
  '13_kyc_intro': (Routes.kycIntro, false, false, false),
  '14_bvn_nin': (Routes.kycBvn, false, false, false),
  '15_chn': (Routes.kycChn, false, false, false),
  '16_id_upload': (Routes.kycId, false, false, false),
  '17_liveness': (Routes.kycLiveness, false, false, false),
  '18_utility_bill': (Routes.kycUtilityBill, false, false, false),
  '19_bank_dcs': (Routes.kycBankDcs, false, false, false),
  '20_declarations': (Routes.kycDeclarations, false, false, false),
  '21_next_of_kin': (Routes.kycNextOfKin, false, false, false),
  // D-1 (2026-08-27 removals pass, R-9): review_submit_screen.dart dropped
  // — next_of_kin above is now the last collection step and submits
  // directly, so '22_review_submit' no longer exists.
  '23_24_submitted_pending': (Routes.kycSubmitted, true, false, false),
  '25_approved': (Routes.kycApproved, true, false, false),
  '26_outcome_not_approved': (Routes.kycOutcome, true, false, false),
  '27_questionnaire': (Routes.questionnaire, true, true, false),
  '28_suitability_result': (Routes.suitabilityResult, true, true, false),
  // 2026-08-29 (DECISIONS.md's R-8a superseded note): risk disclosure moved
  // back into termsOfService's document list — there is no standalone
  // risk-disclaimer route left to capture here. '29_terms_of_service'
  // replaces '29_risk_disclaimer', same suitabilityComplete: true state
  // (reached right after suitability under the real flow).
  '29_terms_of_service': (Routes.termsOfService, true, true, true),
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

Future<_Mounted> _mount(
  WidgetTester tester, {
  required bool kycSubmitted,
  required bool kycApproved,
  required bool suitabilityComplete,
}) async {
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
    ..kycSubmitted = kycSubmitted
    ..kycApproved = kycApproved
    ..suitabilityComplete = suitabilityComplete
    ..apiClient = apiClient
    // declarations_screen.dart/next_of_kin.dart/review_submit_screen.dart
    // read AppScope.read(context).kycForm at build time (2026-08-24) —
    // main.dart's real bootstrap always sets this too.
    ..kycForm = KycFormState();
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
      Directory('/tmp/shots_kyc').createSync(recursive: true);
      _currentRouteLabel = entry.key;

      FlutterError.onError = (details) {
        final label = _currentRouteLabel ?? 'unknown';
        _layoutErrors[label] = (_layoutErrors[label] ?? '') + details.exceptionAsString();
      };

      final (route, kycSubmitted, kycApproved, suitabilityComplete) = entry.value;
      final mounted = await _mount(
        tester,
        kycSubmitted: kycSubmitted,
        kycApproved: kycApproved,
        suitabilityComplete: suitabilityComplete,
      );
      mounted.router.go(route);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _capture(tester, mounted.key, '/tmp/shots_kyc/${entry.key}.png');
    });
  }

  tearDownAll(() {
    if (_layoutErrors.isNotEmpty) {
      // ignore: avoid_print
      print('LAYOUT ERRORS:\n${_layoutErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n---\n')}');
    }
  });
}
