# Backend gaps — what's needed for the redesigned UI to be 100% real

## Status (2026-08-24, updated same day) — backend AND mobile now wired end-to-end for most of this

Two passes today. First closed the additive backend half of this doc
(`Kudimata-Securities-Backend` commit `1d78d59`); a second pass (commits
`089d62d`, `429525d`, `c10e6e1` on the backend, `0781df0` on mobile) fixed
a real correctness bug the user caught, added the last KYC piece, redid
every transactional email, and — critically — **wired the Flutter app to
all of it**. This doc was previously "backend real, mobile still mock" for
everything below; that's now closed for most items.

- **Done end-to-end (backend + mobile wired)**: dividends (history,
  summary, e-mandate — `dividends_screen.dart`), corporate actions (rights
  issues + AGM voting — `corporate_actions_screen.dart` and children),
  price alerts (full CRUD — `price_alerts_screen.dart`), complaints (file +
  track, real presigned upload — `complaint_screen.dart` +
  `complaint_tracked_screen.dart`), order cancel + real reference number
  (`orders_repository.dart`, `trade_flows.dart`'s `SalePlacedScreen`),
  dormancy (auto-detected at login, routes to the Dormant screen —
  `log_in_screen.dart`), account closure request
  (`close_account_screen.dart`), the two new consent toggles
  (`data_privacy_screen.dart`). All 10 transactional emails rewritten to
  the new canvas designs, plus the 2 that didn't exist (dividend-paid,
  document-ready).
- **DCS fix (user caught this before it shipped anywhere real)**: the
  first version of sell-proceeds-to-bank-account only checked *ownership*
  of the destination bank account, not that it was the investor's actual
  DCS-mandated account. Per how DCS really works (and the design's own
  "withdrawals can only ever go to a DCS account" copy), there is exactly
  one lawful destination — corrected server-side to require
  `BankAccount.primary === true`, with tests for accept/reject cases. Sell
  proceeds still only credit the wallet, not an actual bank payout — see
  below, unchanged from the original scoping.
- **§13 phased-KYC — now mostly done.** All 3 missing real steps built
  (CHN, Bank & DCS-during-KYC reusing the real bank-linking endpoints, PEP
  declarations) plus a new Review & submit screen, and the whole flow
  re-sequenced from 5 to the canvas's real 8 steps. Screen 24 "NGX account
  under review" deliberately not built — no real backend state exists to
  justify it. Two small real gaps remain: the PEP "who/position" detail
  fields and the "trade for myself" checkbox have no backend column (only
  the yes/no PEP flag persists), and Review's optional note field has
  nowhere to send its value.
- **Still a real gap, not silently closed**:
  - Price-alert *notification delivery* has no scheduler wired anywhere
    (alerts save for real, they just won't fire yet — app-wide job
    infrastructure doesn't exist).
  - Sell-to-bank-account payout still only credits the wallet — the
    destination is now correctly validated as the real DCS account, but
    actually redirecting the payout needs the withdrawal module's
    tier-limit/Flutterwave logic, deliberately not risked without live
    testing.
  - `order_status_screen.dart` still can't show a cancel button for real —
    it sources from `GET /transactions`, which has no link back to
    `Order`. The new investor-scoped `GET /orders` closes the backend half
    of this; the screen itself needs a follow-up to actually use it.
  - `Routes.reset`/`preAuthOnly` router bug (§8) — unfixed, frontend-only.
  - §3, §4, §9, §11, §12, §14 are entirely untouched. §9 (account closure)
    is now request-only, same as originally scoped — no real closure
    workflow exists past the request landing with staff.

---

Every screen in this app is built to match the design canvas exactly,
regardless of whether the backend can support its real actions yet — per
explicit product direction, the UI is never held back to fit the current
API. This document is the other half of that deal: every place a screen's
real action isn't backed by a real endpoint, honestly flagged in-code
(grep for "REAL GAP" / "backend gap" / "not available yet" across
`lib/screens/`), consolidated here so it can be scoped as real backend work.

Each entry says what's missing, why it matters, and which screen(s) need
it. Nothing here should be read as "the UI is faked" — every screen either
shows real data where real data exists, or tells the investor honestly that
an action isn't wired yet (never a silent fake success).

## How to read "code gap" vs "data gap"

- **Code gap** — no endpoint/entity exists at all; needs real backend
  engineering (new tables, new controllers, business logic).
- **Data gap** — the endpoint/mechanism already exists and is generic
  enough to cover this, it just needs new *content* published through it
  (e.g. a new legal document, a new `kind` value). Much cheaper to close.

---

## 1. Corporate actions — code gap, no data model at all

Screens: Corporate actions hub (#81), Rights issue (#82), AGM voting (#83),
Dividends & e-mandate (#84).

Confirmed via `Kudimata-Securities-Backend/.pipeline/registry.json`: zero
matches for rights/AGM/resolution/vote/dividend-ledger. Nothing in
`lib/data/models.dart` or any repository has a concept of a corporate
action.

Needed:
- **Rights issue** entity: issuer, ratio, subscription price, entitlement
  per holder, subscription window, status. A subscribe/lapse action that
  places a real CSCS-side instruction — "Take up" currently shows an
  honest "not available yet" rather than faking an order.
- **AGM** entity: meeting, resolutions (ordered list, each with a
  description), a per-shareholder eligible-vote count. A proxy-vote
  submission endpoint (per-resolution For/Against/Abstain) and a
  "send me the notice by email" action.
- **Dividend ledger**: `TxnType` (`lib/data/models.dart`) has no
  `dividend` value at all — this blocks the dividend row on the
  per-broker statement (#76) AND every "paid to you this year" figure on
  #84. This is probably the single highest-leverage fix in this whole
  document — it's a real, already-happening business event (Kudimata
  pays dividends today) that the data model simply doesn't represent.
- **E-dividend mandate** (registrar-level) — confirmed via the canvas's
  own copy to be a genuinely different mechanism from the existing DCS
  bank mandate (`bank_accounts_screen.dart`): it's for dividends declared
  *before* an e-mandate existed, held by a share registrar, not the CSCS.
  Needs its own registrar-integration entity and a mandate-signing action
  — do not conflate with the existing DCS mandate flow.

Judgment call already made and worth ratifying: the AGM screen's canvas
slice only showed 2 of the 5 resolutions it references — the other 3 were
filled in with standard NGX AGM order-of-business items as a placeholder.
**Verify against the real canvas before treating that content as final.**

## 2. Complaints / ticketing — code gap

Screens: File a complaint (#87), Complaint · tracked (#88).

Confirmed via the backend's own registry — no complaint/ticket resource,
and `account-help.json`'s fragment declares no reads/actions for it either.

Needed: `POST /complaints {category, reference?, description,
attachmentObjectKey?} -> Complaint {id, reference, status, filedAt,
answerDueAt}`, a `GET /complaints/:id` (or timeline sub-resource) for the
tracked view, and a category taxonomy (the app currently mirrors
`help_support_screen.dart`'s existing FAQ topics as a placeholder: order/
trade, money movement, verification, fees, other — worth confirming against
whatever the SEC-facing complaints register actually needs). File-attach
also needs an upload endpoint/object-key convention, same shape as the
existing KYC document uploads.

"Send complaint" currently shows an honest "isn't available yet" snackbar.
`ComplaintTrackedScreen` is fully built and routed but has no live entry
point until this exists.

## 3. Tax documents — data gap (probably), needs a decision

Screen: Tax documents (#85).

Judgment call made and flagged for review: reuse `statements_repository.dart`'s
existing `Statement` resource (already per-user, already has real
download-URL plumbing) by adding new `kind` values (e.g.
`wht_credit_note`, `annual_tax_summary`) — **not**
`legal_documents_repository.dart`'s `LegalDocument`, which is a small
global unscoped list of legal agreements, the wrong shape for per-investor
generated tax records. No speculative call was made against either
repository since neither `kind` exists yet; the screen ships as a static
shell with honest "not available yet" copy. This also depends on item 1's
dividend-ledger gap — a real "tax documents" summary needs real dividend/
WHT data to summarize.

## 4. Per-broker statements — code gap, deeper than expected

Screen: Statement · per broker (#76).

Confirmed directly against `prisma/schema.prisma`: Order/Holding have no
`brokerId`/`brokerCode` field anywhere. The app is single-broker today —
"Blue Marina" is presentational co-branding copy only, not a real data
dimension (this was already known from the original redesign pass's
decisions, re-confirmed here). A real per-broker statement breakdown needs
a broker dimension added to trades/holdings, plus a structured per-broker
response shape (account number, holdings, movements, subtotal) from
`statements_repository.dart`. Until then, `StatementDetailScreen` shows
only real metadata (title/date/size) plus one honest "not available yet"
block.

## 5. Price alerts — code gap

Screen: Price alerts (#86).

`WatchlistRepository`'s `WatchlistItem` has no threshold field.
`NotificationPreferencesRepository`'s `NotificationPreference` is exactly
three email-only booleans (`ordersEmail`/`priceAlertsEmail`/`accountEmail`)
with no per-asset granularity. Needed: a new resource, e.g.
`PriceAlert { id, userId, ticker, thresholdPct?, thresholdPriceKobo?,
active }` with `GET/POST/PATCH/DELETE /price-alerts`, plus a
quote-monitoring job to actually fire the notification when a threshold is
crossed. Every threshold/preset on the current screen is local UI state
only, reset on next visit; "Save alerts" shows an honest preview-only
message rather than persisting anything fake.

## 6. Sell order gaps — code gap, on an existing endpoint

Screens: Sell (#77-79).

`POST /orders` (`OrderPlacementRepository.placeOrder`):
- **No proceeds-destination field.** The canvas's "straight to bank via
  DCS" option is fully built in the UI but disabled with an honest note —
  only "wallet" (the real current behavior) is selectable. Needs a
  destination parameter on order placement.
- **No order reference returned.** The endpoint currently returns nothing
  usable as a reference number; the canvas's "Reference · KDM-SL-9021" row
  was dropped from `SalePlacedScreen` rather than faked. Recommend the
  endpoint return the created order's id/reference in its response.
- **No order-cancel endpoint** (pre-existing gap, re-confirmed via
  `order_status_screen.dart`'s own comment) — blocks #80's "Cancel the
  unfilled N" button.
- **No partial-fill data model.** Orders collapse to 3 states (completed/
  pending/failed); there's no fills array with per-fill price/time/
  contract-note. `OrderFillProgressScreen` (#80) is fully built and
  parameterized but genuinely unwired — nothing constructs it because
  there's no real fill data to pass in. Needs an API shape roughly like
  `{filledUnits, totalUnits, fills: [{units, price, at, contractNoteId}]}`.

## 7. Withdraw outside market hours — data gap, cosmetic

Screen: Withdraw · outside hours (#63).

`POST /transactions/withdraw` has no off-hours branching server-side, so
the built screen avoids the canvas's literal "Tomorrow from 09:00" promise
in favor of the existing app's honest "Within 1 business day" wording. Fee
is genuinely ₦0.00 today, not the canvas's mock ₦50.00 — real copy, not a
gap, just noting the divergence from the mockup is intentional (real data
beats mockup fiction).

## 8. Account lifecycle states — code gap, nothing triggers these screens yet

Screens: Dormant account (#89), Locked out (#92).

Both screens are fully built and match the canvas, but **nothing in the
app can currently route a user to either of them**:
- **Dormancy**: `PersonalInfo.accountStatus` is the only account-state
  signal that exists (a raw string like `'active'`/`'suspended'`) — no
  `'dormant'` value or 12-month-idle detection anywhere. Needs a real
  dormancy signal from the backend plus a router-level check on sign-in.
  "Reactivate my account" has no dedicated backend action either — the
  screen pushes the real Personal info screen as the closest working
  action, per the canvas's own "Reactivate re-confirms personal details"
  note, but that's a judgment call, not a verified reactivation flow.
- **Lockout**: `PasscodeStore` has no failed-attempt counter or lockout
  timestamp — `log_in_screen.dart`'s unlock flow just shows "Incorrect
  passcode" on every wrong try, with no branch that ever reaches a lockout
  state. Needs attempt-counting + a lockout timer, either client-side
  (simplest) or server-enforced (more secure against a reinstalled app
  resetting local state).
- **Pre-existing bug surfaced while building #92, not introduced by it**:
  `Routes.reset` (used by both this screen's "Reset with my email" and
  `log_in_screen.dart`'s own existing "Forgot your password?" button) is
  gated `preAuthOnly` in `app_router.dart`'s `_gateRedirect` — it redirects
  straight to Home whenever `AppState.signedIn` is true. A locally-locked-
  out investor still has a valid signed-in *session* (only the local
  passcode is locked), so this button currently cannot work for exactly
  the case it exists for. Needs a router fix independent of any backend
  work.

## 9. Account closure — code gap

Screen: Close your account (#90).

"Request closure" has no backing endpoint anywhere. Needs a real
`POST /users/me/close` (or similar) with whatever real-world workflow
account closure requires (pending settlement checks, CSCS transfer/
liquidation instructions, a cooling-off period). The screen's
share/company count summary currently sums one page (100 items) of
holdings client-side since there's no dedicated summary endpoint for this
context — fine for now, but note it doesn't handle >100 holdings.

## 10. Data & privacy — partial code gap

Screen: Data & privacy (#91).

- "Improve the app" / "Product emails" toggles have no backing consent-
  preferences endpoint — only the existing email-channel
  `NotificationPreferences` exists, unrelated to these. Currently local-
  state only.
- "Download my data" (the canvas's #93, a data-export email flow) is
  unbuilt anywhere in the backend — a real DSAR-style export endpoint
  would be needed.

## 11. Legal / consent reference screens — mostly a data gap, good news

Screens: Partner disclosures (#94), Referral terms (#95), Data notice ·
NDPA (#96), Account closure terms (#97).

The good news: `LegalDocumentsRepository` is already generic — `GET
/legal-documents` (any `kind`), `GET /legal-documents/content/:kind`, and a
presigned download URL. `ComplianceRepository.acknowledge({kind})` is
generic too. **Two of these four already wire to real content** — Partner
disclosures and Data notice reuse `getContent('client_agreement')` /
`getContent('privacy_policy')` respectively, confirmed against the actual
LEGAL.zip document text (Blue Marina Securities sub-broker role; NDPA
rights/retention language).

The other two are genuine content gaps, not code gaps:
- **Referral terms (#95)**: no backing document exists anywhere (checked
  both LEGAL.zip and the backend). Also worth flagging: the canvas's own
  copy says referral rewards are "credits, never cash" — this is factually
  wrong against the app's real shipped mechanic (a flat ₦1,000 cash reward
  per `refer_earn_screen.dart`). The screen correctly ships the real
  copy, not the canvas's copy — but the canvas itself should probably be
  corrected upstream so this doesn't recur.
- **Account closure terms (#97)**: no backing document exists yet either.
  The screen's stated "10 business days" figure and #95's "14 days'
  notice" figure are both the canvas's own numbers, **unverified against
  the real legal pack** — flag for legal/compliance sign-off before
  treating either as authoritative, and publish both documents through
  the existing `LegalDocument` mechanism once approved (a `kind: 'other'`
  reference doc is enough — no new endpoint needed).

## 12. AI comprehension layer — pre-existing, carried forward from the original redesign

Screens: Explain this investment, DigestCard (Home/Portfolio), Generating
text, Credit meter/gate/plans, Glossary terms, Document summary.

Every screen here is UI-complete and has been shipped since the original
"Soft Landing" pass — every "AI-generated" string is honestly commented as
static/local content. No LLM integration, no credit metering/billing, no
translation backend (the English/Pidgin `KLanguageSwitch` is cosmetic/
local-state only) exists anywhere. This is a genuinely separate, much
larger project than a UI redesign pass — flagged here again only because
it's still outstanding, not because anything changed about it this pass.

---

## 13. KYC is a 5-step flow, not the canvas's real 8-step/10-screen flow — the biggest structural gap in this document

Screens: BVN & NIN (#14), CHN (#15), Bank & DCS (#19), Declarations · PEP
(#20), Review & submit (#22), NGX account under review (#24).

This is deliberate — a documented 2026-08-20 "phased KYC" product/backend
directive (`kyc_form_state.dart`, `kyc_repository.dart` headers) — not
sloppiness, and the backend's `KycSubmission` draft schema genuinely only
has 5 steps today. But it means four real pieces of investor identity/
compliance data described by the canvas are **never collected anywhere**:

- **CHN** (#15) — never collected.
- **Bank & Direct Cash Settlement** (#19) — never collected. The canvas
  describes DCS as "Required by the NGX"; there is no field or screen for
  it in this app at all, and DCS is later *referenced* as if it exists
  (the bank-accounts screen's "DCS active" pill maps onto the unrelated
  `primary` flag as a workaround — see the original redesign's own
  decision log).
- **Declarations · PEP** (#20) — the SEC-required politically-exposed-
  person declaration is simply absent from onboarding.
- **Review & submit** (#22) — doesn't exist; the last real KYC step
  submits directly with no review interstitial.
- **NGX account under review** (#24) — no distinct interstitial exists
  between "submitted" and the final approved/rejected outcome; the app
  jumps straight from a generic pending state to the full outcome.

Closing this needs real backend schema work (extending `KycSubmission`
with these fields/steps) and new screens/routes wired to them — a
genuinely larger piece of work than any other single item in this
document, and worth scoping as its own project rather than folding into
smaller fixes.

## 14. Smaller data gaps found during the full re-audit (screens 1-59)

- **Dividend yield** on Asset detail (#33) — no backend field; renders `—`.
  Same root cause as gap §1's dividend-ledger absence.
- **Glossary route** — the canvas's `T+3` and similar inline
  `KGlossaryTerm`s are meant to link to an Article & Glossary destination
  per-term; only one article (Settlement/T+3) was built this pass (the
  only one the canvas gives full content for). Other glossary terms
  (elsewhere in the app) remain no-ops. Needs either more canvas-sourced
  article content or a real glossary content resource.
- **FAQ article content** — Article & Glossary (#57) was built for real,
  but only for the one question ("When does money from a sale arrive?")
  the canvas provides full article content for. The other 3 FAQ questions
  ("Why is my order still filling?", "My verification was not approved",
  "Fees, in full") still fall back to the general FAQ list — needs real
  article copy written for each, then wired the same way.
- **Suitability `computedAt`** — Personal info's "Investor profile" card
  should show "Answered {date}" per the canvas; `SuitabilityResult` has no
  timestamp field reaching the client. Small addition to
  `suitability_repository.dart`'s response shape.
- **Referral stats mismatch** — the canvas's Refer & earn stats show
  "Friends joined / Still verifying / Explanations earned"; this backend's
  `ReferralAccount` only has `referredCount` and `earningsTotalKobo` (it
  pays cash, not AI-credits, and has no verifying-vs-joined split). The
  screen shows the two real fields rather than inventing the other two —
  a real product-model mismatch between the canvas's assumptions and how
  referrals actually work here, worth reconciling upstream.
- **Order cancellation** — STALE, partially fixed: `PATCH
  /orders/:id/cancel` now exists (investor-only, own pending order) and
  `OrdersRepository.cancel()` calls it correctly — but the Orders screen
  itself (`order_status_screen.dart`) still can't use it: it sources its
  list from `GET /transactions`, which carries no `orderId` field, so
  there's nothing valid to pass `cancel()`. Needs an investor-scoped `GET
  /orders` list wired into this screen instead (see that screen's own
  header comment for the full trail). Left here as a reminder that this
  exact doc drifted out of sync with reality once already ("no cancel
  endpoint exists" was stale even before this rewrite) — re-verify
  against the code before trusting any gap claim in this file.
- **Test-fixture gap, not a product gap**: `test/fixtures/mock_api_adapter.dart`
  has no `/statements` mock, so the Statements screen's own screenshot
  shows its (correctly-styled) error state rather than real-looking data.
  Harmless for production, worth fixing so future screenshot audits of
  this screen are actually useful.
- **NGX All-Share index row** on Markets (#32/#60) — canvas shows a live
  "104,562.18 · +0.84% today · Open · closes 14:30" index figure. No real
  NGX index feed exists anywhere in this app (`AssetRepository` only has
  per-instrument quotes); rendering a number here would be a fabricated
  market index, not a data-shape gap that can be closed by wiring
  existing fields. Deliberately not built — needs a real index data
  source (an NGX data vendor, most likely) before it can ship.
- **Portfolio change label says "all-time", canvas says "today"** — the
  Home/Portfolio `BalancePanel`'s change line
  (`HoldingsRepository.summary()`) is genuinely computed as all-time
  unrealized return, not day-over-day change (see that repository's own
  doc comment) — there is no daily-change aggregate on the backend to
  wire instead. Rendering "today" over an all-time figure would misstate
  what the number means, so the label stays honest rather than matching
  the canvas's exact word. Needs a real daily-change aggregate
  (`PortfolioSummary` gaining a second figure) to close for real.
- **2026-08-24 rebuild — Home/Markets/Asset-detail structural fixes**: an
  earlier "full re-audit" pass (commit `27b829a`) found real, concrete
  deviations from the canvas on these three screens and documented them
  as accepted exceptions ("prior approved decision", "regression risk")
  instead of fixing them. They were not actually approved for this
  canvas — rebuilt this pass to match s29/s30 (Home verified/not
  verified), s32/s60 (Markets open/closed) and s33 (Asset detail)
  structurally. See git log for the full diff; the two gaps immediately
  above (NGX index, portfolio change label) are what's left after that
  rebuild — both are real data-availability gaps, not deferred fixes.
  Also fixed in the same pass: `KProductCard`'s risk/fee/liquidity/
  minimum cells were rendering "—" as if unmodelled — they're real,
  product-wide constants (1.35% fee, T+3, ₦5,000 minimum) already used
  correctly elsewhere; and the asset-detail hero price line was missing
  the absolute change figure even though the backend already returns
  `changeAbsKobo` — the mobile `Asset` model just never parsed it. Added
  a real `Asset.sector` backend column (NGX sector classification) so
  Markets' category chips and the asset-detail subtitle are genuinely
  wired instead of omitted.

## Priority read, if useful for scoping

Roughly highest-leverage-first, independent of screen numbering:

1. **Phased-KYC completion** (§13) — CHN, Bank & DCS, PEP declarations,
   and a review step are entirely uncollected today. This is compliance-
   adjacent (PEP, DCS) and by far the largest single scope item in this
   document — worth scoping as its own project, separately from the
   smaller items below.
2. **Dividend ledger** (§1) — unblocks real data on #33, #76, #84, and
   indirectly #85; it's also just a real, already-happening business event
   the data model can't currently represent at all.
4. **Router fix for the `Routes.reset` / `preAuthOnly` bug** (§8) — not
   backend work, a one-line router fix, but blocks a real safety-critical
   flow (locked-out investors resetting access) today, independent of
   whether #92 itself ever ships.
5. **Sell order destination + reference number** (§6) — small additions
   to an endpoint that already exists.
6. **Legal content for #95/#97** (§11) — a content/legal-review task, not
   an engineering one; cheap once written.
7. Corporate actions, complaints, price alerts, dormancy/lockout,
   closure, tax documents, and the smaller §14 data gaps — each a real,
   standalone feature; sequence by product priority.
