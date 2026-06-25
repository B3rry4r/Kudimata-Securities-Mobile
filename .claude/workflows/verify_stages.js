export const meta = {
  name: 'kudimata-verify-stages',
  description: 'Audit & fix each Kudimata stage against the design — layout/overflow, scroll, nav, fidelity, data',
  phases: [
    { title: 'Audit', detail: 'one verify-and-fix agent per stage (disjoint folders)' },
    { title: 'Consolidate', detail: 'apply escalated shared fixes, analyze + test' },
  ],
};

const PID = '419a69c5-0ddf-452b-ab86-3b5716629c18';
const ROOT = '/workspace/projects/Kudimata-Securities-Mobile';

const COMMON = `
You are auditing a Flutter 1:1 rebuild of a claude.ai/design project (Kudimata Securities) AGAINST
its design, on a REAL DEVICE. The design system (lib/widgets, lib/theme) and router (lib/router) and
data (lib/data) are SHARED — do NOT edit them; if you find a bug there, ESCALATE it in your report
(sharedIssues) instead of fixing it. Fix bugs ONLY inside the folder(s) you own.

DESIGN SOURCE: read via DesignSync MCP (method 'get_file', projectId '${PID}', path '<file>'; use
'list_files' to discover). The implemented screens are on disk under ${ROOT}/lib/screens. Read the
design's *-screens.jsx for the screens you own and the implemented Dart, and reconcile them.

BUG CLASSES TO HUNT (this is what real-device testing exposed — be thorough):
1. OVERFLOW / SCROLL: a fixed Column that can exceed the screen height MUST be scrollable
   (SingleChildScrollView or ListView) — phones are shorter than the 812px design canvas. No
   RenderFlex overflow horizontally or vertically. Wrap content; keep sticky CTAs pinned correctly.
2. FLOATING NAV OVERLAP: the 5 TAB-ROOT screens (Home, Portfolio, Markets, Wallet, Account) render
   under a floating KBottomNav (~70px tall + 12 bottom margin + safe area). Their scrollable content
   MUST add ~100px bottom padding so the last rows/CTAs aren't hidden behind the nav. Pushed (detail)
   screens have NO nav and use KDetailHeader.
3. SAFEAREA: content must not collide with the status bar / home indicator. Root screens own a
   Scaffold(SafeArea); pushed screens use KDetailHeader then a SafeArea/scroll body.
4. NAVIGATION CORRECTNESS: every tappable goes to the RIGHT place per the flow (use Routes.* and the
   flow launchers showBuyFlow/showSellFlow/showAddMoneyFlow/showWithdrawFlow/showConvertFlow). Back
   chevrons pop. No dead buttons that should navigate.
5. FIDELITY: copy, section order, labels, and which K-widgets are used should match the design.
   Sentence case; tracked UPPERCASE eyebrows; .tnum on every number; near-monochrome; purple only on
   the interactive layer; no fixed income anywhere.
6. DATA: screens read real MockData; parameterized screens (asset/holding/txn by id) look up correctly
   and handle a missing record gracefully.
7. INTERACTION: forms accept input, buttons enable/disable correctly, segmented controls/chips toggle,
   selected state persists via setState/AppState.

After fixing, run \`flutter analyze <your folder>\` (e.g. flutter analyze lib/screens/kyc) and ensure it
is clean for your scope. Keep the Stage-1 code style. Return a precise report.`;

const AUDIT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['stage', 'bugsFixed'],
  properties: {
    stage: { type: 'string' },
    bugsFixed: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['file', 'issue', 'fix'],
        properties: {
          file: { type: 'string' },
          issue: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
    sharedIssues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['file', 'issue', 'suggestedFix'],
        properties: {
          file: { type: 'string' },
          issue: { type: 'string' },
          suggestedFix: { type: 'string' },
        },
      },
    },
    analyzeCleanForScope: { type: 'boolean' },
    notes: { type: 'string' },
  },
};

const STAGES = [
  { key: 'onboarding', label: 'onboarding', folder: 'lib/screens/onboarding/', files: ['Kudimata Onboarding.html', 'screens.jsx', 'shared.jsx'],
    extra: 'Splash, SignUp, Otp, CreatePasscode, ConfirmPasscode, Biometric, LogIn, ResetPasscode. Linear gated flow, no tab bar. Keypad/dots/OTP must be tidy (no overflow). Splash logo crisp. Forms validate sensibly.' },
  { key: 'kyc', label: 'kyc', folder: 'lib/screens/kyc/', files: ['Kudimata KYC.html', 'kyc-screens.jsx'],
    extra: 'KycIntro→PersonalDetails→Bvn→IdUpload→Liveness→Checking→NextOfKin→Submitted→Approved. Long forms must scroll; step progress correct; Checking/Submitted auto-advance.' },
  { key: 'suitability', label: 'suitability', folder: 'lib/screens/suitability/', files: ['Kudimata Suitability.html', 'risk-screens.jsx'],
    extra: 'Questionnaire (radio + progress), SuitabilityResult, RiskDisclosure (scroll + ack), ClientAgreement (scroll + ack). Long legal copy must scroll; primary disabled until acknowledged.' },
  { key: 'homeMarkets', label: 'home+markets', folder: 'lib/screens/home/ + lib/screens/markets/', files: ['Kudimata Main App.html', 'app-screens.jsx', 'app-data.jsx', 'extra-screens.jsx'],
    extra: 'Home, NotificationsFeed, Search (home/); Markets, AssetList, AssetDetail, Watchlist (markets/). Home/Markets are TAB ROOTS — must scroll + ~100px bottom padding under the floating nav. AssetDetail sticky Buy/Sell call showBuyFlow/showSellFlow. Quick actions wired.' },
  { key: 'trade', label: 'trade', folder: 'lib/screens/trade/', files: ['Kudimata Trade.html', 'trade-screens.jsx'],
    extra: 'Buy/Sell are bottom-sheet flows (showKSheet) via trade_flows.dart showBuyFlow/showSellFlow. Sheets must be scrollable + respect the keyboard inset (viewInsets). Amount entry, review rows, OverLimit, KStatusView success all correct.' },
  { key: 'portfolio', label: 'portfolio', folder: 'lib/screens/portfolio/', files: ['Kudimata Portfolio.html', 'portfolio-screens.jsx'],
    extra: 'Portfolio (TAB ROOT — scroll + ~100px bottom padding), HoldingDetail (Buy more/Sell → flows), OrderStatus. Donut + legend correct; holdings tap → holdingDetail.' },
  { key: 'wallet', label: 'wallet', folder: 'lib/screens/wallet/', files: ['Kudimata Wallet.html', 'wallet-screens.jsx'],
    extra: 'Wallet (TAB ROOT — scroll + ~100px bottom padding) with action row → wallet_flows.dart showAddMoneyFlow/showWithdrawFlow/showConvertFlow (bottom sheets, keyboard-safe). TransactionDetail by id. Txns list → transactionDetail.' },
  { key: 'account', label: 'account', folder: 'lib/screens/account/', files: ['Kudimata Account.html', 'settings-screens.jsx'],
    extra: 'Account hub (TAB ROOT — scroll + ~100px bottom padding) + 8 pushed subs (KDetailHeader, no nav). Menu rows → Routes.acct*. Switches/toggles persist. Sign out → Routes.login.' },
];

phase('Audit');
const results = await parallel(
  STAGES.map((s) => () =>
    agent(
      `${COMMON}

STAGE: ${s.label}. Folder(s) you own and may edit: ${s.folder}
Screens / focus: ${s.extra}
Design files to read first (DesignSync, projectId '${PID}'): ${s.files.map((f) => `'${f}'`).join(', ')}.
Audit EVERY screen in your folder against the design and the bug classes above; FIX what you find in
your folder; ESCALATE shared-widget/router/data issues. Then run \`flutter analyze ${s.folder.split(' ')[0]}\`
and confirm clean for your scope. Return the report.`,
      { label: `verify:${s.label}`, phase: 'Audit', schema: AUDIT_SCHEMA },
    ),
  ),
);

phase('Consolidate');
const escalations = JSON.stringify(
  results.map((r, i) => ({ stage: STAGES[i].label, sharedIssues: (r && r.sharedIssues) || [] })).filter((x) => x.sharedIssues.length),
  null, 1,
);

const consolidate = await agent(
  `${COMMON}

YOU ARE THE CONSOLIDATION AGENT. The per-stage audits are done. Now:
1. Address escalated SHARED issues (lib/widgets, lib/router, lib/theme, lib/data, lib/app) — you MAY
   edit those here. Escalations:
${escalations}
   Apply only the ones that are genuine bugs; note any you reject and why. Be conservative with shared
   widgets (they're used everywhere) — fix the root cause, don't paper over.
2. Run \`flutter analyze\` over the whole project and fix EVERY error/warning across lib/.
3. Run \`flutter test\` and fix until green (tests: smoke_test.dart boots the router at splash;
   route_walk_test.dart walks all routes and asserts the 5 tab roots resolve — do not weaken these).
Return what you changed and the final analyze/test status.`,
  {
    label: 'consolidate',
    phase: 'Consolidate',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['analyzeClean', 'testsPass', 'sharedFixes'],
      properties: {
        analyzeClean: { type: 'boolean' },
        testsPass: { type: 'boolean' },
        sharedFixes: { type: 'array', items: { type: 'string' } },
        rejected: { type: 'array', items: { type: 'string' } },
        notes: { type: 'string' },
      },
    },
  },
);

return {
  perStage: results.map((r, i) => ({
    stage: STAGES[i].label,
    fixed: (r && r.bugsFixed || []).length,
    escalated: (r && r.sharedIssues || []).length,
    analyzeClean: r && r.analyzeCleanForScope,
  })),
  allBugs: results.flatMap((r, i) => (r && r.bugsFixed || []).map((b) => ({ stage: STAGES[i].label, ...b }))),
  consolidate,
};
