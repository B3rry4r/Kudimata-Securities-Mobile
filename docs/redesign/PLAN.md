# "Soft Landing" redesign — tracking

Source: Kudimata Design System (Claude Design project
`b88dc96c-642d-4cb1-af7e-06764002af55`) + the "App redesign: Design system
flows" canvas (project `a30e5872-cfee-4fa8-8882-d4d76f36d173`, file
`Kudimata Invest App.dc.html`) + `Kudimata_Full_Audit (1).docx` (2026-08-22
product/design audit that called for this direction change).

**The canvas is the source of truth, not a hand-transcribed spec doc.** The
previous version of this tracking doc pointed at a `screen-specs.md` that
manually transcribed all 66 screens — it silently went stale the moment the
canvas grew to 97 screens, and nobody updated it. Rather than repeat that
failure mode, the canvas file itself is now committed straight into the repo:
**`docs/design/kudimata-invest-app.dc.html`** (open it in a browser — it's a
static self-contained page, screens are `<div id="sNN">` blocks in order) and
**`docs/design/design-system/`** (tokens, styles, readme — the Flutter port
lives in `lib/theme/tokens.dart` / `lib/widgets/`). Read the actual screen
markup before touching any screen; don't trust a paraphrase of it, including
the one in this file.

## Status (2026-08-23, canvas-expansion pass)

The canvas grew from 66 to **97 screens** sometime after the original
"Soft Landing" pass was merged (commit `63c9492`) and audited (commit
`9285800` and later fixes). 10 of the 97 are email templates (screens
67-75, 93) — out of scope for this Flutter app. That leaves **87 real
in-app mobile screens**.

### 1. Foundation — DONE
Tokens, fonts, illustrations, dark-mode removal. Unchanged since the
original pass — see git history (`5452a5d`, `ed574c5`) for detail, not
worth re-stating here.

### 2. Widget layer — DONE, additively extended this pass
Original widget set unchanged. This pass added, all via new optional props
on existing widgets rather than forked components (per the house "never
fork" rule):
- `KFreezeConfirm.primary`/`.secondary` made nullable — a caller can place
  its own button row elsewhere in the layout instead of using the built-in
  one (`lib/widgets/security.dart`; needed once #s65's spec put the buttons
  below an Input+explainer, not right after the effects list)
- `KInput.multiline`/`.minLines` — real textarea support (`lib/widgets/inputs.dart`)
- `KAccountSubScaffold.headerTrailing`, `KAccountRow.titleColor` (`lib/screens/account/account_widgets.dart`)
- `KStatusView.extra` — optional content slot between message and buttons (`lib/widgets/feedback.dart`)
- `KDetailHeader.trailing` (`lib/widgets/scaffold.dart`)
- `KKeyValueRow` — new shared label/value row (`lib/screens/shared/state_views.dart`)
- A plain `'shield'` icon alongside the existing `'shieldCheck'` (`lib/widgets/k_icon.dart`)

### 3. Screens 1-66 — reskinned, exactness-audited, believed current
Flows A-F (onboarding through account/security/support) were reskinned in
the original pass and have had multiple follow-up exactness passes (see git
log for `screen-specs.md` era commits + the 2026-08-23 bank-accounts/
withdraw-mandate fixes in commit `d68d3ab`). **Not re-verified screen-by-screen
in this pass** — the audit docx has previously found real gaps in a
"done" pass before, so treat this as believed-current, not guaranteed.
Next real audit pass should re-walk 1-66 against the committed canvas file
the same way this pass built 76-97, screen by screen with a screenshot.

### 4. Screens 60-66 (Flow G — market hours, mandate, receipts) — DONE
- #60 Markets closed: inline banner state on the Markets tab, not a route
- #61 Buy · market closed: `_MarketClosedBuySheet` in `trade_flows.dart`,
  re-verified against spec this pass (title/pill layout, radio-card
  treatment, real computed next-session date)
- #62 Price moved at the open: `lib/screens/trade/price_moved_screen.dart`
- #63 Withdraw · outside hours: `_OutsideHoursWithdrawSheet` in
  `lib/screens/wallet/wallet_flows.dart` (new this pass)
- #64 Bank accounts & mandate: `lib/screens/account/bank_accounts_screen.dart`
- #65 Withdraw the DCS mandate: `lib/screens/account/withdraw_mandate_screen.dart`
- #66 Contract note: `lib/screens/account/contract_note_screen.dart`

### 5. Screens 76-97 (canvas expansion) — DONE, this pass
Built by 6 parallel, file-disjoint agents, then centrally wired (routes,
entry points) and verified (`flutter analyze` clean, `flutter test` clean,
`test/shots_expansion.dart` — no layout errors across all 18 new routes at
the real 390x880 viewport). Every screen matches its canvas markup;
every gap where the backend can't support the real action yet is flagged
honestly in-code (see `BACKEND_GAPS.md`) rather than faked.

| # | Screen | File | Entry point |
|---|---|---|---|
| 76 | Statement · per broker | `lib/screens/account/statement_detail_screen.dart` | Statements → row tap |
| 77-79 | Sell (amount/review/placed) | `lib/screens/trade/trade_flows.dart` (`_runSellFlow` etc.) | Holding detail → Sell |
| 80 | Order lifecycle · part-fills | `lib/screens/trade/order_fill_progress_screen.dart` | **Not yet wired** — no route, no real fill data to drive it (see below) |
| 81 | Corporate actions | `lib/screens/corporate_actions/corporate_actions_screen.dart` | **Not yet wired from Portfolio/Holding detail** — canvas doesn't draw an entry affordance on #38/#39 itself; open design decision, see below |
| 82 | Rights issue | `lib/screens/corporate_actions/rights_issue_screen.dart` | From Corporate actions hub |
| 83 | AGM · vote your shares | `lib/screens/corporate_actions/agm_vote_screen.dart` | From Corporate actions hub |
| 84 | Dividends & e-mandate | `lib/screens/corporate_actions/dividends_screen.dart` | From Corporate actions hub |
| 85 | Tax documents | `lib/screens/account/tax_documents_screen.dart` | Statements → Tax row |
| 86 | Price alerts | `lib/screens/markets/price_alerts_screen.dart` | Watchlist → "Manage price alerts" |
| 87 | File a complaint | `lib/screens/account/complaint_screen.dart` | Help & support → File a complaint |
| 88 | Complaint · tracked | `lib/screens/account/complaint_tracked_screen.dart` | Route registered, **no live entry point** (submission has no backend to return a tracked complaint from yet) |
| 89 | Dormant account | `lib/screens/account/dormant_account_screen.dart` | Route registered, **not auto-triggered** (no dormancy signal exists — see gaps doc) |
| 90 | Close your account | `lib/screens/account/close_account_screen.dart` | From Dormant account / Data & privacy |
| 91 | Data & privacy | `lib/screens/account/data_privacy_screen.dart` | Account hub |
| 92 | Locked out | `lib/screens/onboarding/locked_out_screen.dart` | Route registered, **not auto-triggered** (no failed-attempt counter exists — see gaps doc) |
| 94 | Partner disclosures | `lib/screens/account/legal_reference_screens.dart` | Account → Legal |
| 95 | Referral terms | `lib/screens/account/legal_reference_screens.dart` | Account → Legal |
| 96 | Data notice · NDPA | `lib/screens/account/legal_reference_screens.dart` | Account → Legal, Data & privacy |
| 97 | Account closure terms | `lib/screens/account/legal_reference_screens.dart` | Account → Legal, Close account |

### Open design decisions (not code gaps — need a product/design call)
- **#81 Corporate actions entry point**: the canvas's own footer note says
  "Entry from 38, 39 or a notification," but neither #38 (Portfolio) nor #39
  (Holding detail) actually draws an entry affordance in their own markup —
  and #38 has its own comment insisting on no extra elements beyond exactly
  what the canvas draws, from a prior exactness audit. Didn't invent a
  banner rather than risk a second mismatch. Needs a real design call on
  where/how this surfaces (permanent row? conditional banner only when a
  decision is pending? notification-only?).
- **#80 Order fill progress**: fully built (`order_fill_progress_screen.dart`)
  but takes required real params (fills list, remaining units, callbacks) —
  nothing constructs it yet because there's no partial-fill data anywhere
  in the order model. Route it from Order status once that data exists.
- **Dead code follow-up**: `trade_flows.dart`'s original shared `_AmountSheet`/
  `_ReviewSheet`/`_showSuccessSheet` still contain `isSell` branches that are
  now unreachable (only `side: _Side.buy` is ever passed to `_runTradeFlow`
  since the dedicated sell flow shipped). Left in place deliberately this
  pass to avoid a risky wide-diff edit under time pressure — real cleanup,
  not a functional bug. Worth a dedicated pass.

See **`BACKEND_GAPS.md`** for every real backend gap found across both this
pass and the original redesign — the AI comprehension layer, corporate
actions, dividends, complaints, dormancy, and more.
