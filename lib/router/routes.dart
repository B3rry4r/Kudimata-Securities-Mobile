// Kudimata Securities — route table. Path constants + dynamic-route helpers for
// GoRouter. The 4 tab roots (R-28, 2026-08-26: Home · Markets · Portfolio ·
// Wallet — "You" removed, account reached from the header avatar) live in a
// StatefulShellRoute (indexedStack); every `pushed` route below is TOP-LEVEL
// so it covers the shell (no tab bar). `account` is one such pushed route now
// — it used to be the 5th tab root.
//
// Navigation convention:
//   • gated linear steps  → context.go(...)   (replace, no back stack)
//   • pushed detail screens → context.push(...) (over the shell)
//   • dismiss a pushed screen → context.pop()
class Routes {
  Routes._();

  // ── Gated onboarding flow ────────────────────────────────────────────────
  static const String splash = '/';
  // Illustrated welcome slider (2026-08-22 "Soft Landing" redesign, screen
  // 02) — first thing a first-time (no passcode set yet) investor sees
  // after splash, before sign-up/log-in.
  static const String welcome = '/welcome';
  static const String signup = '/signup';
  static const String otp = '/otp';
  // ALL FOUR legal documents (terms of service, privacy policy, risk
  // disclosure, client agreement) — ONE combined screen/tick (2026-08-20
  // consolidation, final pass, see terms_and_privacy_screen.dart), accepted
  // right after OTP verification, before passcode/KYC. Path segment still
  // says "suitability" for historical reasons.
  static const String termsOfService = '/suitability/terms';
  static const String createPasscode = '/passcode/create';
  static const String confirmPasscode = '/passcode/confirm';
  static const String biometric = '/biometric';
  static const String onboardingPersonal = '/onboarding/personal';
  static const String onboardingAvatar = '/onboarding/avatar';
  // "Your account is ready" / three-step checklist (screen s07) — X-4,
  // SHARED-CHANGES.md. Sits between avatar selection and KYC start.
  static const String onboardingNextSteps = '/onboarding/next-steps';
  static const String login = '/login';
  static const String reset = '/reset';

  // ── KYC ──────────────────────────────────────────────────────────────────
  static const String kycIntro = '/kyc';
  // Verification checklist hub (screen s11) — the flow's spine. Re-entered
  // after every completed step (see kyc_checklist_screen.dart's own header
  // and DECISIONS.md's SHARED-CHANGES S-8/X-5), unlike kycIntro above,
  // which is a one-shot entry with its own resume logic.
  static const String kycChecklist = '/kyc/checklist';
  static const String kycBvn = '/kyc/bvn';
  // CHN · optional — 2 of 8 (2026-08-24 canvas screen 15, re-sequencing the
  // real 5-step flow to the canvas's real 8 steps). Right after bvn/nin,
  // before id upload.
  static const String kycChn = '/kyc/chn';
  static const String kycId = '/kyc/id';
  static const String kycLiveness = '/kyc/liveness';
  static const String kycChecking = '/kyc/checking';
  // Utility bill upload — step 5 of 8 (2026-08-20 phased-KYC directive:
  // "we need to collect Utility bill"). documentKind 'proof_of_address'
  // already existed in the backend schema; this is the first screen that
  // actually collects it.
  static const String kycUtilityBill = '/kyc/utility-bill';
  // Bank & Direct Cash Settlement — 6 of 8 (2026-08-24 canvas screen 19).
  // Collects a real bank account (BankAccountsRepository — same mechanism
  // Account → Bank accounts uses) during KYC and sets it primary/DCS.
  static const String kycBankDcs = '/kyc/bank-dcs';
  // Declarations · PEP — 7 of 8 (2026-08-24 canvas screen 20). PATCHes
  // pepSelfDeclared onto the draft.
  static const String kycDeclarations = '/kyc/declarations';
  // Next of kin — the last collection step (D-1, 2026-08-27 removals pass,
  // R-9: the standalone Review & submit screen was dropped; Next of kin's
  // own "Submit for verification" now calls finalizeDraft() directly).
  static const String kycNextOfKin = '/kyc/next-of-kin';
  static const String kycSubmitted = '/kyc/submitted';
  static const String kycApproved = '/kyc/approved';
  static const String kycOutcome = '/kyc/outcome';

  // ── Suitability ──────────────────────────────────────────────────────────
  static const String questionnaire = '/suitability';
  static const String suitabilityResult = '/suitability/result';
  // Last gated screen — Accept & Proceed here completes onboarding to Home.
  // Restored 2026-08-24 (direct product instruction, real SEC compliance
  // intake): the risk disclaimer moved back to running immediately after
  // suitability instead of bundled into termsOfService at signup — see
  // risk_disclaimer_screen.dart's header comment.
  static const String riskDisclaimer = '/suitability/risk-disclaimer';

  // ── Tab roots (StatefulShellRoute / indexedStack) ────────────────────────
  // R-28: 4 tabs, Markets before Portfolio. "Assets" (the old nav label on
  // this same `portfolio` route/screen) and "Portfolio" consolidate into one
  // tab, labelled "Portfolio" — see lib/widgets/navigation.dart.
  static const String home = '/home';
  static const String markets = '/markets';
  static const String portfolio = '/portfolio';
  static const String wallet = '/wallet';

  /// Tab roots in shell branch order (index 0..3).
  static const List<String> tabs = [home, markets, portfolio, wallet];

  // ── Pushed (top-level) detail screens — cover the shell, no tab bar ───────
  // Account hub — was the 5th tab root ("You"); R-28 moved it here, reached
  // from the header avatar on Home instead of a tab.
  static const String account = '/account';
  static const String notifications = '/notifications';
  static const String search = '/search';
  static const String orderStatus = '/orders';
  // watchlist_screen.dart dropped (D-2, SHARED-CHANGES.md 2026-08-27
  // removals pass, R-16) — the '+ watchlist' toggle on asset detail stays,
  // and 'My alerts' (priceAlerts below) is now the permanent reader for the
  // saved-assets data, reached from the Account menu instead of this route.

  // Dynamic pushed routes.
  static String assetDetail(String ticker) => '/asset/$ticker';
  // Set a price alert (screen s49) — S-11, SHARED-CHANGES.md. Public,
  // ticker-parametrised, reached from the asset page's own entry point
  // (X-7) as well as price_alerts_screen.dart's existing "New alert" picker.
  static String setPriceAlert(String ticker) => '/asset/$ticker/alert';
  static String holdingDetail(String ticker) => '/portfolio/holding/$ticker';
  static String transactionDetail(String id) => '/wallet/txn/$id';
  // Read-only legal-document preview, pushed from sign_up_screen.dart's
  // "By continuing..." links — the one place a document needs to be
  // readable before an account (and thus a token) exists. [kind] is one of
  // 'terms_of_service' | 'privacy_policy' | 'risk_disclosure'. Unlike the
  // other dynamic routes above, this one is reachable while signed out, so
  // it also needs an entry in app_router.dart's `_gateRedirect`.
  static String legalPreview(String kind) => '/legal-preview/$kind';

  // 2026-08-24: sign-up's "By continuing..." line used to be 4 separate
  // inline links, each pushing legalPreview directly — direct feedback
  // wanted "the old structure... all in one screen where they scroll see
  // all and click" instead. One scrollable row-list of all 4 documents;
  // each row still opens the same legalPreview detail. Reachable
  // pre-signup, same as legalPreview — also needs a _gateRedirect entry.
  static const String legalBundlePreview = '/legal-preview';

  // Path patterns for GoRoute registration (the router agent uses these).
  static const String assetDetailPath = '/asset/:ticker';
  static const String setPriceAlertPath = '/asset/:ticker/alert';
  static const String holdingDetailPath = '/portfolio/holding/:ticker';
  static const String transactionDetailPath = '/wallet/txn/:id';
  static const String legalPreviewPath = '/legal-preview/:kind';

  // ── Account sub-pages (pushed) ───────────────────────────────────────────
  static const String acctPersonal = '/account/personal';
  static const String acctBanks = '/account/banks';
  static const String acctRefer = '/account/refer';
  static const String acctHelp = '/account/help';
  static const String acctFaq = '/account/help/faq';
  static const String acctSecurity = '/account/security';
  static const String acctNotifications = '/account/notifications';
  static const String acctLegal = '/account/legal';
  static const String acctStatements = '/account/statements';

  // ── "Soft Landing" redesign additions (2026-08-22) ───────────────────────
  // Self-service account freeze (audit P0) — reachable from Security
  // (acctSecurity) and from a security alert notification.
  static const String acctFreeze = '/account/security/freeze';
  static const String securityAlert = '/security-alert';
  // AI comprehension layer — UI-complete, content is static/canned pending
  // a real backend (see docs/redesign/PLAN.md). [topic] identifies what's
  // being explained, e.g. an asset ticker or a document kind.
  static String explainThis(String topic) => '/explain/$topic';
  static const String explainThisPath = '/explain/:topic';
  static const String acctPlans = '/account/plans';
  // documentSummary ('/document-summary', screen 06) removed (D-4,
  // SHARED-CHANGES.md 2026-08-27 removals pass, R-8): it was built
  // (2026-08-22) but never actually wired in — found unreachable during the
  // exactness audit, and superseded anyway by legal documents opening in
  // the phone's native viewer (legal_preview_screen.dart).

  // ── Flow G — market hours, mandate and receipts (2026-08-23) ─────────────
  // Withdraw the DCS mandate (screen 65) — pushed with a BankAccountSummary
  // `extra` (not a path param — needs the full bank/masked-number pair, not
  // just an id). Reachable from Account -> Bank accounts.
  static const String acctWithdrawMandate = '/account/banks/withdraw-mandate';
  // Contract note document (screen 66) — pushed with a Statement `extra`
  // (needs the already-fetched title/date/size, not just an id). Reachable
  // from Statements & documents.
  static const String contractNote = '/account/statements/contract-note';

  // ── Screens 76-97 — canvas expansion from 66 to 97 screens (2026-08-23) ──
  // Statement detail / per-broker breakdown (screen 76) — pushed with a
  // Statement `extra`, same reasoning as contractNote above.
  static const String acctStatementDetail = '/account/statements/detail';
  // Tax documents (screen 85).
  static const String acctTax = '/account/tax';
  // Price alerts (screen 86). Reachable from Watchlist and Notification
  // settings.
  static const String priceAlerts = '/watchlist/alerts';
  // Corporate actions hub + detail screens (screens 81-84).
  static const String corpActions = '/corporate-actions';
  static const String corpActionsRightsIssue = '/corporate-actions/rights-issue';
  static const String corpActionsAgm = '/corporate-actions/agm';
  static const String corpActionsDividends = '/corporate-actions/dividends';
  // File / track a complaint (screens 87-88). acctComplaintTracked is pushed
  // with a ComplaintSummary `extra` — no live entry point yet since
  // submitting a complaint has no real backend to return one from (see
  // complaint_screen.dart), registered so the built screen is reachable
  // once that exists.
  static const String acctComplaint = '/account/help/complaint';
  static const String acctComplaintTracked = '/account/help/complaint/tracked';
  // Account lifecycle edge states (screens 89, 90, 92).
  static const String acctDormant = '/account/dormant';
  static const String acctClose = '/account/close';
  static const String lockedOut = '/locked-out';
  // Data & privacy (screen 91).
  static const String acctDataPrivacy = '/account/data-privacy';
  // Reference/legal documents (screens 94-97).
  static const String acctLegalPartnerDisclosures = '/account/legal/partner-disclosures';
  static const String acctLegalReferralTerms = '/account/legal/referral-terms';
  static const String acctLegalDataNotice = '/account/legal/data-notice';
  static const String acctLegalClosureTerms = '/account/legal/closure-terms';

  // ── Hardware back button (B-2, 2026-08-29 audit) ─────────────────────────
  // "why is my own phone back button designed to remove the app and not go
  // back?" — every gated-flow screen is reached via `context.go()` (replace,
  // no back stack, by design — see this file's header), so Android's
  // hardware back button has no Flutter Navigator entry of its own to pop
  // and falls through to the OS, which exits the app. Each screen already
  // draws its OWN correct back arrow for the SAME destination listed below
  // (confirmed by reading every one — e.g. confirm_passcode_screen.dart's
  // `onBack: () => context.go(Routes.createPasscode)`); this table lets
  // app_router.dart's `_handleGatedBack` (wired per-route via `themedGated`)
  // send the hardware button to that exact same place instead of guessing,
  // so the two can never drift apart.
  //
  // A location that is NOT a key here either genuinely has nothing to go
  // back to (see [backExitAllowed] below — exiting there is the same
  // standard behaviour every other app has at its own entry/root screens)
  // or was deliberately built with no back arrow at all (biometric_screen.
  // dart's `s06` draws none; the KYC checklist hub and every terminal/
  // status KYC screen the same) — `_handleGatedBack` blocks the hardware
  // button there too, but WITH an on-screen message, never a silent close.
  static const Map<String, String> gatedBackTarget = {
    signup: welcome,
    otp: signup,
    questionnaire: otp,
    suitabilityResult: questionnaire,
    // riskDisclaimer has no entry here on purpose — every path that reaches
    // it (suitability_result_screen.dart's Continue AND Home's
    // tradingEligibilityGap prompt, home_screen.dart) uses `context.push()`,
    // so it always has a real Navigator entry underneath and
    // app_router.dart's `_handleGatedBack` pops it normally before ever
    // consulting this map.
    termsOfService: riskDisclaimer,
    createPasscode: termsOfService,
    confirmPasscode: createPasscode,
    reset: login,
    kycBvn: kycIntro,
    kycChn: kycBvn,
    kycId: kycChn,
    kycLiveness: kycId,
    kycChecking: kycLiveness,
    kycUtilityBill: kycLiveness,
    kycBankDcs: kycUtilityBill,
    kycDeclarations: kycBankDcs,
    kycNextOfKin: kycDeclarations,
  };

  /// True entry/root screens — nothing legitimate to go back TO, so the
  /// hardware button falling through to the OS (exiting the app) is
  /// correct, ordinary behaviour here, not the B-2 bug. `login` covers only
  /// the plain unlock/sign-in entry (`resumeLock: false`); the resume-lock
  /// challenge (`resumeLock: true`, A-6) has its own PopScope(canPop: false)
  /// on the screen itself, which intercepts the button before
  /// `_handleGatedBack` ever sees it — see LogInScreen.resumeLock's doc
  /// comment.
  static const Set<String> backExitAllowed = {welcome, login, home, markets, portfolio, wallet};

  /// A short, honest, on-screen reason for the hardware-back block on a
  /// location that is neither in [gatedBackTarget] nor [backExitAllowed] —
  /// "it must never silently kill the app" (B-2 audit), and a block with no
  /// explanation reads exactly like the bug this fixes. Keyed by the
  /// specific screens this pass could confirm draw no back arrow by design;
  /// everything else mid-flow falls back to a generic line rather than a
  /// guess at wording that belongs to a screen this pass doesn't own. Note
  /// `kycChecking` is NOT here even though it draws no back arrow either —
  /// it IS in [gatedBackTarget] (checking.dart's own onBack points back to
  /// kycLiveness), which is consulted first, so it navigates rather than
  /// blocking.
  static const Map<String, String> backBlockedMessage = {
    biometric: 'Choose an option above to continue.',
    kycSubmitted: 'Your application has been submitted.',
    kycApproved: 'Tap Start investing above to continue.',
    kycOutcome: 'Review the options above to continue.',
  };
}
