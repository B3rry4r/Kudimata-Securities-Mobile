// Kudimata Securities — route table. Path constants + dynamic-route helpers for
// GoRouter. The 5 tab roots live in a StatefulShellRoute (indexedStack); every
// `pushed` route below is TOP-LEVEL so it covers the shell (no tab bar).
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
  static const String login = '/login';
  static const String reset = '/reset';

  // ── KYC ──────────────────────────────────────────────────────────────────
  static const String kycIntro = '/kyc';
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
  static const String kycNextOfKin = '/kyc/next-of-kin';
  // Review & submit — new final screen (2026-08-24 canvas screen 22). Next
  // of kin's Continue now lands here instead of calling finalizeDraft()
  // directly; THIS screen's "Submit for verification" is what actually
  // calls it.
  static const String kycReview = '/kyc/review';
  static const String kycSubmitted = '/kyc/submitted';
  static const String kycApproved = '/kyc/approved';
  static const String kycOutcome = '/kyc/outcome';

  // ── Suitability ──────────────────────────────────────────────────────────
  static const String questionnaire = '/suitability';
  // Last gated screen — Continue here completes onboarding straight to
  // Home (2026-08-20: all four legal documents are now accepted upfront,
  // via termsOfService above, so there's no separate legal step left after
  // suitability; see suitability_result_screen.dart).
  static const String suitabilityResult = '/suitability/result';

  // ── Tab roots (StatefulShellRoute / indexedStack) ────────────────────────
  static const String home = '/home';
  static const String portfolio = '/portfolio';
  static const String markets = '/markets';
  static const String wallet = '/wallet';
  static const String account = '/account';

  /// Tab roots in shell branch order (index 0..4).
  static const List<String> tabs = [home, portfolio, markets, wallet, account];

  // ── Pushed (top-level) detail screens — cover the shell, no tab bar ───────
  static const String notifications = '/notifications';
  static const String search = '/search';
  static const String orderStatus = '/orders';
  static const String assetList = '/assets';
  static const String watchlist = '/watchlist';

  // Dynamic pushed routes.
  static String assetDetail(String ticker) => '/asset/$ticker';
  static String holdingDetail(String ticker) => '/portfolio/holding/$ticker';
  static String transactionDetail(String id) => '/wallet/txn/$id';
  // Read-only legal-document preview, pushed from sign_up_screen.dart's
  // "By continuing..." links — the one place a document needs to be
  // readable before an account (and thus a token) exists. [kind] is one of
  // 'terms_of_service' | 'privacy_policy' | 'risk_disclosure'. Unlike the
  // other dynamic routes above, this one is reachable while signed out, so
  // it also needs an entry in app_router.dart's `_gateRedirect`.
  static String legalPreview(String kind) => '/legal-preview/$kind';

  // Path patterns for GoRoute registration (the router agent uses these).
  static const String assetDetailPath = '/asset/:ticker';
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
  // Plain-English document summary (screen 06) — pushed with a
  // DocumentSummaryArgs `extra`, not a path param, since it needs the
  // already-fetched title/summary/points/original text, not just a kind
  // string. Reachable from the terms screen's document rows and later from
  // Account → Legal. Was built (2026-08-22) but never actually wired in —
  // found unreachable during the exactness audit.
  static const String documentSummary = '/document-summary';

  // ── Flow G — market hours, mandate and receipts (2026-08-23) ─────────────
  // Withdraw the DCS mandate (screen 65) — pushed with a BankAccountSummary
  // `extra` (not a path param — needs the full bank/masked-number pair, not
  // just an id). Reachable from Account -> Bank accounts.
  static const String acctWithdrawMandate = '/account/banks/withdraw-mandate';
  // Contract note document (screen 66) — pushed with a Statement `extra`,
  // same reasoning as documentSummary above (needs the already-fetched
  // title/date/size, not just an id). Reachable from Statements & documents.
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
}
