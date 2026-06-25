export const meta = {
  name: 'kudimata-reverify',
  description: 'Re-verify every Kudimata screen against the design after device-bug fixes; fix remaining issues',
  phases: [
    { title: 'Audit', detail: 'one verify-and-fix agent per stage (disjoint folders)' },
    { title: 'Consolidate', detail: 'shared escalations + analyze + test' },
  ],
};

const PID = '419a69c5-0ddf-452b-ab86-3b5716629c18';
const ROOT = '/workspace/projects/Kudimata-Securities-Mobile';

const COMMON = `
You are RE-VERIFYING a Flutter 1:1 rebuild of a claude.ai/design project (Kudimata Securities) on a
REAL DEVICE, after a round of device-bug fixes. Design system (lib/widgets, lib/theme), router
(lib/router), data (lib/data), app state (lib/app) are SHARED — do NOT edit them; ESCALATE shared
bugs in your report (sharedIssues). Fix bugs ONLY inside the folder(s) you own.

DESIGN SOURCE: DesignSync MCP (method 'get_file', projectId '${PID}', path; 'list_files' to discover).
Implemented screens are under ${ROOT}/lib/screens. Read the design's *-screens.jsx for your screens
and reconcile faithfully.

CURRENT STATE — already fixed centrally; do NOT undo or duplicate these:
- Space Grotesk is BUNDLED (assets/fonts, declared in pubspec); google_fonts was REMOVED — never
  re-add it or call GoogleFonts. Use KType / the theme text styles only.
- KDetailHeader (used as Scaffold appBar on pushed screens) now applies the status-bar inset itself,
  so pushed screens already clear the notch — keep using KDetailHeader as the appBar; don't add an
  extra SafeArea around it.
- Bottom nav fills the width (real navbar) and floats; the 5 TAB-ROOT screens must keep ~100px bottom
  scroll padding so content clears it.
- Bottom sheets go through showKSheet (root navigator, above the nav) and are scrollable/keyboard-safe.
- Portfolio allocation donut uses the PURPLE ramp (KAllocationDonut.ramp) — keep it purple.

HUNT FOR THESE (real-device issues):
1. SAFE AREA / SCAFFOLD: every ROOT tab screen wraps its body in SafeArea (top) and clears the nav
   (~100px). Pushed screens: Scaffold(appBar: KDetailHeader, body: <scrollable>) — confirm the body
   content below the header is not clipped, scrolls, and its bottom isn't cut off on short phones.
2. OVERFLOW / SCROLL: no RenderFlex overflow (vertical or horizontal); long content scrolls.
3. CENTERING / LAYOUT BALANCE: passcode/auth screens (and any centered screens) must be visually
   balanced and consistent with their siblings.
4. SECTION HEADERS: where a section has a "See all"/link, use the consistent format (tracked eyebrow
   on the left, the link on the right of the same row) — match the design and the other sections.
5. FIDELITY: copy, order, labels, which K-widgets are used; sentence case; tracked UPPERCASE eyebrows;
   .tnum on every number; near-monochrome; purple only on the interactive layer; NO fixed income.
6. FONT: ensure all text uses the bundled Space Grotesk (via KType/theme) — no hardcoded fontFamily.
7. NAVIGATION: every tappable goes to the right place (Routes.* + the flow launchers
   showBuyFlow/showSellFlow/showAddMoneyFlow/showWithdrawFlow/showConvertFlow). Back chevrons pop.
8. DATA: real MockData; parameterized screens look up by ticker/id and handle a missing record.

After fixing, run \`flutter analyze <your folder>\` and confirm clean for your scope. Match Stage-1 style.`;

const AUDIT_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['stage', 'bugsFixed'],
  properties: {
    stage: { type: 'string' },
    bugsFixed: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['file', 'issue', 'fix'],
      properties: { file: { type: 'string' }, issue: { type: 'string' }, fix: { type: 'string' } } } },
    sharedIssues: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['file', 'issue', 'suggestedFix'],
      properties: { file: { type: 'string' }, issue: { type: 'string' }, suggestedFix: { type: 'string' } } } },
    analyzeCleanForScope: { type: 'boolean' },
    notes: { type: 'string' },
  },
};

const STAGES = [
  { key: 'onboarding', label: 'onboarding', folder: 'lib/screens/onboarding/', files: ['Kudimata Onboarding.html', 'screens.jsx', 'shared.jsx'],
    extra: `Splash, SignUp, Otp, CreatePasscode, ConfirmPasscode, Biometric, LogIn, ResetPasscode.
      PRIORITY BUG: the LogIn passcode screen is reported "broken / not centered properly like the others".
      Make LogIn visually consistent and balanced with CreatePasscode/ConfirmPasscode — same vertical
      rhythm, horizontally-centered dots + keypad, keypad pinned toward the bottom, brand/header at top.
      Reconcile against screens.jsx LogIn. Verify the numeric keypad (KKeypad) is centered and not
      clipped, and that input fills the 6 dots and unlocks. Check SignUp/Reset forms scroll with the
      keyboard up.` },
  { key: 'kyc', label: 'kyc', folder: 'lib/screens/kyc/', files: ['Kudimata KYC.html', 'kyc-screens.jsx'],
    extra: 'KycIntro→…→Approved. Long forms scroll; step progress correct; Checking/Submitted auto-advance; back chevrons work.' },
  { key: 'suitability', label: 'suitability', folder: 'lib/screens/suitability/', files: ['Kudimata Suitability.html', 'risk-screens.jsx'],
    extra: 'Questionnaire (check rows + progress), Result, RiskDisclosure + ClientAgreement (long copy scrolls; primary gated on the checkbox).' },
  { key: 'homeMarkets', label: 'home+markets', folder: 'lib/screens/home/ + lib/screens/markets/', files: ['Kudimata Main App.html', 'app-screens.jsx', 'app-data.jsx', 'extra-screens.jsx'],
    extra: `Home, NotificationsFeed, Search (home/); Markets, AssetList, AssetDetail, Watchlist (markets/).
      Home/Markets are TAB ROOTS (SafeArea + ~100px bottom). Confirm ALL section headers use the
      consistent eyebrow-left / See-all-right format. AssetDetail sticky Buy/Sell call the trade flows.
      Pushed screens (NotificationsFeed, Search, AssetList, AssetDetail, Watchlist) use KDetailHeader and
      must not clip content.` },
  { key: 'trade', label: 'trade', folder: 'lib/screens/trade/', files: ['Kudimata Trade.html', 'trade-screens.jsx'],
    extra: 'Buy/Sell sheet flows (showKSheet) via trade_flows.dart. Sheets scroll + keyboard-safe; amount entry, review, OverLimit, success correct; sit above the nav.' },
  { key: 'portfolio', label: 'portfolio', folder: 'lib/screens/portfolio/', files: ['Kudimata Portfolio.html', 'portfolio-screens.jsx'],
    extra: 'Portfolio (TAB ROOT — SafeArea + ~100px bottom; donut PURPLE), HoldingDetail, OrderStatus. Holdings tap → holdingDetail; Buy more/Sell → flows.' },
  { key: 'wallet', label: 'wallet', folder: 'lib/screens/wallet/', files: ['Kudimata Wallet.html', 'wallet-screens.jsx'],
    extra: 'Wallet (TAB ROOT — SafeArea + ~100px bottom) action row → wallet_flows (sheets above nav); TransactionDetail by id; txns → transactionDetail.' },
  { key: 'account', label: 'account', folder: 'lib/screens/account/', files: ['Kudimata Account.html', 'settings-screens.jsx'],
    extra: 'Account hub (TAB ROOT — SafeArea + ~100px bottom) + 8 pushed subs (KDetailHeader). Menu rows → Routes.acct*; toggles persist; sign out → Routes.login.' },
];

phase('Audit');
const results = await parallel(STAGES.map((s) => () =>
  agent(`${COMMON}

STAGE: ${s.label}. Folder(s) you may edit: ${s.folder}
Focus: ${s.extra}
Design files (DesignSync, projectId '${PID}'): ${s.files.map((f) => `'${f}'`).join(', ')}.
Audit every screen in your folder against the design and the hunt list; FIX in your folder; ESCALATE
shared issues. Run \`flutter analyze ${s.folder.split(' ')[0]}\` and confirm clean. Return the report.`,
    { label: `reverify:${s.label}`, phase: 'Audit', schema: AUDIT_SCHEMA })));

phase('Consolidate');
const escalations = JSON.stringify(results.map((r, i) => ({ stage: STAGES[i].label, sharedIssues: (r && r.sharedIssues) || [] })).filter((x) => x.sharedIssues.length), null, 1);

const consolidate = await agent(`${COMMON}

CONSOLIDATION AGENT. Per-stage audits are done.
1. Address escalated SHARED issues (you MAY edit lib/widgets, lib/router, lib/theme, lib/data, lib/app):
${escalations}
   Fix genuine bugs at the root; be conservative with shared widgets (used everywhere). Do NOT re-add
   google_fonts. Note any escalations you reject and why.
2. Run \`flutter analyze\` over the whole project; fix every error/warning in lib/.
3. Run \`flutter test\`; fix until green WITHOUT weakening smoke_test.dart or route_walk_test.dart
   (route_walk asserts every route resolves to its real screen + the 5 tab roots).
Return what you changed and the final analyze/test status.`,
  { label: 'consolidate', phase: 'Consolidate', schema: { type: 'object', additionalProperties: false, required: ['analyzeClean', 'testsPass', 'sharedFixes'],
    properties: { analyzeClean: { type: 'boolean' }, testsPass: { type: 'boolean' }, sharedFixes: { type: 'array', items: { type: 'string' } }, rejected: { type: 'array', items: { type: 'string' } }, notes: { type: 'string' } } } });

return {
  perStage: results.map((r, i) => ({ stage: STAGES[i].label, fixed: (r && r.bugsFixed || []).length, escalated: (r && r.sharedIssues || []).length, analyzeClean: r && r.analyzeCleanForScope })),
  allBugs: results.flatMap((r, i) => (r && r.bugsFixed || []).map((b) => ({ stage: STAGES[i].label, ...b }))),
  consolidate,
};
