export const meta = {
  name: 'kudimata-dark-screens',
  description: 'Make every Kudimata screen compile + render under the new dark theme (const removals + hardcoded-colour audit)',
  phases: [
    { title: 'Fix', detail: 'per-folder: remove broken const + theme hardcoded colours, loop until analyze clean' },
    { title: 'Consolidate', detail: 'whole-project analyze + test' },
  ],
};

const ROOT = '/workspace/projects/Kudimata-Securities-Mobile';

const COMMON = `
CONTEXT: We just added a DARK THEME to a Flutter app (Kudimata Securities). The colour system
changed: \`KColor.paper\`, \`KColor.ink\`, etc. used to be \`static const\`; they are now runtime GETTERS
that read the active light/dark palette (lib/theme/tokens.dart). So:
- Any \`const\` widget/decoration/list/text-style that references a \`KColor.x\` no longer compiles
  ("Invalid constant value" / "non_constant_list_element" / "non_constant_default_value"). FIX by
  removing the offending \`const\` keyword (push \`const\` inward to the still-const parts where useful,
  e.g. keep \`const EdgeInsets.all(2)\` but drop \`const\` from the enclosing widget). The CORRECT const
  to remove is the nearest ENCLOSING const that puts the KColor reference in a const context — often
  an outer widget, not the nearest token. Verify by re-running analyze, not by guessing.
- DO NOT change KColor references themselves, the design, layout, or copy. This is a compile fix +
  a small colour-correctness audit, nothing else.

ALSO AUDIT for HARDCODED light-only colours that won't adapt to dark, and replace with the right
KColor token so dark mode is correct:
- \`Colors.white\` / \`Color(0xFFFFFFFF)\` used as a surface/card/sheet bg → \`KColor.paper\`; used as text
  on a coloured fill (e.g. on the purple button or an ink circle) → that's fine, leave it.
- \`Colors.black\` / near-black \`Color(0xFF0F0F12)\`-ish used as a surface or text → \`KColor.ink\` /
  \`KColor.feature\` as appropriate.
- A hardcoded light grey bg / hairline (e.g. \`Color(0xFFE7E7EA)\`, \`Color(0xFFFAFAFA)\`) → \`KColor.hairline\`
  / \`KColor.bg\`.
- KEEP these as-is (they're intentionally fixed): the gain/loss-on-ink tints used INSIDE the dark
  BalancePanel, the chart \`onDark\` colours, the purple knob shadow \`Color(0x57670099)\`, white text on
  the purple primary button / on ink avatar circles, and pure \`Color(0x00000000)\` transparents.
Use judgement: the goal is that surfaces/text/hairlines come from KColor so they invert in dark, while
colour-on-fill stays legible.

After changes, run \`flutter analyze <your folder>\` and LOOP until it reports no issues for your scope.
Keep the existing code style. Touch ONLY your folder.`;

const SCHEMA = {
  type: 'object', additionalProperties: false, required: ['folder', 'analyzeClean'],
  properties: {
    folder: { type: 'string' },
    analyzeClean: { type: 'boolean' },
    constRemovals: { type: 'number' },
    hardcodedColorsFixed: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
};

const FOLDERS = ['onboarding', 'kyc', 'suitability', 'home', 'markets', 'trade', 'portfolio', 'wallet', 'account', 'shared'];

phase('Fix');
const results = await parallel(FOLDERS.map((f) => () =>
  agent(`${COMMON}

YOUR FOLDER (edit ONLY here): ${ROOT}/lib/screens/${f}/
Run \`cd ${ROOT} && flutter analyze lib/screens/${f}\`, fix every error (broken const + hardcoded
colours per the rules), and LOOP re-running analyze until it is clean for lib/screens/${f}. Return the report.`,
    { label: `dark:${f}`, phase: 'Fix', schema: SCHEMA })));

phase('Consolidate');
const consolidate = await agent(`${COMMON}

CONSOLIDATION: the per-folder fixes are done. From ${ROOT}:
1. Run \`flutter analyze\` over the WHOLE project. Fix every remaining error/warning (same rules —
   broken const + hardcoded colours; you MAY edit any file incl. lib/widgets if a straggler remains).
2. Run \`flutter test\`. Fix until green WITHOUT weakening smoke_test.dart or route_walk_test.dart.
Return the final analyze/test status and anything notable.`,
  { label: 'consolidate', phase: 'Consolidate', schema: {
    type: 'object', additionalProperties: false, required: ['analyzeClean', 'testsPass'],
    properties: { analyzeClean: { type: 'boolean' }, testsPass: { type: 'boolean' }, fixes: { type: 'array', items: { type: 'string' } }, notes: { type: 'string' } } } });

return {
  perFolder: results.map((r, i) => ({ folder: FOLDERS[i], clean: r && r.analyzeClean, removals: r && r.constRemovals, hardcoded: (r && r.hardcodedColorsFixed || []).length })),
  allHardcoded: results.flatMap((r) => (r && r.hardcodedColorsFixed) || []),
  consolidate,
};
