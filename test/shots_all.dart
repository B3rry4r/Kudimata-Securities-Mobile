// Full-coverage screenshot harness for the 56-screen redesign verification
// pass (docs/redesign/PLAN.md). Renders EVERY GoRoute registered in
// lib/router/app_router.dart, in both light and dark, to
// build/shots/<name>__light.png / __dark.png, and writes
// build/shots/_captures.json — the per-route facts (route, source dart
// file, PNG paths, whether it actually rendered) that
// scripts/design/build_manifest.py later merges with docs/redesign/RULINGS.md
// artboard ids into build/shots/manifest.json. Splitting the concerns this
// way (Dart renders + records facts; Python matches those facts against the
// ruling sheet) keeps the artboard lookup out of this file entirely — R-5
// (docs/redesign/DECISIONS.md) is explicit that artboard ids come ONLY from
// RULINGS.md, never from a hand-maintained mapping living next to render
// code that could drift out of sync with it.
//
//   flutter test test/shots_all.dart
//   (normally invoked via scripts/design/shots.sh, which also runs the
//   manifest step and prints the summary)
//
// Route/state pattern follows the existing shots_*.dart siblings:
//   - test/shots.dart: fresh single mount + KColor.active/ThemeMode split
//     for light vs dark (see its 'capture dark mode' test).
//   - test/shots_onboarding.dart: signed-out mount for pre-auth screens,
//     since the default signed-in mount's _gateRedirect bounces
//     splash/welcome/signup/otp/reset straight to /home.
//   - test/shots_kyc.dart: per-screen (kycSubmitted, kycApproved) tuples
//     matching what a real investor actually has AT that point in the flow
//     (router gating only checks signedIn,
//     so these flags don't gate navigation — they gate what the SCREEN
//     ITSELF renders, e.g. approved.dart's status card).
// A fresh mount per (route, theme) pair — rather than one shared mount
// driven through all routes — avoids the animation/timer bleed and the
// asset_detail fake-network flakiness shots.dart's own header documents
// bleeding into whatever route runs right after it.
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
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart'
    show BankAccountSummary;
import 'package:kudimata_invest/data/repositories/statements_repository.dart'
    show Statement, StatementKind;
import 'package:kudimata_invest/data/repositories/complaint_repository.dart'
    show Complaint, ComplaintStatus, ComplaintTimelineEntry;
import 'package:kudimata_invest/router/app_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/kyc/kyc_form_state.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart' show KErrorView;
import 'package:kudimata_invest/theme/app_theme.dart';
import 'package:kudimata_invest/theme/tokens.dart';

import 'fixtures/mock_api_adapter.dart';

const _outDir = 'build/shots';

// ── Fixture extras for the 4 routes GoRoute only accepts via `extra:` ──────
// Values match test/fixtures/mock_api_adapter.dart's own canned responses
// (bank-accounts BA1/GTBank, /statements' ST-M-1 monthly and ST-CN-1
// contract-note rows) so the captured screen matches what the rest of the
// app would show for the same underlying record, not an arbitrary one.
final _bankAccount = const BankAccountSummary(
  id: 'BA1',
  bankName: 'GTBank',
  accountNumberMasked: '••••6789',
  primary: true,
  addedDate: '14 Mar 2026',
);
final _monthlyStatement = Statement(
  id: 'ST-M-1',
  kind: StatementKind.monthly,
  title: 'Statement — February 2026',
  periodOrTradeRef: '2026-02',
  fileSizeBytes: 18842,
  generatedAt: DateTime.parse('2026-03-01T02:00:00.000Z'),
  fileObjectKey: 'statements/monthly/u/2026-02.pdf',
);
final _contractNoteStatement = Statement(
  id: 'ST-CN-1',
  kind: StatementKind.contractNote,
  title: 'Contract note — Bought MTNN',
  periodOrTradeRef: 'KDM-CN-4471',
  fileSizeBytes: 71693,
  generatedAt: DateTime.parse('2026-03-14T09:41:00.000Z'),
  fileObjectKey: 'statements/contract-notes/u/KDM-CN-4471.pdf',
);
final _complaint = Complaint(
  id: 'C1',
  reference: 'CMP-1001',
  userId: 'U1',
  category: 'Trade execution',
  description: 'Order took longer than expected to fill.',
  status: ComplaintStatus.reviewing,
  filedAt: DateTime.parse('2026-03-01T09:00:00.000Z'),
  answerDueAt: DateTime.parse('2026-03-15T09:00:00.000Z'),
  // A populated register log. This fixture carried `timeline: null` until
  // 2026-09-02, so the branch that renders staff replies had never once been
  // captured — the screen was only ever seen in its empty state, which is the
  // state that will stop being typical the moment the staff queue ships.
  timeline: [
    ComplaintTimelineEntry(
      label: 'Complaint received',
      at: DateTime.parse('2026-03-01T09:00:00.000Z'),
      by: 'Kudimata Securities',
    ),
    ComplaintTimelineEntry(
      label: 'A member of our team is reviewing your order history.',
      at: DateTime.parse('2026-03-02T11:20:00.000Z'),
      by: 'Client Services',
    ),
  ],
);

/// One captured (or attempted) screen. [dartFile]/[rulingKey] are relative
/// to `lib/screens/` and match RULINGS.md's `screen` column EXACTLY
/// (including any `#fragment` suffix for a file that holds more than one
/// routed screen) — build_manifest.py looks up artboard ids by that exact
/// string, never by guessing from the file name alone.
class _RouteSpec {
  const _RouteSpec(
    this.name,
    this.path,
    this.dartFile, {
    this.signedIn = true,
    this.kycSubmitted = true,
    this.kycApproved = true,
    this.extra,
    String? rulingKey,
  }) : rulingKey = rulingKey ?? dartFile;

  final String name;
  final String path;
  final String dartFile;
  final String rulingKey;
  final bool signedIn;
  final bool kycSubmitted;
  final bool kycApproved;
  final Object? extra;
}

// Every GoRoute registered in lib/router/app_router.dart (75 total: 76 as
// of the 2026-08-27 flow pass, which added kycChecklist/onboardingNextSteps/
// setPriceAlert — 73 before — minus onboardingNextSteps itself, removed
// 2026-08-31 along with whats_next_screen.dart per direct product-owner
// instruction; see DECISIONS.md's superseding note under R-33. The
// errorBuilder's RouteNotFoundScreen is a fallback, not a registered route,
// and is deliberately excluded). Grouped to match the state each screen is
// actually reached with in the real flow — see the file header.
final List<_RouteSpec> _specs = [
  // ── Onboarding / pre-auth (signed out, matching shots_onboarding.dart) ──
  _RouteSpec('01_splash', Routes.splash, 'onboarding/splash_screen.dart', signedIn: false),
  _RouteSpec('02_welcome', Routes.welcome, 'onboarding/welcome_slider_screen.dart', signedIn: false),
  _RouteSpec('03_signup', Routes.signup, 'onboarding/sign_up_screen.dart', signedIn: false),
  _RouteSpec('04_otp', Routes.otp, 'onboarding/otp_screen.dart', signedIn: false),
  // 05_legal_bundle_preview/06_legal_preview_kind/07_terms no longer exist
  // (R-51, DECISIONS.md, 2026-08-31) — legal_preview_screen.dart,
  // terms_and_privacy_screen.dart and their routes are all gone. otp above
  // hands straight to passcode creation below.
  _RouteSpec('08_passcode_create', Routes.createPasscode, 'onboarding/create_passcode_screen.dart',
      signedIn: false),
  _RouteSpec('09_passcode_confirm', Routes.confirmPasscode, 'onboarding/confirm_passcode_screen.dart',
      signedIn: false),
  _RouteSpec('10_biometric', Routes.biometric, 'onboarding/biometric_screen.dart', signedIn: false),
  // D-4 (2026-08-27 removals pass, R-8): document_summary_screen.dart
  // dropped — it was never wired in (superseded by legal documents opening
  // in the phone's native viewer), so '11_document_summary' no longer
  // exists.
  // Screen 10 onward is reached with signedIn already true (confirm_passcode/
  // biometric call setSignedIn(true) partway through the real flow) — see
  // shots_onboarding.dart's own header comment for the same reasoning.
  _RouteSpec('12_onboarding_personal', Routes.onboardingPersonal,
      'onboarding/personal_details_screen.dart'),
  _RouteSpec('13_onboarding_avatar', Routes.onboardingAvatar, 'onboarding/avatar_screen.dart'),
  // s07 "Your account is ready" (X-4, SHARED-CHANGES.md 2026-08-27) used to
  // sit here, between avatar selection and KYC start — removed 2026-08-31
  // (DECISIONS.md's superseding note under R-33): both of avatar_screen.
  // dart's exits now go straight to Home.
  _RouteSpec('14_login', Routes.login, 'onboarding/log_in_screen.dart', signedIn: false),
  _RouteSpec('15_reset', Routes.reset, 'onboarding/reset_passcode_screen.dart', signedIn: false),

  // ── KYC + suitability (signed in; per-screen progress flags matching
  //    shots_kyc.dart's table — router gating only checks signedIn, so these
  //    flags drive what each screen itself shows, not navigation) ──────────
  _RouteSpec('16_kyc_intro', Routes.kycIntro, 'kyc/kyc_intro.dart',
      kycSubmitted: false, kycApproved: false),
  // s11 checklist hub (S-8, SHARED-CHANGES.md 2026-08-27) — the flow's
  // spine, re-entered after every completed step; same in-progress flags
  // as kyc_intro above.
  _RouteSpec('16b_kyc_checklist', Routes.kycChecklist, 'kyc/kyc_checklist_screen.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('17_kyc_bvn', Routes.kycBvn, 'kyc/bvn_nin.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('18_kyc_chn', Routes.kycChn, 'kyc/chn_screen.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('19_kyc_id', Routes.kycId, 'kyc/id_upload.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('20_kyc_liveness', Routes.kycLiveness, 'kyc/liveness.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('21_kyc_checking', Routes.kycChecking, 'kyc/checking.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('22_kyc_utility_bill', Routes.kycUtilityBill, 'kyc/utility_bill.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('23_kyc_bank_dcs', Routes.kycBankDcs, 'kyc/bank_dcs_screen.dart',
      kycSubmitted: false, kycApproved: false),
  // Source of funds — KYC step 6, added 2026-09-04 (SEC No Objection
  // condition 2). Numbered 23b rather than renumbering every capture after
  // it: the shot names are how a reviewer finds a screen across runs.
  _RouteSpec('23b_kyc_source_of_funds', Routes.kycSourceOfFunds, 'kyc/source_of_funds_screen.dart',
      kycSubmitted: false, kycApproved: false),
  _RouteSpec('24_kyc_declarations', Routes.kycDeclarations, 'kyc/declarations_screen.dart',
      kycSubmitted: false, kycApproved: false),
  // D-1 (2026-08-27 removals pass, R-9): review_submit_screen.dart dropped
  // — Next of kin (above) is now the last collection step and submits
  // directly, so the '26_kyc_review' capture no longer exists.
  _RouteSpec('27_kyc_submitted', Routes.kycSubmitted, 'kyc/submitted.dart',
      kycApproved: false),
  _RouteSpec('28_kyc_approved', Routes.kycApproved, 'kyc/approved.dart'),
  _RouteSpec('29_kyc_outcome', Routes.kycOutcome, 'kyc/outcome_not_approved.dart'),
  // '30_questionnaire'/'31_suitability_result'/'32_risk_disclaimer' no
  // longer exist (R-51, DECISIONS.md, 2026-08-31): the suitability
  // questionnaire, its result screen and the legal-documents/risk-disclosure
  // chain they used to hand off to are all removed — see routes.dart's own
  // header notes.

  // ── Pushed detail (fully onboarded investor) ────────────────────────────
  _RouteSpec('33_notifications', Routes.notifications, 'home/notifications_screen.dart'),
  _RouteSpec('34_search', Routes.search, 'home/search_screen.dart'),
  _RouteSpec('35_orders', Routes.orderStatus, 'portfolio/order_status_screen.dart'),
  // Home's "Learn" quick action destination (owner direction, 2026-08-29) —
  // no canvas screen number of its own (no artboard covers it; see
  // learn_screen.dart's header).
  _RouteSpec('35b_learn', Routes.learn, 'home/learn_screen.dart'),
  // D-2 (2026-08-27 removals pass, R-16): watchlist_screen.dart dropped —
  // '36_watchlist' no longer exists. See account_screen.dart's 'My alerts'
  // row / price_alerts_screen.dart for the surviving reader.
  _RouteSpec('37_asset_detail', Routes.assetDetail('MTNN'), 'markets/asset_detail_screen.dart'),
  // s49 "Set a price alert" (S-11/X-7, SHARED-CHANGES.md 2026-08-27) —
  // public, ticker-parametrised; reached from the asset page's own bell
  // icon-button as well as price_alerts_screen.dart's "New alert" picker.
  _RouteSpec('37b_set_price_alert', Routes.setPriceAlert('MTNN'), 'markets/price_alerts_screen.dart',
      rulingKey: 'markets/price_alerts_screen.dart#set_price_alert'),
  _RouteSpec('38_explain', Routes.explainThis('MTNN'), 'markets/explain_screen.dart'),
  _RouteSpec('39_holding_detail', Routes.holdingDetail('MTNN'), 'portfolio/holding_detail_screen.dart'),
  _RouteSpec('40_transaction_detail', Routes.transactionDetail('TX1042'), 'wallet/wallet_screens.dart',
      rulingKey: 'wallet/wallet_screens.dart#transaction_detail'),

  // ── Account sub-pages ────────────────────────────────────────────────────
  _RouteSpec('41_acct_personal', Routes.acctPersonal, 'account/personal_info_screen.dart'),
  _RouteSpec('42_acct_banks', Routes.acctBanks, 'account/bank_accounts_screen.dart'),
  // Payout preference — SEC No Objection condition 1 (2026-09-04). Same 'b'
  // suffix convention as 23b above, for the same reason.
  _RouteSpec('42b_acct_payout_preference', Routes.acctPayoutPreference,
      'account/payout_preference_screen.dart'),
  _RouteSpec('43_acct_refer', Routes.acctRefer, 'account/refer_earn_screen.dart'),
  _RouteSpec('44_acct_help', Routes.acctHelp, 'account/help_support_screen.dart'),
  _RouteSpec('45_acct_faq', Routes.acctFaq, 'account/faq_screen.dart'),
  _RouteSpec('46_acct_security', Routes.acctSecurity, 'account/security_screen.dart'),
  _RouteSpec('47_acct_notifications', Routes.acctNotifications,
      'account/notifications_settings_screen.dart'),
  // '48_acct_legal' no longer exists (R-51, DECISIONS.md, 2026-08-31) —
  // legal_screen.dart and Routes.acctLegal are gone; the "Terms and
  // disclosures" row opens KLinks.legal externally instead of pushing an
  // in-app screen (account_screen.dart's own note on that row).
  _RouteSpec('49_acct_statements', Routes.acctStatements, 'account/statements_screen.dart'),
  _RouteSpec('50_acct_freeze', Routes.acctFreeze, 'account/freeze_account_screen.dart'),
  _RouteSpec('51_security_alert', Routes.securityAlert, 'account/security_alert_screen.dart'),
  _RouteSpec('52_acct_plans', Routes.acctPlans, 'account/plans_screen.dart'),
  _RouteSpec('53_withdraw_mandate', Routes.acctWithdrawMandate, 'account/withdraw_mandate_screen.dart',
      extra: _bankAccount),
  _RouteSpec('54_contract_note', Routes.contractNote, 'account/contract_note_screen.dart',
      extra: _contractNoteStatement),

  // ── Screens 76-97 (2026-08-23 canvas expansion) ─────────────────────────
  _RouteSpec('55_statement_detail', Routes.acctStatementDetail, 'account/statement_detail_screen.dart',
      extra: _monthlyStatement),
  _RouteSpec('55b_request_statement', Routes.acctRequestStatement,
      'account/request_statement_screen.dart'),
  _RouteSpec('56_acct_tax', Routes.acctTax, 'account/tax_documents_screen.dart'),
  _RouteSpec('57_price_alerts', Routes.priceAlerts, 'markets/price_alerts_screen.dart'),
  _RouteSpec('58_corp_actions', Routes.corpActions, 'corporate_actions/corporate_actions_screen.dart'),
  _RouteSpec('59_rights_issue', Routes.corpActionsRightsIssue,
      'corporate_actions/rights_issue_screen.dart'),
  _RouteSpec('60_agm_vote', Routes.corpActionsAgm, 'corporate_actions/agm_vote_screen.dart'),
  _RouteSpec('61_dividends', Routes.corpActionsDividends, 'corporate_actions/dividends_screen.dart'),
  _RouteSpec('62_complaint', Routes.acctComplaint, 'account/complaint_screen.dart'),
  _RouteSpec('63_complaint_tracked', Routes.acctComplaintTracked,
      'account/complaint_tracked_screen.dart', extra: _complaint),
  _RouteSpec('64_dormant', Routes.acctDormant, 'account/dormant_account_screen.dart'),
  _RouteSpec('65_close_account', Routes.acctClose, 'account/close_account_screen.dart'),
  _RouteSpec('66_data_privacy', Routes.acctDataPrivacy, 'account/data_privacy_screen.dart'),
  _RouteSpec('67_locked_out', Routes.lockedOut, 'onboarding/locked_out_screen.dart'),
  _RouteSpec('68_partner_disclosures', Routes.acctLegalPartnerDisclosures,
      'account/legal_reference_screens.dart'),
  _RouteSpec('69_referral_terms', Routes.acctLegalReferralTerms,
      'account/legal_reference_screens.dart'),
  _RouteSpec('70_data_notice', Routes.acctLegalDataNotice, 'account/legal_reference_screens.dart'),
  _RouteSpec('71_closure_terms', Routes.acctLegalClosureTerms,
      'account/legal_reference_screens.dart'),

  // ── Tab roots ────────────────────────────────────────────────────────────
  _RouteSpec('72_home', Routes.home, 'home/home_screen.dart'),
  _RouteSpec('73_portfolio', Routes.portfolio, 'portfolio/portfolio_screen.dart'),
  _RouteSpec('74_markets', Routes.markets, 'markets/markets_screen.dart'),
  _RouteSpec('75_wallet', Routes.wallet, 'wallet/wallet_screens.dart',
      rulingKey: 'wallet/wallet_screens.dart#wallet_home'),
  _RouteSpec('76_account', Routes.account, 'account/account_screen.dart'),
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

/// Returns null on success, or an error description if even the PNG write
/// itself failed (as opposed to the screen merely rendering an error state,
/// which is still a successful capture — see file header).
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

Future<_Mounted> _mount(WidgetTester tester, _RouteSpec spec, ThemeMode mode) async {
  // screen-specs.md: "Screens 01–66 are 390×880 phone frames." — see
  // test/shots.dart's identical setup for the full rationale.
  tester.view.physicalSize = const Size(1170, 2640); // 390×880 @ 3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  KColor.active = mode == ThemeMode.dark ? KPalette.dark : KPalette.light;

  final apiClient = ApiClient();
  apiClient.dio.httpClientAdapter = MockApiAdapter();
  final state = AppState()
    ..signedIn = spec.signedIn
    ..biometricEnabled = spec.signedIn
    ..passcodeSet = spec.signedIn
    ..kycSubmitted = spec.kycSubmitted
    ..kycApproved = spec.kycApproved
    ..apiClient = apiClient
    // declarations_screen.dart/next_of_kin.dart/review_submit_screen.dart
    // read AppScope.read(context).kycForm at build time (2026-08-24) — main.
    // dart's real bootstrap always sets this, so every mount does too,
    // harmless for screens that never touch it.
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

/// One record per (route, theme), keyed by its `'$name ($theme)'` label —
/// written to build/shots/_captures.json at the end of the run for
/// scripts/design/build_manifest.py to consume. A map (not a list) so the
/// teardown-error handler below can merge a note into an already-recorded
/// entry after the fact.
final _results = <String, Map<String, Object?>>{};

/// A FRAMEWORK-level error caught by [FlutterError.onError] (not by this
/// file's own try/catch, since it fires during the widget tree's automatic
/// teardown AFTER this test's body has already returned successfully),
/// keyed by capture label so it can still be attributed and recorded —
/// same technique test/shots.dart's own `_layoutErrors` uses. Found live:
/// lib/widgets/comprehension.dart's `_KGeneratingTextState._shimmerCtrl` is
/// a `late final` only ever read from build()'s `thinking`-state branch — a
/// KGeneratingText that starts in the (default) `writing` state and is
/// disposed without ever passing through `thinking` creates its
/// AnimationController for the first time INSIDE dispose(), which needs a
/// still-active element tree and throws ("Looking up a deactivated widget's
/// ancestor is unsafe"). Pre-existing app bug, out of scope to fix here (see
/// this file's header — screens/widgets are not touched by this pass) but
/// real: markets/explain_screen.dart's ExplainScreen hits it. Overriding
/// onError here only keeps THIS harness from reporting it as a test
/// failure; it does not silence or fix the underlying defect.
final _teardownErrors = <String, String>{};

void main() {
  setUpAll(() async {
    await _loadFonts();
    Directory(_outDir).createSync(recursive: true);
  });

  for (final spec in _specs) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final suffix = mode == ThemeMode.dark ? 'dark' : 'light';
      final pngPath = '$_outDir/${spec.name}__$suffix.png';
      final label = '${spec.name} ($suffix)';

      testWidgets('capture $label', (tester) async {
        // Must be set as the FIRST statement inside the testWidgets body
        // (not in an outer setUp) — testWidgets installs its own
        // error-catching FlutterError.onError as part of entering the
        // test's zone, which would otherwise clobber an override set
        // earlier. Same placement test/shots.dart's own onError override
        // uses, for the same reason.
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
            // Every mount lands on Home first (initialLocation: splash,
            // redirected there since these mounts are always signed in —
            // see _mount/_gateRedirect), and Home's own _initialLoad kicks
            // off an async KYC-gating refresh (refreshKycGatingState) that
            // calls several AppState setters — each a notifyListeners() —
            // once it resolves. Home never actually unmounts when we
            // navigate away (it's a StatefulShellRoute branch root kept
            // alive in the IndexedStack), so if that refresh is STILL
            // in-flight when we go() to a route below, its notifyListeners()
            // fires AFTER navigation and hits GoRouter's refreshListenable —
            // which reparses the CURRENT location from the bare URI alone.
            // `extra` isn't part of the URI, so that reparse silently drops
            // it, and any of the 4 routes below that type-guard on `extra`
            // (see app_router.dart) falls through to their `KErrorView`
            // fallback — a real capture bug found 2026-08-27: shots.sh was
            // reporting these as successful captures of the target screen
            // when the PNG was actually the app's own "Couldn't load" error
            // card (see the KErrorView detection below, and this loop's own
            // rendered/error bookkeeping). Draining Home's in-flight refresh
            // HERE, before navigating, means its notifyListeners() calls all
            // land while we're still on Home (harmless — same route,
            // rebuilding from the same URI loses nothing) instead of after,
            // so the extra we're about to pass survives. Scoped to
            // extra-bearing specs only: every other spec's mount already
            // pays this settle cost implicitly via the pumps below, and
            // widening it to all 144 captures for a bug that's only
            // observable on 8 of them isn't worth the runtime.
            if (spec.extra != null) {
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump(const Duration(milliseconds: 350));
            }
            mounted.router.go(spec.path, extra: spec.extra);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
          } on Object catch (e) {
            // The screen's own build/navigation threw outside anything
            // _capture() can catch — same broad-swallow reasoning as
            // shots.dart's main loop: this harness is visual QA, not a
            // correctness assertion, so one screen's backend-error handling
            // shouldn't take out its own capture attempt. Still try to
            // capture whatever ended up on screen before giving up.
            renderError = e.toString();
          }

          // A capture that shows the app's OWN error/"couldn't load" card
          // (KErrorView — state_views.dart) is NOT a successful capture of
          // the target screen, no matter how cleanly the PNG wrote — it's
          // evidence the route failed to resolve (e.g. a dropped/mistyped
          // `extra`, see the comment above) or the screen's own FutureBuilder
          // hit its error branch. Every KErrorView call site in lib/screens/
          // is gated behind `snapshot.hasError`/an explicit failure branch —
          // never a happy-path render — so finding one on screen after the
          // settle pumps is unambiguous. Checked BEFORE _capture() (which
          // still runs regardless, so the misleading PNG is available for
          // inspection), and — unlike [renderError] above, which is kept
          // only as an informational note when a PNG still came out usable —
          // this UNCONDITIONALLY fails the capture below: this is what makes
          // a false "N screens captured, 0 unrenderable" like 2026-08-27's
          // actually impossible, instead of just noting it happened.
          String? errorViewError;
          if (find.byType(KErrorView).evaluate().isNotEmpty) {
            errorViewError =
                "rendered the app's own KErrorView (\"Couldn't load\") instead "
                'of the target screen — likely a dropped/mistyped `extra` '
                'or an unhandled backend-error fixture, not a genuine '
                'capture of ${spec.dartFile}';
          }

          captureError = await _capture(tester, mounted.key, pngPath);
          mounted.state.dispose();

          final rendered = File(pngPath).existsSync() &&
              captureError == null &&
              errorViewError == null;
          _results[label] = {
            'name': spec.name,
            'theme': suffix,
            'route': spec.path,
            'dartFile': spec.dartFile,
            'rulingKey': spec.rulingKey,
            'png': rendered ? pngPath : null,
            'rendered': rendered,
            'error': rendered ? null : (errorViewError ?? renderError ?? captureError ?? 'unknown'),
            // Kept even when rendered=true: a screen can throw mid-build (e.g.
            // a caught backend-error future) and still produce a usable PNG of
            // whatever state it settled into — this is a transparency note,
            // not a reason the capture is missing.
            'renderNote': rendered ? renderError : null,
          };
        } else {
          _results[label] = {
            'name': spec.name,
            'theme': suffix,
            'route': spec.path,
            'dartFile': spec.dartFile,
            'rulingKey': spec.rulingKey,
            'png': null,
            'rendered': false,
            'error': renderError ?? 'unknown',
            'renderNote': null,
          };
        }
      });
    }
  }

  tearDownAll(() {
    final records = _results.values.toList();
    File('$_outDir/_captures.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(records),
    );
    final failed = records.where((r) => r['rendered'] != true).toList();
    // ignore: avoid_print
    print(
      'shots_all: ${records.length} captures attempted, '
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
