export const meta = {
  name: 'kudimata-build-stages',
  description: 'Build Kudimata Securities stages 2-10 (onboarding→account + nav) as a dynamic multi-agent workflow',
  phases: [
    { title: 'Foundation', detail: 'data + app state + routes + build contract' },
    { title: 'Screens', detail: '8 stages fan out to disjoint folders' },
    { title: 'Integrate', detail: 'go_router shell, gated flow, shared states, main.dart' },
    { title: 'Verify', detail: 'flutter analyze + test, fix compile errors' },
  ],
};

const PID = '419a69c5-0ddf-452b-ab86-3b5716629c18';
const ROOT = '/workspace/projects/Kudimata-Securities-Mobile';

// Shared preamble every code agent receives.
const COMMON = `
PROJECT: Kudimata Securities — a Flutter (iOS+Android, mobile-only) 1:1 rebuild of a
claude.ai/design project. Stage 1 (design system: tokens + shared widgets) is DONE and
must NOT be modified. You are building later stages on top of it.

DESIGN SOURCE OF TRUTH: the design project is read via the DesignSync MCP tool
(method 'get_file', projectId '${PID}', path '<file>'). To discover files use
method 'list_files'. The compiled component bundle and tokens are already ported to
Flutter — do NOT re-port them. Read the *-screens.jsx / *.html design files for the
SCREENS you own and mirror them faithfully (layout, copy, order, spacing). The design's
React screen components are plain functions registered on window[<ScreenId>].

NON-NEGOTIABLE VISUAL RULES (already encoded in the widgets — honour them):
- Near-monochrome: white #FAFAFA surfaces, ink #0F0F12 text. Purple #670099 is the
  interactive layer (primary Button, selected chips, active toggles, active nav, donut
  ramp) — MATCH THE BUNDLE (the user confirmed broad purple is correct).
- BalancePanel = solid ink, max one per screen. Surfaces opaque, no glass. Content cards
  = 1px hairline, NO shadow (soft shadow only on bottom nav + sheets).
- Movement colour (gain green / loss red) only on NUMBERS. All prices/balances/percentages
  use tabular figures via the .tnum extension and are NEVER truncated. Eyebrows/labels are
  tracked UPPERCASE; everything else sentence case. Lucide icons via KIcon, 1.5px stroke.
- SCOPE: investable products are Nigerian stocks, US stocks, and ETFs ONLY. There is NO
  fixed income anywhere — never add it (the design README mentions it; ignore that).

YOU MUST FIRST read '${ROOT}/docs/BUILD_CONTRACT.md' (the widget API, data API, routes,
flow-launcher signatures, and conventions). Build ONLY from the K-widgets it documents.
Read the actual widget source under '${ROOT}/lib/widgets/' when you need exact params.

CONVENTIONS: 20px screen gutters; KScreenHead for titled roots; KDetailHeader (back chevron,
no tab bar) for pushed screens; showKSheet for overlays; .tnum on every number; navigate with
GoRouter (context.go for gated linear steps, context.push for detail screens) using the
Routes constants; mock data only from lib/data; leave clearly-commented seams where the
sponsoring-broker order API / wallet processor / KYC provider plug in (do NOT implement real
trading, payments, or KYC). Match Stage-1 code style: K-prefixed widgets, terse comments.
`;

const FILE_HINTS = {
  onboarding: ['Kudimata Onboarding.html', 'screens.jsx', 'shared.jsx'],
  kyc: ['Kudimata KYC.html', 'kyc-screens.jsx'],
  suitability: ['Kudimata Suitability.html', 'risk-screens.jsx'],
  homeMarkets: ['Kudimata Main App.html', 'app-screens.jsx', 'app-data.jsx', 'extra-screens.jsx'],
  trade: ['Kudimata Trade.html', 'trade-screens.jsx'],
  portfolio: ['Kudimata Portfolio.html', 'portfolio-screens.jsx'],
  wallet: ['Kudimata Wallet.html', 'wallet-screens.jsx'],
  account: ['Kudimata Account.html', 'settings-screens.jsx'],
  states: ['Kudimata States.html', 'states.jsx'],
};

const SCREEN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['stage', 'filesWritten', 'screens'],
  properties: {
    stage: { type: 'string' },
    filesWritten: { type: 'array', items: { type: 'string' } },
    screens: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'widgetClass', 'filePath'],
        properties: {
          id: { type: 'string' },
          widgetClass: { type: 'string' },
          filePath: { type: 'string' },
          routeHint: { type: 'string' },
          ctorArgs: { type: 'string' },
        },
      },
    },
    flowsExported: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'filePath', 'signature'],
        properties: {
          name: { type: 'string' },
          filePath: { type: 'string' },
          signature: { type: 'string' },
        },
      },
    },
    deviations: { type: 'array', items: { type: 'string' } },
  },
};

// ───────────────────────── Phase 1 — Foundation ─────────────────────────
phase('Foundation');
const foundation = await agent(
  `${COMMON}

YOU ARE THE FOUNDATION AGENT. Build the shared layer every screen agent depends on, then
write the build contract. Read '${ROOT}/lib/widgets/' (all files) and '${ROOT}/lib/theme/tokens.dart'
to document the EXACT API, and read design file 'app-data.jsx' (via DesignSync) for canonical mock data.

WRITE THESE FILES (under ${ROOT}):

1) lib/data/models.dart — immutable models:
   - enum Trend { gain, loss }  enum AssetClass { ngx, us, etf }
   - class Asset { final String name, ticker, price, change; final Trend trend;
       final AssetClass assetClass; final Color? logoColor; List<double> get sparkline => spark(trend==Trend.gain); const ctor }
   - class Holding { final Asset asset; final String units, marketValue, avgPrice, totalReturn, returnPct; final Trend returnTrend; }
   - enum TxnType { fund, withdraw, buy, sell, convert }  enum TxnStatus { completed, pending, failed }
   - class Txn { final String id, title, subtitle, amount, date; final TxnType type; final TxnStatus status; final bool incoming; }
   - class AppNotification { final String title, body, time, icon; final bool unread; }
   - class UserProfile { final String fullName, email, phone, tier, memberSince; }
   Keep price/change as preformatted strings exactly like app-data.jsx (e.g. "₦268.40", "+1.94%").

2) lib/data/mock.dart — port app-data.jsx EXACTLY (spark(bool up,[n=16]) using the same formula;
   homeSeries, mtnnSeries; holdings, trending, ngStocks, watchlist) and EXTEND with: usStocks
   (AAPL, TSLA, NVDA, MSFT, AMZN — realistic $ prices), etfs (VOO, SPY, QQQ, VTI), txns (a mix of
   fund/buy/sell/withdraw/convert, completed+pending+failed), notifications (4-5), and a UserProfile
   ("Ada Okeke", "ada.okeke@email.com", "+234 803 555 0192", "Premium", "2023"). Provide a couple of
   Holding records derived from holdings. Expose everything as top-level const/final getters in a
   class MockData (static) AND assign sensible Asset.assetClass + logoColor (MTNN amber etc.).

3) lib/app/app_state.dart — class AppState extends ChangeNotifier with bools: passcodeSet,
   biometricEnabled, kycSubmitted, kycApproved, suitabilityComplete, signedIn; a Set<String>
   watchlistTickers; methods to flip each (notifyListeners). Provide InheritedNotifier wrapper
   'AppScope' with static AppState of(BuildContext) (listen:false variant too). Keep minimal.

4) lib/router/routes.dart — class Routes with static const String path constants AND helpers.
   Use EXACTLY these paths:
   gated: splash '/', signup '/signup', otp '/otp', createPasscode '/passcode/create',
     confirmPasscode '/passcode/confirm', biometric '/biometric', login '/login', reset '/reset';
   kyc: kycIntro '/kyc', kycPersonal '/kyc/personal', kycBvn '/kyc/bvn', kycId '/kyc/id',
     kycLiveness '/kyc/liveness', kycChecking '/kyc/checking', kycNextOfKin '/kyc/next-of-kin',
     kycSubmitted '/kyc/submitted', kycApproved '/kyc/approved';
   suitability: questionnaire '/suitability', suitabilityResult '/suitability/result',
     riskDisclosure '/suitability/risk', clientAgreement '/suitability/agreement';
   tabs: home '/home', portfolio '/portfolio', markets '/markets', wallet '/wallet', account '/account';
   pushed: notifications '/notifications', search '/search', orderStatus '/orders',
     assetList '/assets', watchlist '/watchlist';
     plus helpers: assetDetail(String ticker)=>'/asset/\$ticker', holdingDetail(String ticker)=>'/portfolio/holding/\$ticker',
     transactionDetail(String id)=>'/wallet/txn/\$id';
   account subs: acctPersonal '/account/personal', acctBanks '/account/banks', acctRefer '/account/refer',
     acctHelp '/account/help', acctSecurity '/account/security', acctNotifications '/account/notifications',
     acctLegal '/account/legal', acctStatements '/account/statements'.

5) docs/BUILD_CONTRACT.md — the contract for screen agents. Include:
   (a) WIDGET API: for every K-widget in lib/widgets, its constructor signature (param names, types,
       defaults) — derive from source, be precise. Group by file.
   (b) DATA API: the models + MockData accessors.
   (c) ROUTES: the full Routes table above + how to navigate (context.go for gated steps; context.push
       for pushed detail screens; pop to dismiss). Note pushed detail routes are TOP-LEVEL (cover the
       shell → no tab bar); the 5 tab roots live in a StatefulShellRoute (indexedStack).
   (d) FLOW LAUNCHERS (cross-stage contract — producers MUST create these exact files+signatures,
       consumers import them):
        lib/screens/trade/trade_flows.dart:
          Future<void> showBuyFlow(BuildContext context, Asset asset);
          Future<void> showSellFlow(BuildContext context, Asset asset);
        lib/screens/wallet/wallet_flows.dart:
          Future<void> showAddMoneyFlow(BuildContext context);
          Future<void> showWithdrawFlow(BuildContext context);
          Future<void> showConvertFlow(BuildContext context);
   (e) CONVENTIONS recap (gutters, KScreenHead/KDetailHeader, showKSheet, .tnum, sentence case,
       no fixed income, seam comments). (f) A short COMPILE CHECKLIST.

Make sure lib/data, lib/app, lib/router, docs exist. Return the manifest. Do NOT write any screen
files or the router itself — only the foundation + contract.`,
  {
    label: 'foundation',
    phase: 'Foundation',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['filesWritten', 'summary'],
      properties: {
        filesWritten: { type: 'array', items: { type: 'string' } },
        summary: { type: 'string' },
        contractPath: { type: 'string' },
      },
    },
  },
);
log(`Foundation done: ${(foundation?.filesWritten || []).length} files`);

// ───────────────────────── Phase 2 — Screens (parallel, disjoint folders) ─────────────────────────
phase('Screens');

const STAGES = [
  {
    key: 'onboarding', label: 'S2 onboarding', folder: 'lib/screens/onboarding/',
    files: FILE_HINTS.onboarding,
    brief: `STAGE 2 — Onboarding & security. Screens (own these): Splash, SignUp, Otp, CreatePasscode,
      ConfirmPasscode, Biometric, LogIn, ResetPasscode. Linear gated flow, NO tab bar. The shared
      scaffold (passcode dots, numeric keypad, OTP cells, fingerprint icon, Splash) exists in the design's
      shared.jsx — reproduce the keypad/OTP/passcode-dots as small local widgets in this folder if not
      already in lib/widgets (KIcon has 'fingerprint'). Wire linear nav with context.go: Splash→SignUp→Otp
      →CreatePasscode→ConfirmPasscode→Biometric→(Routes.kycIntro). LogIn is the returning-user unlock
      (→Routes.home), with a 'forgot' link to ResetPasscode→back to LogIn. Set AppState.passcodeSet/
      biometricEnabled/signedIn at the right steps.`,
  },
  {
    key: 'kyc', label: 'S3 kyc', folder: 'lib/screens/kyc/',
    files: FILE_HINTS.kyc,
    brief: `STAGE 3 — KYC / account activation. Screens: KycIntro, PersonalDetails, Bvn, IdUpload, Liveness,
      Checking, NextOfKin, Submitted, Approved. Linear, NO tab bar, back chevrons. Use KInput, KFileUpload
      (ID upload), KButton, KStatusView (Submitted/Approved), a spinner/progress for Checking. Liveness =
      a framed selfie placeholder (use the fingerprint/profile motif; no camera). Mark the KYC-provider seam
      clearly. Flow with context.go through the list, Checking auto-advances (Future.delayed) to NextOfKin,
      Submitted→Approved→Routes.questionnaire. Set AppState.kycSubmitted/kycApproved.`,
  },
  {
    key: 'suitability', label: 'S4 suitability', folder: 'lib/screens/suitability/',
    files: FILE_HINTS.suitability,
    brief: `STAGE 4 — Suitability & agreements. Screens: Questionnaire (multi-question, KRadio options,
      progress), SuitabilityResult (risk profile result — e.g. "Moderate", with KBalancePanel-style or
      KStatCard summary; NO purple donut required), RiskDisclosure (scrollable legal copy + KCheckbox ack),
      ClientAgreement (scrollable + KCheckbox + primary button). Linear, no tab bar. context.go through;
      ClientAgreement confirm → set AppState.suitabilityComplete + signedIn → context.go(Routes.home).`,
  },
  {
    key: 'homeMarkets', label: 'S5 home+markets', folder: 'lib/screens/home/ + lib/screens/markets/',
    files: FILE_HINTS.homeMarkets,
    brief: `STAGE 5 — Home + Markets (the richest stage). Screens & folders:
      lib/screens/home/: Home (root tab — greeting, BalancePanel with KLineChart, quick actions row,
        holdings preview→portfolio, watchlist strip, trending), NotificationsFeed (pushed; MockData.notifications),
        Search (pushed; KSearchPill + results from MockData, tap→context.push(Routes.assetDetail(ticker))).
      lib/screens/markets/: Markets (root tab — SearchPill, category PillChips All/NGX/US/ETFs, trending +
        lists), AssetList (pushed; a category list of KAssetRow), AssetDetail (pushed; price header, KLineChart
        with range pills, stats via KStatCard, About; sticky Buy/Sell buttons calling showBuyFlow/showSellFlow
        from lib/screens/trade/trade_flows.dart), Watchlist (pushed; MockData.watchlist, AssetRows, toggle via
        AppState.watchlistTickers). Home is the Home tab root; Markets is the Markets tab root. Quick actions:
        Add money → showAddMoneyFlow (import lib/screens/wallet/wallet_flows.dart), and links to Search/
        Notifications/Portfolio/Watchlist/OrderStatus via Routes. Use real MockData; .tnum everywhere.`,
  },
  {
    key: 'trade', label: 'S6 trade', folder: 'lib/screens/trade/',
    files: FILE_HINTS.trade,
    brief: `STAGE 6 — Trade buy/sell as BOTTOM SHEETS (showKSheet), NOT routes. Screens: BuyAmount, ReviewOrder,
      OverLimit, BuySuccess, SellAmount, SellReview, SellSuccess. YOU MUST create lib/screens/trade/trade_flows.dart
      exporting exactly: Future<void> showBuyFlow(BuildContext context, Asset asset) and
      Future<void> showSellFlow(BuildContext context, Asset asset). Implement each flow as a sequence of
      bottom sheets (amount entry with KInput numeric ₦ prefix + quick-amount chips + SegmentedControl Buy/Sell
      where relevant; review summary rows; KStatusView success). OverLimit is an error/limit state shown when the
      amount exceeds a mock limit. Mark the sponsoring-broker order API seam clearly (mock confirm with a delay +
      KStatusView). Buy/Sell success can offer "View order" → context.push(Routes.orderStatus).`,
  },
  {
    key: 'portfolio', label: 'S7 portfolio', folder: 'lib/screens/portfolio/',
    files: FILE_HINTS.portfolio,
    brief: `STAGE 7 — Portfolio. Screens: Portfolio (root tab — BalancePanel total value + return, KAllocationDonut
      (purple ramp) with legend NGX/US/ETF/Cash, holdings list of KAssetRow→holdingDetail), HoldingDetail (pushed;
      KLineChart, position stats via KStatCard (units, avg price, market value, total return), Buy more / Sell →
      showBuyFlow/showSellFlow from lib/screens/trade/trade_flows.dart), OrderStatus (pushed; an orders list +
      status via KBadge/KStatusView; route Routes.orderStatus). Use MockData.holdings/holdingRecords. No fixed income.`,
  },
  {
    key: 'wallet', label: 'S8 wallet', folder: 'lib/screens/wallet/',
    files: FILE_HINTS.wallet,
    brief: `STAGE 8 — Wallet. Screens: Wallet (root tab — BalancePanel naira balance + maybe a $ sub-balance,
      action row Add money/Withdraw/Convert, transactions list of MockData.txns→transactionDetail), AddMoney,
      Withdraw, Convert (these THREE are bottom-sheet flows), TransactionDetail (pushed; KStatusView-style summary
      + detail rows; route Routes.transactionDetail(id)). YOU MUST create lib/screens/wallet/wallet_flows.dart
      exporting exactly: Future<void> showAddMoneyFlow(BuildContext), showWithdrawFlow(BuildContext),
      showConvertFlow(BuildContext) — each a showKSheet sequence (amount, method/bank via SegmentedControl or rows,
      review, KStatusView success). Mark the wallet/funding-processor seam clearly.`,
  },
  {
    key: 'account', label: 'S9 account', folder: 'lib/screens/account/',
    files: FILE_HINTS.account,
    brief: `STAGE 9 — Account. Screens: Account hub (root tab — profile header with UserProfile, grouped menu rows
      with KIcon + chevronRight to the 8 subs, sign out), and the 8 pushed sub-screens: PersonalInfo (read-only
      KInput-style rows), BankAccounts (list + add), ReferEarn (code + share), HelpSupport (FAQ/contact rows),
      Security (KSwitch biometric/2FA, change passcode), Notifications settings (KSwitch list), Legal (document
      rows), Statements (KFileUpload/download rows by month). All pushed subs use KDetailHeader (back, no tab bar).
      Wire via Routes.acct* with context.push. Sign out → context.go(Routes.login).`,
  },
];

const screenResults = await parallel(
  STAGES.map((s) => () =>
    agent(
      `${COMMON}

${s.brief}

TARGET FOLDER(S): ${s.folder} (write ONLY here — other agents own other folders; do not touch lib/widgets,
lib/theme, lib/data, lib/app, lib/router, or other stages' folders).
DESIGN FILES to read first (via DesignSync get_file, projectId '${PID}'): ${s.files.map((f) => `'${f}'`).join(', ')}.
Also call list_files if a screen component isn't in those files. Reproduce the design's layout and copy
faithfully; this is a 1:1 rebuild. Each screen = one Flutter widget the router can instantiate (StatelessWidget
or StatefulWidget; pushed screens build their own Scaffold with KDetailHeader; root tab screens build a Scaffold
body WITHOUT a bottom nav — the shell provides it). Use Routes for navigation and the flow launchers per the
contract. Verify your Dart is syntactically complete (balanced braces, imports). Return the manifest mapping
every screen id → widget class + file path (+ ctorArgs if it needs params like a ticker/asset).`,
      { label: s.label, phase: 'Screens', schema: SCREEN_SCHEMA },
    ),
  ),
);
const ok = screenResults.filter(Boolean);
log(`Screens done: ${ok.length}/${STAGES.length} stages, ${ok.reduce((n, r) => n + (r.filesWritten || []).length, 0)} files`);

// ───────────────────────── Phase 3 — Integrate ─────────────────────────
phase('Integrate');
const manifestJson = JSON.stringify(screenResults.map((r, i) => ({ stage: STAGES[i].label, ...(r || { error: 'no result' }) })), null, 1);

const integrate = await agent(
  `${COMMON}

YOU ARE THE INTEGRATION AGENT (also covers Stage 10 — shared states + wiring all navigation per the Flow Map).
The foundation (lib/data, lib/app, lib/router/routes.dart) and all screen folders exist. Here is the screen
manifest from the screen agents (route ids → widget classes → file paths → ctor args):

${manifestJson}

DO THIS:
1) Read 'states.jsx' and 'Kudimata States.html' (DesignSync) and build lib/screens/shared/state_views.dart:
   reusable empty / loading / error / success state widgets (lean on KStatusView, KSpinner). Use them where a
   screen agent left a TODO for empty/loading/error if easy; otherwise just expose them.
2) Build lib/router/app_router.dart — a GoRouter:
   - StatefulShellRoute.indexedStack with 5 branches: Home, Portfolio, Markets, Wallet, Account (each branch's
     root is that stage's root screen). The shell scaffold shows a floating KBottomNav (items Home·Portfolio·
     Markets·Wallet·Account; the 'profile' item id maps to the Account branch) that switches branches and keeps
     each tab's own stack. The bottom nav floats above content with its shadow.
   - ALL gated-flow, KYC, suitability, pushed-detail, trade(if any route), and account-sub routes as TOP-LEVEL
     routes (NOT in the shell) so they cover the tab bar. Map each to the widget class from the manifest, parsing
     path params (ticker, id) and looking up MockData where a screen needs an Asset/Holding/Txn.
   - initialLocation = Routes.splash. Add a redirect using AppState that lets the gated flow proceed but bounces
     deep links into the tab section back to /splash unless signedIn (keep it pragmatic, not draconian).
   - If any manifest entry is missing/ambiguous, open the file to find the class; if a screen is genuinely
     missing, create a minimal faithful placeholder screen so the router compiles.
3) Rewrite lib/main.dart: wrap MaterialApp.router with AppScope(AppState) and KTheme.light(), routerConfig =
   the GoRouter. Remove the Stage-1 gallery home (keep the gallery file on disk but unreferenced).
4) Return a summary of routes wired + any screens you had to placeholder.`,
  {
    label: 'integrate',
    phase: 'Integrate',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['filesWritten', 'routesWired', 'summary'],
      properties: {
        filesWritten: { type: 'array', items: { type: 'string' } },
        routesWired: { type: 'number' },
        placeholders: { type: 'array', items: { type: 'string' } },
        summary: { type: 'string' },
      },
    },
  },
);
log(`Integrate done: ${integrate?.routesWired ?? '?'} routes`);

// ───────────────────────── Phase 4 — Verify & fix ─────────────────────────
phase('Verify');
const verify = await agent(
  `${COMMON}

YOU ARE THE VERIFY/FIX AGENT. The full app (stages 1-10) is now on disk. Make it compile and pass a smoke test.
Run from ${ROOT}:
  flutter analyze
Fix EVERY error (and obvious warnings) across all of lib/ — missing imports, wrong widget params, type
mismatches, undefined names, route/manifest mismatches, duplicate symbols. Re-run until 'No issues found'.
Then update test/smoke_test.dart to pump the real app (MaterialApp.router via the GoRouter with AppScope) instead
of the gallery, and run:
  flutter test
Fix until it passes (pump + a couple of settle calls; tolerate google_fonts network fallback — it must not throw).
Do NOT change the design intent or delete screens to make it compile — fix properly. You MAY touch any file.
Return the final analyze/test status and a concise list of the substantive fixes you made.`,
  {
    label: 'verify',
    phase: 'Verify',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['analyzeClean', 'testsPass', 'fixes'],
      properties: {
        analyzeClean: { type: 'boolean' },
        testsPass: { type: 'boolean' },
        remainingIssues: { type: 'array', items: { type: 'string' } },
        fixes: { type: 'array', items: { type: 'string' } },
      },
    },
  },
);

return {
  foundation: foundation?.summary,
  screens: screenResults.map((r, i) => ({ stage: STAGES[i].label, files: (r && r.filesWritten || []).length, deviations: r && r.deviations || ['(no result)'] })),
  integrate: integrate?.summary,
  routesWired: integrate?.routesWired,
  verify,
};
