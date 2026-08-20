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
  static const String signup = '/signup';
  static const String otp = '/otp';
  // Terms of service + privacy policy + risk disclosure — ONE combined
  // screen/tick (2026-08-20 consolidation, see terms_and_privacy_screen.dart),
  // accepted right after OTP verification, before passcode/KYC. Path segment
  // still says "suitability" for historical reasons; see the note above
  // riskDisclosure below.
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
  static const String kycId = '/kyc/id';
  static const String kycLiveness = '/kyc/liveness';
  static const String kycChecking = '/kyc/checking';
  // Utility bill upload — step 4 of 5 (2026-08-20 phased-KYC directive:
  // "we need to collect Utility bill"). documentKind 'proof_of_address'
  // already existed in the backend schema; this is the first screen that
  // actually collects it.
  static const String kycUtilityBill = '/kyc/utility-bill';
  static const String kycNextOfKin = '/kyc/next-of-kin';
  static const String kycSubmitted = '/kyc/submitted';
  static const String kycApproved = '/kyc/approved';
  static const String kycOutcome = '/kyc/outcome';

  // ── Suitability ──────────────────────────────────────────────────────────
  static const String questionnaire = '/suitability';
  static const String suitabilityResult = '/suitability/result';
  // Client agreement — its own single-document screen (see
  // client_agreement_screen.dart), accepted right after the suitability
  // result. Risk Disclosure used to be paired with it here too, but moved
  // up to join termsOfService above (2026-08-20) — Client Agreement is the
  // one document that stays gated behind suitability, since it's the actual
  // binding contract to become a trading client. Path segment/constant name
  // (riskDisclosure, '/suitability/risk') is unchanged from before that
  // move, purely to avoid an unnecessary router churn.
  static const String riskDisclosure = '/suitability/risk';

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
}
