# "Soft Landing" redesign — tracking

Branch: `redesign/soft-landing`. Source: Kudimata Design System (Claude Design
project `b88dc96c-642d-4cb1-af7e-06764002af55`) + the "App redesign: Design
system flows" canvas mockup (project `a30e5872-cfee-4fa8-8882-d4d76f36d173`,
file `Kudimata Invest App.dc.html`) + `Kudimata_Full_Audit (1).docx` (2026-08-22
product/design audit that called for this direction change).

Per-screen specs extracted from the canvas mockup: **`docs/redesign/screen-specs.md`**
(66 mobile screens across flows A–G, plus 7 email templates out of scope for
this repo). Read that file before touching any screen — it has exact copy,
layout order, components used, and which illustration/plate each screen uses.

## Status

### 1. Foundation — DONE
- [x] Tokens ported (colors/typography/spacing/radii/elevation/motion/illustration) — `lib/theme/tokens.dart`
- [x] Nunito + Nunito Sans bundled, Space Grotesk removed — `pubspec.yaml`, `assets/fonts/`
- [x] Dark mode removed (design system is light-only; see `main.dart` header comment)
- [x] `KIllustration` / `KAvatar` widgets added — `lib/widgets/illustration.dart`
- [x] 44 illustration/avatar SVGs imported — `assets/illustrations/`

### 2. Widget layer re-skin — IN PROGRESS
Every widget in `lib/widgets/*.dart` needs to match the new radii/shadows/press
states described in the design system readme (rounder corners, warm-tinted
shadows, 0.98/0.96 press-scale, new button variants incl. `warm`/`destructive`).
New components needed that don't exist yet in the Dart widget set (mirror the
`.jsx` in the design system 1:1, same naming where sensible):
- [ ] `Button` — add `warm` and `destructive` variants (see screens 50, 53)
- [ ] `StatusPill` — needs review/pending/approved/rejected/expired vocabulary (mostly exists, verify tint/colour mapping matches `--status-*`)
- [ ] `NudgeCard` — warm/grape/sun tone variants, guide avatar, dismissible
- [ ] `DigestCard` — AI portfolio narrative card (screens 29, 38)
- [ ] `ExplainPanel` / `ExplainTrigger` — comprehension layer (screens 06, 14, 15, 27, 34)
- [ ] `GeneratingText` — thinking/writing/done states (screen 34)
- [ ] `GlossaryTerm` — tappable inline term (screens 36, 57)
- [ ] `CreditMeter` / `CreditGate` / `PlanCard` — AI credits system (screens 34, 45, 53, 54)
- [ ] `LanguageSwitch` — English/Pidgin toggle (screens 02, 06, 45, 57)
- [ ] `MilestoneSheet` — celebratory full-bleed card (screens 25, 37)
- [ ] `SecurityAlert` — device/location/time + fraud desk (screen 51)
- [ ] `OnboardingSlide` — reuse/extend existing onboarding carousel widget
- [ ] `DocumentSummary` — plain-English-over-raw-document layout (screen 06)
- [ ] `AllocationDonut` — portfolio allocation chart (screen 38, uses `KColor.ramp`)
- [ ] `Sheet` — confirm existing `KSheet`/bottom-sheet matches new radius-28/scrim tokens

### 3. Screen-by-screen reskin (existing screens, matching `screen-specs.md`)
Grouped by flow, existing screen → spec section:
- [ ] Flow A — Onboarding (screens 01–12): splash, welcome slider, sign-up, OTP, terms, passcode ×2, biometric prompt, personal details, log in, reset password
- [ ] Flow B — KYC (screens 13–26): intro, BVN/NIN, CHN, ID upload, liveness, utility bill, bank/DCS, declarations, next-of-kin, review, checking, NGX-review, verified milestone, not-approved
- [ ] Flow C — Suitability (27–28)
- [ ] Flow D — Home/markets/trading (29–37)
- [ ] Flow E — Portfolio/wallet (38–46)
- [ ] Flow F — Account/security/support (47–59)
- [ ] Flow G — Market hours, mandate and receipts (60–66): markets closed, buy-when-closed queuing, price-moved-at-open, withdraw outside hours, bank accounts & mandate, withdraw DCS mandate, contract note document

### 4. New features (genuinely new, not a reskin)
Flagged in `screen-specs.md`; roughly in priority order:
- [ ] **Self-service account freeze** (screens 50, 51) — P0 per the audit (Bamboo-parity gap: "no self-service freeze exists, only admin-side suspend"). Needs a real new backend endpoint (`POST /users/me/freeze` or similar, self-service, distinct from the existing staff-only `PATCH /users/:id/suspend`) plus the mobile screen. Scoped, well-defined, no AI/LLM dependency — do this one for real, not a stub.
- [ ] **Language switch (English/Pidgin)** — UI toggle is buildable now; actual translation of AI-generated content needs the comprehension layer's backend, which doesn't exist. Ship the toggle + a real English/Pidgin string swap for STATIC copy where cheap; stub/no-op the AI-content re-register until a backend lands.
- [ ] **AI comprehension layer** (Explain this investment, DigestCard, GeneratingText, CreditMeter/Gate/Plans, GlossaryTerm, DocumentSummary) — this is a full generative-AI product feature (screens 06, 14, 15, 27, 29, 34, 38, 45, 53, 54, 57) with no backend today. Building the real thing (LLM wiring, credit metering/billing, generation infra) is out of scope for a redesign pass. Plan: ship every screen UI-complete against static/local mock content (matching this repo's existing SEAM convention for not-yet-wired backends), clearly commented as a stub, so the *visual* redesign is complete and demoable even though real generation isn't wired.
- [ ] **Referral credits, corporate actions, tax documents, data & privacy** — screen 45/55 reference nav ids beyond the 66-screen canvas (unmocked). Lower priority; note as future work.

## Decisions made along the way
- **Dark mode removed**, not just hidden — the design system's own readme says dark is an undesigned draft; shipping it with the new illustrations would look broken. See `main.dart`.
- **"Passport" mockup copy vs current app "International passport" naming**: the mockup (screen 16) predates the app's own recent rename; keep the app's current "International passport" + "Voter's card" strings, don't regress to the mockup's plain "Passport".
- **"Blue Marina" executing-broker references** (screens 39, 52): the mockup implies a co-branded/introducing-broker model not confirmed in the current data model. Treat as presentational copy only for now — do not invent new backend fields for this without product confirmation.
