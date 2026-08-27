// Sub-state screenshot harness (docs/redesign/DECISIONS.md B-3/B-4).
//
// test/shots_all.dart renders every routed screen's DEFAULT state only. Two
// consequences already hit during the build: an agent had to write and
// delete a throwaway test just to see its own Order Book tab (B-3), and the
// unverified Home (s23) — the state every brand-new investor actually sees
// — could not be rendered at all, because test/fixtures/mock_api_adapter.dart
// always answered `/kyc-submissions/me` as approved (B-4).
//
// This file is the fix for both: a plain Dart list of [SubStateSpec]s, each
// one a screen + a named sub-state + how to reach it (a fixture scenario
// from mock_api_adapter.dart's `MockKyc`/`MockPortfolio`/`MockMarket`/
// `MockNetwork` enums, and/or a sequence of texts to find-and-tap once the
// screen has settled). Output goes to
// `build/shots/<screen>__<substate>__light.png` / `__dark.png`, and
// scripts/design/build_manifest.py folds `build/shots/_substate_captures.json`
// (written by tearDownAll below) into the same `build/shots/manifest.json`
// shots_all.dart's captures already populate.
//
// ADDING A SUB-STATE — the whole point of this file — is ONE entry in
// `_subStates` below, e.g.:
//
//   SubStateSpec(screen: 'holding_detail', substate: 'empty_trades',
//       route: Routes.holdingDetail('MTNN'),
//       dartFile: 'portfolio/holding_detail_screen.dart'),
//
// or, for something behind a tap (a second tab, an expanded sheet):
//
//   SubStateSpec(screen: 'asset_detail', substate: 'order_book',
//       route: Routes.assetDetail('MTNN'),
//       dartFile: 'markets/asset_detail_screen.dart',
//       tapTexts: ['Order book']),
//
// No knowledge of _mount/_capture/the fixture's internals is needed — only
// the screen's route, its dartFile (for the manifest), which fixture
// scenario reaches the sub-state (if any), and which texts to tap in order
// (if any).
//
//   flutter test test/shots_substates.dart
//   (normally invoked via scripts/design/shots.sh, alongside shots_all.dart)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/data/repositories/market_status_repository.dart';
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart' show KErrorView;
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

const _outDir = 'build/shots';

/// One named sub-state of an already-captured screen. Every field besides
/// [screen]/[substate]/[route] has a default that reproduces the screen's
/// ordinary fully-onboarded, populated-data state (the same defaults
/// test/shots_all.dart's own `_RouteSpec` uses) — a sub-state entry only
/// needs to override whatever actually reaches it.
class SubStateSpec {
  const SubStateSpec({
    required this.screen,
    required this.substate,
    required this.route,
    required this.dartFile,
    this.signedIn = true,
    this.kycSubmitted = true,
    this.kycApproved = true,
    this.suitabilityComplete = true,
    this.kyc = MockKyc.approved,
    this.portfolio = MockPortfolio.populated,
    this.market = MockMarket.open,
    this.network = MockNetwork.ok,
    this.notifications = MockNotifications.populated,
    this.priceAlerts = MockPriceAlerts.populated,
    this.extra,
    this.tapTexts = const [],
  });

  /// Matches shots_all.dart's route `name` where the sub-state belongs to a
  /// routed screen (e.g. 'home', 'asset_detail') — used only for the output
  /// filename and manifest grouping, not for artboard lookup (sub-states
  /// are variants of an already-ruled screen, not new screens needing their
  /// own R-5 ruling).
  final String screen;
  final String substate;
  final String route;
  final String dartFile;
  final bool signedIn;
  final bool kycSubmitted;
  final bool kycApproved;
  final bool suitabilityComplete;
  final MockKyc kyc;
  final MockPortfolio portfolio;
  final MockMarket market;
  final MockNetwork network;
  final MockNotifications notifications;
  final MockPriceAlerts priceAlerts;
  final Object? extra;

  /// Texts tapped in order, each followed by two 350ms pumps (matching
  /// shots_all.dart's own settle timing), to reach a sub-state that lives
  /// behind an interaction rather than a fixture scenario — e.g. a second
  /// tab. Left empty when the fixture scenario alone reaches the substate.
  final List<String> tapTexts;
}

// ── Seed config (docs/redesign/DECISIONS.md B-3/B-4's own named list) ──────
final List<SubStateSpec> _subStates = [
  // B-4 — s23, the unverified Home every brand-new investor actually sees.
  // kyc: draft makes /kyc-submissions/me report an in-progress submission,
  // which home_screen.dart's own _initialLoad (via refreshKycGatingState)
  // re-fetches BEFORE deciding verified vs not-verified — setting
  // kycApproved/kycSubmitted at mount time alone is not enough, since that
  // fetch overwrites them.
  SubStateSpec(
    screen: 'home',
    substate: 'unverified',
    route: Routes.home,
    dartFile: 'home/home_screen.dart',
    kyc: MockKyc.draft,
  ),

  // B-3 — the Order Book tab (R-18), reachable only behind a tap; the
  // canvas/agent that built it had no way to render it without this.
  SubStateSpec(
    screen: 'asset_detail',
    substate: 'order_book',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'markets/asset_detail_screen.dart',
    tapTexts: ['Order book'],
  ),

  // R-30's one real canvas-designed state variant (s29c) — the Markets
  // header pill's closed reading. AppState.marketOpen only reflects the
  // fixture once refreshMarketStatus() is actually called (see _mount
  // below) — the local wall-clock fallback it otherwise uses is not
  // deterministic for a screenshot.
  SubStateSpec(
    screen: 'markets',
    substate: 'market_closed',
    route: Routes.markets,
    dartFile: 'markets/markets_screen.dart',
    market: MockMarket.closed,
  ),

  // Portfolio's own designed empty state (KEmptyView.holdings()).
  SubStateSpec(
    screen: 'portfolio',
    substate: 'empty',
    route: Routes.portfolio,
    dartFile: 'portfolio/portfolio_screen.dart',
    portfolio: MockPortfolio.empty,
  ),

  // ── R-30 loading/error — a representative handful via the network
  //    fixture, not all 76 screens (per DECISIONS.md B-4's own scope). Each
  //    pair uses the SAME route as shots_all.dart's own default capture for
  //    that screen, so the only difference is which body renders.
  SubStateSpec(
    screen: 'home',
    substate: 'loading',
    route: Routes.home,
    dartFile: 'home/home_screen.dart',
    network: MockNetwork.slow,
  ),
  SubStateSpec(
    screen: 'home',
    substate: 'error',
    route: Routes.home,
    dartFile: 'home/home_screen.dart',
    network: MockNetwork.error,
  ),
  SubStateSpec(
    screen: 'portfolio',
    substate: 'loading',
    route: Routes.portfolio,
    dartFile: 'portfolio/portfolio_screen.dart',
    network: MockNetwork.slow,
  ),
  SubStateSpec(
    screen: 'portfolio',
    substate: 'error',
    route: Routes.portfolio,
    dartFile: 'portfolio/portfolio_screen.dart',
    network: MockNetwork.error,
  ),
  SubStateSpec(
    screen: 'wallet',
    substate: 'loading',
    route: Routes.wallet,
    dartFile: 'wallet/wallet_screens.dart',
    network: MockNetwork.slow,
  ),
  SubStateSpec(
    screen: 'wallet',
    substate: 'error',
    route: Routes.wallet,
    dartFile: 'wallet/wallet_screens.dart',
    network: MockNetwork.error,
  ),

  // R-25 (notifications_screen.dart) — loading/error/empty. Empty is a
  // real, reachable condition: an investor with no notification history
  // yet (a brand-new account, or one that has never had an order fill,
  // dividend, security event, or verification update).
  SubStateSpec(
    screen: 'notifications',
    substate: 'loading',
    route: Routes.notifications,
    dartFile: 'home/notifications_screen.dart',
    network: MockNetwork.slow,
  ),
  SubStateSpec(
    screen: 'notifications',
    substate: 'error',
    route: Routes.notifications,
    dartFile: 'home/notifications_screen.dart',
    network: MockNetwork.error,
  ),
  SubStateSpec(
    screen: 'notifications',
    substate: 'empty',
    route: Routes.notifications,
    dartFile: 'home/notifications_screen.dart',
    notifications: MockNotifications.empty,
  ),

  // s49/s50 (price_alerts_screen.dart) — loading/error/empty. Empty is a
  // real, reachable condition: an investor who has never set a price
  // alert on any asset — the default state for most accounts, since
  // R-16 dropped the only other entry point (the watchlist screen) and
  // this screen now starts empty until something is set from an asset
  // page.
  SubStateSpec(
    screen: 'price_alerts',
    substate: 'loading',
    route: Routes.priceAlerts,
    dartFile: 'markets/price_alerts_screen.dart',
    network: MockNetwork.slow,
  ),
  SubStateSpec(
    screen: 'price_alerts',
    substate: 'error',
    route: Routes.priceAlerts,
    dartFile: 'markets/price_alerts_screen.dart',
    network: MockNetwork.error,
  ),
  SubStateSpec(
    screen: 'price_alerts',
    substate: 'empty',
    route: Routes.priceAlerts,
    dartFile: 'markets/price_alerts_screen.dart',
    priceAlerts: MockPriceAlerts.empty,
  ),

  // H-1 (SHARED-CHANGES.md) — outcome_not_approved.dart's three genuinely
  // terminal non-approved statuses (rejected / flagged / expired). The
  // standing shots_all.dart capture for this screen (route Routes.kycOutcome)
  // uses the default MockKyc.approved fixture, which the screen's own
  // switch never matches — it silently falls through to the defensive
  // fallback branch, so none of the three real outcomes was ever rendered
  // by the harness. kycApproved/suitabilityComplete false to match how this
  // screen is actually reached (post-KYC-submission, pre-approval).
  SubStateSpec(
    screen: 'kyc_outcome',
    substate: 'rejected',
    route: Routes.kycOutcome,
    dartFile: 'kyc/outcome_not_approved.dart',
    kyc: MockKyc.rejected,
    kycApproved: false,
    suitabilityComplete: false,
  ),
  SubStateSpec(
    screen: 'kyc_outcome',
    substate: 'flagged',
    route: Routes.kycOutcome,
    dartFile: 'kyc/outcome_not_approved.dart',
    kyc: MockKyc.flagged,
    kycApproved: false,
    suitabilityComplete: false,
  ),
  SubStateSpec(
    screen: 'kyc_outcome',
    substate: 'expired',
    route: Routes.kycOutcome,
    dartFile: 'kyc/outcome_not_approved.dart',
    kyc: MockKyc.expired,
    kycApproved: false,
    suitabilityComplete: false,
  ),
];

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

typedef _Mounted = ({AppState state, GoRouter router, GlobalKey key});

Future<_Mounted> _mount(WidgetTester tester, SubStateSpec spec, ThemeMode mode) async {
  // Same 390x880@3x phone frame as shots_all.dart/shots.dart.
  tester.view.physicalSize = const Size(1170, 2640);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = mode == ThemeMode.dark ? KPalette.dark : KPalette.light;

  final apiClient = ApiClient();
  apiClient.dio.httpClientAdapter = MockApiAdapter(
    kyc: spec.kyc,
    portfolio: spec.portfolio,
    market: spec.market,
    network: spec.network,
    notifications: spec.notifications,
    priceAlerts: spec.priceAlerts,
  );
  final state = AppState()
    ..signedIn = spec.signedIn
    ..biometricEnabled = spec.signedIn
    ..passcodeSet = spec.signedIn
    ..kycSubmitted = spec.kycSubmitted
    ..kycApproved = spec.kycApproved
    ..suitabilityComplete = spec.suitabilityComplete
    ..riskDisclosureAccepted = spec.suitabilityComplete
    ..apiClient = apiClient
    ..kycForm = KycFormState();

  // Deterministic market-open/closed reading (see the market_closed spec's
  // own comment). Skipped for MockNetwork.slow specifically — its
  // never-resolving response would hang this setup step forever, before
  // the screen under test ever mounts (AppState.refreshMarketStatus itself
  // already swallows a network error, so MockNetwork.error is harmless
  // here, but there is nothing to gain from calling it under error/slow
  // scenarios anyway, since none of today's substates combine market with
  // network).
  //
  // MUST run inside tester.runAsync — testWidgets bodies execute inside a
  // FakeAsync zone (that's what lets shots_all.dart's own bounded
  // tester.pump(duration) calls simulate elapsed time without a real
  // wait), and a bare top-level `await` on a Future whose completion relies
  // on the microtask queue never gets flushed there unless something pumps
  // it — a plain `await state.refreshMarketStatus(...)` here hung this
  // whole test file for the full 10-minute test timeout before this fix.
  // runAsync briefly escapes to the real zone, where the mock adapter's
  // synchronous response resolves immediately.
  if (spec.network != MockNetwork.slow) {
    await tester.runAsync(() => state.refreshMarketStatus(MarketStatusRepository(apiClient)));
  }

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
          darkTheme: KTheme.dark(),
          themeMode: mode,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pump();
  return (state: state, router: router, key: key);
}

Future<String?> _capture(WidgetTester tester, GlobalKey key, String path) async {
  try {
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    return null;
  } on Object catch (e) {
    return e.toString();
  }
}

final _results = <String, Map<String, Object?>>{};
final _teardownErrors = <String, String>{};

void main() {
  setUpAll(() async {
    await _loadFonts();
    Directory(_outDir).createSync(recursive: true);
  });

  for (final spec in _subStates) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final suffix = mode == ThemeMode.dark ? 'dark' : 'light';
      final pngPath = '$_outDir/${spec.screen}__${spec.substate}__$suffix.png';
      final label = '${spec.screen}__${spec.substate} ($suffix)';

      testWidgets('capture $label', (tester) async {
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          _teardownErrors[label] = details.summary.toString();
        };
        addTearDown(() {
          FlutterError.onError = originalOnError;
          final note = _teardownErrors.remove(label);
          if (note != null) {
            final entry = _results[label];
            if (entry != null) {
              entry['renderNote'] =
                  entry['renderNote'] == null ? note : '${entry['renderNote']}; $note';
            }
          }
        });

        _mockPlatformChannels();
        String? renderError;
        String? captureError;
        _Mounted? mounted;

        try {
          mounted = await _mount(tester, spec, mode);
        } on Object catch (e) {
          renderError = 'mount failed: $e';
        }

        if (mounted != null) {
          try {
            // See test/shots_all.dart's identical guard for the full
            // rationale (2026-08-27 false-capture fix): Home's own async
            // KYC-gating refresh can still be in-flight when we navigate
            // away, and if it resolves (notifyListeners) after go(), it
            // makes GoRouter reparse the current location from the bare
            // URI — which silently drops `extra`. No SubStateSpec passes
            // `extra` today, but draining Home's refresh first keeps this
            // file safe for the day one does, at zero cost to specs that
            // don't.
            if (spec.extra != null) {
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump(const Duration(milliseconds: 350));
            }
            mounted.router.go(spec.route, extra: spec.extra);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
            for (final text in spec.tapTexts) {
              await tester.tap(find.text(text).first);
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump(const Duration(milliseconds: 350));
            }
          } on Object catch (e) {
            renderError = e.toString();
          }

          // Same false-capture guard as shots_all.dart, with one exemption:
          // this file's OWN 'error' substates (home__error, portfolio__error,
          // wallet__error — MockNetwork.error) deliberately drive the screen
          // into its real KErrorView/KErrorView.failedLoad branch, so
          // finding one there is the capture WORKING, not a dropped `extra`
          // or an accidental failure. Every other substate's KErrorView is
          // still exactly as unambiguous a failure signal as shots_all.dart's
          // comment explains.
          String? errorViewError;
          if (spec.substate != 'error' && find.byType(KErrorView).evaluate().isNotEmpty) {
            errorViewError =
                "rendered the app's own KErrorView (\"Couldn't load\") instead "
                'of the target sub-state — likely a dropped/mistyped `extra` '
                'or an unhandled backend-error fixture, not a genuine capture '
                'of ${spec.dartFile}';
          }

          captureError = await _capture(tester, mounted.key, pngPath);
          mounted.state.dispose();

          final rendered = File(pngPath).existsSync() &&
              captureError == null &&
              errorViewError == null;
          _results[label] = {
            'screen': spec.screen,
            'substate': spec.substate,
            'name': '${spec.screen}__${spec.substate}',
            'theme': suffix,
            'route': spec.route,
            'dartFile': spec.dartFile,
            'png': rendered ? pngPath : null,
            'rendered': rendered,
            'error': rendered ? null : (errorViewError ?? renderError ?? captureError ?? 'unknown'),
            'renderNote': rendered ? renderError : null,
          };
        } else {
          _results[label] = {
            'screen': spec.screen,
            'substate': spec.substate,
            'name': '${spec.screen}__${spec.substate}',
            'theme': suffix,
            'route': spec.route,
            'dartFile': spec.dartFile,
            'png': null,
            'rendered': false,
            'error': renderError ?? 'unknown',
            'renderNote': null,
          };
        }
      // Per-test timeout (docs/redesign per this file's debugging pass) —
      // without this, a future spec that trips a never-resolving Future
      // (e.g. a new MockNetwork.slow combination, or an accidental
      // repeating-animation pumpAndSettle) hangs the ENTIRE suite for
      // flutter_test's default 10-minute per-test ceiling instead of
      // failing loudly in seconds. 30s comfortably covers the slowest
      // legitimate capture (font load + 3 settle pumps + PNG encode) with
      // headroom, while still turning a genuine hang into a fast, visible
      // failure.
      }, timeout: const Timeout(Duration(seconds: 30)));
    }
  }

  tearDownAll(() {
    final records = _results.values.toList();
    File('$_outDir/_substate_captures.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(records),
    );
    final failed = records.where((r) => r['rendered'] != true).toList();
    // ignore: avoid_print
    print(
      'shots_substates: ${records.length} captures attempted, '
      '${records.length - failed.length} rendered, ${failed.length} failed.',
    );
    if (failed.isNotEmpty) {
      for (final f in failed) {
        // ignore: avoid_print
        print('  UNRENDERABLE [${f['name']} ${f['theme']}] ${f['error']}');
      }
    }
  });
}
