// Screenshot harness for UNROUTED picker/explainer sheets that live behind
// a tap inside an already-routed screen — the same structural gap
// test/shots_flows.dart's header describes for buy/sell/add-money/withdraw,
// but for the ~54 other `showKSheet`/`showModalBottomSheet` call sites
// across lib/ (grepped 2026-08-29 during an independent capture audit).
// shots_all.dart's route walk mounts the HOST screen (bank_dcs, next_of_kin,
// declarations, bank_accounts, complaint) and stops there; it structurally
// cannot see a sheet that only opens after a tap. This file drives a
// curated, verified subset of those sheets — the ones with real, distinct
// visual content (a picker list, an explainer panel, a row-actions sheet) —
// not the trivial one-line "couldn't save" error toasts already exercised
// indirectly elsewhere.
//
// NOT covered here (documented as a finding by the audit that produced this
// file, not as "unreachable" — these ARE reachable, just not yet driven):
// personal_info_screen.dart's city/state, phone, address edit sheets and
// avatar picker (icon-only triggers, no stable text finder found without
// risking a false-positive tap); price_alerts_screen.dart's ticker picker;
// onboarding/personal_details_screen.dart's state/country pickers;
// plans_screen.dart's low-balance sheet (needs a wallet-balance fixture
// override); security_screen.dart's confirm sheet.
//
//   flutter test test/shots_pickers.dart
//
// Output: build/shots/<name>__light.png / __dark.png, plus
// build/shots/_picker_captures.json (same shape as shots_flows.dart's own
// _flow_captures.json).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
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
import 'package:kudimata_invest/screens/shared/state_views.dart' show KErrorView;
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

const _outDir = 'build/shots';

sealed class Step {
  const Step();
}

class Tap extends Step {
  const Tap(this.text);
  final String text;
}

/// Invokes a [TapGestureRecognizer] attached to one [TextSpan] whose own
/// `text` (not the enclosing [RichText]'s full `toPlainText()`) equals
/// [text] exactly — for links embedded mid-sentence in a raw `RichText`
/// (e.g. declarations_screen.dart's "What's a PEP?"), where
/// `find.text(_, findRichText: true)` matches against the WHOLE
/// [InlineSpan.toPlainText] (every sibling span concatenated), not the one
/// span actually carrying the recognizer, and so never equals a snippet
/// like just "What's a PEP?" on its own.
class TapRichSpan extends Step {
  const TapRichSpan(this.text);
  final String text;
}

class PickerSpec {
  const PickerSpec({
    required this.name,
    required this.route,
    required this.dartFile,
    required this.steps,
    this.kycSubmitted = true,
    this.kycApproved = true,
  });

  /// Descriptive name — none of these sheets have a canvas artboard id (all
  /// are "kept though undrawn" per RULINGS.md/DECISIONS.md's own no-artboard
  /// buckets for these files), so unlike shots_flows.dart's sNN-suffixed
  /// names, these are named `<host screen>_<sheet purpose>` instead of a
  /// fabricated artboard id.
  final String name;
  final String route;
  final String dartFile;
  final List<Step> steps;

  /// Per-spec AppState.kycSubmitted/kycApproved — KYC in-progress screens
  /// (next_of_kin, declarations, bank_dcs, utility_bill) need
  /// kycSubmitted=false to render their own normal draft-in-progress body;
  /// account screens (bank_accounts, complaint) need a fully-onboarded
  /// investor so the tab shell itself renders.
  final bool kycSubmitted;
  final bool kycApproved;
}

final List<PickerSpec> _pickers = [
  // ── next_of_kin.dart (kyc/next_of_kin.dart) — R-9's own final KYC
  //    collection step; this is its ONE interactive sheet. ────────────────
  PickerSpec(
    name: 'next_of_kin_relationship_picker',
    route: Routes.kycNextOfKin,
    dartFile: 'kyc/next_of_kin.dart',
    kycSubmitted: false,
    kycApproved: false,
    steps: const [Tap('Select')],
  ),

  // ── kyc/utility_bill.dart — address state picker (kyc/_address_data.dart
  //    backs it; the LGA picker is a second tap gated on a state already
  //    being chosen, not driven here to keep this a single verified tap). ─
  PickerSpec(
    name: 'utility_bill_state_picker',
    route: Routes.kycUtilityBill,
    dartFile: 'kyc/_address_data.dart',
    kycSubmitted: false,
    kycApproved: false,
    steps: const [Tap('Select')],
  ),

  // ── kyc/declarations_screen.dart — PEP explainer + (after answering
  //    "Yes") the position-holder picker. ─────────────────────────────────
  PickerSpec(
    name: 'declarations_pep_explainer',
    route: Routes.kycDeclarations,
    dartFile: 'kyc/declarations_screen.dart',
    kycSubmitted: false,
    kycApproved: false,
    steps: const [TapRichSpan("What's a PEP?")],
  ),
  PickerSpec(
    name: 'declarations_pep_who_picker',
    route: Routes.kycDeclarations,
    dartFile: 'kyc/declarations_screen.dart',
    kycSubmitted: false,
    kycApproved: false,
    steps: const [Tap('Yes'), Tap('Select')],
  ),

  // ── kyc/bank_dcs_screen.dart — bank picker (behind "Change" on the
  //    existing-account card the mock's one seeded bank account produces)
  //    + the DCS explainer panel. ─────────────────────────────────────────
  PickerSpec(
    name: 'bank_dcs_bank_picker',
    route: Routes.kycBankDcs,
    dartFile: 'kyc/bank_dcs_screen.dart',
    kycSubmitted: false,
    kycApproved: false,
    steps: const [Tap('Change'), Tap('Select bank')],
  ),
  PickerSpec(
    name: 'bank_dcs_explainer',
    route: Routes.kycBankDcs,
    dartFile: 'kyc/bank_dcs_screen.dart',
    kycSubmitted: false,
    kycApproved: false,
    steps: const [Tap('What is Direct Cash Settlement?')],
  ),

  // ── account/bank_accounts_screen.dart — bank picker (behind "Add another
  //    account", since the mock seeds one existing primary account) + the
  //    row-actions sheet on that existing account. ───────────────────────
  PickerSpec(
    name: 'bank_accounts_select_bank_picker',
    route: Routes.acctBanks,
    dartFile: 'account/bank_accounts_screen.dart',
    steps: const [Tap('Add another account'), Tap('Select bank')],
  ),
  PickerSpec(
    name: 'bank_accounts_row_actions',
    route: Routes.acctBanks,
    dartFile: 'account/bank_accounts_screen.dart',
    steps: const [Tap('GTBank ••••6789')],
  ),

  // complaint_screen.dart's own topic picker (_pickTopic/_ComplaintTopicSheet)
  // is NOT captured here — see this file's header. It lives on
  // `_ComplaintFormScreen`, reached only by pushing a MaterialPageRoute from
  // the routed ComplaintScreen, and every category row on that screen ALSO
  // matches part of the same literal strings the footer "File a complaint"
  // button's own tap needs to disambiguate from — driving it reliably needs
  // a widget-tree-position finder (e.g. find.ancestor keyed off the footer),
  // not the plain text finder every other spec here uses; left undriven
  // this pass rather than shipped as an unverified, possibly-flaky capture.
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

Future<_Mounted> _mount(WidgetTester tester, PickerSpec spec, ThemeMode mode) async {
  // Same 390×880@3x phone frame as every other shots_*.dart harness.
  tester.view.physicalSize = const Size(1170, 2640);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = mode == ThemeMode.dark ? KPalette.dark : KPalette.light;

  final apiClient = ApiClient();
  apiClient.dio.httpClientAdapter = MockApiAdapter();
  final state = AppState()
    ..signedIn = true
    ..biometricEnabled = true
    ..passcodeSet = true
    ..kycSubmitted = spec.kycSubmitted
    ..kycApproved = spec.kycApproved
    ..apiClient = apiClient
    ..kycForm = KycFormState();

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

void main() {
  setUpAll(() async {
    await _loadFonts();
    Directory(_outDir).createSync(recursive: true);
  });

  for (final spec in _pickers) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final suffix = mode == ThemeMode.dark ? 'dark' : 'light';
      final pngPath = '$_outDir/${spec.name}__$suffix.png';
      final label = '${spec.name} ($suffix)';

      testWidgets('capture $label', (tester) async {
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
                  final tapFinder = find.text(text).first;
                  await tester.ensureVisible(tapFinder);
                  await tester.pump(const Duration(milliseconds: 100));
                  await tester.tap(tapFinder);
                case TapRichSpan(:final text):
                  // find.text's findRichText:true compares against the
                  // WHOLE RichText's InlineSpan.toPlainText() — every
                  // sibling TextSpan concatenated — so it never equals a
                  // sentence-fragment link like "What's a PEP?" on its own
                  // when it shares a RichText with other prose spans.
                  // Walk every RichText's span tree instead and invoke the
                  // recognizer on the ONE span whose own text matches.
                  TapGestureRecognizer? found;
                  for (final e in find.byType(RichText).evaluate()) {
                    final root = (e.widget as RichText).text;
                    root.visitChildren((span) {
                      if (span is TextSpan &&
                          span.text == text &&
                          span.recognizer is TapGestureRecognizer) {
                        found = span.recognizer as TapGestureRecognizer;
                      }
                      return found == null;
                    });
                    if (found != null) break;
                  }
                  if (found == null) {
                    throw StateError('No TapGestureRecognizer found for span "$text"');
                  }
                  found!.onTap!();
              }
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump(const Duration(milliseconds: 350));
            }
          } on Object catch (e) {
            renderError = e.toString();
          }

          // Same false-capture guard shots_flows.dart/shots_substates.dart
          // use: a stray KErrorView means the driven path fell off the
          // real sheet it was supposed to land on.
          String? errorViewError;
          if (find.byType(KErrorView).evaluate().isNotEmpty) {
            errorViewError =
                "rendered the app's own KErrorView (\"Couldn't load\") instead "
                'of the target sheet — likely a step text/order mismatch, '
                'not a genuine capture of ${spec.dartFile}';
          }

          captureError = await _capture(tester, mounted.key, pngPath);
          mounted.state.dispose();

          // renderError (a step that threw — e.g. its finder text matched
          // nothing) MUST fail this capture even if a PNG still got
          // written afterward: a screenshot of whatever was on screen
          // before the failed tap is exactly the false-capture trap this
          // guard exists to catch, not a genuine capture of the target
          // sheet.
          final rendered = renderError == null &&
              File(pngPath).existsSync() &&
              captureError == null &&
              errorViewError == null;
          if (!rendered && File(pngPath).existsSync()) {
            // Never keep a false capture as evidence — delete it.
            File(pngPath).deleteSync();
          }
          _results[label] = {
            'screen': spec.name,
            'substate': 'picker',
            'name': spec.name,
            'theme': suffix,
            'route': spec.route,
            'dartFile': spec.dartFile,
            'png': rendered ? pngPath : null,
            'rendered': rendered,
            'error': rendered ? null : (errorViewError ?? renderError ?? captureError ?? 'unknown'),
          };
        } else {
          _results[label] = {
            'screen': spec.name,
            'substate': 'picker',
            'name': spec.name,
            'theme': suffix,
            'route': spec.route,
            'dartFile': spec.dartFile,
            'png': null,
            'rendered': false,
            'error': renderError ?? 'unknown',
          };
        }
      }, timeout: const Timeout(Duration(seconds: 30)));
    }
  }

  tearDownAll(() {
    final records = _results.values.toList();
    File('$_outDir/_picker_captures.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(records),
    );
    final failed = records.where((r) => r['rendered'] != true).toList();
    // ignore: avoid_print
    print(
      'shots_pickers: ${records.length} captures attempted, '
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
