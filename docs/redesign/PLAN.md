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

### 2. Widget layer re-skin — DONE
All widgets updated/added, ported 1:1 from the design system's `.jsx` source:
- [x] `KButton` — `warm` and `destructive` variants added (`lib/widgets/buttons.dart`)
- [x] `KStatusPill` — pending/review/approved/rejected/expired/flagged, matches `STATUS` tint map (`lib/widgets/feedback.dart`)
- [x] `KNudgeCard` — warm/grape/sun tones, guide avatar, dismissible (`lib/widgets/comprehension.dart`)
- [x] `KDigestCard` (same file)
- [x] `KExplainPanel` / `KExplainTrigger` (same file)
- [x] `KGeneratingText` — thinking/writing/done, respects reduced-motion (same file)
- [x] `KGlossaryTerm` — dashed underline via `CustomPainter` (same file)
- [x] `KCreditMeter` / `KCreditGate` / `KPlanCard` (same file)
- [x] `KLanguageSwitch` (same file)
- [x] `KMilestoneSheet` / `KOnboardingSlide` — new `lib/widgets/mobile.dart`
- [x] `KSecurityAlert` / `KFreezeConfirm` — new `lib/widgets/security.dart`
- [x] `KDocumentSummary` (`lib/widgets/comprehension.dart`)
- [x] `KAllocationDonut` — uses `KColor.ramp` (`lib/widgets/charts.dart`)
- [x] `KSheet` grabber/radius verified against spec (`lib/widgets/overlays.dart`)
- [x] `KProductCard` — net-new, no prior equivalent (`lib/widgets/finance.dart`)

### 3. Screen-by-screen reskin — DONE
All flows re-skinned against `screen-specs.md`, verified via `flutter analyze`
(clean) and `flutter test test/route_walk_test.dart test/gate_redirect_test.dart
test/smoke_test.dart` (all pass — every route renders without exceptions) plus
a manual visual pass via `test/shots.dart` → `/tmp/shots/*.png`.
- [x] Flow A — Onboarding (01–12): illustrated welcome slider (new screen,
  now wired as splash's real first-time destination), sign-up, OTP, terms
  (NudgeCard), plain-English document summary (new screen), passcode ×2,
  biometric prompt, personal details, log in, reset password
- [x] Flow B — KYC (13–26): intro (ExplainPanel-ready chrome), BVN/NIN, ID
  upload, liveness, utility bill, bank/DCS (grape feature plate), next-of-kin,
  checking, verified milestone (`KMilestoneSheet`), not-approved
- [x] Flow C — Suitability (27–28): selected-card treatment, inline
  ExplainTrigger, sun-plate result screen
- [x] Flow D — Home/markets/trading (29–37): DigestCard (real holdings data,
  not canned), grape "get set up" plate, ProductCard + Explain-this screen
  (new), milestone sheet on order placed
- [x] Flow E — Portfolio/wallet (38–46): AllocationDonut, DigestCard,
  feature-plate virtual account number, NudgeCards
- [x] Flow F — Account/security/support (47–59): self-service freeze screen
  (new, wired to the real backend), security alert screen (new), plans &
  credits screen (new, honestly labeled preview)
- [ ] Flow G — Market hours, mandate and receipts (60–66): markets closed,
  buy-when-closed queuing, price-moved-at-open, withdraw outside hours, bank
  accounts & mandate, withdraw DCS mandate, contract note document. **Not
  started** — lower-priority edge-case screens; existing buy/withdraw flows
  work, they just don't yet handle "market is closed" as a distinct state.

Two real layout regressions the redesign introduced were caught (by
`route_walk_test.dart`'s overflow check) and fixed: `kyc_intro.dart`'s
unscrollable Column (52px bottom overflow once the illustration was added —
now `Expanded`+`SingleChildScrollView`), and `questionnaire_screen.dart`'s
"Back" button (fixed 100px width was 1.4px too narrow for "Back" set in the
new Nunito Sans font vs. the old Space Grotesk — bumped to 112px).

### 4. New features (genuinely new, not a reskin) — DONE except AI content
- [x] **Self-service account freeze** (screens 50, 51) — real, end-to-end:
  `POST /users/me/freeze` (Kudimata-Securities-Backend, deployed to the
  droplet), `UserRepository.freeze()`, `freeze_account_screen.dart` wired
  from `security_screen.dart`. Blocks orders/withdrawals immediately,
  revokes every session, audit-logged. Unfreezing stays staff-only
  (existing `reactivate()` endpoint) — deliberately no self-service unfreeze.
- [x] **Language switch (English/Pidgin)** — `KLanguageSwitch` shipped on
  welcome slider, document summary, and Account hub. Cosmetic/local state
  only — no real translation backend (see item below).
- [~] **AI comprehension layer** (Explain this investment, DigestCard,
  GeneratingText, CreditMeter/Gate/Plans, GlossaryTerm, DocumentSummary) —
  every screen is UI-complete and shipped (`explain_screen.dart`,
  `plans_screen.dart`, `document_summary_screen.dart`, Home/Portfolio
  DigestCards), each honestly commented as static/local content pending a
  real backend. No LLM, no credit metering/billing, no translation service
  exists — building those is a genuinely separate, much larger project than
  this redesign pass. Treat every "AI-generated" string in these screens as
  a placeholder until that backend exists.
- [ ] **Referral credits, corporate actions, tax documents, data & privacy** — screen 45/55 reference nav ids beyond the 66-screen canvas (unmocked). Lower priority; note as future work.

## Decisions made along the way
- **Dark mode removed**, not just hidden — the design system's own readme says dark is an undesigned draft; shipping it with the new illustrations would look broken. See `main.dart`.
- **"Passport" mockup copy vs current app "International passport" naming**: the mockup (screen 16) predates the app's own recent rename; keep the app's current "International passport" + "Voter's card" strings, don't regress to the mockup's plain "Passport".
- **"Blue Marina" executing-broker references** (screens 39, 52): the mockup implies a co-branded/introducing-broker model not confirmed in the current data model. Treat as presentational copy only for now — do not invent new backend fields for this without product confirmation.
