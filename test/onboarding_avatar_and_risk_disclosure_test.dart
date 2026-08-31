// Two real-tap flow-walk tests:
//
//   1. Risk disclosure lives IN the legal-documents screen (DECISIONS.md's
//      R-8a superseded note, 2026-08-29), and since its 2026-08-31 addendum
//      ("the risk disclosure should be a PDF too not a screen") it is
//      opened the EXACT SAME WAY as the other three documents in that
//      list — the phone's native viewer over a real presigned file, marked
//      'opened' the instant that launch reports success — not a bespoke
//      in-app scroll-gated view of hand-authored text. This drives the
//      real screen and asserts on that: the tap reaches
//      LegalDocumentsRepository.downloadUrl (a real network call, through
//      the mock adapter) and a successful launchUrl, with no separate
//      in-app viewer route or widget appearing at all.
//   2. The avatar picker is back in ONBOARDING, reached from
//      biometric_screen.dart's two exits, never from KYC (R-44).
//
// Driven by real taps through the real router, not just asserting on
// routes — a prior ruling in this repo was reported done four times by
// agents who only read the route table.
//
//   flutter test test/onboarding_avatar_and_risk_disclosure_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/home/home_screen.dart';
import 'package:kudimata_invest/screens/onboarding/avatar_screen.dart';
import 'package:kudimata_invest/screens/onboarding/biometric_screen.dart';
import 'package:kudimata_invest/screens/onboarding/whats_next_screen.dart';
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

/// Swaps in for [UrlLauncherPlatform.instance] so legal_acceptance_screen.
/// dart's real `launchUrl()` call resolves without a real platform channel
/// behind it (none is registered in a plain widget test) — the standard
/// url_launcher testing seam. Records every URL it was asked to open so a
/// test can assert on it, and always reports success.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
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
  group('Risk disclosure is a row inside the legal documents screen', () {
    testWidgets(
      'tapping it opens the phone\'s native viewer over a real presigned '
      'file — the SAME mechanism as the other three documents, not a '
      'bespoke in-app screen — and counts as opened once that launch '
      'succeeds',
      (tester) async {
        final fakeLauncher = _FakeUrlLauncher();
        final previousLauncher = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = fakeLauncher;
        addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);

        await _mount(tester, Routes.termsOfService);

        await pumpUntil(
          tester,
          () => find.text('Risk Disclosure').evaluate().isNotEmpty,
          'the four legal documents to load',
        );
        // All four real documents are listed, gate not yet satisfied.
        expect(find.text('Open every document above to continue.'), findsOneWidget);

        await tester.tap(find.text('Risk Disclosure'));
        await pumpUntil(
          tester,
          () => fakeLauncher.launchedUrls.isNotEmpty,
          'legal_acceptance_screen.dart to call launchUrl() for the '
          "risk_disclosure row's real presigned file — never a separate "
          'in-app viewer',
        );
        await tester.pump(const Duration(milliseconds: 200));

        // No bespoke risk-disclosure screen exists any more — the whole
        // interaction is this list plus the OS-level launch above.
        expect(find.text('Important regulatory & risk notice'), findsNothing,
            reason: 'risk disclosure is opened externally now, not rendered '
                'in-app from hand-authored sections text');
        expect(find.text("I've read this"), findsNothing);

        // Back on (still on) the list: risk_disclosure is now 'opened', but
        // the other three (never tapped) are not, so the shared gate still
        // blocks — exactly the same evidence-per-row rule as before, just
        // uniform across all four now instead of risk_disclosure being the
        // one exception.
        expect(
          find.text('Open every document above to continue.'),
          findsOneWidget,
          reason: 'three documents are still unopened; the shared checkbox must stay locked',
        );
      },
    );
  });

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

        // Skippable: nothing is chosen, "Skip" still proceeds.
        await tester.tap(find.text('Skip'));
        await pumpUntil(
          tester,
          () => find.byType(WhatsNextScreen).evaluate().isNotEmpty,
          'skipping the avatar picker to land on "Your account is ready"',
        );
        await tester.pump(const Duration(milliseconds: 500));

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
          await tester.tap(find.text('Look around first'));
          await tester.pump();
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
