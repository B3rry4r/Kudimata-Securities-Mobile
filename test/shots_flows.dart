// Modal-sheet flow screenshot harness — buy/sell/add-money/withdraw and the
// two shared bottom sheets they and other screens reuse
// (confirm_passcode_sheet.dart, glossary_sheet.dart).
//
// WHY THIS FILE EXISTS, NOT MORE ENTRIES IN shots_substates.dart: a
// [SubStateSpec] there is "a fixture scenario + a flat list of texts to
// tap" — the right shape for a second tab or an empty/loading/error variant
// of an already-mounted routed screen. The flows below are different in
// kind, not just degree: `showBuyFlow`/`showSellFlow`/`showAddMoneyFlow`/
// `showWithdrawFlow` are never GoRoutes at all (they are `showKSheet` calls
// launched from a button on a routed screen), they are MULTI-STEP — each
// step is its own sheet, popped and replaced by the next — and several
// steps need TEXT ENTERED before their primary button even unlocks (the
// shares field starts empty; `_showBuySharesSheet`'s "Review order" is
// disabled until something is typed). Bolting text entry and multi-sheet
// navigation onto [SubStateSpec]'s single flat `tapTexts` list would have
// made that class do two unrelated jobs. [FlowSpec] below is the same idea
// — declare the fixture + the interaction, get a named PNG — built for
// sequences of (tap this / type this) instead.
//
// An independent audit (2026-08-29) found these four files had ZERO
// rendered evidence, ever, because they are unreachable from
// test/shots_all.dart's route walk:
//   lib/screens/trade/trade_flows.dart        (buy AND sell)
//   lib/screens/wallet/wallet_flows.dart      (add money, withdraw)
//   lib/screens/shared/confirm_passcode_sheet.dart
//   lib/screens/shared/glossary_sheet.dart
// This file is the fix. Every [FlowSpec] below is named after the artboard
// it should visually match (docs/redesign/evidence/trade-wallet.json's
// `buy_sell_journey`), so a future audit can pair render to artboard
// without re-deriving anything.
//
// ADDING A FLOW CAPTURE: one [FlowSpec] entry — a name, a route, the
// dartFile it exercises, and a `steps` list of [Tap]/[EnterText]. Steps run in
// order against the SAME mounted app (each step is a real tap/text-entry on
// whatever sheet the previous step left on screen), with two settle pumps
// after each one, mirroring shots_substates.dart's own timing.
//
//   flutter test test/shots_flows.dart
//   (normally invoked via scripts/design/shots.sh, alongside shots_all.dart
//   and shots_substates.dart)
//
// Output: build/shots/<name>__light.png / __dark.png, plus
// build/shots/_flow_captures.json (same per-capture record shape
// shots_substates.dart's own _substate_captures.json uses — folded into
// build/shots/manifest.json by scripts/design/build_manifest.py's existing
// `build_substate_entries`, unmodified except to also read this file).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
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

/// One interaction step inside a [FlowSpec]: tap an exact [Text] match, or
/// type into the currently-visible `TextField` (there is exactly one on
/// every sheet this file drives — the KInput/amount field for that step).
sealed class FlowStep {
  const FlowStep();
}

class Tap extends FlowStep {
  const Tap(this.text);
  final String text;
}

class EnterText extends FlowStep {
  const EnterText(this.text);
  final String text;
}

/// Taps a 6-digit passcode into `KKeypad` one digit at a time — shared by
/// every flow that ends at the app's real PIN step
/// (confirm_passcode_sheet.dart's `confirmPasscode`).
List<FlowStep> _digits(String code) => code.split('').map(Tap.new).toList();

/// The passcode this file seeds into its own in-memory secure-storage mock
/// (see [_mockPlatformChannels]) so `confirmPasscode` has something real to
/// verify against — without this, PasscodeStore.verifyPasscode always
/// returns false (no salt/hash ever stored) and every flow would dead-end
/// at "Incorrect passcode" instead of ever reaching a placed/success
/// screen. Arbitrary; only this file's own mock reads it.
const _kTestPasscode = '135790';
const _kTestSalt = 'shots-flows-fixed-salt';
String _testPasscodeHash() =>
    sha256.convert(utf8.encode('$_kTestSalt:$_kTestPasscode')).toString();

class FlowSpec {
  const FlowSpec({
    required this.name,
    required this.route,
    required this.dartFile,
    required this.steps,
    this.market = MockMarket.open,
  });

  /// Named after the artboard it should match (e.g. `buy_review_s29`) per
  /// this file's header — never a code-comment id (R-5).
  final String name;
  final String route;
  final String dartFile;
  final List<FlowStep> steps;
  final MockMarket market;
}

final List<FlowSpec> _flows = [
  // ── BUY — chooser (s42) → price (s43) → shares (s43b) → review (s29) →
  //    PIN (s30) → placed (s31). ─────────────────────────────────────────
  FlowSpec(
    name: 'buy_chooser_s42',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Buy')],
  ),
  FlowSpec(
    name: 'buy_price_s43',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Buy'), Tap('Name your price')],
  ),
  FlowSpec(
    name: 'buy_shares_s43b',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Buy'), Tap('Name your price'), Tap('Continue'), EnterText('60')],
  ),
  FlowSpec(
    name: 'buy_review_s29',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [
      Tap('Buy'), Tap('Name your price'), Tap('Continue'), EnterText('60'), Tap('Review order'),
    ],
  ),
  FlowSpec(
    name: 'buy_pin_s30',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [
      Tap('Buy'), Tap('Name your price'), Tap('Continue'), EnterText('60'), Tap('Review order'),
      Tap('I understand the risks'), Tap('Place order'),
    ],
  ),
  FlowSpec(
    name: 'buy_placed_s31',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: [
      const Tap('Buy'), const Tap('Name your price'), const Tap('Continue'), const EnterText('60'),
      const Tap('Review order'), const Tap('I understand the risks'), const Tap('Place order'),
      ..._digits(_kTestPasscode),
    ],
  ),
  // Wrong-code branch of the SAME shared confirm_passcode_sheet.dart —
  // real, reachable state (a mistyped PIN), not decoration.
  FlowSpec(
    name: 'buy_pin_wrong_code',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'shared/confirm_passcode_sheet.dart',
    steps: const [
      Tap('Buy'), Tap('Name your price'), Tap('Continue'), EnterText('60'), Tap('Review order'),
      Tap('I understand the risks'), Tap('Place order'),
      Tap('1'), Tap('1'), Tap('1'), Tap('1'), Tap('1'), Tap('1'),
    ],
  ),

  // ── BUY NOW (market order) branch — shares (s43m) → review (s29m). ────
  FlowSpec(
    name: 'buy_shares_now_s43m',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Buy'), Tap('Buy now'), EnterText('60')],
  ),
  FlowSpec(
    name: 'buy_review_now_s29m',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Buy'), Tap('Buy now'), EnterText('60'), Tap('Review order')],
  ),

  // ── Market-closed interstitial (s29c) — over the review, both sides. ──
  FlowSpec(
    name: 'buy_market_closed_interstitial_s29c',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    market: MockMarket.closed,
    steps: const [
      Tap('Buy'), Tap('Name your price'), Tap('Continue'), EnterText('60'), Tap('Review order'),
      Tap('I understand the risks'), Tap('Place order'),
    ],
  ),

  // ── SELL — chooser (s45) → price (s46) → shares (s47) → review (s48) →
  //    PIN (s30, shared) → placed (same terminal screen as buy's s31). ───
  FlowSpec(
    name: 'sell_chooser_s45',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Sell')],
  ),
  FlowSpec(
    name: 'sell_price_s46',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Sell'), Tap('Name your price')],
  ),
  FlowSpec(
    name: 'sell_shares_s47',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Sell'), Tap('Name your price'), Tap('Continue'), EnterText('20')],
  ),
  FlowSpec(
    name: 'sell_review_s48',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [
      Tap('Sell'), Tap('Name your price'), Tap('Continue'), EnterText('20'), Tap('Review sale'),
    ],
  ),
  FlowSpec(
    name: 'sell_pin_s30',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [
      Tap('Sell'), Tap('Name your price'), Tap('Continue'), EnterText('20'), Tap('Review sale'),
      Tap('Place sell order'),
    ],
  ),
  FlowSpec(
    name: 'sell_placed_s31',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: [
      const Tap('Sell'), const Tap('Name your price'), const Tap('Continue'), const EnterText('20'),
      const Tap('Review sale'), const Tap('Place sell order'),
      ..._digits(_kTestPasscode),
    ],
  ),

  // ── SELL NOW (market order) branch — shares (s46m) → review (s48m). ───
  FlowSpec(
    name: 'sell_shares_now_s46m',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Sell'), Tap('Sell now'), EnterText('20')],
  ),
  FlowSpec(
    name: 'sell_review_now_s48m',
    route: Routes.assetDetail('MTNN'),
    dartFile: 'trade/trade_flows.dart',
    steps: const [Tap('Sell'), Tap('Sell now'), EnterText('20'), Tap('Review sale')],
  ),

  // ── ADD MONEY (s36) — one sheet, method choice + panel. ───────────────
  FlowSpec(
    name: 'add_money_bank_s36',
    route: Routes.wallet,
    dartFile: 'wallet/wallet_flows.dart',
    steps: const [Tap('Add money')],
  ),
  // Card panel — s36 draws no content for this branch (file header); this
  // file's own composition, captured so it's at least reviewed once.
  FlowSpec(
    name: 'add_money_card',
    route: Routes.wallet,
    dartFile: 'wallet/wallet_flows.dart',
    steps: const [Tap('Add money'), Tap('Debit card')],
  ),
  // Real reachable failure: the mock adapter's POST /transactions/fund has
  // no `checkoutUrl` to return (see mock_api_adapter.dart's header — it
  // resolves by PATH only, so this hits the generic list/object fallback),
  // so `_continueCard` genuinely can't launch anything and falls into its
  // own real error sheet — not a broken capture, the honest result of
  // driving this real code path against this fixture.
  FlowSpec(
    name: 'add_money_card_checkout_failed',
    route: Routes.wallet,
    dartFile: 'wallet/wallet_flows.dart',
    steps: const [Tap('Add money'), Tap('Debit card'), Tap('Continue to payment')],
  ),

  // ── WITHDRAW (s37) — see this file's tearDownAll for why only the
  //    outside-hours variant is captured here (R-21; the in-hours sheet is
  //    recorded as unreachable, not skipped). ───────────────────────────
  FlowSpec(
    name: 'withdraw_outside_hours_s37variant',
    route: Routes.wallet,
    dartFile: 'wallet/wallet_flows.dart',
    steps: const [Tap('Withdraw')],
  ),
  FlowSpec(
    name: 'withdraw_outside_hours_pin',
    route: Routes.wallet,
    dartFile: 'shared/confirm_passcode_sheet.dart',
    steps: const [Tap('Withdraw'), Tap('Queue it for 09:00')],
  ),

  // ── Glossary sheet (glossary_sheet.dart) — via FAQ's real "T+3" term. ─
  FlowSpec(
    name: 'glossary_term_t3',
    route: Routes.acctFaq,
    dartFile: 'shared/glossary_sheet.dart',
    steps: const [Tap('T+3')],
  ),
];

/// Flows this file cannot drive to at all, with why — rule 1 of this pass's
/// brief: "If a state cannot be reached, record it as unreachable with the
/// reason — never skip it silently."
///
/// `_WithdrawSheet` (the in-hours s37, and the `_showSuccessSheet` it alone
/// leads to) is chosen by `_isOutsideWithdrawHours()`
/// (lib/screens/wallet/wallet_flows.dart), which reads the REAL
/// `DateTime.now()` — weekday first, so any Saturday/Sunday test run always
/// takes the outside-hours branch regardless of the hour. No clock
/// injection point exists anywhere in that function or AppState (checked:
/// no `package:clock` / injectable `Clock` anywhere in lib/), and adding
/// one would be an app-code change this pass is not permitted to make
/// (rule 2). So which of the two withdraw sheets is reachable depends on
/// the wall-clock day this suite happens to run on — recorded here rather
/// than silently only ever capturing whichever one that day.
const _unreachable = [
  (
    name: 'withdraw_inhours_s37',
    dartFile: 'wallet/wallet_flows.dart',
    reason: "_isOutsideWithdrawHours() checks DateTime.now().weekday first — this suite ran on a "
        'Saturday, so the in-hours _WithdrawSheet branch (and the "Withdrawal started" '
        '_showSuccessSheet only it leads to) cannot be reached without injecting a fake clock, '
        'which needs a lib/ change (out of scope for this pass, rule 2).',
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

/// A real in-memory backing for `flutter_secure_storage`'s method channel —
/// every other shots_*.dart file's own `_mockPlatformChannels` answers
/// every `read` with `null` unconditionally, which is right for THOSE
/// files (nothing in them ever needs a passcode to actually verify) but
/// wrong here: `confirmPasscode` (confirm_passcode_sheet.dart) calls
/// `PasscodeStore.verifyPasscode`, which reads back exactly what
/// `setPasscode` would have written — a null-always mock makes every PIN
/// entry fail as "Incorrect passcode" forever, so no buy/sell/withdraw flow
/// could ever reach its own placed/success screen. Seeded below with a
/// known passcode ([_kTestPasscode]) via the SAME salted-SHA-256 scheme
/// PasscodeStore itself uses (duplicated here rather than imported: that
/// hashing is a private method on PasscodeStore, not exposed for a test to
/// call directly).
void _mockPlatformChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final secureStore = <String, String>{
    'kudimata.passcode.hash': _testPasscodeHash(),
    'kudimata.passcode.salt': _kTestSalt,
    'kudimata.passcode.owner': 'shots-flows@example.com',
  };
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'read':
          return secureStore[args['key'] as String?];
        case 'write':
          final key = args['key'] as String?;
          final value = args['value'] as String?;
          if (key != null && value != null) secureStore[key] = value;
          return null;
        case 'readAll':
          return Map<String, String>.from(secureStore);
        case 'containsKey':
          return secureStore.containsKey(args['key'] as String?);
        case 'delete':
          secureStore.remove(args['key'] as String?);
          return null;
        case 'deleteAll':
          secureStore.clear();
          return null;
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

Future<_Mounted> _mount(WidgetTester tester, FlowSpec spec, ThemeMode mode) async {
  // Same 390×880@3x phone frame as every other shots_*.dart harness.
  tester.view.physicalSize = const Size(1170, 2640);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = mode == ThemeMode.dark ? KPalette.dark : KPalette.light;

  final apiClient = ApiClient();
  apiClient.dio.httpClientAdapter = MockApiAdapter(market: spec.market);
  // Fully eligible, fully onboarded investor — every flow this file drives
  // is gated on tradingEligibilityGap()/KYC+suitability, and this pass is
  // about the trade/wallet sheets themselves, not that gate (already
  // covered by shots_substates.dart's own KYC sub-states).
  final state = AppState()
    ..signedIn = true
    ..biometricEnabled = true
    ..passcodeSet = true
    ..kycSubmitted = true
    ..kycApproved = true
    ..suitabilityComplete = true
    ..riskDisclosureAccepted = true
    ..apiClient = apiClient
    ..kycForm = KycFormState();

  // Deterministic market-open/closed reading — AppState.marketOpen only
  // reflects the fixture once this is actually called (the local
  // wall-clock fallback it otherwise uses isn't deterministic for a
  // screenshot). Must run inside tester.runAsync: testWidgets bodies run in
  // a FakeAsync zone, and a bare top-level `await` on a Future that
  // resolves via the microtask queue never gets flushed there — see
  // shots_substates.dart's identical comment for the full 2026-08-27
  // debugging history behind this.
  await tester.runAsync(() => state.refreshMarketStatus(MarketStatusRepository(apiClient)));

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

  for (final spec in _flows) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final suffix = mode == ThemeMode.dark ? 'dark' : 'light';
      final pngPath = '$_outDir/${spec.name}__$suffix.png';
      final label = '${spec.name} ($suffix)';

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
            mounted.router.go(spec.route);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
            for (final step in spec.steps) {
              switch (step) {
                case Tap(:final text):
                  await tester.tap(find.text(text).first);
                case EnterText(:final text):
                  await tester.enterText(find.byType(TextField).first, text);
              }
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump(const Duration(milliseconds: 350));
            }
            // Extra settle beyond the per-step pumps above: the terminal
            // "placed" screen is a NEW MaterialPageRoute push
            // (trade_flows.dart's _pushPlacedScreen) that only starts once
            // the passcode verify + placeOrder() chain following the last
            // digit tap resolves, so its own ~300ms slide-in transition can
            // still be mid-flight when the per-step pumps above return —
            // caught as a visibly offset/half-scrolled capture before this
            // was added.
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
          } on Object catch (e) {
            renderError = e.toString();
          }

          // Same false-capture guard shots_substates.dart uses: a stray
          // KErrorView means this driven path silently fell off the real
          // sheet it was supposed to land on, not a genuine capture of it.
          String? errorViewError;
          if (find.byType(KErrorView).evaluate().isNotEmpty) {
            errorViewError =
                "rendered the app's own KErrorView (\"Couldn't load\") instead "
                'of the target flow step — likely a step text/order mismatch, '
                'not a genuine capture of ${spec.dartFile}';
          }

          captureError = await _capture(tester, mounted.key, pngPath);
          mounted.state.dispose();

          final rendered = File(pngPath).existsSync() &&
              captureError == null &&
              errorViewError == null;
          _results[label] = {
            'screen': spec.name,
            'substate': 'flow',
            'name': spec.name,
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
            'screen': spec.name,
            'substate': 'flow',
            'name': spec.name,
            'theme': suffix,
            'route': spec.route,
            'dartFile': spec.dartFile,
            'png': null,
            'rendered': false,
            'error': renderError ?? 'unknown',
            'renderNote': null,
          };
        }
      }, timeout: const Timeout(Duration(seconds: 30)));
    }
  }

  tearDownAll(() {
    final records = _results.values.toList();
    for (final u in _unreachable) {
      for (final theme in ['light', 'dark']) {
        records.add({
          'screen': u.name,
          'substate': 'flow',
          'name': u.name,
          'theme': theme,
          'route': Routes.wallet,
          'dartFile': u.dartFile,
          'png': null,
          'rendered': false,
          'error': u.reason,
          'renderNote': null,
        });
      }
    }
    File('$_outDir/_flow_captures.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(records),
    );
    final failed = records.where((r) => r['rendered'] != true).toList();
    // ignore: avoid_print
    print(
      'shots_flows: ${records.length} captures attempted, '
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
