# Factual conflicts between the new canvas and the system

Per ruling D-9: every place the canvas asserts a **fact** — a fee, a rate, a
timing, a document count, a counterparty — that the running system contradicts.
Ruled one at a time by the product owner. **No agent may transcribe any figure
below into code until its row has a ruling.**

Design authority (R-4) covers structure, layout, copy tone, flow and interaction.
It was never meant to cover numbers that make a commercial or legal statement to
a customer, and these are those numbers.

Sources: canvas at `docs/design/redesign-2026-08/`; rate card at
`Kudimata-Securities-Backend/src/orders/fees.ts` (its own header calls itself
"THE SINGLE SOURCE OF TRUTH").

---

## C-1 — Trading fees: the canvas is ~4× cheaper than the backend charges

**This is the most serious row in this file. It is on the money path of a
licensed broker.**

Backend rate card (`fees.ts`): commission **0.90%** + NGX·SEC·CSCS **0.45%**,
plus **7.5% VAT** on those — an effective **1.4512%** of consideration.

The new canvas draws:

| artboard screen | consideration | canvas fee | canvas rate | backend fee | investor is out by |
|---|---:|---:|---:|---:|---:|
| Buy · limit review | ₦24,906.50 | ₦93.50 | 0.375% | ₦361.46 | ₦267.96 |
| Buy · executed receipt | ₦24,933.75 | ₦93.50 | 0.375% | ₦361.85 | ₦268.35 |
| Sell · limit review | ₦87,780.00 | ₦316.70 | 0.361% | ₦1,273.91 | ₦957.21 |
| Sell · market review | ₦85,880.00 | ₦309.80 | 0.361% | ₦1,246.33 | ₦936.53 |

On the sell screens the canvas tells the investor they will **receive ₦957 more
than the backend will actually pay them.**

**Neither figure is verified.** `fees.ts` says so itself:

> `!! BEFORE GO-LIVE !!  These rates are design-derived, NOT confirmed against a
> published NGX/SEC/CSCS schedule or against whatever commission Kudimata has
> actually agreed with Blue Marina Securities.`

So the backend's 1.45% was back-derived from the **old** canvas's contract note
(old screen 66), and the **new** canvas disagrees with the old one by roughly
four times. This is not a design question and not an engineering question — the
business and compliance own it.

**Ruling needed:** which rate card is real? Then `fees.ts` is the one place it
changes, and every screen renders from the backend rather than from a drawn
figure.

- [ ] ruling:

---

## C-2 — "Stamp duty" is a fee category that does not exist

The canvas's sell screens say **"Fees and stamp duty"**. The word `stamp` appears
nowhere in the backend or the app, and `fees.ts` has no such component — its
breakdown is commission / exchange fees / VAT.

Either stamp duty is a real charge missing from the rate card (a compliance gap
on live trades), or it is copy that should not appear on a review screen.

- [ ] ruling:

---

## C-3 — Add money: bank transfer is drawn as priced, and is actually free

| | canvas | system |
|---|---|---|
| bank transfer | **"₦100 to ₦150 · same day"** | **Free** — a dedicated virtual account; no deposit fee constant exists anywhere in the backend |
| debit card | **"Flutterwave · ₦28 fee, instant"** | no card fee constant exists in the backend |

Charging for deposits would be a new commercial policy, not a redesign. Showing a
fee that is not collected is the mirror-image defect: it deters funding for no
reason.

- [ ] ruling:

---

## C-4 — Legal documents: 8 named policies vs 4 implemented

The canvas's legal list names 8 documents; the app implements 4
(terms of service, privacy policy, risk disclosure, client agreement).

A document listed but not present is a broken link in a regulated disclosure
flow. Either the other 4 exist and must be seeded, or the canvas list is
aspirational and must be trimmed.

- [ ] ruling:

---

## C-5 — Withdrawal timing wording

Canvas: **"Withdrawal fee Free · Money arrives Within 1 working day"**.
The app states within 1 business day and charges nothing — **these agree.**
Listed only so the row is closed rather than silently assumed.

- [x] no conflict — canvas matches the system.

---

## C-6 — Data retention: 6 years (canvas) vs 12 years (app)

*Filed by the `06 Account and Support` screen agent, 2026-08-27.*

`s57` ("57 · Data and privacy") draws: **"We must keep your trade records for
six years, even after you close the account."**

`data_privacy_screen.dart`'s existing "How long we keep things" row, and
`legal_reference_screens.dart`'s data-notice content (several places,
independently), all say **12 years**, each explicitly citing the SEC as the
source. The 12-year figure is the more corroborated one — it appears
consistently across real, already-shipped legal copy, not just one drawn
line — but neither side has been checked against an actual SEC rule/reg by
this pass.

**Not resolved here.** `data_privacy_screen.dart` keeps the existing
"12 years" wording (in both the body row and the new pinned footer) rather
than transcribing the canvas's "six years" — per R-7, a genuine numeric
conflict on a compliance-facing screen is filed, not silently picked by an
agent.

- [x] **RULED 2026-08-27 — keep 12 years; verify against the actual SEC rule
  before go-live.** Twelve is the more corroborated figure: it appears
  consistently across already-shipped legal copy, each instance citing the SEC,
  while six appears once in a drawing. But *neither* has been checked against a
  published SEC regulation, so this is a decision to keep the status quo, not a
  confirmation that the status quo is right. A retention period stated to users
  on a data-privacy screen is a compliance commitment — it needs counsel, not a
  designer or an agent.

---

## Resolved without a ruling

Two things flagged during evidence-gathering turned out to be **correct in the
canvas**, and are recorded here so nobody re-raises them:

- **"Executed by Blue Marina Securities Limited"** — real. Blue Marina Securities
  Limited is the sponsoring broker named in the signed Client Agreement
  (`orders.service.ts:93`, `statement-generator.service.ts:30`). The canvas
  branding is accurate.
- **T+3 settlement ("Shares settle Thu 28 Aug", "money reaches you in 3 working
  days")** — matches the backend's T+3 business-day convention
  (`fees.ts:92`, `contract-note-pdf.service.ts:218`). Accurate.

---

## RULINGS — 2026-08-26

| id | ruling | consequence |
|---|---|---|
| **C-1** | **The canvas rate is the new intended pricing.** Fees drop to roughly 0.37%. | `fees.ts` is rewritten. **BLOCKED** — see the open question below; the canvas figures do not decompose into a rate card. |
| **C-2** | **Stamp duty is a real charge missing from the rate card.** | Added to `fees.ts` as a fourth component; filed as a backend gap. **BLOCKED** — no rate supplied. |
| **C-3** | **Introduce the deposit fees as drawn.** Bank transfer ₦100–₦150, card ₦28. | New backend work: fee constants, collection, disclosure, and an in-app fee-change notice to existing users (required by your own client agreement). **BLOCKED** — see open question. |
| **C-4** | **Four documents, opened in the phone's file viewer.** The canvas's other four are not to be created. | See R-8. Not blocked. |

### ⚠️ Concern on C-1, stated once and then set aside

`fees.ts` records the broker commission payable to Blue Marina Securities as
**0.90% of consideration**. The new customer-facing rate is **~0.37% all-in**.

If both figures are right, Kudimata pays the sponsoring broker roughly two and a
half times what it collects from the investor — **a loss on every trade, growing
with volume.**

The saving grace is that the 0.90% is *also* unverified: `fees.ts` says the whole
rate card was back-derived from the old canvas and never checked against the
actual Blue Marina agreement. So the honest position is not "this pricing is
wrong" but **"customer pricing is being set without knowing the cost of goods."**

This is the business's call and it has been made. It is recorded here so it is a
decision rather than an accident, and so that whoever signs off the rate card
sees the commission question at the same time.

### PROVISIONAL rate card — ruled 2026-08-26

Back-derived from the canvas, as ruled. **Every number below is PROVISIONAL and
must not reach production unconfirmed.**

| item | provisional value | derivation |
|---|---|---|
| buy, all-in | **0.375%** of consideration | ₦93.50 on ₦24,933.75 — exact |
| sell, all-in | **0.361%** of consideration | ₦316.70 on ₦87,780 and ₦309.80 on ₦85,880 — consistent |
| component split | **none** | the canvas shows a single "Fees" line; stamp duty is folded in, no separate VAT |
| bank transfer deposit | **₦100 flat** | canvas shows a ₦100–₦150 range with no stated rule; flat low end taken |
| card deposit | **Flutterwave pass-through** | the canvas's ₦28 is ruled wrong; the real provider rate is read live rather than hardcoded |

Two consequences that are **not** provisional:

1. **`fees.ts` is the only place any of this lives**, and screens render what the
   backend computes. No client-side fee constant, ever — that is precisely how
   the app once showed "Fees · 1.35%" while the backend charged nothing.
2. **A gate fails the build if this ships unconfirmed.** The provisional marker is
   not a comment somebody might notice; it is an exit code. Otherwise "confirm
   before go-live" becomes exactly the kind of prose that this whole exercise
   exists to stop trusting.

### 🚧 Still open — asset and content gaps (not blocking screen work)

**The canvas figures do not decompose into a rate card.** Working backwards:

- buy implies **0.375%** of consideration (₦93.50 on ₦24,933.75 — exact)
- sell implies **0.361%** (₦316.70 on ₦87,780.00 and ₦309.80 on ₦85,880.00 — consistent)

Two different rates, and neither separates commission from exchange fees, stamp
duty or VAT. A rate card cannot be written from these, and a screen must never
render a fee it computed from a drawn example.

Required to unblock: the buy rate and the sell rate, each broken into **broker
commission %, NGX·SEC·CSCS %, stamp duty %**, and whether **VAT at 7.5%** applies
on top. Same for deposits: is bank transfer a flat fee or the ₦100–₦150 range the
canvas shows (and what varies it), and is the card fee a flat ₦28 or a pass-through
of what Flutterwave actually charges?

---

## Standing rule this file establishes

Once C-1 is ruled, **no screen renders a fee it computed itself.** Every fee,
total and proceeds figure comes from the backend's calculation over the wire, so
there is exactly one place the rate lives and no screen can drift from it.

The app has been here before: `fees.ts`'s header records that the mobile app once
displayed "Fees · 1.35%" on every review screen **while the backend charged
nothing at all** — the investor was quoted a total the platform never collected.
A client-side fee constant is how that happens. There should not be one.
