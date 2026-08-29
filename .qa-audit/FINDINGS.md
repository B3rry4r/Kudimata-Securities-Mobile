# Findings — Phase 4 classification, worst-first

Authority checked: `docs/redesign/DECISIONS.md` (R-1…R-41, C-1…C-6, D-1…D-9).
`docs/redesign/RULINGS.md` treated as evidence only — confirmed stale/self-contradictory
in several places (see #14). Inputs classified: `.qa-audit/coverage-findings.md`,
`.qa-audit/composition-findings.md`, `.qa-audit/release-check.md`. Prior art
(`docs/redesign/AUDIT-FINDINGS-conformance.md`, `AUDIT-2026-08-29.md`) read only for
corroboration, per `.qa-audit/independence.md`'s own rule.

**Counts:** 8 `defect`, 0 `divergence-with-reason` (nothing I checked against DECISIONS.md
carried a real ruling id excusing it — every apparent divergence I inspected closely either
resolved cleanly with no ruling needed, or had no ruling at all), 7 `unclear`.

---

## 1 — DEFECT — Asset detail hardcodes the exact fee figure this project already killed everywhere else

**File:** `lib/screens/markets/asset_detail_screen.dart:568` (+ `lib/data/glossary.dart:22`)

Every stock's detail page shows `fee: '1.35% all-in'` — a literal string, not a wire value.
The file's own comment claims this is a "real, product-wide constant... used identically
elsewhere in this app." That is false: it exists **nowhere else**. `trade_flows.dart` and
`wallet_flows.dart` both document, at length, ripping out this *exact* constant as R-34/C-1's
highest-priority rule ("NO CLIENT-SIDE FEE CONSTANT, EVER") because it once "displayed
'Fees · 1.35%' on every review screen while the backend charged nothing at all." `FACT-CONFLICTS.md`
calls this bug class "the most serious row in this file... on the money path of a licensed
broker" and records the real backend rate as ~1.45%, not 1.35%. Every buy/sell screen in the
app now correctly withholds any fee figure until the order fills — asset detail and the
glossary are the only two places left that violate the rule, and neither is flagged in
`BACKEND_GAPS.md`.

**Hides:** that this figure is verified and shared. It is neither.
**User impact:** every investor viewing any stock is told a fee that matches neither the
design nor the real backend rate card, on a screen more visible than the trade flow itself.

---

## 2 — DEFECT — Interrupted onboarding leaves a signed-in session with zero local credential (verified independently)

**File:** `otp_screen.dart:135`, `app_state.dart:415-434`, `app_router.dart:520-523`, `main.dart:148`

Traced independently, matching composition-findings.md exactly. Token save happens at OTP
verify, before suitability/legal/passcode. If killed before passcode confirm, cold start sets
`signedIn=true` from the token alone, `passcodeSet` stays `false`, the cold-start force-unlock
requires `passcodeSet==true` so never fires, and `preAuthOnly` (splash, welcome) redirects
straight to Home. The resume-lock (`main.dart:148`) has the identical guard, so backgrounding
never catches it either. No ruling in DECISIONS.md covers this.

**User impact:** a live, funded brokerage session, fully signed in, with no passcode, no
biometric, and no mechanism that will ever challenge it until the token's ~15-minute TTL
forces a refresh.

---

## 3 — UNCLEAR — The entire buy/sell/add-money/withdraw flow has never been rendered, by anyone, ever

**File:** `trade_flows.dart` (showBuyFlow/showSellFlow), `wallet_flows.dart` (showAddMoneyFlow/showWithdrawFlow)

Read `test/shots_all.dart` directly: 76 `_RouteSpec` entries, zero for any of these four modal
sheets — structurally unreachable by the routed-screen harness. This is `DECISIONS.md`'s own
open item B-3, still unexecuted. **This directly contradicts coverage-findings.md's claim**
that buy/sell "is thoroughly captured" by name (`buy_chooser_s42`, etc.) — no such capture
names exist in the current harness; that claim likely came from a stale/external screenshot
dir (`/tmp/shots`, `/tmp/uiops-phase5/shots` — both outside the repo). Independent prior art
(`AUDIT-FINDINGS-conformance.md`) reaches the same "zero renders" conclusion by a completely
different method.

**Owner must answer:** extend the harness to sheet-driven sub-states (B-3) before this flow —
the app's only revenue path — can be called verified by anything stronger than "it compiles."

---

## 4 — DEFECT — Live-pushed account suspension is decoded and silently dropped (verified independently)

**File:** `app_state.dart:377-384`, `realtime_client.dart:92-110`

`RealtimeKycStatus` decodes `accountStatus`; its own doc comment says it's one of "the two
fields this app's gate actually reacts to." `applyRealtimeKycStatus` reads `kycStatus` three
times, `accountStatus` zero times — confirmed by direct read of the method body. `accountStatus`
IS read elsewhere (account screen, dormant redirect) but only from REST fetches at login/manual
nav, never from the live push. No ruling authorizes the gap; R-41 requires exactly this class
of surface to push immediately.

**User impact:** a staff-pushed suspension/dormancy flag does nothing while the investor's
socket stays open — session looks fully active until token TTL or a manual fetch. Two related
`unclear` items from scenario-matrix.json: whether a suspended login attempt is told why
(unclear, no distinct client handling found), and how long a self-frozen session looks normal
before the next call 401s it out (unclear, needs a live run).

---

## 5 — UNCLEAR — The KYC step that actually submits the application has no screenshot

**File:** `lib/screens/kyc/next_of_kin.dart` (step 8 of 8, calls `finalizeDraft()` directly per R-9)

Confirmed via `shots_all.dart`: the steps immediately before and after are captured; this one
is not. Nobody has looked at the one screen every investor must complete to submit their KYC.

---

## 6 — DEFECT — "We'll notify you... you can close the app" has no delivery mechanism

**File:** `lib/screens/kyc/submitted.dart:202` (weaker instances: `approved.dart:146`, `outcome_not_approved.dart:194-195`)

Confirmed: zero push-notification dependency anywhere in `pubspec.yaml`/`lib/` (no
firebase_messaging, no APNs, no flutter_local_notifications). The only live mechanism is
socket.io, which requires the app open. The same message's own header, three lines up,
correctly removes a different unverified claim for the same reason — this one wasn't caught.

**User impact:** an investor who follows the explicit instruction to close the app gets no
notification of any kind when KYC completes.

---

## 7 — UNCLEAR — Three live screens never went through the mandatory R-3 ruling process

**File:** `kyc/kyc_checklist_screen.dart`, `onboarding/legal_preview_screen.dart#LegalBundlePreviewScreen`, `markets/price_alerts_screen.dart#SetPriceAlertScreen`

Confirmed absent from both RULINGS.md and DECISIONS.md by direct grep. (A fourth screen
coverage-findings.md grouped with these, `whats_next_screen.dart`, is actually covered
functionally by DECISIONS.md's R-33/s07 entry — not included here.) `kyc_checklist_screen.dart`
is the KYC flow's own hub, re-entered after every step, with unevaluated artboards s11/s11d.
R-3: "no blanket policy... every one ruled individually... an agent may not infer."

---

## 8 — DEFECT — Buy/Sell button order swapped on asset detail, uniquely undocumented

**File:** `asset_detail_screen.dart:402-415`

Verified: Sell renders first, Buy second; the artboard draws the reverse. This file documents
every other divergence in detail — this is the one swap with no comment and no ruling.

---

## 9 — UNCLEAR — Artboard s38 claimed by two structurally different receipt screens

**File:** `account/contract_note_screen.dart`, `wallet/wallet_screens.dart#transaction_detail`

Both cite s38 as their match on identical-strength evidence; neither DECISIONS.md nor
RULINGS.md records whether it was drawn to be one, the other, or both.

---

## 10 — UNCLEAR — tax_documents_screen went live one day after being ruled unreachable, no visual ruling since

**File:** `account/tax_documents_screen.dart`, `account/account_screen.dart`

RULINGS.md (2026-08-26) calls it unreachable; `account_screen.dart`'s own comment says the
menu row was "Restored 2026-08-27." Live, wired, permanent — zero artboard coverage or ruling.

---

## 11 — UNCLEAR — Release APK's CAMERA permission has no `required="false"`

**File:** `android/app/src/main/AndroidManifest.xml`

Confirmed in the packaged artifact (`aapt dump badging`). Filters cameraless devices out of
the Play Store listing entirely — store-distribution-only, invisible to debug testing. Product
call: is a camera a hard requirement to invest, or should KYC degrade gracefully.

---

## 12 — UNCLEAR — Local release build silently debug-signs when `key.properties` is missing

**File:** `android/app/build.gradle.kts` — no warning either way; the artifact actually
verified in this audit used the real key. Risk confined to a contributor's local build.

---

## 13 — UNCLEAR — No CSP on the web build

**File:** `web/index.html` — no defense-in-depth against injected content on web specifically;
web isn't in CI per CLAUDE.md.

---

## 14 — UNCLEAR — RULINGS.md is stale and self-contradictory; DECISIONS.md is the real source of truth

**File:** `docs/redesign/RULINGS.md` — lists 3 deleted files as pending, all 39 needs-ruling
rows show an empty ruling column while DECISIONS.md's R-1…R-41 resolve nearly all of them by
name. Recommend regenerating or deprecating it. No user-facing impact; risk is to future
readers who trust it over DECISIONS.md.

---

## 15 — UNCLEAR — `Routes.acctComplaintTracked` has no real in-app entry point

**File:** `app_router.dart` — developer-acknowledged, intentional pre-wiring ahead of a backend
capability that doesn't exist yet. Not a bug.

---

## What I verified myself vs. what I took on the auditors' word

Independently re-traced (read the actual source, not just the report): the OTP/passcode
security gap (#2), the `accountStatus` drop (#4), the fee-constant history across
`trade_flows.dart`/`wallet_flows.dart`/`FACT-CONFLICTS.md` (#1), the harness's actual route
list in `shots_all.dart` (#3, #5), the button-order swap (#8), the "24-hour security hold"
claim the task brief warned about (checked all three sites — `personal_info_screen.dart`,
`security_screen.dart`, `wallet_flows.dart` — **all three already correctly omit it**, not a
live defect here). Took on citation alone (RULINGS.md/DECISIONS.md grep only, no render):
#7, #9, #10, #14. Release-artifact findings (#11–13) are release-check.md's own verified
artifact-level checks, restated with severity assigned.
