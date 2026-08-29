# Redesign 2026-08 — authority and rulings

This file is the reason the last redesign went wrong and this one should not.

Last time, screens were quietly reshaped to fit how the backend happened to be
built. That was not the model being careless — it was the model applying its
correct default (*don't break the working thing*) to a case where the opposite
was wanted, because **nothing in the input said which side yields.**

So this file says it, first and explicitly, before any screen work begins.

---

## Authority declaration

**The canvas at `docs/design/redesign-2026-08/` is authoritative for the UI.**

Consequences, which are rules and not preferences:

1. A screen is built as designed. It is **never** reshaped to fit what the API
   currently returns.
2. Where the design needs data the backend does not serve, that is a **backend
   change request**, written to `docs/redesign/BACKEND_GAPS.md` with the artboard
   id that requires it. It is never resolved by changing the design.
3. "The endpoint doesn't return that field" is not a reason to drop the field
   from the screen. It is a ticket.
4. An agent that believes the design is wrong **halts and says so**. It does not
   exercise judgement about the design on its own authority.

The one thing that outranks the canvas is a ruling in this file.

---

## Source of truth

> ### ⚠️ The `_ds/` bundle is NOT the mobile design system
>
> It is the **admin dashboard's** ("the desk"), by its own readme: *"adapts it for
> a desktop internal admin dashboard."* Its manifest declares `"themes": []` — no
> dark tokens exist in it at all.
>
> And its tokens were **reverse-engineered from this Flutter app**: *"`lib/theme/
> tokens.dart` — Source of truth for colour, type, spacing, radii… that original
> CSS was not in the upload, so `tokens/` here is reconstructed from the Dart
> constants."*
>
> So it is a *derivative of the mobile app, adapted for desktop*. Reading mobile
> values out of it pulls desk-oriented decisions into a phone.
>
> **For this redesign: the artboards are the spec, and `lib/theme/tokens.dart`
> remains the source of truth for the light palette.** Dark values come from the
> dark artboards, each cited to its source line. No agent may take a mobile token
> from `_ds/`.

| artifact | role |
|---|---|
| `docs/design/redesign-2026-08/*.dc.html` | the design. 56 light artboards + 55 dark + state variants. Committed, so it cannot silently go stale like the transcribed spec it replaces. **The authoritative spec.** |
| `docs/design/redesign-2026-08/_ds/` | the **admin dashboard's** design system, reconstructed from this app. Reference only — never a source for mobile tokens. See the warning above. |
| `docs/redesign/canvas-inventory.json` | machine inventory: per artboard id, label, copy, structure hash |
| `docs/redesign/evidence/*.json` | per app screen: what it does, which artboard covers it, and the evidence for that call |
| `docs/redesign/RULINGS.md` | the human decisions on every screen with no clear artboard |
| `docs/redesign/BACKEND_GAPS.md` | design needs the API cannot serve yet |
| this file | authority + rulings that outrank everything above |

Regenerate the inventory after any canvas update:

```bash
python3 scripts/design/canvas_inventory.py docs/design/redesign-2026-08 \
    --out docs/redesign/canvas-inventory.json
```

---

## What the diff actually showed

Worth recording, because it sets the shape of the work and contradicts the
assumption we started from.

- Old canvas: **97** light screens. New canvas: **56** light screens, plus 55
  dark twins and assorted state variants.
- Best content overlap between any old and any new screen: **0.52**. Median
  ~0.2. **This is a wholesale rewrite, not an incremental edit.** There is no
  meaningful "unchanged" bucket, so "only touch what changed" does not apply.
- The app has **86 screen files / 77 routes** against 56 designed artboards.
  That gap is the entire risk of this redesign, and it is why no screen work
  starts before `RULINGS.md` is complete.

Features present in the old canvas and **absent by name** from the new one:

| feature | old mentions | new mentions |
|---|---|---|
| suitability quiz | 5 | 0 |
| plans / subscription | 16 | 0 |
| watchlist | 6 | 0 |
| glossary | 7 | 0 |

Absence from the canvas is **not** evidence of removal. Each one is a ruling.

---

## Rulings

### R-1 — Suitability quiz: KEEP, relocate, restyle
*Ruled by the product owner, 2026-08-26.*

The suitability questionnaire survives the redesign. It becomes the **last step
of the KYC flow**, or another point that does not break the flow. It is restyled
to the new design system.

### R-2 — No profiling framing anywhere
*Ruled by the product owner, 2026-08-26.*

> "Nothing like risk profile — we are not profiling anything."

No screen presents the user with a risk score, risk category, risk profile or
any equivalent classification. The questionnaire is retained; **the
classification output of it is not**. Any existing copy or logic that computes
and displays a risk classification is a removal candidate — see the
`profiling_language` findings in `docs/redesign/evidence/suitability-corp.json`.

This is a product rule, not a screen decision: it applies to copy, headings,
iconography and result screens equally, and it should end up as an executable
check in `scripts/gates/` so it cannot be reintroduced by a later agent.

### R-3 — Undesigned screens: no default, rule each one
*Ruled by the product owner, 2026-08-26.*

There is **no blanket policy** for app screens with no matching artboard. Every
one is listed with evidence in `RULINGS.md` and ruled individually before any
work on it starts. An agent may not infer keep, restyle or cut.

### R-4 — Backend yields to the UI
*Ruled by the product owner, 2026-08-26.*

Per the authority declaration above: screens are built as designed and backend
shortfalls are filed as gaps. Backend changes are **not** made in the same pass
as the screen work — they are a separate, separately reviewed body of work.

---

### R-1a — Suitability assessment moves EARLY, before the legal documents
*Ruled by the product owner, 2026-08-26. Supersedes the placement in R-1.*

R-1 said "last step of KYC, or another reasonable place". The owner has now named
the place, and it is early rather than late:

> "assessment should come before risk disclosure which means… before the legal
> docs they see and accept"

Resulting onboarding order:

```
signup → verify email (OTP) → SUITABILITY ASSESSMENT → legal documents
       → (risk disclosure is one of those 4 documents) → passcode → biometric → KYC
```

The assessment therefore **informs** the risk disclosure the investor then
accepts, rather than trailing behind it. It no longer attaches to
`Routes.kycApproved`, and `approved.dart`'s "Start investing → questionnaire"
wiring is removed.

Still true from R-1/R-2: the quiz survives, restyled; it produces **no** risk
classification, and `SuitabilityResult.profile` — still computed and persisted
today with no reader — is removed from the backend.

### R-8 — Legal documents: 4 only, opened in the phone's file viewer
*Ruled by the product owner, 2026-08-26. Covers C-4 and D-8.*

Four documents, not eight — the canvas's other four are **not** to be created.
Risk disclosure is **one of the four**, presented at the start with the rest, not
as its own gated screen (this replaces R-1's expectation and answers D-7).
Documents open in the phone's native viewer rather than being rendered in-app,
so `document_summary_screen.dart`'s in-app parsed rendering is superseded.

**Consequence to watch:** the app loses scroll-gated acceptance evidence. If
compliance later needs proof an investor actually read a document, that proof no
longer exists. Flagged, not blocked.

### R-9 — KYC: keep CHN and next of kin, drop review-before-submit
*Ruled by the product owner, 2026-08-26.*

CHN and next of kin remain KYC steps (CSCS requires them), styled to the new
design. The review-before-submit screen is removed; submission happens from the
last collection step.

### R-10 — KYC failure screen: designed fresh in the canvas's visual language
*Ruled by the product owner, 2026-08-26.*

Rejected / flagged / expired outcomes keep their existing behaviour (resubmit if
attempts remain, else contact support) but the screen is authored fresh against
the redesign's patterns rather than waiting for an artboard. The layout is ours;
that is recorded here so nobody later mistakes it for designer intent.

### R-11 — Auth mechanics
*Ruled by the product owner, 2026-08-26.*

- **Passcode stays 6 digits with a confirm step**, everywhere including login.
  The canvas's 4-digit single-entry screen is not adopted; its *look* is.
- **Phone field is added at signup as designed**, and the missing backend support
  is filed in `BACKEND_GAPS.md`. Until it lands the field must not silently
  discard input — it is either wired or visibly unavailable, never a dead control.
- **Terms acceptance stays a dedicated post-OTP screen.** The canvas's pre-OTP
  checkbox is not adopted.

### R-12 — Rights issue keeps partial take-up
*Ruled by the product owner, 2026-08-26.*

The investor continues to choose how many of their entitled shares to take up.
The canvas's binary take-all-or-skip model is not adopted.

### R-13 — Dark mode is first-class, with a toggle
*Ruled by the product owner, 2026-08-26.*

The app ships **light and dark**, with a user-facing dark-mode toggle.

This is a real reversal and the reason is documented in the code: `tokens.dart:9`
records that dark was removed because the *old* design system's readme called it
"an undesigned draft". The new canvas designs **55 dark artboards** — dark is now
fully specified, so the reason for removing it is gone.

Work implied: a dark `KPalette` built from `_ds/tokens/colors.css`, `ThemeMode`
wiring (`darkTheme` is absent entirely today), the toggle itself with persistence,
and every screen verified in both themes. `KPalette` already carries a
`brightness` field, so the structure is there — only the light palette exists.

### R-14 — Welcome: Landing Video Concept V3
*Ruled by the product owner, 2026-08-26.*

The welcome screen is the **Landing Video Concept**, treatment **V3** — the
6-second muted looping video behind "Dream. Invest. Live.", with the
"Kudimata Securities Ltd · SEC registered" line. Not `s02`, and **not a
carousel** (the canvas contains no carousel: zero occurrences of slide, swipe,
dots or "1 of 3" anywhere).

**Blocked on an asset**, not a decision: V3 needs footage shot to the canvas's own
brief — one person, phone in hand, warm daylight, plain wall, calm top third,
nothing important below the waist, no text in frame. Until that exists the screen
is built with V1's illustrated frame in the same layout, so swapping in the loop
later is a media change and not a rebuild. Filed in `BACKEND_GAPS.md` as an asset
gap.

### R-15 — Home: s22/s22d + s23/s23d
*Ruled by the product owner, 2026-08-26.*

Home is four artboards — verified (`s22` light / `s22d` dark) and
verification-not-finished (`s23` / `s23d`). `Home Variants.dc.html` (L1/3E) is the
exploration whose approved treatment is already carried into them; `s22`'s own
caption says so: *"The approved pattern, carried across every screen in light and
dark."*

Structure per the canvas — money card with the naira illustration, four round
actions, sideways content rails, one rotating movers card, four-tab navbar — and
the app's **holdings and trending rails are kept** within it. The AI digest stays
parked under R-6.

### R-16 … R-25 — the remaining screen rulings
*All ruled by the product owner, 2026-08-26.*

| id | screen / area | ruling |
|---|---|---|
| R-16 | Watchlist | **Screen dropped.** The `+ watchlist` toggle on asset detail stays. **"My alerts" (`s50`) gets a permanent Account-menu row** so saved assets still have a reader and alerts stay reachable. |
| R-17 | Orders | **Cancel is kept** and added to the new layout. The artboard omits it; it is live, wired, and the alternative is phoning support to stop a trade. |
| R-18 | Asset detail | **Build the Order Book tab** as designed. If the broker feed serves no depth data, that is a backend gap ticket — not a dropped tab. |
| R-19 | Identity / address | **BVN/NIN auto-populate is adopted, AND an address step is kept.** BVN returns name and DOB but not a current address, and proof-of-address is required. `s17` already pairs address fields with the utility-bill upload — build that. |
| R-20 | Password reset | **Account password reset and local passcode reset stay separate flows.** The canvas's combined flow is not adopted. |
| R-21 | Withdraw outside hours | **Kept, restyled.** Reachable every evening and all weekend; without it the user is never told why their money hasn't moved. |
| R-22 | Portfolio allocation | **Adopt the canvas — bar chart by sector**, replacing the donut by asset class. |
| R-23 | Holding detail | **Build `s34`, keep the extra rows** — dividends received and held-in-CSCS stay. |
| R-24 | Corporate actions | **AGM vote, dividends detail and rights issue detail are kept and restyled.** `s55` lists them as hub items, so only the detail screens went undrawn. Partial rights take-up retained per R-12. |
| R-25 | Notifications feed | **Kept, restyled.** Live, backend-wired, no artboard anywhere. |

### R-26 — Dark grape flattens to the dark card colour
*Ruled by the product owner, 2026-08-26.*

The canvas is internally inconsistent: `s22d`/`s23d`/`s24d` flatten the grape
"rich surface" to the ordinary dark card `#26242A`, while `01 Getting In`'s dark
onboarding screens keep full-bleed grape `#6524A8`.

**Flattening wins, everywhere.** Onboarding's full-bleed grape is not carried into
dark. Recorded here because it is a deliberate divergence from what one canvas
file draws, not an oversight — do not "fix" it back.

### R-27 — The six unevidenced dark tokens stand as extrapolations
*Ruled by the product owner, 2026-08-26.*

`feature2`, `ramp5`, `indicatorPress`, `warmPress`, `sunPress`,
`statusRejectedTint` and `scrim` have no dark artboard evidence. They were reasoned
from neighbouring tokens and are flagged in `tokens.dart` with that reasoning.
They stand as-is and do **not** block a release. Revisit only if a screen reads
wrong in dark.

### R-28 — Four-tab navbar; Account moves to the header avatar
*Ruled by the product owner, 2026-08-26.*

The tab bar becomes **Home · Markets · Portfolio · Wallet**, per `s22` and its own
caption ("clean four-tab navbar"). Consequences:

- The **You** tab is removed. Account is reached from the **header avatar**, which
  `s22` already draws.
- **Assets and Portfolio consolidate** into the single Portfolio tab.
- This touches every screen's shell and all deep links into the removed tabs, so
  it lands **before** the screen waves, not during them.

### R-29 — Persona, readiness, quiz and financial literacy are external links
*Ruled by the product owner, 2026-08-26.*

These are **existing products already live on the Kudimata website**, not features
to build in the app. The canvas's Home rails link out to them.

The public site is **kudimata.app** (not kudimata.com — that host appears in the
`Kudimata-Web` source but the live product site is `.app`). All four destinations
verified against the `Kudimata-Web` page tree and the live site:

| feature | destination |
|---|---|
| Kudimata Persona ("what's your money persona?") | `https://www.kudimata.app/kudimata-persona` |
| Investor Readiness ("check your readiness") | `https://www.kudimata.app/iri` |
| The quiz | `https://www.kudimata.app/quiz` |
| Financial literacy | `https://www.kudimata.app/our-app/financial-literacy-quiz` |

These live in ONE place — a `KLinks` constants file — so a moved page is a
one-line fix rather than a hunt across screens.

**Consequence, and it is not optional:** the canvas draws *"Financial literacy ·
Lesson 3 of 12 · 4 min"*. If the lessons live on the website, the app cannot know
which lesson the user is on. A progress figure with nothing writing it is a fake
number — the same defect class as a seeded chart presented as live data.

**So these rails render as static promo cards, never as progress cards.** No
"Lesson N of 12", no completion state, no persona result echoed back into the app.

This also keeps R-2 intact: the persona classification happens on the website and
is never displayed inside the app.

### R-30 — Non-happy states are owed by the queue, not by the canvas
*Ruled by the product owner, 2026-08-26.*

**The canvas designs no loading, error or empty state for any of its 56 screens.**
Of 24 state variants, only `s29c` (market closed) is a real UI state; the rest are
flow branches — limit-vs-market forks, onboarding sub-steps, a device-trust login
fork.

So: **reuse `lib/screens/shared/state_views.dart`**, restyled to the new tokens.
One implementation, used everywhere.

And the part that makes it stick: **every screen in the build queue carries an
explicit state task**, with the condition that enters each state. A screen is not
done because its happy path matches the artboard. This is deliberate — the happy
path gets built by default, so the other states have to be *owed by an artifact*
or they evaporate. That is exactly how a screen ships looking finished and then
shows a blank panel on the first 500.

### R-31 — Per-order PIN reuses the existing passcode
*Ruled by the product owner, 2026-08-26.*

`s30`'s per-order transaction PIN is built, **reusing the app's existing 6-digit
passcode** (`PasscodeStore`, salted SHA-256 in `flutter_secure_storage`) rather
than introducing a second credential. Confirmation is local; the order call is
unchanged, so no backend work is required.

Not adopted: a separate transaction PIN with its own storage, set-up, reset and
recovery flows.

### R-32 — Home is rebuilt from scratch against s22/s23
*Ruled by the product owner, 2026-08-26.*

`home_screen.dart` was built against **stale old-canvas ids `s29`/`s30`**, which in
the current canvas point at unrelated screens — the R-5 trap, already realised.
Home is therefore rebuilt as a new screen against `s22` (verified) and `s23`
(verification not finished), not patched.

Must include, all currently missing: the money card as drawn, the round quick
actions as drawn (including Withdraw and Learn), the **"Grow with Kudimata" rail**
linking out per R-29, the rotating **"Top movers today"** card, and `s23`'s
**"While you wait"** rail plus KYC banner for unverified users. Holdings and
trending rails are kept per the earlier D-6b ruling. The AI digest card stays
parked per R-6 and must be removed from the current Home.

### R-33 — The six new screens are build work, not rulings
*Recorded 2026-08-26.*

The reverse sweep found six artboards with no app counterpart. Five follow
directly from flow structure, which the canvas owns under R-4, so they are built
without further rulings:

| artboard | screen |
|---|---|
| `s07` | post-signup "What happens next" overview |
| `s42` / `s45` | up-front buy / sell market-vs-limit chooser |
| `s43` / `s46` | limit-price entry, buy / sell |
| `s30` | per-order PIN — ruled separately in R-31 |

Also confirmed: the new canvas contains **zero email templates** (the old one had
10), so nothing there is out of scope to route elsewhere.

### R-34 — A designed figure with no data source is omitted and filed, never invented
*Precedent set on the `s24` pilot, 2026-08-26.*

Two rules pull against each other and this is how they resolve. R-4 says build the
screen as designed. But a number rendered to a user with nothing writing it is a
fake, and shipping one is the same defect class as a seeded chart presented as
live data.

**Resolution: omit the figure, keep everything else the artboard draws, and file
the gap** in `BACKEND_GAPS.md` naming the artboard and the field. Never substitute
a plausible-looking value, and never quietly delete the surrounding element.

First instance: `s24` draws "NGX All-Share +1.4%"; no index feed exists. The
up/down counts beside it are real, so the card ships without the index clause.

This is the screen-level form of the standing rule in `FACT-CONFLICTS.md`: no
screen renders a figure it computed or invented.

### R-5 — Artboard ids come from the ruling sheet, never from code comments
*Recorded 2026-08-26, from evidence.*

The app's source carries comments citing **old** canvas ids — `s29`, `s30`,
`#s47`, `#s48`, `#s51` — from the 97-screen canvas. In the renumbered 56-artboard
canvas those ids now point at **completely unrelated screens** (Buy/Sell steps,
the Account hub).

An agent that trusts an in-code canvas reference will read the wrong artboard and
build the wrong screen with full confidence. So:

- A screen agent takes its artboard id **only** from `RULINGS.md`.
- Stale `sNN` references in code comments are stripped or re-pointed as part of
  the work on that screen.
- No agent may cite a canvas id it did not receive in its own task.

### R-6 — AI-credits line: parked, not cut
*Ruled by the product owner, 2026-08-26.*

Plans/subscription, Refer & earn, the Gemini "Explain this investment" screen and
the glossary's credit-metered "Explain further" are **parked**:

- Entry points are removed — Account hub rows, routes, and any nav that reaches
  them — so nothing in the shipped app can navigate to them.
- The screens and their repositories **stay in the tree**, behind a single flag,
  so the decision is reversible in one edit.
- Nothing is deleted. This is not a cut; it is a hidden feature awaiting a
  product decision.

Note the coupling that made this one decision rather than four: referrals pay out
in AI credits, and the glossary's "Explain further" is credit-metered — so the
free/static half of the glossary must survive the parking. **The plain-language
glossary definitions stay reachable; only the metered AI half goes behind the
flag.** Cutting the whole sheet would break trade flows, FAQ, asset detail and the
suitability questionnaire, all of which use it.

### R-7 — Factual conflicts are ruled one at a time
*Ruled by the product owner, 2026-08-26.*

See `docs/redesign/FACT-CONFLICTS.md`. Every canvas assertion that contradicts the
running system is listed there with both figures and a ruling checkbox. No agent
transcribes any of those figures into code before its row is ruled.

---

## Amendment pending: the limit of "UI wins" (R-4)

**R-4 as written is too broad, and the evidence found the hole.**

The canvas contains assertions that are not design decisions but *claims about
commercial and legal fact*:

| canvas claim | reality |
|---|---|
| priced fees on Add Money | the app's real bank-transfer fee is **Free / ₦0.00** |
| a ₦28 card fee | unverified; no backend basis found |
| a non-zero fee line on transaction detail | the backend genuinely has no such fee |
| broker co-branding on transaction detail | not verified as accurate |
| 8 legal documents | the app has 4 |

"The design is authoritative" cannot mean "adopt whatever number is drawn in the
mockup." A fee figure rendered to a customer of a licensed broker is a pricing
statement, not a layout choice. Shipping a placeholder fee as though it were real
is the same defect class as shipping fixture data — it looks finished and it is
false.

**Proposed amendment (awaiting the product owner):** the canvas is authoritative
for *structure, layout, copy tone, flow and interaction*. It is **not**
authoritative for **money amounts, fees, rates, legal document sets, statutory
text, or third-party branding**. Where the canvas asserts one of those and the
system disagrees, the pipeline HALTS and asks — it adopts neither side silently.

Until this is ruled, no agent may transcribe a fee, rate or document count from
an artboard into code.

---

## Rulings still open

Grouped, because 39 individual screens collapse into a much smaller number of
real decisions. Full per-screen evidence in `RULINGS.md`.

| # | decision | screens affected |
|---|---|---|
| D-1 | **The whole AI-credits product line has no presence in the redesign.** Plans/subscription, referrals (which pay out in AI credits), the Gemini "Explain this investment" screen, and the glossary's credit-metered "Explain further" are all absent together. Keep the line, or cut it? | 4 |
| D-2 | **KYC completeness.** The canvas designs 5 steps; the app collects CSCS-required fields it omits (CHN, next of kin) plus a review-before-submit step. And there is **no designed screen for a rejected, flagged or expired KYC** at all. | 5 |
| D-3 | **Auth and onboarding mechanics.** Passcode 4-digit single-entry (canvas) vs 6-digit create+confirm (app); a phone field re-added at signup that was deliberately removed; terms as a pre-OTP checkbox vs a dedicated post-OTP screen; personal-details form dropped for BVN auto-populate; reset flow conflates account password with local passcode. | 7 |
| D-4 | **Trading mechanics.** Limit ("name your price") becomes the primary flow with market as a branch; a **new per-order PIN step**; amount entry loses its toggle and quick-chips; rights issue changes from partial-quantity to binary take-all-or-skip; the artboard omits the live order-Cancel action. | 8 |
| D-5 | **Watchlist / price alerts.** No watchlist artboard exists, and watchlist is today the sole entry point to price alerts. The two features also use different models (per-asset absolute price vs whole-list percent move). | 3 |
| D-6 | **Notifications feed.** Live and backend-wired; zero artboard anywhere. | 1 |
| D-7 | **Statutory risk disclosure (Rule 76).** The canvas demotes it from a dedicated scroll-gated acceptance screen to one downloadable PDF in a list. Compliance decision, not a design one. | 2 |
| D-8 | **Legal documents mechanism.** In-app parsed rendering (app) vs opening the real PDF/DOCX in the phone's viewer (canvas), and 4 documents vs 8. | 3 |
| D-9 | **The R-4 amendment above** — fees, rates, document counts and branding. | 3 |

Dead code found along the way, needing no ruling — `locked_out_screen.dart`,
`order_fill_progress_screen.dart`, `price_moved_screen.dart`, `trade_flows.dart`'s
`_Side.sell` branches, and `wallet_screens.dart`'s `TxnType.convert`. All are
unreachable in the app and absent from the canvas.

None of the above may be resolved by an agent.

---

## Open items raised during the build

Small rulings surfaced by screen agents. Batched rather than interrupting for each
one; none blocks its screen.

| # | raised by | question | recommendation |
|---|---|---|---|
| B-1 | holding detail (`s34`) | The per-holding trades list lost its pending/cancelled **status pill** — R-23 authorised only dividends and CSCS as extras beyond the artboard, so the agent removed it rather than assume. Status is still visible on the Orders hub. | **Restore it.** On a screen showing one holding, whether your trade is still pending is directly relevant, and making the user go to another tab to find out is a downgrade. |

| B-2 | asset detail (`s26`/`s27`) | The **Order Book tab always renders "Depth unavailable"** — its empty state is entered unconditionally, because no depth feed exists anywhere in `lib/data/`. R-18 said build it and file the gap, which is what happened; the consequence is a permanently empty tab. | **Hide the tab until the feed exists**, keeping the built code behind the same check. A tab that can never show anything trains users to ignore tabs. The alternative — ship it as-is — is defensible only if the feed is imminent. |
| B-3 | harness limitation | The screenshot harness captures each screen's **default state only**. Anything behind an interaction — a second tab, an expanded sheet, a filtered list — is never rendered. The asset-detail agent had to write and delete a throwaway test to see its own Order Book tab. | **Extend `shots_all.dart` to capture named sub-states**, driven by a per-screen list. Otherwise the designed variants (`sNNb`/`sNNp`/`sNNc`/`sNNm`) get built with no rendered evidence — the exact gap that lets a state ship broken. |

| B-4 | Home (`s23`) | **The unverified Home state has no fixture.** `MockApiAdapter` always answers `/kyc-submissions/me` as approved, so `shots_all.dart` cannot reach `s23` at all — the agent had to build a throwaway adapter to see its own work. Same root cause as B-3. | **Add fixture variants to the harness** (approved / draft / rejected KYC, empty portfolio, market closed). Without them the *unverified* experience — the one every new user has — is never rendered by the standing harness. |

| B-5 | login (`s08p`) | `s08p` doesn't draw "New here? Create an account", so it was removed. But `_showEmailLogin` **also covers a genuinely account-less fresh install** — someone who has never signed up now reaches a sign-in screen with no way to create an account. The artboard assumed a returning user on a new phone; the code path is broader than the artboard. | **Restore a signup affordance on the account-less path.** Not on the trusted-device variant. A first-time user landing on a sign-in screen with no exit is a dead end, and it is the worst possible one — it is the first screen they ever see. |

### B-6 — Search dropped locally-saved recent searches
*Raised by the `s25` agent, 2026-08-27. Awaiting ruling.*

`s25` draws a "Popular this week" chip row and no recent-search history, so the
agent replaced the app's **locally-persisted recent searches** with trending
tickers from the real `GET /assets/trending`.

That is faithful to the artboard, and "Popular this week" is now backed by real
data rather than the canvas's illustrative tickers — both good. But recent
searches were a real convenience feature, and this is a **capability removal**
rather than a restyle. It is not the same class as B-5 (which was a dead end);
nobody is stranded. It is just gone.

**Recommendation: keep both.** Trending as drawn, plus recent searches beneath
it. A returning investor searching the same two tickers every morning notices
their absence immediately, and the artboard omitting a convenience is weaker
evidence of intent than the artboard omitting a whole screen.

### Rulings on the open items — 2026-08-27

- **B-1 — RESTORE the status pill** on the per-holding trades list. Whether a
  trade is still pending is relevant on the screen showing that holding.
- **B-5 — RESTORE the signup affordance on the account-less path only.** Hidden on
  the trusted-device variant `s08p` actually depicts. Fixes the fresh-install dead
  end without contradicting the artboard.
- **X-3 — POPULATE the address on the KYC submission too.** A compliance officer
  reviewing a case must see the address as it was *when submitted*, not whatever
  the profile says today. Wire the collected values into `finalizeDraft` as well
  as `PATCH /users/me`.
- **B-2 — see below.** Answered, not yet ruled.

### B-2 — the Order Book, and the thing underneath it

Investigating B-2 surfaced something larger than the tab.

**`SimulatedNgxBroker` is the only `BrokerAdapter`, and it is what `broker.module.ts`
wires.** Its own header describes it: *"generates plausible, deterministic-per-ticker
quotes that slowly random-walk over time, and simulates instant/delayed order
fills."*

So there is no NGX connection anywhere. **Every price in the app is synthetic, and
every fill is simulated.** Not just the order book — the whole market-data layer.

This is a **deliberate, documented seam**, not a hidden defect: `broker.module.ts`
states that `useClass` becomes the real adapter when one exists. It is the honest
kind of placeholder. But it sets the real build order:

```
commercial market-data agreement (NGX direct, or via Blue Marina)
  → real BrokerAdapter replacing the simulator
    → backend depth/order-book model
      → the s26/s27 Order Book tab
```

The UI tab is the last and smallest piece. Hiding it until then is not a
workaround — it is correct, because the layer beneath it does not exist.

**This belongs on the go-live checklist, well above the redesign.** An app that
shows simulated prices cannot take real investor money, and no amount of screen
work changes that.

An agent that flags a call like this instead of making it quietly is the system
working. These get answered in batches, not one interruption at a time.

---

## Process correction — shared files must be serialised

Wave 1 ran four screen agents concurrently. Three of them edited **shared** files
(`widgets/charts.dart`, `widgets/scaffold.dart`, `widgets/finance.dart`,
`widgets/k_icon.dart`, `data/models.dart`, `data/glossary.dart`,
`data/repositories/holdings_repository.dart`).

Nothing was clobbered — verified by `flutter analyze` (clean), `flutter test`
(11/11) and a gate run. **But that was luck: the file sets happened not to
overlap.** Two agents adding a prop to the same `K*` widget would have silently
overwritten each other, and the loser's work would look like it was never done.

**From wave 2 on:** before dispatching a wave, name the shared widgets it will
touch. Either give one agent ownership of each shared file and have the others
consume it, or make shared-widget changes a serial pre-step. Rule 5 of the brief
already forbids forking; it does not yet prevent two agents editing the same file
at the same time, and that is the gap.

---

### R-8a — Risk disclosure is its own scroll-gated screen, not one of the four
*Ruled by the product owner, 2026-08-27. Amends R-8. Executed by the flow pass.*

R-8 put all four legal documents in one bundle opened in the phone's viewer.
Three rulings then pulled against each other:

- **R-1a** — suitability comes before the legal documents.
- **R-8** — risk disclosure is one of the four, shown together at the start.
- **The 2026-08-24 SEC-intake instruction** (recorded in
  `suitability_result_screen.dart`, citing "My observations on KSL papers.docx")
  — *"the disclaimer must appear immediately after suitability"* — plus the
  2026-08-27 amendment keeping it scroll-gated in-app.

**Resolution — the onboarding order is:**

```
signup → OTP → suitability → result → RISK DISCLOSURE (own screen, in-app,
       scroll-gated) → the other 3 legal documents (phone viewer)
       → passcode → biometric → KYC
```

So **R-8 now covers three documents, not four.** Terms of service, privacy
policy and client agreement open in the phone's native viewer. The statutory
risk disclosure keeps in-app rendering and a scroll gate, because that is the
only mechanism producing evidence the investor was shown the text — and with
BR-6 live (files never uploaded, presigning succeeds, the viewer 404s) the
viewer pattern would record acceptance for a document nobody could read.

**Two things that must not be lost in the rewiring:**

1. `setSignedIn(true)` currently fires in the risk disclaimer's accept action.
   Wherever that step lands, sign-in completion moves with it. Dropping it
   strands a user mid-onboarding with no visible cause.
2. R-2 still holds: the disclaimer must **not** display the computed profile.
   The 2026-08-24 instruction's "show this computed profile dynamically" half is
   superseded — `RiskDisclaimerArgs.profile` stays unused.

**Retained deliberately:** `app_state.dart`'s post-KYC trading gate stays as a
*fallback* for returning investors who onboarded under the old optional regime
and never took the assessment. It is no longer the only path to the
questionnaire, which is what R-1a was about — it is a safety net behind it.

> **SUPERSEDED 2026-08-29 — product owner, verbatim:** *"risk disclosure
> should be part of the legal docs screen not a standalone before them they
> should be in on user opens and then can click on the checkmark leave the
> scroll thing please."*
>
> This reverses this ruling's own central move: risk disclosure goes back
> into the legal-documents bundle (`terms_and_privacy_screen.dart`) as one
> row among the other three, not a standalone screen ahead of it. **What
> does NOT change:** the scroll-to-bottom gate this ruling's whole rationale
> rested on — "the only mechanism producing evidence the investor was shown
> the text" — is explicitly kept ("leave the scroll thing please"), just
> relocated. The mechanic is: the investor taps the Risk Disclosure row
> (same open-then-check pattern the other three documents already use),
> which pushes an in-app scroll-gated viewer
> (`risk_disclaimer_screen.dart`'s `RiskDisclosureScrollScreen`) instead of
> handing off to the phone's native viewer the other three use; the row only
> counts as "opened" once genuinely scrolled to the end, exactly as strong a
> signal as before. Both "must not be lost" items above carried over intact:
> `setSignedIn(true)` now fires in `legal_acceptance_screen.dart`'s shared
> accept action when its `kinds` include `risk_disclosure`, and R-2 still
> holds (no profile is ever displayed). This is a placement change, not a
> reversal of the evidentiary standard — the old arrangement above is kept
> verbatim for history; it is no longer what the app does.

---

## Rulings 2026-08-27 (evening) — the simulation phase

### R-35 — Simulated market data is the INTENDED state, not a defect
*Ruled by the product owner.*

> "we need to simulate to get our license from SEC before we plug in to real NGX"

This reframes BR-5 entirely. `SimulatedNgxBroker` is not a placeholder someone
forgot to replace — **simulation is the product's current purpose.** The app is
being built to demonstrate to the SEC for licensing, before any real market
connection exists.

So the order book is simulated too (done: `BrokerAdapter.getOrderBook`, generated
only inside the simulator, seeded from the same price drift so depth and quote can
never contradict each other).

**What this does NOT change:** the `PROVISIONAL` gate stays. Simulated figures are
correct for the licensing phase and must not reach real investors unreviewed, and
tagging a release still fails while any provisional value stands. That mechanism
now does exactly the job it was built for — it separates "fine for the demo" from
"fine to take someone's money".

### R-36 — Fees, stamp duty and rates resolve at broker integration
*Ruled by the product owner.*

> "it's a simulation same thing stamp duty... all those are not ours to actually
> cover... when we plug in to a broker's API or NGX we can resolve all that"

C-1 and C-2 are **closed for this phase.** The provisional rate card (buy 0.375%,
sell 0.361%, stamp duty folded into the all-in figure) stands as simulation. The
real commission split, the actual NGX/SEC/CSCS schedule and stamp duty are the
broker's to supply and are settled at integration.

The engineering rule is unchanged and is what makes this safe: **no screen
computes a fee.** Every figure comes from the backend, so the day a real rate card
arrives it is one edit in `fees.ts` and nothing else moves.

The commission concern is recorded but deferred: 0.37% customer pricing against a
0.90% broker cost would lose money per trade — but both figures are simulated, so
there is nothing to reconcile until a real agreement exists.

### R-37 — Deposit fee: ₦100 transfer, ₦150 card, ₦28 of it Flutterwave's
*Ruled by the product owner.*

> "it's meant to be 100–150 naira... 28 out of that is flutterwave, the rest we
> own, it should be logical"

**This resolves the canvas's apparent self-contradiction.** It reads
*"Transfer costs less"* beside "transfer ₦100 to ₦150" and "card ₦28" — nonsense
as drawn, because ₦28 was never the card's total. It is the **provider's cut
inside** the fee.

The logical structure:

| method | investor pays | Flutterwave takes | Kudimata keeps |
|---|---:|---:|---:|
| bank transfer (virtual account) | **₦100** | — | ₦100 |
| debit card | **₦150** | ₦28 | ₦122 |

Transfer is cheaper than card, which is both true of the underlying costs and
makes the canvas's own copy correct. The ₦100–₦150 "range" was the two methods,
not a tier.

**Implementation:** the fee lives in the backend and is returned by the funding
endpoints. The app renders what it is given — `_depositFeeLabel` in
`wallet_flows.dart` is already the single place the copy is decided. Nothing in
the client hardcodes ₦100, ₦150 or ₦28. Introducing a real deposit fee triggers
the in-app fee-change notice your client agreement requires.

### R-38 — Legal documents ship as PDFs
*Ruled by the product owner: "convert to pdfs please".*

The four documents are converted from `.docx` to `.pdf` and uploaded at the
seeded keys. PDF renders natively in iOS Quick Look and Android viewers; `.docx`
depends on the reader having Word or Docs installed. This also means the seeded
`fileObjectKey`s need no change.

### R-39 — Search keeps recent searches (closes B-6)
*Ruled by the product owner: "for search keep the capability".*

Both ship: "Popular this week" as the canvas draws it, backed by the real trending
endpoint, **and** the locally-saved recent searches beneath it. The artboard
omitting a convenience is not evidence it should be removed.

### R-40 — D-9, in plain words (closes the R-4 amendment)
*Ruled by the product owner.*

> "I don't even know what that means but all I want is the good new reasonable
> design without losing key things — hence the decisions MD"

That is the amendment, stated better than the original wording managed. Recorded
as the governing principle:

**Take the new design. Do not lose anything that works. Where the canvas asserts
a fact the system does not have — a fee, a rate, a hold period, a document count,
a guarantee — the system wins and the gap gets written down.**

Every ruling in this file has been an instance of it. It needed no separate
decision; it needed a name.

### R-41 — Real-time over WebSocket, not polling
*Ruled by the product owner, 2026-08-27.*

Five surfaces push instead of being polled:

| surface | why it matters |
|---|---|
| **Live prices / quotes** | asset prices, movers, portfolio value. The simulator already drifts prices on a timer — this pushes what it already computes. |
| **Order book depth** | derived from the same price drift, so it changes exactly when the price does. Rides the price stream at almost no extra cost. |
| **Order status and fills** | the moment an investor most wants immediate feedback. Today they must leave and re-enter the screen. |
| **Wallet balance / deposits landing** | a virtual-account transfer arrives asynchronously; today there is no way to know except refreshing repeatedly. |
| **Notifications and KYC status** | a KYC decision updates the gate immediately rather than on next app launch. |

**Transport:** socket.io — NestJS's default gateway, with a mature Flutter client
that handles reconnection and backoff. Not a product decision; recorded so nobody
relitigates it.

**Non-negotiables:**

- The socket authenticates with the **same JWT** as the REST API. An
  unauthenticated socket that streams another investor's fills is a data breach,
  not a bug.
- A client subscribes only to **its own** account channels, plus public market
  data. Server-side enforced, never client-asserted.
- **Push is an optimisation, never the only path.** Every surface keeps working if
  the socket is down — reconnect, refetch, and carry on. A screen that renders
  only on a socket event shows nothing on a flaky Nigerian mobile connection,
  which is most of them.
- The stream carries **the same shapes the REST endpoints return.** A second
  serialisation of the same entity is two truths that drift — the forked-widget
  problem in a new place.

---

## The recurring structural defect: work that nobody owns

*Recorded 2026-08-28, after the fourth instance.*

Four times in this redesign, a decision was correctly made, correctly recorded,
and then simply did not happen — while every individual agent reported done, and
every gate stayed green.

| # | what | why it stalled |
|---|---|---|
| 1 | **R-1a** — move suitability before the legal documents | needs a router change; screen agents are fenced out of `lib/router/**`, so no pass owned *flow*. Survived four waves. |
| 2 | **R-9, R-16, R-6, R-8** — drop or park five screens | waves are organised around *building*; nothing owned *deletion*. |
| 3 | **R-41** — replace polling with push | push landed, polls stayed. Nobody owned *removing what the new thing replaced*. Found by the live gate. |
| 4 | **S-2** — the sign-up phone field | disabled pending backend support, marked "blocked on backend". BR-3 delivered it. Nobody owned *re-checking a cleared blocker*. **Found by a user, not by us.** |

Each was a different shape of the same hole: **a task with no pass that owns it is
a task that does not happen**, and its absence is invisible because everyone
working on something else is legitimately finished.

This is the identical failure that started this work — 12 unresolved `stubs.json`
entries and 19 open align-tasks that a pipeline reported "done" over. Writing the
decision down was never the missing piece. Someone owning its execution was.

### What actually closes it

1. **Every ruling names its executing pass at the moment it is made** — screen
   wave, removals pass, flow pass, serial shared-change pass. A ruling with no
   named pass is not a ruling, it is a wish.
2. **A blocked item names the fact that unblocks it**, not just "blocked". S-2
   should have read *"blocked until `AuthRepository.signUp` accepts `phone`"* —
   a condition that can be checked mechanically rather than remembered.
3. **The live gate asserts capability, not just the absence of errors.** Instance
   4 is the sharpest lesson: the app authenticated, every surface loaded, no error
   view appeared, the gate passed — and a sign-up field was dead. *"Nothing
   crashed"* and *"the user can do the thing"* are different claims, and only the
   second one matters. Every gate assertion should be phrased as a capability the
   user has, not a failure that is absent.

Instance 3 was caught by the live gate. Instance 4 reached a human first. The
difference between those two outcomes is the whole value of the gate — and point
3 above is what would have moved instance 4 into the first column.

### R-42 — No identity field is investor-editable, email included
*Ruled by the product owner, 2026-08-29.*

An investor cannot change their **name**, **phone number**, **residential
address**, or **email**. Nothing on Personal details (`s58`) is editable.

`s58` draws edit affordances on these rows. **This ruling outranks the canvas**
— the artboard shows the screen as originally conceived, and the product
decision moved. Do not "restore" them.

Why, so nobody re-derives it wrongly:

- Name, phone and address are **KYC-bound**. Phone is this system's identity
  canon in E.164 form. An investor changing the phone or address their approved
  KYC submission was checked against silently breaks the tie between the account
  and the identity that was verified.
- Email is the **login credential and the password-reset destination**. Changing
  it without verifying the new address first would trade a locked-field problem
  for an account-takeover one. There is deliberately no email-change flow; if one
  is ever wanted it needs OTP verification of the new address, not a re-enabled
  button.

Enforced in two places, and both are required — a removed button is not a removed
capability:

1. **Client:** the `Change` affordance is gone from every row on
   `personal_info_screen.dart`, including email. A control whose only possible
   outcome is a refusal is a dead control.
2. **Server:** `firstName`/`middleName`/`lastName`/`phone` are removed from
   `UpdateMeDto` entirely, so `PATCH /users/me` rejects them with a 400 naming
   the field. `residentialAddress`/`city`/`state` stay writable **until
   `kycStatus === 'approved'`** and are frozen after — the KYC utility-bill step
   is a real pre-approval writer of them, and rejecting it outright would break
   verification for every new investor.

**Known gap, deliberately open:** there is no staff correction path for these
fields either. A name misspelled at signup cannot currently be fixed by anyone.
That needs its own staff-role endpoint — not a reopening of the investor one.

### R-43 — Password policy: 8 characters, one number, one special character
*Ruled by the product owner, 2026-08-29. Overrides the canvas.*

Sign-up's password checklist shows exactly two lines:

    At least 8 characters
    One number and one special character

The capital-letter requirement is dropped. The advisory line **"Not a password
you use elsewhere" is removed** — nothing could ever verify it, and it rendered
permanently unticked beside two rules that do tick, which teaches the investor
that the checklist is decorative.

**This overrides `s03p`/`s03pd`**, which draw "At least 10 characters", "One
capital letter and one number" and the advisory line. The built screen previously
matched the canvas correctly; this is a product decision that moved, not a
conformance defect. Do not "restore" the canvas wording.

**The rule must be enforced on the server, not only shown on the client.** Before
this ruling the backend's only constraint was `@MinLength(8)` on
`SignupDto.password` — no complexity check anywhere — so the client checklist was
decorative: a direct `POST /auth/signup` with `12345678` succeeded. A rule the
API does not enforce is not a rule, it is a suggestion rendered in a tick-box.

The policy lives in **one** place that every password entry point uses — sign-up,
password reset, and staff invite acceptance. A policy enforced at sign-up but not
at reset is one an attacker walks around by resetting.

### R-44 — The avatar picker belongs to onboarding, and is optional
*Ruled by the product owner, 2026-08-29.*

An investor is offered an avatar **during onboarding**. Not during KYC, and not
from `kyc_intro`. Owner's words: *"avatar should never be on KYC — onboarding."*

Choosing one is **optional**. Whoever skips it gets their name rendered as text
wherever an avatar would appear — that was the original instruction when the
screen was added on 2026-08-24, and it still holds. The screen offers a choice;
it does not gate Home.

**Why this ruling exists at all:** the screen was built, given artboard `s06b` /
`s06bd`, registered in the router — and then silently stranded. Its entry point
was `kyc_intro.dart`'s `_start()`, which was later rewritten to route straight to
`Routes.kycChecklist` / `Routes.kycBvn`. Nothing navigated to the avatar screen
after that. It was never cut, never ruled out, never mentioned; it just stopped
being reachable, and its own header comment went on describing the dead entry
point as if it were live.

The product owner found it by noticing it was gone. That is the failure mode
this file exists to prevent, so the rule is written down rather than left to
whoever next reads the flow:

**A screen losing its entry point is not the same as a screen being cut.** Any
pass that removes or rewrites a navigation call must account for every
destination that call was the only route to — and a destination left with no
callers is reported, never silently accepted. `personal_details_screen.dart` was
stranded by the same rewrite and is still open at the time of this ruling.

### R-45 — Steps completed in a PREVIOUS session are disconnected
*Ruled by the product owner, 2026-08-29. Amended the same day — see below.*

The distinguishing fact is **when** a step was completed, not merely whether it
is done.

- **Within one continuous run, back works normally.** An investor who has just
  uploaded an ID and is now on liveness can press back and return to it. That is
  how someone corrects a mistake they just made, and it must keep working.
- **After an app restart, the steps that were already complete when the app
  opened are disconnected.** Back does not walk into them and the hub does not
  route to them. That is finished work from a previous session, not part of the
  run in progress. Owner's words: *"the draft screens should be properly
  disconnected... they can go back but on restart they shouldn't be able to do
  so — on the flow they can go back."*

**Amendment note, kept deliberately:** this ruling was first written as "a
completed step is always terminal", which would have blocked an investor from
stepping back to fix an upload they had made sixty seconds earlier. The owner
corrected it before it was built. Recorded rather than silently rewritten,
because the over-strict version is the one an agent will re-derive from the
phrase "properly disconnected" if the reasoning is not here.

Implementation: on entering the flow, snapshot which steps the draft already
shows complete — that snapshot is the locked set for this run, held **in memory
only**. A restart re-derives it from the draft, which is exactly the wanted
behaviour with nothing to persist; persisting it would defeat the rule, since a
restart is the event that should clear the session's own progress from it.

- **Back** from a locked step returns to `Routes.kycChecklist`. Back from a step
  completed during this run goes to the previous step, as normal. The gated flow
  navigates with `context.go()` and so has no back stack at all — which is why
  this is derived from state rather than from history.
- **The hub** routes to outstanding steps and to steps completed during this
  run. A locked step renders as complete and carries no tap target at all — not
  a disabled one, because a control that does nothing is worse than an absent
  one.

**This ruling depends entirely on the completion derivation being correct**, and
at the time it was made it was not. `kyc_checklist_screen.dart` inferred
completion from the backend's `currentStep` — the stale 5-step phased counter
that has not matched the real 7-step flow since 2026-08-24, and the same figure
behind the "4/5" defect reported three times. Documents required `cs >= 5` while
the selfie required `cs >= 4`, so uploading documents never marked them done, and
the investor was returned to document upload forever. Completion now comes from
the draft's real `documents` list, which the backend has always sent.

Getting that order wrong inverts the ruling: applied on top of a wrong
derivation, this locks an investor out of a step they still need — worse than the
bug it fixes.

**Known cost, deliberately accepted:** an investor who uploads the wrong document
and then restarts the app cannot replace it themselves. In-session they can. The backend has a `resubmission` value in
`KycSubmissionDocumentType`, so a path may exist; if it does not, it is filed in
`BACKEND_GAPS.md` rather than solved by quietly re-opening completed steps.

### R-46 — NGX closes at 16:30 WAT, not 14:30
*Ruled by the product owner, 2026-08-29: "NGX CLOSES 16:30 NOT 14".*

The session is **10:00–16:30 WAT, Monday to Friday**. The code had 14:30 and had
been shutting the market two hours early — in the mobile client
(`isNgxOpenNow()`), in the backend (`computeAutoOpen`), and in the copy on
`price_moved_screen.dart` that told an investor their order was held "until
14:30 today".

**The interesting part is which source was right.** `markets_screen.dart` carried
`const _ngxCloseTime = '4:30pm'`, copied from artboard `s24`, sitting beside a
computed open/closed state that used 14:30. The two disagreed, so the header
could read "Open till 4:30pm" while the app believed the market had closed at
half past two.

Confronted with a hardcoded label next to a computed time, the first fix went the
**wrong way** — the label looked like the copied-from-a-mockup error and the
computation looked authoritative, so the label was changed to match the code. It
was the other way round: the canvas was right and the arithmetic was wrong. The
owner caught it immediately.

Recorded because the general lesson is not the one this project keeps repeating.
The usual failure is trusting a design over a fact. This was the opposite:
**a number in code is not evidence merely because it is in code.** A computation
is as capable of being wrong as a string, and it is more persuasive while being
so. Where a label and a computation disagree, the answer is to find out which is
true — not to assume the executable one is.

There is now **one** definition, `kNgxOpenMinutes`/`kNgxCloseMinutes` in
`market_hours.dart`, and every user-visible label derives from it, so a label can
no longer drift from the state it sits beside. The backend has a matching test
covering both boundaries, 15:00 (which the old close wrongly excluded), and the
21:35 case the owner reported. There was no test at all before, which is how it
survived.

**Separately:** the live database has `MarketStatusOverride` set to
`forced_open` (2026-08-24). That is a deliberate pre-launch staff switch so
document, statement and receipt flows can be exercised outside a short real
session — but it means the app reports the market open at any hour, and it is
still on.

### R-47 — The Account ("You") screen keeps a back button
*Ruled by the product owner, 2026-08-29: "add the back button".*

`s51` draws "You" with no back affordance, and the screen briefly matched it
after the 2026-08-29 conformance pass. That match was wrong, and this ruling
restores the control.

**The artboard is not mistaken — it is answering a different question.** It draws
Account as a **tab destination**, where a back arrow would mean nothing. R-28
then took Account off the tab bar and made it a screen pushed from Home's header
avatar. A pushed screen with no visible way out leaves edge-swipe and the
hardware key as the only exits: invisible to anyone who does not already know
them, and on a gesture-navigation Android the swipe competes with the system's
own back gesture.

The title keeps s51's treatment — 26px/800, left-aligned, under the status bar,
not the centred `KDetailHeader` used by true detail screens — and gains the same
circular back control those screens use, so it reads as the same app.

**Why this is worth writing down rather than just fixing:** the comment removed
by this change argued, correctly on its own terms, that R-28 "only rules HOW this
screen is reached, not what its own header renders". That is true and it still
led to the wrong answer, because how a screen is reached is exactly what decides
whether it needs a way back. An artboard drawn for one navigation model does not
transfer unchanged to another — the same trap as R-44's orphaned avatar screen,
where a flow rewrite silently stranded a destination.
