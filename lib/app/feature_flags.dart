// A small set of compile-time toggles for functionality that is fully
// built and wired but not yet exposed to users.
//
// D-3 (SHARED-CHANGES.md, 2026-08-27 removals pass; ruling R-6,
// docs/redesign/DECISIONS.md): the AI-credits product line — Plans &
// credits (plans_screen.dart), Refer & earn (refer_earn_screen.dart),
// "Explain this investment" (explain_screen.dart), and the glossary's
// credit-metered "Explain further" half (glossary_sheet.dart) — is PARKED,
// not deleted. Every entry point into that cluster is gated behind this
// ONE flag so the decision is reversible in a single edit; the screens and
// their repositories stay in the tree.
//
// The glossary's STATIC plain-language definitions are NOT gated by this
// flag — trade flows, FAQ, asset detail and the suitability questionnaire
// all read them directly, and R-6 is explicit that only the metered AI half
// parks. See glossary_sheet.dart's own doc comment.
const bool kAiCreditsEnabled = false;
