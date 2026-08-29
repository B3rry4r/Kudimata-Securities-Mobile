# Conformance audit — markets / portfolio / trade / wallet / suitability / corporate_actions / shared

Independent pass. Did not build any of these screens. Method: pulled each artboard's
raw text out of the `.dc.html` source (`docs/design/redesign-2026-08/*.dc.html`),
opened the corresponding light **and** dark PNGs in `build/shots/`, and compared
element-by-element. Where a code comment explained a difference, I read it and
checked it against `docs/redesign/DECISIONS.md` / `BACKEND_GAPS.md` before calling
anything a defect — several "differences" turned out to be documented, filed
decisions, not oversights.

## Summary

- **Screens/flows in scope with a render to audit: 17** — all opened in light and
  dark, compared against their artboard text or (where no artboard exists) judged
  for internal consistency.
- **Screens/flows in scope with NO render anywhere in `build/shots/`: 6**,
  covering roughly 34 artboards. These were **not silently skipped** — see
  "Could not audit" below. This is itself the largest finding in this report.
- **Defects: 2**
- **Divergences-with-reason (cite a ruling or a filed gap): 9**
- **Unclear (needs the owner, cannot be settled from a render): 3**

### The five worst things found

1. **The entire buy/sell trading flow and the entire add-money/withdraw flow have
   never been screenshotted, let alone verified.** `lib/screens/trade/trade_flows.dart`
   and `lib/screens/wallet/wallet_flows.dart` implement ~34 artboards
   (`04 Buy and Sell.dc.html`'s s29/s29c/s29m/s30/s31/s42/s43/s43b/s43m/s44/s45/s46/
   s46m/s47/s48/s48m, plus `05 Portfolio and Wallet.dc.html`'s s36/s37) and carry the
   app's only revenue-generating action — and zero evidence exists that anyone,
   agent or human, has ever looked at a picture of them next to their artboards.
   Not a rendering bug: the harness only shoots routed screens, and these are
   modal bottom sheets (`showBuyFlow`/`showSellFlow`/`showAddMoneyFlow`/
   `showWithdrawFlow`). Already known (`DECISIONS.md` B-3) and still unfixed.
2. **Asset detail's designed fact card was never built; the app substitutes its
   own, un-ruled.** `s26`/`s27` draw a plain three-cell "From ₦5,000 / Paid out
   3 days / Dividend 5.9%" row plus a green "Easy to sell" liquidity banner. The
   live screen shows neither — it shows a pre-existing "Risk / Fees / Liquidity /
   Minimum" card and separate "Dividend yield"/"You own" tiles instead. The
   building agent's own comment says this was a unilateral call ("kept rather
   than silently dropped... reported in this pass's summary") and
   `docs/redesign/evidence/markets-home.json` flagged it as needing a human
   decision — but no ruling in `DECISIONS.md` ever answered it. `R-18` rules only
   on the Order Book tab, not this. File: `lib/screens/markets/asset_detail_screen.dart`.
3. **Risk disclaimer's rendered body reads as placeholder copy, not Rule 76
   legal text**, and this is a statutory compliance screen. Cannot be resolved
   from a render — see "Unclear" below.
4. Buy/Sell button order is swapped from the artboard on asset detail (artboard:
   Buy left/filled, Sell right/outlined; app: Sell left, Buy right) with no
   comment explaining why, unlike every other divergence on that file. File:
   `lib/screens/markets/asset_detail_screen.dart` (~lines 398–417).
5. A second, undesigned icon (a notification bell) sits in the asset-detail
   header next to the one icon the artboard actually draws there (the watchlist
   plus/check). Not clearly wrong, not clearly right — flagged as unclear.

---

## Could not audit — no render exists

Per the brief: reporting these as "clean" would be the exact failure this audit
exists to correct, so they are listed as unaudited, not passed.

| file | what it owns | artboards it should be checked against | why it has no render |
|---|---|---|---|
| `lib/screens/trade/trade_flows.dart` (`showBuyFlow`) | Buy flow: order-type choice, price entry, share count, review, PIN, placed | s42/s42d, s43/s43d, s43b/s43bd, s29/s29d, s29c/s29cd, s43m/s43md, s29m/s29md, s30/s30d, s31/s31d, s44/s44d | Modal bottom sheet, not a route. `test/shots_all.dart` / the shot harness only captures routed screens (`DECISIONS.md` B-3, still open). |
| `lib/screens/trade/trade_flows.dart` (`showSellFlow`) | Sell flow: same shape, sell side | s45/s45d, s46/s46d, s46m/s46md, s47/s47d, s48/s48d, s48m/s48md | Same as above. |
| `lib/screens/wallet/wallet_flows.dart` (`showAddMoneyFlow`) | Add-money chooser + bank-transfer sheet | s36/s36d | Modal bottom sheet, no route. |
| `lib/screens/wallet/wallet_flows.dart` (`showWithdrawFlow`, incl. outside-hours variant) | Withdraw flow, normal and queued | s37/s37d, s30/s30d (shared PIN) | Modal bottom sheet, no route. |
| `lib/screens/shared/confirm_passcode_sheet.dart` | Passcode confirm sheet reused for the per-order PIN (R-31) | s08 (pattern match only, per `RULINGS.md`) | Sheet, only reachable mid-trade-flow, which itself has no render. |
| `lib/screens/shared/glossary_sheet.dart` | "Explain this term" bottom sheet used from the questionnaire, trade flows, FAQ, asset detail | none (confirmed absent from canvas, `RULINGS.md` §glossary_finding) | Sheet, no route; never triggered by the harness's default-state captures (B-3). |

`corporate_actions_widgets.dart` and `market_hours.dart` are pure helper files
(no-action per `RULINGS.md`) and need no separate audit — their fate is covered
by the screens that use them, audited below.

---

## Screen-by-screen

### Markets tab — `markets/markets_screen.dart` → **s24**
**Verdict: divergence-with-reason only, otherwise a strong match.**

| artboard element | render shows | file | severity |
|---|---|---|---|
| "Green day / 32 up · 14 down · NGX All-Share +1.4%" | "Green day / 3 up · 1 down" — index clause omitted | `markets_screen.dart` | divergence-with-reason — **R-34**, no index feed exists; up/down counts are real |
| Sector chips: All / Banking / Telecoms / Consumer / Oil & gas | All / Banking / Industrial Goods / Telecoms | `markets_screen.dart` | divergence-with-reason — real backend sector taxonomy replacing the artboard's illustrative examples, not invented data |
| Everything else (header, search, mood card colour/copy, gainer cards, All companies list, four-tab nav) | matches | — | none |

Market-closed substate (`markets__market_closed`) adds an honest "The market is
closed / Opens Monday at 10:00 · prices below are Friday's close" banner not
drawn by any artboard — real state coverage per R-30, not a defect.

### Corporate actions hub — `corporate_actions/corporate_actions_screen.dart` → **s55**
**Verdict: good match.**

| artboard element | render shows | severity |
|---|---|---|
| One featured, fully-expanded pending-decision card (rights issue, with cost/close-date/Take-up/Skip inline) | Two pending items surfaced: AGM (full "Vote now" CTA) + rights issue (compact "NEEDS YOU" row, detail behind a tap) | none — reasonable handling of two simultaneous real decisions vs. the artboard's single illustrative one |
| "Recent" list: dividend + AGM-already-voted | "Recent": MTNN dividend only | none — real data has only one settled item |
| Dividend row: "paid to your bank" (artboard's illustrative copy) | "MTNN dividend +₦4,120.00 to your wallet" | note only — consistent with the dividends detail screen's own "Credited to your Kudimata wallet"; looks like real DCS behaviour, not a bug |
| Footer e-mandate note | matches | none |

### Portfolio tab — `portfolio/portfolio_screen.dart` → **s33**
**Verdict: strong match, no defects.** "What you own", value, all-time pill,
company-count pill, "Where your money sits" **bar** allocation (R-22 adopted
correctly, sector-based not asset-class donut), "Your companies" list, "Is my
portfolio healthy?" card, four-tab nav — all present, in order, matching copy.
Empty/loading/error substates use the shared, restyled `state_views.dart`
illustrations consistently (R-30).

### Holding detail — `portfolio/holding_detail_screen.dart` → **s34**
**Verdict: strong match.** Hero value + gain, Shares/Average price/Price now
rows match; **Dividends received** and **Held in (CSCS/CHN)** rows are the R-23
authorised extras and are present; the per-trade **status pill** ("FILLING") is
present, confirming **B-1's restoration** actually shipped. Buy more/Sell footer
matches. No defects.

### Wallet tab — `wallet/wallet_screens.dart#wallet_home` → **s35**
**Verdict: strong match.** Cash available, subtitle copy verbatim ("Ready to
invest now. Held with our custodian, never lent out."), Add money/Withdraw
buttons, "Money in and out" list. The artboard's trailing link literally reads
"All"; the app deliberately renders "Orders" instead — documented in-code as an
intentional, more-honest relabel (the link goes to the buy/sell-only Orders
screen, not a superset of all money movement) — divergence-with-reason, not a
miss.

### Transaction detail (receipt) — `wallet/wallet_screens.dart#transaction_detail` → **s38**
**Verdict: divergence-with-reason, correctly filed.** Artboard draws a
"Fees, all in ₦93.50" row for a completed buy; the rendered receipt (a bank
deposit) shows no Fee row at all. Confirmed via code comment: the `Txn` model
has no fee field, so per **R-34** the row is omitted rather than invented, and
it is filed in `BACKEND_GAPS.md` (s38 entry). One thing worth re-checking:
**R-37 already gives the backend a real per-deposit `feeKobo`** (surfaced at
deposit time via `FundResult`/`VirtualAccountDetails` in
`wallet_repository.dart`) — but that figure is never carried onto the
persisted `Txn`, so even a post-R-37 deposit's permanent receipt can never show
what fee was actually charged. Worth updating the existing BACKEND_GAPS.md entry
to note the fee is already known at deposit time and just isn't threaded
through.

### Asset detail — `markets/asset_detail_screen.dart` → **s26 (About) / s27 (Order book)**
**Verdict: defect.** See summary items #2, #4, #5 above. Full comparison:

| artboard element (s26) | render shows | severity |
|---|---|---|
| Header: back, ticker+company name, one plus/watchlist icon | back, ticker + "MTNN · NGX · TELECOMS" subtitle, **plus a bell icon** the artboard doesn't draw | unclear — possibly a shortcut into price alerts; not in spec |
| Hero price + LineChart (no visible range-selector UI in the artboard) | hero price + LineChart **plus** a 1D/1W/1M/1Y/ALL pill row | unclear — reasonable added affordance, but not designed |
| Three-cell "From ₦5,000 / Paid out 3 days / Dividend 5.9%" fact row | **Not built at all.** Replaced by a "Risk: High / Fees: 1.35% all-in / Liquidity: Daily·T+3 / Minimum: ₦5,000" card plus separate "Dividend yield —"/"You own 120 shares" tiles | **defect** — self-authorized substitution, never ruled (see summary #2) |
| Green "Easy to sell. Plenty of buyers and sellers today." liquidity banner | absent (both tabs) | divergence-with-reason — documented in-code: `SimulatedNgxBroker` computes no liquidity tier, filed as a gap, but genuinely a piece of the design that's simply missing |
| About paragraph + "More about MTNN" link | About paragraph present (different, real, per-asset copy), no "More about" link | none — cosmetic, real data |
| Buy (left, filled) / Sell (right, outlined) | **Sell (left) / Buy (right)** | **defect** — order swapped, unexplained (summary #4) |
| Order book tab (s27): liquidity warning + bid/ask depth table | Tab present; MTNN's order book render shows "Depth unavailable" | not a live defect — code confirms this is wired to a real (simulated) `GET /assets/:ticker/order-book` per R-35/BR-5; the empty state in the captured screenshot reflects the render harness's fixture, not production behaviour |

### Set a price alert / My alerts — `markets/price_alerts_screen.dart` → **s49 / s50**
**Verdict: divergence-with-reason, all gaps genuinely filed.**

| artboard element | render shows | severity |
|---|---|---|
| s49: "Rises above / Falls below" direction toggle | Toggle absent, single "reaches" field only | divergence-with-reason — backend `CreatePriceAlertRequest` has no direction field; building a toggle that silently always meant "rises above" was correctly rejected. Filed in `BACKEND_GAPS.md`. |
| s49: "Min ₦0.05 / Max ₦250.00" band + "That's X% below today's price" | absent | divergence-with-reason — no tick-size/price-limit field exists anywhere on `Asset`; R-34-style omission |
| s50: a triggered alert card at the top ("GTCO fell below ₦46.00...") | every alert renders "Waiting" | divergence-with-reason — no scheduler wired server-side (`PriceAlertsService#checkAndNotify` unregistered) and `lastTriggeredAt` isn't on the wire shape; genuinely can't be anything but "Waiting" today |
| — | one rendered alert reads "MTNN moves ±5% in a day" — the OLD percent-move alert type, not the new price-target model s49/s50 draw | unclear — looks like leftover fixture data from before the rebuild rather than a live defect, since the new UI can only create price-target alerts now; worth confirming no surface still creates percent alerts |

### Orders — `portfolio/order_status_screen.dart` → **s41**
**Verdict: good match.** Open/Done/Cancelled filter, order card with status pill,
**Cancel** action present (R-17, correctly added beyond the artboard), "What
these mean" explainer copy matches near-verbatim, "Place a new order" CTA
matches. No part-fill progress bar visible, but the one live order isn't
partially filled, so nothing to show. No defects.

### Rights issue detail — `corporate_actions/rights_issue_screen.dart` (no artboard; s55 lists it as a hub item only)
**Verdict: consistent, no defect.** Partial take-up is genuinely implemented
("How many will you take? 24 of 24", "part of the entitlement is fine" helper
text) — correctly honours **R-12**, not the artboard's binary all-or-nothing
model. Entitlement/price/cost/closes fact card, an explainer card, "Take up N
for ₦X" / "Let it lapse" — all present and coherent with the rest of the redesign
system. No artboard to diverge from; judged on consistency only.

### AGM vote — `corporate_actions/agm_vote_screen.dart` (no artboard; s55 lists it as a hub item only)
**Verdict: consistent, no defect.** Five resolutions, each with For/Against/Abstain,
defaulting to For; "We submit your votes as your proxy"; Submit/Email-notice
actions. Matches the hub's own summary ("120 votes on 5 resolutions"). No defect.

### Dividends detail — `corporate_actions/dividends_screen.dart` (no artboard; s55 lists it as a hub item only)
**Verdict: consistent, no defect.** "Paid to you this year" hero, "Unclaimed
from before Kudimata" e-mandate card with a toggle and CTA (matches s55's
footer note), per-dividend history row with "net of 10% WHT", "Withholding tax
statement" link. No defect.

### Suitability questionnaire — `suitability/questionnaire_screen.dart` (no artboard)
**Verdict: matches its own documented shape exactly.** "Question 1 of 4",
"Investment Experience" with the three literal option strings from
`RULINGS.md`'s `suitability_quiz_shape`, step-progress bar, Back/Next question.
No profiling language visible anywhere. No defect.

### Suitability result — `suitability/suitability_result_screen.dart` (no artboard)
**Verdict: compliant with R-2, no defect.** "Assessment complete" / the exact
generic copy `RULINGS.md` records as the current live text ("Thanks — that
helps us keep what you see here suited to you...") — no risk classification,
no "profile," no "only Nigerian shares" language anywhere. Continue / Change an
answer. Matches its own ruling precisely.

### Terms & agreements — `suitability/terms_and_privacy_screen.dart` / `legal_acceptance_screen.dart` (no artboard; backs the R-8/R-8a model)
**Verdict: compliant with R-8a, no defect.** Exactly three documents (Terms of
Service, Privacy Policy, Client Agreement) — risk disclosure correctly excluded
since it now has its own screen. Each row carries a download affordance
consistent with "opens in the phone's native viewer." Single "I have read and
agree to all three" checkbox stays disabled until all three are opened,
matching the scroll/open-gated intent. "Step 2 of 4" label. No defect.

### Risk disclaimer — `suitability/risk_disclaimer_screen.dart` (no artboard; R-8a governs)
**Verdict: unclear — cannot be settled from this render.** Code review confirms
the *mechanism* is right: real scroll-to-bottom gating (`_onScroll`,
`_scrolledToBottom`), checkbox disabled until scrolled, "Accept & Proceed"
disabled until both scrolled and checked, content fetched live from
`GET /legal-documents/content/risk_disclosure` and rendered verbatim per
section — all correctly matches R-8a's requirement. **But** the only section
the render shows is a thin, meta-descriptive paragraph ("A plain-English
summary of the Risk Disclosure document, covering what it means for you as an
investor on Kudimata.") rather than anything reading like actual Rule 76 legal
text (Risk of Capital Loss / Digital Platform Infrastructure Risks / No
Investment Advice / Regulatory Jurisdiction, per the screen's own header
comment on what legal is supposed to author). This may simply be thin test
fixture content standing in for real backend-seeded copy — CLAUDE.md's own
"done" ladder puts real-backend content above anything a mocked render can
prove. **Needs checking against the real backend's seeded `risk_disclosure`
document, not against this screenshot**, before this screen can be called done.

### Explain screen (AI/Gemini) — `markets/explain_screen.dart` (needs-ruling bucket; governed by R-6)
**Verdict: consistent with R-6, no defect.** Screen still renders in full
(credit meter, free-trial progress, "See plans and credits") when reached
directly by route, exactly as R-6 specifies ("screens... stay in the tree...
behind a single flag"). `SHARED-CHANGES.md`'s D-3 entry confirms the entry
points (`account_screen.dart`'s Plans row, `asset_detail_screen.dart`'s
`onExplain` callback, `glossary_sheet.dart`'s "Explain further" button) are
gated off by `kAiCreditsEnabled = false`. The harness reaching this screen by
direct route doesn't indicate it's reachable by a real user; not audited further
since flow-reachability is outside what a render can show.

---

## Everything not listed above in this scope

`shared/state_views.dart` was checked indirectly through the loading/error/empty
substates of portfolio, wallet, price alerts and markets — one shared,
consistently restyled illustration system used everywhere per **R-30**. No
defect.
