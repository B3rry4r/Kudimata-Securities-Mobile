# Backend gaps — what's needed for the redesigned UI to be 100% real

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

## Priority read, if useful for scoping

Roughly highest-leverage-first, independent of screen numbering:

1. **Dividend ledger** (§1) — unblocks real data on #76, #84, and
   indirectly #85; it's also just a real, already-happening business event
   the data model can't currently represent at all.
2. **Router fix for the `Routes.reset` / `preAuthOnly` bug** (§8) — not
   backend work, a one-line router fix, but blocks a real safety-critical
   flow (locked-out investors resetting access) today, independent of
   whether #92 itself ever ships.
3. **Sell order destination + reference number** (§6) — small additions
   to an endpoint that already exists.
4. **Legal content for #95/#97** (§11) — a content/legal-review task, not
   an engineering one; cheap once written.
5. Corporate actions, complaints, price alerts, dormancy/lockout,
   closure, tax documents — each a real, standalone feature; sequence
   by product priority.
