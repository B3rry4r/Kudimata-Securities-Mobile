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
  static const String createPasscode = '/passcode/create';
  static const String confirmPasscode = '/passcode/confirm';
  static const String biometric = '/biometric';
  static const String login = '/login';
  static const String reset = '/reset';

  // ── KYC ──────────────────────────────────────────────────────────────────
  static const String kycIntro = '/kyc';
  static const String kycPersonal = '/kyc/personal';
  static const String kycBvn = '/kyc/bvn';
  static const String kycId = '/kyc/id';
  static const String kycLiveness = '/kyc/liveness';
  static const String kycChecking = '/kyc/checking';
  static const String kycNextOfKin = '/kyc/next-of-kin';
  static const String kycSubmitted = '/kyc/submitted';
  static const String kycApproved = '/kyc/approved';

  // ── Suitability ──────────────────────────────────────────────────────────
  static const String questionnaire = '/suitability';
  static const String suitabilityResult = '/suitability/result';
  static const String riskDisclosure = '/suitability/risk';
  static const String clientAgreement = '/suitability/agreement';

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

  // Path patterns for GoRoute registration (the router agent uses these).
  static const String assetDetailPath = '/asset/:ticker';
  static const String holdingDetailPath = '/portfolio/holding/:ticker';
  static const String transactionDetailPath = '/wallet/txn/:id';

  // ── Account sub-pages (pushed) ───────────────────────────────────────────
  static const String acctPersonal = '/account/personal';
  static const String acctBanks = '/account/banks';
  static const String acctRefer = '/account/refer';
  static const String acctHelp = '/account/help';
  static const String acctSecurity = '/account/security';
  static const String acctNotifications = '/account/notifications';
  static const String acctLegal = '/account/legal';
  static const String acctStatements = '/account/statements';
}
