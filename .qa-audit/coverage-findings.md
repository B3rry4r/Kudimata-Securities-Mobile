# Coverage inventory — findings (worst-first)

Independent audit. Three sources, verified against source files directly, not against
each other's summaries: route table (`lib/router/app_router.dart`, 76 `GoRoute`
registrations, counted by grep), design canvas (`docs/design/redesign-2026-08/*.dc.html`,
135 artboard ids, counted by my own regex against the raw HTML), and the product's
ruling list (`docs/redesign/RULINGS.md`, 91 screens across 4 buckets, cross-checked
against `docs/redesign/DECISIONS.md`'s R-1…R-41).

---

## 1. RULINGS.md is not actually exhaustive against the route table

RULINGS.md's own text says it "buckets every screen" and totals 91. It does not.
Four live, routed screens have **zero mentions anywhere in the document**, across
all 4 buckets:

- `kyc/kyc_checklist_screen.dart` — `/kyc/checklist`. `app_router.dart`'s own comment
  calls this **"the flow's spine... re-entered after every completed step"** — it is
  not a minor screen, it is the KYC hub every investor returns to after each of the
  8 collection steps. `routes.dart` cites "screen s11", and **s11/s11d exist in the
  current canvas** (verified against the raw `.dc.html`).
- `onboarding/whats_next_screen.dart` — `/onboarding/next-steps`, the "your account
  is ready" checklist every new investor sees. Cites "screen s07" — **exists in canvas**.
- `LegalBundlePreviewScreen` (`/legal-preview`) — a second class living inside
  `onboarding/legal_preview_screen.dart`, alongside `LegalPreviewScreen`, which IS
  ruled (matched to s03c). The bundled-list variant is never separately addressed.
- `SetPriceAlertScreen` (`/asset/:ticker/alert`) — a second class inside
  `markets/price_alerts_screen.dart`, alongside `PriceAlertsScreen`, which IS ruled.
  Cites "screen s49" — **exists in canvas**, never evaluated.

**What a reader of only RULINGS.md would wrongly conclude:** that every screen in the
app has been triaged into keep/cut/needs-ruling. In fact the document's own file-level
granularity silently swallows a second route whenever two screen classes share a
file (2 of the 4 cases above), and it never touched the KYC flow's own hub screen or
the onboarding-completion screen at all — despite artboards existing for both.

---

## 2. The KYC step that actually submits the application has no screenshot

`kyc/next_of_kin.dart` (`/kyc/next-of-kin`) is step 8 of 8 — the **last** collection
step. Its own header notes that "Submit for verification" now calls
`finalizeDraft()` **directly** (R-9: the standalone review-before-submit screen was
dropped specifically because this screen absorbed that responsibility). It has
**zero captures** in `build/shots/`, light or dark. The step immediately before it
(`kyc_declarations`) and immediately after it (`kyc_submitted`) are both fully
captured in both themes — the capture harness walks past this one specific screen.

**What a reader scanning the shot set by KYC step number would wrongly conclude:**
that the whole 8-step onboarding sequence was visually checked, because the sequence
*looks* unbroken from the filenames alone. Nobody has actually looked at the screen
every investor must complete to submit their application.

---

## 3. The everyday withdraw flow has no screenshot; the rare one does

`wallet/wallet_flows.dart`'s normal-hours withdraw sheet (`_WithdrawSheet`, launched
via `showWithdrawFlow()`, matched to artboards s37/s30 in RULINGS.md's
redesign-to-artboard bucket) has **no capture anywhere** in `build/shots/`. Its
sibling — the outside-hours/queued variant (`_OutsideHoursWithdrawSheet`, R-21,
fires roughly 21:00–09:00 weekdays and all weekend) — **is** captured, twice
(`withdraw_outside_hours_pin`, `withdraw_outside_hours_s37variant`). A third,
unrelated screen (`withdraw_mandate`, the DCS-mandate-removal flow) is also captured
and easy to mistake for "withdraw is covered."

**What a reader searching the shot set for "withdraw" would wrongly conclude:** that
the withdraw flow is checked, because two of the three withdraw-adjacent hits are
real captures. The path used during the ~12 hours a day money actually leaves the
app under normal conditions has never been visually checked.

*(By contrast: the buy/sell/add-money side of this same revenue path is thoroughly
captured — `buy_chooser_s42`, `buy_price_s43`, `buy_shares_s43b`, `buy_review_s29`,
`buy_review_now_s29m`, `buy_market_closed_interstitial_s29c`, `buy_pin_s30`,
`buy_pin_wrong_code`, `buy_placed_s31`, and the full sell/add-money mirror set. The
"34 missing buy/sell artboards" defect the task brief describes from a prior pass
appears to already be fixed in this codebase — RULINGS.md's
`trade-wallet · buy_sell_journey` section maps the entire 17-step journey to specific
artboard ids, and the shot set backs it up. Withdraw is the one piece of that same
family that regressed.)*

---

## 4. RULINGS.md's own bucket assignment doesn't track its own evidence text

22 of the 39 rows RULINGS.md buckets as **"needs-ruling"** — defined by the document
itself as *"no artboard covers these"* — carry evidence text in that same row citing
a specific matching artboard id:

- `onboarding/create_passcode_screen.dart`'s evidence: *"New canvas '05 · Create
  passcode' (#s05)... **matches the app screen**"* — yet bucketed as if no artboard existed.
- `onboarding/welcome_slider_screen.dart`'s evidence cites s02 as a structural match.
- `wallet/wallet_screens.dart#transaction_detail`'s evidence: *"found in s38...
  matching the app's own 'Reference' row"* / *"found in s38..."* for fees too.
- 19 more (`portfolio_screen`→s33, `holding_detail_screen`→s34, `order_status_screen`→s41,
  `sign_up_screen`→s03/s03b, `reset_passcode_screen`→s09, `legal_preview_screen`→s03c,
  `utility_bill.dart`→s17, and others) follow the same pattern — see
  `.qa-audit/coverage-inventory.json` rows with `status: "matched"` inside the
  needs-ruling-bucket set.

**What a reader trusting the 39-vs-28 headline split would wrongly conclude:**
that more than half the "needs-ruling" screens are genuinely undesigned. Most of
them have direct textual/structural evidence of a specific artboard; the "ruling"
still needed is almost always about *reshaping* the screen to fit the artboard, or
about a features'-fate decision, not about the artboard's existence — but the
document does not make that distinction visible at the bucket level.

---

## 5. One artboard (s38) is independently claimed by two different receipt screens

`account/contract_note_screen.dart` (redesign-to-artboard, confidence "likely":
*"s38 is the closest new-canvas expression of a post-trade receipt"*) and
`wallet/wallet_screens.dart#transaction_detail` (needs-ruling, evidence: s38 match on
both the Reference row and the fee breakdown) both cite the **same artboard**. One is
marked resolved; the other isn't — off identical evidence. A contract note (per
executed order, naming the executing broker) and a wallet transaction receipt
(any wallet Txn: deposit, withdrawal, fee, dividend) are structurally different
screens with different data models. Nothing in RULINGS.md records whether s38 was
drawn to be one, the other, or genuinely both.

---

## 6. RULINGS.md's build-gate gate was never closed out — DECISIONS.md quietly did it instead

RULINGS.md states: *"Nothing in the build queue starts until the needs-ruling
section is empty."* Its needs-ruling table has an **empty "your ruling" column for
all 39 rows**, dated 2026-08-26. `DECISIONS.md`, written the same day through
2026-08-27, contains explicit product-owner rulings (R-1, R-1a, R-6, R-8, R-8a, R-9,
R-10, R-11, R-12, R-14, R-15/R-32, R-16…R-25, R-33) that resolve essentially every
one of those 39 rows by name. The build has visibly proceeded well past this gate —
76 routes exist, 236 screenshots were captured, commit history shows "Wave 6" of
screen work landed.

**What a reader of only RULINGS.md would wrongly conclude:** that the project is
still blocked pending 39 open product decisions. The resolutions exist, just not
written back into the document that claims to gate on them — exactly the
"sources that do not read each other" failure mode this audit was set up to catch.

---

## 7. RULINGS.md still lists 3 files that have already been deleted

`kyc/review_submit_screen.dart`, `onboarding/document_summary_screen.dart`, and
`markets/watchlist_screen.dart` are all still listed in RULINGS.md's needs-ruling
table as pending files. **None of the three exist anywhere under `lib/` any more**
(confirmed by filesystem search) — their rulings (R-9 drop review-before-submit,
R-8/D-4 drop document-summary, R-16 drop watchlist) were executed and the files
removed. `Routes.documentSummary` no longer exists in `routes.dart` either,
independently confirming the deletion. This is the mirror image of finding #6:
here the ruling sheet is stale in the *other* direction, still claiming open items
that are actually long since closed and removed.

---

## 8. A route exists with no real way to reach it — the inverse of the UNROUTED problem

`Routes.acctComplaintTracked` (`/account/help/complaint/tracked`,
`ComplaintTrackedScreen`) is a fully registered `GoRoute`. Its own code comment says
plainly: *"no live entry point yet — submitting a complaint has no real backend to
return one from... registered so the built screen is reachable once that exists."*
It appears in the capture set (`63_complaint_tracked`) only because the harness can
drive a route directly, bypassing the missing in-app trigger.

This matters because this audit's brief specifically warns about screens that are
reachable-but-not-routed (sheets, tabs). This is the reverse case: **routed but not
really reachable**. Counting it as "covered" because it's in both the route table
and the shot set overstates real user-reachable coverage.

---

## 9. `tax_documents_screen.dart` — RULINGS.md's classification is one day out of date

RULINGS.md's no-action bucket (2026-08-26) describes this screen as *"currently
unreachable from any live UI in the app itself."* `account_screen.dart`'s own code
comment says the menu row was **"Restored 2026-08-27"** — one day later — once the
backend gained the tax-statement kinds it needed. It is now a live, wired,
real-backend-calling route (`/account/tax`) with a permanent Account-menu entry, and
it has zero artboard coverage anywhere in the canvas. It should be bucketed
restyle-only, not no-action, and nobody has actually ruled on its visual treatment.

---

## 10. The pre-parsed canvas inventory silently drops two design files

`docs/redesign/canvas-inventory.json`'s total of 135 checks out exactly against my
own regex parse of the 6 numbered `.dc.html` files (56 base-numbered screens ×
light/dark + variant states = 135; base numbers run 1–58 with gaps at 28 and 32).
But two more `.dc.html` files sit in the same folder and are invisible to the
inventory because their ids don't match the `sNN` pattern:

- `Home Variants.dc.html` — ids `3e`, `l1` (alternate home-screen treatments —
  "Dark · approved", "Light · reworked").
- `Landing Video Concept.dc.html` — ids `v1`, `v2`, `v3`, `kd-landing-still`.

This is not a cosmetic gap: **`DECISIONS.md` R-14 rules that Welcome uses "Landing
Video Concept V3"** — i.e. the artboard the product owner actually chose for one of
the very first screens in the app lives in a file the pre-parsed inventory never
counts or lists. Anyone treating `canvas-inventory.json` as the complete artboard
index would never find it.

---

## 11. Stale old-canvas screen numbers are still live in shipped code (already flagged by R-5, still present)

`routes.dart`/`app_router.dart` comments cite "Screen 65," "Screen 66," "screens
76-97," "screens 81-84," "screen 85," "screen 86," "screens 87-88," "screens 89, 90,
92," "screen 91," "screens 94-97" — all from the **old 97-light-screen canvas**
`DECISIONS.md` records was replaced. The current canvas's highest artboard id is
`s58`, with only 56 base-numbered screens (verified). `DECISIONS.md`'s own R-5
already names this exact defect and requires stale ids be stripped or re-pointed as
each screen is touched. Nothing new here — but the stale numbers are still present
in the source as of this audit, so the risk R-5 was written to close is not yet
fully closed.

---

## 12. Environment caveat: the capture set was overwritten mid-audit

`build/shots/*.png` (236 files, enumerated and used for the `has_capture` column in
`coverage-inventory.json`) was overwritten partway through this audit by what
appears to be a concurrent Android/Gradle build running in the same working
directory — `build/` now contains only Gradle output folders (`app`, `.cxx`,
`camera_android_camerax`, etc.), no `shots/` folder. The `has_capture` values in the
inventory reflect the snapshot taken **before** that happened. Re-run the capture
harness and re-diff before relying on that column again.

---

## Source counts, verified independently

| source | count | how verified |
|---|---|---|
| routes | **76** | `grep -c "GoRoute(" lib/router/app_router.dart`, cross-checked by counting `path: Routes.\w+` occurrences (also 76) |
| artboards | **135** | own regex (`id="s[0-9]+[a-z]*"`) against the 6 numbered `.dc.html` files directly; matches `canvas-inventory.json`'s stated total exactly, but see finding #10 for what that total excludes |
| ruled screens | **91** | `RULINGS.md`'s own header table (39+14+28+10); re-counted independently by parsing each bucket's markdown table rows — matches |
| routes absent from RULINGS.md's 91 | **4** (see finding #1) | cross-referencing the 76 resolved route→widget pairs against every screen file RULINGS.md names |
