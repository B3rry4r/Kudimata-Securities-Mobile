# Backend gaps — redesign 2026-08

Per DECISIONS.md's authority declaration: a screen is built to match its
artboard even where the current API can't yet back every figure it draws.
Each entry below names the artboard, the missing field, and what the screen
does instead of fabricating it.

## s24 — Markets

**NGX All-Share index change.** The mood card ("Market mood today") draws
"32 up · 14 down · NGX All-Share +1.4%" — a real, published NGX index
figure. `AssetRepository`/the backend only carry per-instrument quotes, no
market-index feed, so there is nothing to source that number from.

Built: the card itself, with real up/down counts computed from the loaded
asset list (`lib/screens/markets/markets_screen.dart`, `_MarketMoodCard`).
Not built: the "NGX All-Share +X%" clause — left off rather than shown as a
fabricated figure. Needs a real NGX index data source (or a broker-feed
equivalent) before it can ship.

## s26/s27 — Asset detail

**Dividend yield.** s26's About tab draws a "Dividend yield 6.20%" figure —
a real per-asset trailing-dividend-over-price calculation. `Dividend`
records exist (`DividendsModule`) but no endpoint computes a per-asset
yield from them yet.

Built: the "Dividend yield" cell itself
(`lib/screens/markets/asset_detail_screen.dart`, `_AboutTab`). Not built:
the figure — renders `—` rather than a fabricated percentage. Needs a
yield-computing endpoint (or a client-side computation fed real trailing
dividend + price data) before it can ship.

**Order book / depth data (R-18) — RESOLVED end to end, 2026-08-27.** s27
draws a full order-book tab: an "Easy to sell"/"Hard to sell" liquidity
call-out, live bid/ask rows keyed to `{{ book }}`, and best-buy/best-sell
price cells. The backend serves this (BR-5, `SimulatedNgxBroker
#getOrderBook`, `GET /assets/:ticker/order-book`) — 5 levels a side,
bids/asks best-first, every bid strictly below every ask. S-7
(`SHARED-CHANGES.md`) landed the mobile side: `OrderBook`/`OrderBookLevel`
(`lib/data/models.dart`, raw kobo/unit ints) and
`AssetRepository.orderBook` (`lib/data/repositories/asset_repository.dart`).
`asset_detail_screen.dart`'s `_OrderBookTab` now fetches via `FutureBuilder`
and renders real bid/ask rows and best-buy/best-sell cells (loading /
error / populated, plus an empty state for the case both sides come back
with zero levels — not observed against the real backend, which always
returns 5 a side, but a real possible response shape). Verified on rendered
PNGs (light + dark) via a throwaway test seeding a real 5-level-a-side
response — the standing `test/shots_substates.dart` sub-state still shows
the empty "Depth unavailable" state because `test/fixtures/mock_api_adapter.dart`
(off-limits to a screen agent) has no handler for the new endpoint yet and
falls back to `{}`; that's a test-fixture gap, not a product one.

**Still a genuine gap:** the liquidity call-out banner. `SimulatedNgxBroker`
computes no liquidity tier at all, and the book is always exactly 5 levels a
side, so level-count can't stand in for one either — any "easy"/"hard to
sell" threshold derived from spread or summed units would be invented, not
real (R-34/D-5). Needs either a backend-computed liquidity signal or a
product ruling on what the threshold means before it can ship.

## s03b — Sign up: phone number (R-11)

**Phone number at sign-up.** #s03 re-splits sign-up into a 3-step wizard
(name → email+phone → password); #s03b's "How do we reach you?" step draws
a real phone-number field alongside email, prefixed `+234`, with helper copy
"Use the line registered to your BVN". `AuthRepository.signUp` only sends
`{email, password, firstName, middleName?, lastName}` — Kudimata-Securities-Backend's
`POST /auth/signup` (AuthSession resource, registry.json) has no phone
column or parameter anywhere in the signup path.

Built: the field itself, exactly where and how #s03b draws it (label,
`+234` prefix, placeholder). Per R-11, it is not wired to a dead write —
it's rendered fully **disabled** (the underlying `TextField` has
`enabled: false`, so nothing can be typed into it at all) with an
honest helper line explaining it isn't collected yet, instead of the
canvas's "Use the line registered to your BVN" copy (kept for once the
field is real). Not built: any submission of a phone number — there is
nowhere real to send it yet.

Needs: a `phone` column on the investor/auth record plus
`POST /auth/signup` accepting an optional `phone`. Once that exists, this
screen's SHARED-CHANGE REQUEST (see the sign_up_screen.dart build report)
covers what changes on the mobile side: `AuthRepository.signUp` gains an
optional `phone` parameter, and this field flips from disabled to a normal
controlled input.

## Welcome (`Routes.welcome`) — Landing Video Concept v3

**Asset gap, not a data gap.** DECISIONS.md R-14: the welcome screen is the
Landing Video Concept, treatment V3 — a 6-second muted looping video behind
"Dream. Invest. Live.". No such footage exists yet.

Built: V3's exact layout (mark, gradient panel, headline, sub-line, CTAs,
"Kudimata Securities Ltd · SEC registered" line, 430px bottom scrim) with V1's
illustrated frame (`assets/illustrations/kd-celebrate.svg` + two decorative
rings over a radial-gradient panel) standing in for the video, structured as
one swappable widget (`_LandingBackground` in
`lib/screens/onboarding/welcome_slider_screen.dart`) so dropping the real loop
in later is a media swap, not a rebuild.

Needs: footage shot to v3's brief — 6s, muted, looping, H.264, under 1.5MB,
first frame shipped as a static poster for slow connections. Storyboard: 0.0s
hands/phone/Kudimata open (close crop, screen glow on the fingers) → 2.0s face
lifts, small smile (eye line off camera, no acting, no thumbs up) → 4.5s walks
out of frame, light fills it (ends bright and empty so the loop point is
invisible). One person, handheld, warm daylight, plain wall behind, calm top
third, nothing important below the waist (bottom 430px is scrim-covered), no
text in frame.

## s06b — Pick your avatar

**Ninth avatar option ("guide").** The grid draws 9 tiles — adebayo, bisi,
chiamaka, emeka, folake, ngozi, tunde, kudi, guide. `UserRepository.avatarKeys`
(`lib/data/repositories/user_repository.dart`) only lists 8 — it omits
`'guide'`, which the app already treats as a special mascot identity
(`KAvatar.guide`) rather than one of the interchangeable user avatars. The
asset itself already exists (`assets/illustrations/avatars/guide.svg`) and
renders fine through the generic `KAvatar(avatarKey: 'guide')` path used here.

Built: the 3×3-shaped grid with all 8 real, selectable avatars, tappable and
correctly highlighted on selection. Not built: a 9th "guide" tile — omitted
rather than letting an investor pick an identity `UserRepository.avatarKeys`
doesn't recognise as a real profile avatar. Needs a product decision (is
"guide" meant to be a selectable personal avatar, or should the canvas's grid
be 8?) before `avatarKeys` — off-limits to a screen agent, per
SCREEN-AGENT-BRIEF.md rule 5 (`lib/data/**`) — is touched.

## s13 — Details from BVN

**Resolved name/date-of-birth/phone from the BVN & NIN check.** Ruling R-19
adopts BVN/NIN auto-populate: s13 "Is this you?" shows the investor's name,
date of birth and phone exactly as the BVN/NIN verification returned them,
for a read-only confirm-or-go-back step, plus a "Matches the name on your
account" checkmark. `POST /kyc-submissions/draft`'s response
(`KycSubmissionStatus`, `lib/data/repositories/kyc_repository.dart`) carries
none of this — only masked `bvn`/`nin` strings and pass/fail
`verificationSignals` booleans (`nin`/`bvn`/`name`/`dob`/`liveness`), never
the resolved values themselves or a real name-match result.

Built (`lib/screens/kyc/bvn_nin.dart`'s `_buildConfirm`): the card, its three
labelled rows, and both buttons ("Yes, that's me" / "Re-enter BVN"). Not
built: the row values, which render `—` rather than the canvas's mock
"Adebayo Okonkwo" / "14 Mar 1992" / "+234 801 234 5678" (R-34 — a figure
with no data source is omitted, never invented), and the "Matches the name
on your account" checkmark line, omitted entirely since it asserts a
computed match with nothing to compute it from.

Needs: `POST /kyc-submissions/draft` (and/or `GET /kyc-submissions/draft`)
to additionally return the BVN/NIN provider's resolved name, date of birth
and phone, plus a boolean/computed flag for whether the resolved name
matches the account's own name on file. See `SHARED-CHANGES.md` for the
matching `KycSubmissionStatus` model change this also needs, since
`lib/data/**` is off-limits to a screen agent.

## s38 — Wallet: Transaction receipt

**Per-transaction fee.** s38 draws a real, non-zero "Fees, all in ₦93.50" row
on the receipt. `Txn`/`TransactionRepository`
(`lib/data/repositories/transaction_repository.dart`) carries no fee field of
any kind, and no endpoint anywhere computes one per transaction.

Built: the rest of the detail-rows card exactly as s38 draws it (Requested,
Settlement where it applies, Reference — reordered to match s38's own
Reference-last layout). Not built: the Fee row — per R-34, the figure is
omitted rather than invented, and since there is no real value to put beside
a "Fee" label, the row itself is dropped rather than shown with nothing next
to it (the previous version of this screen showed a hardcoded "₦0.00" here,
which is exactly the fabricated-figure defect R-34 exists to prevent — this
pass removes that literal too). Needs: a `fee` (or equivalent) field on the
transaction/receipt read model, populated from whatever actually assessed the
charge at execution time, before this row can ship.

## s17 — Address + utility bill (R-19)

**No dedicated LGA field anywhere.** s17 "Where do you live?" draws three
address fields alongside the upload: Street address, State, LGA. Grepped
both `User` (registry.json, backed by `UserRepository.updateProfile`/
`PATCH /users/me`) and `KycSubmission` (`KycRepository.finalizeDraft`) —
neither has an `lga` column or parameter. Both only carry
`address`/`city`/`state`.

Built: all three fields for real — Street address and State go to
`updateProfile`'s `residentialAddress`/`state`. LGA is sent through
`updateProfile`'s `city` parameter rather than dropped or disabled: this
app's own existing address collection
(`onboarding/personal_details_screen.dart`) already uses an LGA name
("Ikeja") as its `city` field's own example value, so this reuses the
closest existing real field for a value the investor actually chose, rather
than inventing a column or discarding the input. Flagged here so a human
can correct the mapping if `city` is meant to mean something narrower than
LGA.

Needs: a product/backend decision — either accept `city`-as-LGA as the
permanent mapping, or add a real `lga` column to `User` (and, if compliance
wants it on the submission record too, to `KycSubmission`/
`FinalizeKycDraftRequest` — see `SHARED-CHANGES.md` X-3 for the related gap
that `finalizeDraft` never receives address/city/state at all today).

## s52 — Statements & documents / s56 — Request a statement

**Broker filter/dimension.** s52 draws "All brokers"/"Blue Marina"/
"Meristem" filter chips over the document list. No broker dimension exists
anywhere on this backend — confirmed directly against
`statements.service.ts`: `Statement` carries `{id, userId, kind, title,
periodOrTradeRef, fileSizeBytes, generatedAt, fileObjectKey}`, no broker
field at all, and this app is single-broker today (same standing gap
`statement_detail_screen.dart` and `holding_detail_screen.dart` already
established).

Built: the search pill and a real filter-chip row, backed by something
real instead of a fabricated broker dimension — distinct calendar years
actually present in the investor's own document list. Not built: the
broker chips themselves, and any "broker" clause in the search
placeholder copy. Needs: a `brokerId`/`brokerCode` dimension on
trades/holdings/statements before a real broker filter can ship.

**`s56` "Request a statement" — custom date range and per-broker
generation.** s56 is a dedicated screen: period presets (This month/This
year/Choose dates), a from/to date-range picker, and an all-brokers-vs-one
selector, emailing the result. Checked directly against
`statements.service.ts` and `statements.controller.ts`: the only real
generator endpoint is `POST /statements/generate-monthly` (current month
only, no date-range or broker parameter of any kind). There is also no
email-dispatch endpoint for statements.

Built: `statements_screen.dart`'s footer button keeps s56's exact label
("Request a statement") and icon, wired to the one real action that
exists — generate the current month, in place, no navigation to a new
screen. Not built: `s56` itself, since it has nothing real to submit to,
and building a screen whose every control writes nowhere would be the
same defect class as a fabricated figure. Needs: a
custom-date-range statement generator endpoint, a broker dimension (see
above) for the broker selector to mean anything, and an email-dispatch
endpoint, before `s56` can be built as its own screen.

## s41 — Orders hub

**Partial-fill progress ("Filled so far").** s41's first order card draws a
"Filled so far · 40 of 109 shares" row plus a progress bar for a
partially-filled pending order. `Order` (`lib/data/models.dart`) carries no
filled-units field at all — only `units` (the full ordered quantity) and a
coarse `status` ('pending'/'approved'/'rejected'/'cancelled'), nothing that
distinguishes "0 of 109 filled" from "40 of 109 filled".

Built: the order card itself, with real ticker/side/units, real limit price
(`limitPrice`) or value, real placed time, and the real status pill. Not
built: the "Filled so far" row and progress bar — omitted per R-34 (a figure
with no data source is omitted, never invented) rather than shown as a
fabricated fraction. Needs a per-order filled-quantity field (or a fills
sub-resource) from the broker/order layer before this can ship.

**No ticker-agnostic "place a new order" entry point.** s41's footer button
navigates straight to a buy/sell chooser (`nav.s42`) with no asset context.
The app's real trade entry points (`showBuyFlow`/`showSellFlow` in
`asset_detail_screen.dart`) both require a specific `Asset`, and R-33's
`s42`/`s45` chooser screens are unbuilt as of this pass — there is no route
that starts a trade without a ticker already chosen.

Built: the footer button, styled and positioned exactly as s41 draws it,
routing to Markets (`Routes.markets`) so the investor picks an asset first —
the closest real, working equivalent. Needs: either a ticker-agnostic
"choose what to trade" screen (asset picker → s42/s45), or a product decision
that Markets is the intended landing spot for this button.

## s03c — Terms and Disclosures

**Legal document files were never actually uploaded to S3.** R-8 (DECISIONS.md)
requires each of the 4 real documents to open in the phone's native file
viewer via `LegalDocumentsRepository.downloadUrl(id)` (a presigned S3 GET
URL) — built and wired on this screen. But every `LegalDocument.fileObjectKey`
today is a placeholder that was never actually uploaded (already flagged
once, in `lib/screens/account/legal_screen.dart`'s own history comment, as
the reason that screen was switched to an in-app renderer instead — a
workaround R-8 no longer permits for this screen). `downloadUrl` itself
succeeds (the presigned-URL endpoint doesn't validate the key exists), so the
phone's file viewer opens and then 404s (S3 `NoSuchKey`) — nothing on the
client can detect this in advance.

Built: the row tap → `downloadUrl` → `launchUrl(..., externalApplication)`
flow, with an honest snackbar on any exception, plus a real empty state for a
document whose `fileObjectKey` is unset. Not built (can't be, client-side):
detection of a *populated-but-dead* key — that needs the 4 real files
actually uploaded to their `fileObjectKey`s server-side.

## s36 — Add money

**Deposit fee fields on the funding endpoints.** s36 draws priced funding —
"Bank transfer ₦100 to ₦150 · same day" and "Debit card Flutterwave · ₦28
fee, instant". Per DECISIONS.md C-3 / the R-4 amendment, neither figure is
real: no deposit or card-funding fee constant exists anywhere in the
backend. `GET /transactions/virtual-account` (`VirtualAccountDetails`) and
`POST /transactions/fund` (`FundResult`) carry no fee field at all — not
even an explicit zero — so there is nothing on either response to source a
figure from, real or otherwise.

Built: both method rows and the funding-account plate, with their fee copy
computed from a single `_depositFeeLabel` constant in
`lib/screens/wallet/wallet_flows.dart` rather than pasted per call site —
currently "Free", because that is what is actually charged today (verified
against the repository, not guessed). Not built: any live fee figure, since
none exists to read. `fees.ts`'s own header records what shipping a
client-side fee guess cost last time (a quoted "Fees · 1.35%" while the
backend charged nothing) — this screen does not repeat it.

Also not built: s37's "Changing it takes a 24-hour security hold" line on
the withdraw destination row — grepped the backend and
`bank_accounts_screen.dart` for any such hold and found nothing, so it is
omitted rather than asserted (same standing as the fee figures).

Needs: real `feeKobo` (or equivalent) fields on
`GET /transactions/virtual-account` and `POST /transactions/fund`, per the
provisional rate card in FACT-CONFLICTS.md (flat bank-transfer fee, live
Flutterwave pass-through for card) once that rate card is actually ruled —
it is currently marked PROVISIONAL there, not production-ready. Once a real
figure exists on the wire, `_depositFeeLabel` is the only place in this file
that needs to change to render it.

## s29/s29m/s43b/s43m/s44, s47/s46m/s48/s48m — buy/sell fees are unreachable
anywhere in this flow

Per R-34/C-1, `trade_flows.dart` no longer carries a client-side fee
constant (it used to, `_kBuyFeeRate`/`_kSellFeeRate`, both now deleted — see
`fees.ts`'s own header for what that cost last time). Checked directly
against the backend for this pass, not assumed: there is genuinely nowhere
in this flow a real fee/commission/total/proceeds figure can be read from
today, at any step —

- **No preview/quote endpoint.** `POST /orders` places a real order; there
  is no side-effect-free "what would this cost" endpoint anywhere under
  `src/orders/`.
- **The order-creation response has no fee fields.** Even though a market
  order fills synchronously and `OrdersService.create` computes real fees
  for it in the same request (`recordContractNote`, called before the
  response returns), the wire type it responds with —
  `Order` in `Kudimata-Securities-Backend/src/common/types/order.types.ts`
  — declares no `commissionKobo`/`exchangeFeesKobo`/`vatKobo`/`totalKobo`
  field at all. `OrdersService.toDto` only ever spreads the fields that
  type declares, so even a fixed version of the one bug below wouldn't
  surface them without a type change too.
- **The one endpoint that does compute them needs a reference the client
  never receives.** `GET /orders/contract-note/:ref` returns the full fee
  breakdown, but keys on `Order.contractNoteRef` — a field the `Order` wire
  type also doesn't expose, so there is no way to reach it from a freshly
  placed order's response.
- **Smaller wiring bug found along the way, left as-is (out of scope for a
  screen agent to fix a backend file):** `OrdersService.create` (around
  line 265-302) fetches `created` from Prisma, then runs
  `recordContractNote(created)` into a separate local `priced` variable for
  a market order — but returns `this.toDto(created)`, the pre-fee row, not
  `priced`. Even a type change alone wouldn't fix this without also fixing
  the return value.

Built: every row the canvas draws — Order type, shares, price, consideration
("Estimated amount", a real `units × price` figure, not a fee), and the
fee/total/proceeds rows themselves, all present with their labels intact.
Not built: a numeric value for any fee/commission/total/proceeds row —
each renders `"Added when your order fills"` (a real, honest statement:
Kudimata does calculate and charge these, just not anywhere this client can
read) instead of a computed or invented figure. The placed screen (s31)
similarly omits the canvas's "for ₦25,000" clause, keeping the share count.

Needs: `POST /orders`'s response — and `GET /orders/:id`/`GET /orders`, so
a later "view this order" read gets the same figures — to include
`commissionKobo`/`exchangeFeesKobo`/`vatKobo`/`totalKobo` on the wire type,
plus the `created`-vs-`priced` return-value fix above. A true pre-placement
preview endpoint would be needed to show fees before the PIN step at all,
which no artboard in this section actually requires (every review screen's
"Place order" button is also the placement action) — so the minimum fix is
the response-shape one, not a new endpoint.

**s44 ("Bought, at the real prices") is not built.** It needs a per-leg
fill breakdown ("64 shares at ₦228.50 / 45 shares at ₦229.10 / Average
price you paid") on top of the fee total above. `Order` stores one
`price`/`units` pair per order, never several fill legs, so there is
nothing to source a multi-price breakdown from even once the fee gap above
is closed. This flow's terminal screen is s31 ("Order placed"/tracker),
which every signal it draws (order created, order status, a settlement
estimate) can actually back.

**Sell proceeds always go to the wallet — the bank-payout side of a sell is
real but incomplete.** `Order.destinationBankAccountId` exists and is
stored, but `OrdersService.applyWalletSideEffect` credits the wallet for
every sell regardless of what it's set to — the actual bank payout needs
`TransactionsService`'s transfer logic, not wired into `OrdersService`
today (see that method's own comment). Built: the review screen's "Where
the money goes" section shows the wallet as the only selectable option and
the investor's real primary bank account as a visibly disabled row with an
honest "Not available yet" note, rather than letting the selection succeed
and silently not move the money. `OrderPlacementRepository.placeOrder`
also doesn't accept a `destinationBankAccountId` parameter yet, so nothing
here calls the endpoint with one set.

**No live bid/ask depth feed.** The price-entry step (s43/s46) draws a
distinct buyer-pays/seller-asks spread ("Nearest seller"/"Best buyer now")
implying an order book. `SimulatedNgxBroker` is the only `BrokerAdapter`
and gives one plausible-per-ticker quote, not a book (the same root cause
already used to justify hiding the asset-detail Order Book tab — see
DECISIONS.md's B-2). Built: the one real quote (`Asset.price`) stands in
for both roles rather than inventing a spread. The artboards' specific
per-tick min/max price bounds ("Min ₦0.05 / Max ₦250.00") have no backend
source either (no NGX tick-size data anywhere in this app) and are also
omitted, replaced with basic "price must be positive" input validation.

## Notifications settings — Weekly digest (no artboard, restyle-only screen)

**Weekly digest email preference.** An older mockup this screen was built
from drew a "Weekly digest" switch alongside Order updates / Price alerts /
Security. `NotificationPreferences` has no field for it —
`ordersEmail`/`priceAlertsEmail`/`accountEmail` are the only three booleans
the backend models — and there is no scheduling job that could ever send a
digest email regardless.

Not built: the switch is omitted rather than shown as inert local state.
It previously existed as a client-only `bool` that never called the API and
reset on every app restart — indistinguishable, from the user's seat, from
a real preference that silently does nothing. Removed 2026-08-27 alongside
the redesign's R-6 parking of the AI-credits product line (the digest it
would summarise is the same `POST /ai/portfolio-digest` feature whose Home
entry point `home_screen.dart` already removed).

Needs, only if/when R-6 is revisited: a persisted `weeklyDigestEmail`
field on `NotificationPreferences`, plus a real digest-scheduling job. Until
both exist, no switch for this belongs on the screen.

## s54 — Security: "Alert me on new logins"

`s54` draws a toggle, default off, sub "By email and push": **"Alert me on
new logins."** Grepped this app and the backend for any new-login/new-device
notification preference or dispatch path and found nothing —
`NotificationPreferences` has no such field, and there is no push channel
anywhere in this backend at all (its own repository header says so).

Not built: the toggle is omitted rather than shown as inert local state
(the same defect class flagged for the removed "Weekly digest" switch
above). Needs a real `newLoginAlert`-shaped preference field plus a login
event that actually dispatches on it (and, separately, a push channel,
since s54's own sub-copy specifically claims "email and push") before this
row can ship.

## s58 — Personal details: no email-change capability

`s58` draws an "Email" row with a "Change" affordance and a "Needs an email
code" hint, implying an OTP-verified email-change flow.
`UserRepository.updateProfile` has no `email` parameter at all — there is
no email-change capability anywhere in this app, gated or otherwise.

Built: the Email row itself, showing the investor's real current address
(`personal_info_screen.dart`). Not built: the change flow — tapping
"Change" surfaces an honest "not available yet, contact support" message,
the same established pattern `data_privacy_screen.dart`'s "Download my
data" and `statements_screen.dart`'s request flow already use for a real,
known, unbuilt capability. Needs: a `PATCH /users/me` (or dedicated
endpoint) that accepts `email`, plus whatever verification step the
product wants in front of it (s58 implies an email OTP) before this can be
self-serve.

## s51 — Account hub: unregistered icon glyphs

`s51` uses `Icon name="users"` for the Personal details row and
`Icon name="flag"` for Corporate actions. Neither name exists in
`lib/widgets/k_icon.dart`'s registry (checked — `KIconBubble` silently
falls back to a generic `card` glyph for any unregistered name, which would
misrepresent both rows rather than help them). `lib/widgets/**` is frozen
for the duration of this wave (screen-agent brief, rule 5), so this screen
agent could not add the glyphs itself.

Built: both rows, with an adjacent available substitute instead
(`profile` for Personal details, `transfer` for Corporate actions —
`account_screen.dart`'s `_menuRows` doc comment records the exact
substitution). SHARED-CHANGE REQUEST: add `users` and `flag` (and,
separately, `logout`, which s51 also references for its own Log out
button's leading icon and which `account_screen.dart`'s ghost-button Log
out currently renders without) to `lib/widgets/k_icon.dart`'s glyph
registry.

## s55 — Corporate actions hub, rights issue and AGM detail

**No per-item detail route for rights issues or AGM meetings.** `GET
/rights-issues/:id` and `GET /agm-meetings/:id` don't exist — only the bare
list endpoints do. `rights_issue_screen.dart` and `agm_vote_screen.dart` are
each pushed with no `extra`/id (see both files' own header comments — the
router doesn't forward one anyway, per the standing `extra`-drop bug below),
so both screens pick their own "most relevant" item from the full list
rather than being told which one to open. That degrades the moment an
investor has **two** open rights issues (or two open AGMs) at once: the hub
(`corporate_actions_screen.dart`) can point at either one via its "Also
waiting" row, but tapping through always lands on the same
most-urgent/most-recent item regardless of which row was tapped, since
neither detail screen has anywhere to receive an id.

Built: the hub surfaces every pending item, spotlighting the most urgent and
listing any others as tappable rows, so nothing is invisible. Not built:
routing a specific item id into either detail screen. Needs: `GET
/rights-issues/:id` and `GET /agm-meetings/:id`, plus a real id-bearing route
(path segment, not `extra` — see the `extra`-drop bug below) for each.

**No notice-of-meeting email endpoint.** `agm_vote_screen.dart`'s "Email me
the notice of meeting" button has nothing to call — grepped
`Kudimata-Securities-Backend`'s corporate-actions module and found no
document-email endpoint of any kind for AGM meetings. Built: the button,
with an honest "isn't available yet" message on tap rather than pretending
an email was sent. Needs: a real notice-of-meeting document + an
email-dispatch endpoint before this can be wired.

---

## s19 — Declarations: broker/NGX-employment question has no backend field

`s19`'s second question — "Do you work for a stockbroker or the NGX?" —
is a real SEC-relevant declaration the canvas draws, same standing as the
PEP question beside it. `UpdateKycDraftFieldsRequest`/`KycSubmission`
(backend `common/types/kyc.types.ts`) only carry `pepSelfDeclared`; there is
no field anywhere for this second question's answer.

Built: the real Yes/No UI (`declarations_screen.dart`), held in
`KycFormState.brokerOrNgxEmployed` for the current session only — the same
treatment already established for the PEP question's own unbacked
who/position follow-up fields. Not built: any server persistence. Two
consequences worth flagging together:

1. A "Yes" here is currently invisible to compliance review — nothing
   downstream (a KYC submission review screen, an admin dashboard) can see
   it, because nothing stores it.
2. `kyc_checklist_screen.dart` (`s11`, the new checklist hub) can only infer
   "Declarations done" from `pepSelfDeclared != null` for this reason — it
   has no way to know, on a fresh session, whether this second question was
   already answered. See that file's own header comment.

Needs: a `brokerOrNgxEmployed` (or similarly named) boolean field on
`KycSubmission`, plus an `UpdateKycDraftFieldsRequest` param the same shape
as `pepSelfDeclared`, before this can be a real persisted declaration rather
than a same-session-only echo.

---

## PRODUCTION BUG — navigation `extra` is silently dropped

*Found 2026-08-27 by the harness-integrity pass. Not a test artifact.*

**Mechanism:** Home is kept alive in the `StatefulShellRoute` IndexedStack, so its
async KYC-gating refresh (`refreshKycGatingState`, `home_screen.dart`) can resolve
*after* the user has navigated away. It then calls `AppState.notifyListeners()`,
which fires GoRouter's `refreshListenable`. The router reparses the current
location **from the bare URI** — and `extra` is not URI-encodable, so it is lost.
The route's type-guard then falls through to `KErrorView`.

**Blast radius:** every route that takes an `extra`:

- `withdraw_mandate_screen.dart`
- `contract_note_screen.dart`
- `statement_detail_screen.dart`
- `complaint_tracked_screen.dart`

**What a user sees:** they open a contract note, some background state settles a
moment later, and the screen becomes an error card. Nothing they did caused it and
retrying looks random, because it depends on request timing.

**Why it hid for so long:** it is timing-dependent, so it does not reproduce on a
fast local network — and the screenshot harness was reporting these four screens
as captured while actually capturing the error card, so no rendered evidence ever
contradicted it.

**Not fixed here.** The harness now drains the pending refresh before navigating,
which makes captures honest but does nothing for the app. The real fix is one of:
pass identifiers in the path and re-fetch, rather than passing objects via `extra`;
or stop the gating refresh from touching the refresh listenable once its screen is
off-stage. That is a router/state-architecture decision, not a screen change.

## s49/s50 — Price alerts (`price_alerts_screen.dart`, rebuilt 2026-08-27)

Rebuilt against s49 ("Set a price alert") / s50 ("My alerts"), replacing the
old per-watchlist-row %-move editor with s49/s50's real model: a per-asset
alert set from one asset's own page, plus a flat list of everything set.
Three real gaps came out of reconciling the artboards against
`PriceAlertRepository`/`Kudimata-Securities-Backend/src/price-alerts/`:

**1. No alert direction.** s49 draws a "Rises above" / "Falls below"
segmented toggle. `CreatePriceAlertRequest` has no direction field —
`PriceAlertsService#isCrossed` always evaluates `thresholdPriceKobo` as
"reached at least this price" (`quote.priceKobo >= thresholdPriceKobo`),
regardless of which segment an investor would have tapped. A "Falls below"
alert set below today's price would, once the scheduler exists (see gap 3),
either never fire as intended or read as already-satisfied the moment it's
saved — a promise the system does not keep (the same defect class as the
s37 security-hold line). Built: the price-target field itself, fully real
and functional. Not built: the direction toggle — `SetPriceAlertScreen`
(`lib/screens/markets/price_alerts_screen.dart`) offers one labelled
field ("Alert me when it reaches"), the one mode the backend actually
implements. Needs: a `direction` column on `PriceAlert` (Prisma schema +
`CreatePriceAlertRequest`) and a second branch in `#isCrossed` for
"falls to at least."

**2. No price-band figures.** s49 draws "Min ₦0.05 / Max ₦250.00" under the
price field. No field anywhere on this backend (`Asset`, `Quote`, or
otherwise — checked against `common/types/asset.types.ts`) carries a tick
size or a daily price-limit band. R-34: omitted rather than invented — the
price field above it ships without a fabricated bounds row. Needs: either
a real tick-size/price-limit source from the exchange feed, or a product
ruling that this row simply doesn't ship.

**3. No triggered-alert visibility.** s50 draws a triggered-alert card at
the top ("GTCO fell below ₦46.00 · Tap to buy, or leave it"). Two
independent blockers: (a) `PriceAlertsService#checkAndNotify` — the
comparison-and-notify logic — is deliberately not wired to any scheduler
(no `@nestjs/schedule` `ScheduleModule` registered anywhere in this
backend; see that method's own header comment), so no alert has ever
actually fired server-side; and (b) even once it does,
`PriceAlert.lastTriggeredAt` is never serialised onto the wire shape
(`common/types/price-alert.types.ts` has no such field) — the app has no
way to distinguish a "waiting" alert from a "fired" one even by asking.
Built: the full "Waiting" list, real and reader-complete. Not built: the
triggered card — every alert renders as waiting because none can honestly
be anything else yet. Needs: the scheduler wired up, and
`lastTriggeredAt` added to `PriceAlert`/`PriceAlertWithQuote`'s wire shape.

**Not a backend gap, flagged for whoever owns the other files:**
`SetPriceAlertScreen` (the s49 screen) has no go_router entry —
`lib/router/routes.dart`/`app_router.dart` are off-limits to a screen
agent mid-wave (rule 5). It's a real, working, public/ticker-parametrised
widget, reached today only via this file's own "New alert" flow
(`Navigator.push`, not go_router), and verified via a throwaway rendering
test (deleted after use, per the Order Book precedent above) rather than
`shots_all.dart`. SHARED-CHANGE REQUEST: add
`Routes.setPriceAlert(String ticker) => '/asset/$ticker/alert'` + a
matching `GoRoute`, after which `asset_detail_screen.dart` (out of this
screen's scope) can wire s49's real "from the asset page" entry point via
`context.push(Routes.setPriceAlert(asset.ticker))`.

## s36 — Add money, debit-card fee (`wallet_flows.dart`, R-37/BR-2, 2026-08-27)

R-37/BR-2 landed a real deposit fee: `VirtualAccountDetails.feeKobo` and
`FundResult.feeKobo`, backed by `transactions/deposit-fees.ts`. The
bank-transfer method now shows its real fee everywhere s36 draws one — the
method-choice row and the account plate's footnote both read
`VirtualAccountDetails.feeKobo` (GET /transactions/virtual-account, known
before the investor picks anything).

The debit-card method row cannot do the same. Its only fee source,
`FundResult.feeKobo`, comes back from `POST /transactions/fund` — and that
call already creates a real pending `Transaction` server-side. There is no
quote endpoint that returns `computeDepositFee('card')` without that side
effect, so the card row states no ₦ figure at selection time ("Flutterwave
· instant") rather than inventing one (R-34). The real ₦150 figure is
surfaced as soon as it IS known: in the awaiting-payment sheet shown right
after `fund()` returns, via its `feeKobo`.

Needs: a side-effect-free quote endpoint (e.g. `GET
/transactions/deposit-fee?method=card`) if the card row is meant to show
its fee before the investor commits to starting a payment.

## Tax documents — WHT credit note has no producer (`tax_documents_screen.dart`, 2026-08-27)

Restoring the Tax documents hub row required extending the mobile
`StatementKind` enum (statements_repository.dart) to cover both tax kinds
`GET /statements?kind=` already accepts: `wht_credit_note` and
`annual_tax_summary`.

`annual_tax_summary` is real end to end —
`StatementGeneratorService.generateTaxSummariesForAll` runs on
`@Cron('30 2 2 1 *')` and creates one Statement row per investor with a
dividend that year. The screen lists these like any other statement.

`wht_credit_note` is not. `StatementsService.generateTaxDocument()` accepts
the kind as a parameter, but grepping the whole backend turns up no caller
that ever passes `'wht_credit_note'` — no cron, no controller route, no
other service. `GET /statements?kind=wht_credit_note` is a real, live call
and will correctly return `[]` for every investor, forever, until a
producer is wired.

Built: the WHT credit notes section on the tax screen makes the real call
and renders a plain empty-state explanation rather than hiding the section
again or fabricating rows. Needs: a caller for
`generateTaxDocument('wht_credit_note', …)` — most naturally alongside the
existing annual-summary cron, since a credit note is logically per-dividend
or per-tax-year WHT proof, not a client-triggered action.
