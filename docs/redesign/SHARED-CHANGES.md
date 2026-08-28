# Shared-change queue

Screen agents may not edit `lib/widgets/**`, `lib/data/**`, `lib/theme/**` or
`lib/router/**` while a wave is running (brief rule 5). They file requests here
instead, and a **serial pre-step between waves** applies them.

This exists because forbidding an agent to edit shared code without giving it a
legal alternative is what produces forks — the sibling backend has
`S3PresignerService` in four modules and `AuthenticatedRequest` in twenty-five,
each one an agent correctly obeying its fence and taking the only other option.

## Open requests

| # | from | file | change | status |
|---|---|---|---|---|
| S-8 | wave · kyc checklist (`s11`) | `lib/router/routes.dart` + router config | Built `lib/screens/kyc/kyc_checklist_screen.dart` (`KycChecklistScreen`) for artboard `s11`/`s11d` — the flow's spine, "re-entered after every completed step" per this screen agent's own task. Needs: add `static const String kycChecklist = '/kyc/checklist';` to `routes.dart` right after `kycIntro`, and a `GoRoute` to `KycChecklistScreen` in the router config. Nothing currently navigates to it — this file deliberately references no such route so the app keeps compiling until it's added. | ✅ applied — see Applied section |
| S-9 | wave · kyc checklist (`s11`) | `lib/widgets/buttons.dart` (`KButton`) | `KButton`'s `ghost` variant's foreground is always `KColor.ink` — invisible on `KColor.feature` (grape). `liveness.dart` (`s15`, the one KYC screen on that panel) needed a "My camera won't work" ghost-style link and used a screen-local text widget instead of forking KButton (see that file's own comment). An `onFeature`/light-fg option on the ghost variant would let it use the real shared button again. | open |
| S-10 | wave · kyc checklist (`s11`) | `lib/data/repositories/kyc_repository.dart` + backend | `declarations_screen.dart`'s (`s19`) second question — "Do you work for a stockbroker or the NGX?" — has no backend field at all (only `pepSelfDeclared` is persisted; confirmed against `UpdateKycDraftFieldsRequest`/`KycSubmission`). Filed properly in `BACKEND_GAPS.md`; noted here too because `kyc_checklist_screen.dart`'s own "Declarations done" signal can only check the PEP half for this reason — see that file's header comment. | blocked on backend |
| S-1 | wave 2 · welcome | `lib/widgets/mobile.dart` | `KOnboardingSlideFrame` and `KOnboardingSlideContent` are now **dead code** — the 3-slide carousel they served was removed by R-14. Delete both, and check for other callers first. | ✅ applied — see Applied section |
| S-2 | wave 2 · sign up | `lib/data/repositories/auth_repository.dart` | `AuthRepository.signUp` needs an optional `phone` parameter. Blocked on the backend gaining a phone field (filed in `BACKEND_GAPS.md`). Until then the sign-up phone input stays **disabled**, not silently discarded. | ✅ applied — see Applied section |

| S-4 | wave 3 · approved | `lib/widgets/` (illustration) | `KIllustration` **always** draws its tinted plate. `s21`-light draws the illustration bare; `s21d`-dark plates it. Needs an optional `plate` control so light/dark can differ. Affects every status screen, not just this one. | ✅ applied — see Applied section |
| S-5 | wave 3 · approved | `lib/widgets/buttons.dart` | `KButton`'s ghost variant renders **borderless**; `s21d` draws an outlined ghost. Needs a border option on the ghost variant. | ✅ applied — see Applied section |
| S-6 | wave · bvn/nin | `lib/data/repositories/kyc_repository.dart` | `KycSubmissionStatus` needs optional `resolvedName`/`resolvedDob`/`resolvedPhone` (or similar) fields, parsed from `draftStep1`'s response, plus a name-match boolean — s13 "Details from BVN" needs them to show what the BVN/NIN check actually returned instead of `—`. Blocked on the backend gaining those fields first (filed in `BACKEND_GAPS.md`, "s13 — Details from BVN"). | blocked on backend |
| S-7 | asset detail (`s26`/`s27`) | `lib/data/models.dart` + `lib/data/repositories/asset_repository.dart` | The backend now serves a real simulated order book (BR-5, `SimulatedNgxBroker#getOrderBook`) at `GET /assets/:ticker/order-book` — `{ ticker, bids: [{priceKobo, units}], asks: [{priceKobo, units}], asOf }`, bids best-first (highest price), asks best-first (lowest), 5 levels a side, every bid strictly below every ask. Mobile has no model or repository method for it yet. Needed: an `OrderBook`/`OrderBookLevel` model mirroring `Kudimata-Securities-Backend/src/common/types/asset.types.ts` 1:1 (keep `priceKobo`/`units` as raw ints, not preformatted strings — the screen formats kobo→naira itself the way `contract_note_screen.dart`/`dividends_screen.dart` already do, not the way `AssetRepository._fromJson` preformats `Asset.price`), plus `AssetRepository.orderBook(String ticker)` calling that endpoint. Once this lands, `asset_detail_screen.dart`'s `_OrderBookTab` needs re-dispatch to wire a `FutureBuilder` (loading/error/empty-when-both-sides-empty/populated) driving the bid/ask rows and best-buy/best-sell cells s27 draws, currently blocked on this. **Not included:** s26/s27's "Easy to sell" / "Hard to sell quickly" liquidity call-out banner — grepped `SimulatedNgxBroker` end to end and it computes no liquidity tier at all, and the book is always exactly 5 levels a side (so level-count can't signal it either); any easy/hard threshold from spread or summed units would be an invented judgment call, not a real mechanism (R-34/DECISIONS.md's CLAIMS extension). That banner stays an omission even after this request lands, pending a product ruling on what "easy" vs "hard to sell" actually means. | ✅ applied — see Applied section |
| S-11 | price alerts (`s49`/`s50`) | `lib/router/routes.dart` + `lib/router/app_router.dart` | Rebuilt `price_alerts_screen.dart` against s49 ("Set a price alert")/s50 ("My alerts") — see `BACKEND_GAPS.md`'s new s49/s50 entry for the model reconciliation against `PriceAlertRepository`. `SetPriceAlertScreen` (s49, public, ticker-parametrised) has no go_router entry: it's reached today only via `price_alerts_screen.dart`'s own "New alert" flow (`Navigator.push`, not go_router). Needed: `static String setPriceAlert(String ticker) => '/asset/$ticker/alert';` in `routes.dart` (near `assetDetail`) + a matching `GoRoute` in `app_router.dart`. Verified without a route in the interim via a throwaway test (deleted after use, same technique as S-7). | ✅ applied — see Applied section |

## Harness follow-ups

| # | raised by | change | status |
|---|---|---|---|
| H-1 | wave 3 · rejection | Now that `MockKyc` supports `rejected`/`flagged`/`expired`, add those as **sub-states** in `test/shots_substates.dart` for `outcome_not_approved`. The agent had to use a throwaway test because the standing harness's KYC fixture is always `approved` — the fixtures now exist, the specs just aren't declared. | ✅ applied — see Applied section |

## Cross-screen follow-ups

Changes one screen's rebuild makes necessary in *another* screen's file. An agent
correctly refuses to reach outside its scope, so these land here.

| # | raised by | target | change | status |
|---|---|---|---|---|
| X-1 | wave 2 · sign up | `lib/screens/onboarding/otp_screen.dart` | Hardcodes `stepLabel: 'Step 1 of 4'`. Sign-up now occupies steps 1–3 of the canvas sequence, so OTP is **"Step 4 of 4"**. | ✅ fixed by the OTP agent in the same wave |
| S-3 | wave 2 · login | `lib/screens/onboarding/onboarding_scaffold.dart` | `KOnboardTopBar`'s back button renders as a bare icon; artboards (`s08p` and others) draw it on a **round tinted chip**. Cosmetic, but it is shared onboarding chrome many screens depend on — apply once, serially, not per-screen. | ✅ applied — see Applied section |
| X-2 | wave · bvn/nin | every other `lib/screens/kyc/*.dart` with a `stepLabel`/`KycStepProgress` (`chn_screen.dart` "2 of 8", `id_upload.dart` "3 of 8", `liveness.dart`/`checking.dart` "4 of 8", `utility_bill.dart` "5 of 8", `bank_dcs_screen.dart` "6 of 8", `declarations_screen.dart` "7 of 8", `next_of_kin.dart` "8 of 8") | This screen now shows **"1 of 7"**, not "1 of 8" — see `bvn_nin.dart`'s header comment for the derivation: the old 8 already excluded the dropped review step; the real change R-9 forces is merging `id_upload.dart`'s ID step and `utility_bill.dart`'s address/utility-bill step into ONE step (`s11`'s checklist lists them as a single "Documents uploaded · ID · utility bill" item). So the real sequence is BVN&NIN(1) → CHN(2) → Documents: ID+address(3) → Selfie(4) → Bank & DCS(5) → Two questions/Declarations(6) → Next of kin(7). Every other KYC screen's `stepLabel`/`KycStepProgress` needs renumbering to this 7-step scheme in one pass, not screen-by-screen (same reasoning as X-1). | ✅ applied — see Applied section |
| X-3 | s14/s17 · id_upload + utility_bill | `lib/screens/kyc/review_submit_screen.dart` (calls `KycRepository.finalizeDraft`) | R-19 (DECISIONS.md) required `utility_bill.dart` (s17) to collect street address/State/LGA alongside the upload. Rather than staging them into `kyc_form_state.dart` — read/written by several other KYC screens outside this pass's scope — the screen saves them straight to the already-real `PATCH /users/me` (`UserRepository.updateProfile`: `residentialAddress`/`state`, plus `city` carrying the LGA value — see utility_bill.dart's header comment for that mapping). That means the data lands on the user's profile but `finalizeDraft`'s own optional `address`/`city`/`state` params are still never populated from `review_submit_screen.dart`, so the KYC *submission* record itself stays addressless even though the profile now has it. Not blocking — nothing is discarded — but worth a decision on whether compliance review needs address on the submission too, which would mean this screen's saved values (or `kyc_form_state.dart` fields carrying them) also feeding that call. | open |
| X-4 | onboarding · `s07` "What happens next" | `lib/router/routes.dart` + `lib/screens/onboarding/avatar_screen.dart` | R-33 names `s07` as build work with no route. Built as `lib/screens/onboarding/whats_next_screen.dart` (`WhatsNextScreen`) — layout/copy/nav match the artboard, its own two buttons already point at real existing routes (`Routes.kycIntro`, `Routes.home`), so nothing shared was needed for those. What's missing is reaching the screen at all: add `static const String onboardingNextSteps = '/onboarding/next-steps';` to `routes.dart` (near `onboardingAvatar`) with a `GoRoute` to `WhatsNextScreen`, then change `avatar_screen.dart`'s two `context.go(Routes.kycIntro)` calls (`_skip()` and the end of `_continue()`) to `context.go(Routes.onboardingNextSteps)` instead — that slots it in exactly where the canvas's own flow puts it, between avatar selection and KYC start. Until this lands the screen is built and correct but unreachable from the live flow. | ✅ applied — see Applied section |
| X-5 | wave · kyc checklist (`s11`) | `kyc_intro.dart`, `chn_screen.dart`, `id_upload.dart`, `liveness.dart`→`checking.dart`, `utility_bill.dart`, `bank_dcs_screen.dart`, `declarations_screen.dart` | `s11`'s own caption: "every step returns to it" — the checklist hub is meant to be the landing point after each completed step, not just a resume screen entered once. Once S-8 lands `Routes.kycChecklist`, the screens above should route their "step complete" transition to it INSTEAD of hardcoding the next screen (`checking.dart`'s success currently goes straight to `Routes.kycUtilityBill`; `chn_screen.dart`'s Continue/Skip to `Routes.kycId`; `bank_dcs_screen.dart`'s post-confirm to `Routes.kycDeclarations`; `declarations_screen.dart`'s Continue to `Routes.kycNextOfKin`; `kyc_intro.dart`'s "Start" resume-map to whichever step it currently jumps straight into). `kyc_checklist_screen.dart` itself already computes the right next step from real draft/account data, so each screen only needs its own destination changed to the hub — no other logic moves. NOT done in this pass: touches five files this screen agent doesn't own (only `checking.dart`, `chn_screen.dart`, `bank_dcs_screen.dart`, `declarations_screen.dart` are this agent's), and changing even the owned ones now would point at a route that doesn't exist yet (S-8). Left as one serial follow-up so it lands as a single coherent change, not five uncoordinated ones. | ✅ applied — see Applied section |
| X-5 | suitability pass · questionnaire/legal/risk-disclaimer | `lib/router/app_router.dart`, `lib/screens/onboarding/otp_screen.dart`, `lib/app/app_state.dart` (`tradingEligibilityGap`) | R-1a says the order should be `signup → OTP → SUITABILITY ASSESSMENT → legal documents (risk disclosure included) → passcode → biometric → KYC`. The router does not hold that order: `otp_screen.dart:137` sends every investor straight to `Routes.termsOfService` (now the 4-document bundle, see below) right after OTP; `Routes.questionnaire` has no caller anywhere in the live flow except `app_state.dart:485`'s `tradingEligibilityGap`, which only routes there **after KYC approval**, as a gate on placing a trade. So today's real order is `signup → OTP → legal docs → passcode → biometric → KYC → [trade attempt] → suitability → risk disclosure (fallback)`, i.e. suitability runs last, not second. Fixing this means: (1) `otp_screen.dart`'s post-verify handoff should go to `Routes.questionnaire` instead of `Routes.termsOfService`; (2) `suitability_result_screen.dart`'s "Continue" (currently `context.push(Routes.riskDisclaimer, ...)`) should instead advance into the legal-documents bundle (`Routes.termsOfService`), since risk disclosure now lives there (see X-6); (3) the post-KYC `!app.suitabilityComplete`/`!app.riskDisclosureAccepted` branches in `tradingEligibilityGap` become dead for newly-onboarded investors and should be reconsidered (kept only as a fallback for pre-existing accounts). Not done in this pass — router and `app_state.dart` gate logic are both outside a suitability-screen agent's file scope (brief rule 5/6). | ✅ applied — see Applied section (superseded by R-8a, executed by the flow pass) |
| X-6 | suitability pass · legal_acceptance_screen/terms_and_privacy/risk_disclaimer | none — informational, paired with X-5 | R-8 ("risk disclosure is one of the four documents, not its own gated screen") is now implemented **within this pass's own files**: `terms_and_privacy_screen.dart` bundles all 4 kinds (`terms_of_service`, `privacy_policy`, `risk_disclosure`, `client_agreement`) through `legal_acceptance_screen.dart`, which now opens each document in the phone's native viewer (mirroring `legal_preview_screen.dart`'s pattern) instead of rendering full text inline, gating the checkbox on "every document tapped open" instead of "scrolled to the bottom of the inlined text". `legal_acceptance_screen.dart`'s `_accept()` now also sets `AppState.riskDisclosureAccepted` when `risk_disclosure` is among the accepted kinds, so a freshly-onboarding investor doesn't get re-gated at `Routes.riskDisclaimer` post-KYC. `risk_disclaimer_screen.dart` itself was rewritten the same way (single-document tap-to-open row, same weaker acceptance-evidence trade-off) and kept alive only as the fallback route X-5 describes. **Consequence, not softened:** the old scroll-gated full-text acceptance (real evidence every word of the statutory Risk Disclaimer was displayed) is gone from both screens; the new evidence is "tapped to open the file in an external viewer once", which cannot confirm reading, and — given BR-6 (the four files were never actually uploaded to storage, so presigning succeeds and the external viewer opens to a broken page) — cannot even confirm the content rendered. This trade-off is what R-8 itself calls for; recorded here concretely per the suitability screen-agent brief's instruction. | **superseded by R-8a** (DECISIONS.md, 2026-08-27) — risk disclosure is pulled back OUT of this bundle into its own scroll-gated in-app screen; see the flow pass's Applied entry. |
| X-7 | price alerts (`s49`/`s50`) | `lib/screens/markets/asset_detail_screen.dart` | s49's own caption: "From the asset page, or 'Set a price alert' on 39 Market closed." Neither entry point is wired — `asset_detail_screen.dart` and the closed-market banner are both outside this screen agent's scope. Once S-11 lands `Routes.setPriceAlert(ticker)`, `asset_detail_screen.dart` should add a "Set a price alert" action calling `context.push(Routes.setPriceAlert(asset.ticker))`. Until then s49 is reachable only via `price_alerts_screen.dart`'s own "New alert" picker (over the investor's watchlist) — a real, working substitute entry point, not a placeholder, just not the one the artboard itself draws. | ✅ applied — see Applied section |

## Removals pass — rulings that delete or hide, and have no home in a wave

**A structural gap, found 2026-08-27.** Waves are organised around *building*
screens, so a ruling that says *remove this* has nobody assigned to it. Several
were ruled, recorded, and never executed — which is exactly how a ruling
evaporates. Discovered when an agent was told `review_submit_screen.dart` had
been dropped per R-9, checked, and found it still there.

These need one dedicated pass, run serially like the shared-change queue:

| # | ruling | action | status |
|---|---|---|---|
| D-1 | R-9 | **Drop `review_submit_screen.dart`** — submission moves to the last collection step. Note X-3 just wired the address into its `finalizeDraft` call, so that wiring must move with it, not be lost. | ✅ applied — see Applied section |
| D-2 | R-16 | **Drop `watchlist_screen.dart`** — keep the `+` toggle on asset detail; "My alerts" (`s50`) gets a permanent Account-menu row so saved assets still have a reader. | ✅ applied — see Applied section |
| D-3 | R-6 | **Park the AI-credits line** — remove entry points for `plans_screen`, `refer_earn_screen`, `explain_screen` and the glossary's metered "Explain further" half, behind one flag. Keep the code and the repositories. The glossary's **static definitions must stay reachable** — trade flows, FAQ, asset detail and the suitability questionnaire all use them. | ✅ applied — see Applied section |
| D-4 | R-8 | **`document_summary_screen.dart` is superseded** by opening files in the phone viewer. Confirm nothing else routes to it before removing. | ✅ applied — see Applied section |
| D-5 | B-2 | **Hide the Order Book tab** behind the same check that renders its empty state — pending the owner's ruling, since the whole market-data layer is simulated. | awaiting ruling — NOT touched this pass |

**Why this is its own pass, not wave work:** every one of these touches routes,
nav entries or entry points that several screens reference. Done inside a wave by
an agent scoped to one screen, each would be a scope violation or a half-removal
leaving a dead route behind.

## Corrections to the queue itself

The build queue and the task briefs derived from it have been wrong three times.
Each was caught because an agent verified against the artboard instead of trusting
its assignment. Recorded so the errors do not recur, and because **the queue is
evidently the weakest link in this pipeline** — not the agents working from it.

| # | the error | how it surfaced | fix |
|---|---|---|---|
| Q-1 | `RULINGS.md` maps **both** `contract_note_screen.dart` and `wallet_screens.dart#TransactionDetailScreen` to **`s38`**. `s38` is the wallet transaction receipt, and the wallet screen is the true match. | The statements agent fetched `s38`'s real markup, saw it was already built elsewhere, and **halted rather than building a duplicate** that would have destroyed contract-note's itemised commission/exchange/VAT breakdown. | `contract_note_screen.dart` is **restyle-only**, no artboard. Its purpose — a per-order fee breakdown — has no canvas counterpart. |
| Q-2 | A brief asserted `review_submit_screen.dart` had already been dropped per R-9 and told the agent to find the new `finalizeDraft` call site. | The agent checked, found the screen still present, and wired the address there instead. | The removals pass then executed R-9 properly, moving both the screen's role and the address wiring into `next_of_kin.dart`. |
| Q-3 | A brief gave the search screen's path as `lib/screens/markets/search_screen.dart`. | The real file is `lib/screens/home/search_screen.dart`; the agent traced the actual route rather than trusting the path. | — |

**Why this keeps happening:** the queue was assembled mechanically from a
word-overlap matcher that under-matched badly (12 title matches out of 97), then
patched from evidence files and rulings. It is good enough to dispatch from and
not good enough to trust. Every screen agent must keep verifying its artboard
against the markup before building — that check is what caught all three.

## Removal candidates found mid-build

| # | screen | finding |
|---|---|---|
| D-6 | `lib/screens/account/tax_documents_screen.dart` | `Routes.acctTax` is registered and the screen is wired to it, but a full `lib/` grep found **zero navigation call sites**. A dead-end route: reachable only by typing the path. Not deleted — removals are a serial pass and this needs a ruling on whether tax documents *should* be reachable (annual tax summary generation is real and cron-scheduled; `wht_credit_note` is not wired anywhere). |
| D-7 | `lib/screens/onboarding/personal_details_screen.dart` | R-19 audit (docs/redesign/DECISIONS.md): its Residential address/City/State fields PATCH the exact same `UserRepository.updateProfile` fields `utility_bill.dart` (`s17`, reached later, inside KYC) also collects and saves — an investor who proceeds to KYC types the same address twice. DOB and phone are NOT duplicates: nothing else in the app collects phone, and despite R-19's text assuming BVN/NIN auto-populates DOB, `bvn_nin.dart`'s own header records the real backend response has no resolved DOB at all (filed as a gap there) — this screen is still the only place DOB is captured. Not trimmed here — removals are a serial pass (SCREEN-AGENT-BRIEF.md R-19) and this needs a human call on which entry point keeps the 3 address fields. Full finding recorded in the screen's own file header. |

## New screens discovered mid-build

Artboards with no app counterpart, found while building neighbouring screens.
These are additions to `BUILD-QUEUE.json`, not rulings.

| # | artboard | screen | why it is separate |
|---|---|---|---|
| N-1 | `s11` | KYC checklist hub | Functionally distinct from `s10`: `s10` is a one-shot entry with resume logic, `s11` is re-entered after **every** completed step. Merging them into `kyc_intro.dart` would break the resume path. Needs its own screen and route. Found by the `s10`/`s12` agent. |

## Applied

| # | change | what was actually done |
|---|---|---|
| X-2 | KYC renumbering to 7 steps | Renumbered `stepLabel`/`KycStepProgress` in `chn_screen.dart` (2 of 7), `id_upload.dart` + `utility_bill.dart` (both 3 of 7, merged Documents step), `liveness.dart` + `checking.dart` (both 4 of 7), `bank_dcs_screen.dart` (5 of 7), `declarations_screen.dart` (6 of 7), `next_of_kin.dart` (7 of 7). `bvn_nin.dart` (1 of 7) was already done. Header comments updated to stop citing the stale "of 8" numbering. `KycStepProgress`'s `total` is passed explicitly at every call site (no hidden default to fix). Verified on rendered PNGs: `17_kyc_bvn` through `25_kyc_next_of_kin` all show correct "N OF 7" labels and correctly-filled progress segments, with `19_kyc_id`/`22_kyc_utility_bill` both showing "3 OF 7" with 3 segments filled. |
| S-1 | delete dead code | Grepped `lib/` and `test/` for `KOnboardingSlideFrame`/`KOnboardingSlideContent` — no real callers, only a stale comment mention in `illustration.dart` (left as-is, it's prose not code). Deleted both classes from `lib/widgets/mobile.dart`. `flutter analyze` clean. |
| S-2 | wire up sign-up phone (BR-3 landed) | Added optional `phone` to `AuthRepository.signUp`, sent only when non-empty (same pattern as `middleName`), following `Kudimata-Securities-Backend`'s `SignupDto.phone?`. `sign_up_screen.dart`'s `#s03b` field is no longer `disabled: true`: got a real controller, submits alongside email/password, and no client-side format check — the server's `normalizePhone()` already accepts `0803…`/`803…`/`234803…`/`+234803…` with or without spaces, so re-validating here could only reject something the backend would accept. Helper copy replaced with the artboard's own "Use the line registered to your BVN" (was the now-false "Not collected at sign-up yet…"). Stays optional at this step per the artboard (no required marker, and the backend's `phone?` is genuinely optional) — Continue still gates on email alone. `_createAccount` now catches `PHONE_ALREADY_REGISTERED` (409) and `INVALID_PHONE` (400) specifically: both send the wizard back to step 2 and attach a field-level error ("That number is already registered to another account." / "Enter a valid Nigerian phone number, e.g. 0803 123 4567.") instead of a generic snackbar pointing at a field the investor can no longer see from the password step. Confirmed the step-1→step-2 `TextField`-reuse fix (`KOnboardBody(key: ValueKey(_step), ...)`) is still present and still works: a throwaway test typed a first/last name on step 1, advanced, and the step-2 phone field rendered its placeholder (empty), not the typed name — screenshotted in both themes, then deleted. |
| S-3 | back-button chip | `KOnboardTopBar` (`lib/screens/onboarding/onboarding_scaffold.dart`) back icon now sits on a 40×40 `KColor.track`-filled circle, icon size 19 (was 22), matching artboard `s08p`'s literal `border-radius:999px;background:var(--track)`. Verified on `14_login` and `04_otp`, light and dark. |
| S-4 | `KIllustration` plate control | Added `plate` bool (default `true`) to `KIllustration` (`lib/widgets/illustration.dart`); `false` skips the tinted `Container` and renders the SVG bare. Threaded through `KStatusView` as `illustrationPlate` (`lib/widgets/feedback.dart`, default `true`). `approved.dart` now passes `illustrationPlate: isDark` per s21 (bare, light) / s21d (plated, dark). Verified on `28_kyc_approved` light (bare) and dark (plated card). |
| S-5 | ghost button border | Added `ghostBorder` bool (default `false`) to `KButton` (`lib/widgets/buttons.dart`); when true and variant is `ghost`, draws `KColor.ink.withValues(alpha: 0.25)` border (matches s21d's `rgba(255,255,255,.25)`). Threaded through `KStatusView` as `secondaryGhostBorder`. `approved.dart` passes `secondaryGhostBorder: isDark`. Verified on `28_kyc_approved`: light ghost borderless, dark ghost outlined. |
| H-1 | KYC outcome sub-states | Added 3 `SubStateSpec` entries to `test/shots_substates.dart` for `outcome_not_approved.dart` (route `Routes.kycOutcome`): `kyc_outcome__rejected` (`MockKyc.rejected`), `kyc_outcome__flagged` (`MockKyc.flagged`), `kyc_outcome__expired` (`MockKyc.expired`), each with `kycApproved`/`suitabilityComplete` false. All 6 (×2 themes) rendered successfully via `shots.sh`. |
| D-1 | drop `review_submit_screen.dart` | Deleted the file. Moved its `_submit`/`_showErrorSheet` logic (including the X-3 address wiring — `UserRepository.personalInfo()` fetched fresh right before submit, `residentialAddress`/`city`/`state` sent into `finalizeDraft`) into `next_of_kin.dart`, now the last collection step; its button reads "Submit for verification" and shows a loading state. Removed `Routes.kycReview`, its `GoRoute`, its entry in the pre-auth `gated` set, and the `review_submit_screen.dart` import in `app_router.dart`. Updated `test/shots_all.dart`, `test/shots_kyc.dart`, `test/route_walk_test.dart` to drop the now-gone route/capture. Verified: `flutter analyze` clean, `flutter test` 11/11, and read `next_of_kin.dart`'s finalized `_submit` method back to confirm `address`/`city`/`state` are still passed into `_kycRepo.finalizeDraft(...)`. |
| D-2 | drop `watchlist_screen.dart` | Deleted the file, its `GoRoute`, its import, and `Routes.watchlist` (constant + its capture in `test/shots_all.dart` and `test/shots.dart`, its entry in `test/route_walk_test.dart`). Left `asset_detail_screen.dart`'s `+ watchlist` toggle untouched. Added a permanent **"My alerts"** row to `account_screen.dart`'s menu, pointing at `Routes.priceAlerts` (`price_alerts_screen.dart`, already reads `WatchlistRepository` alongside `PriceAlertRepository` — confirmed by reading the file) — keeps `s50` reachable and gives the saved-assets data a reader now that `watchlist_screen.dart` is gone. |
| D-3 | park the AI-credits line | Added `lib/app/feature_flags.dart` with a single `const bool kAiCreditsEnabled = false;`. Gated: `account_screen.dart`'s "Plans & credits" row, its compact credit-meter tap row, and "Refer & earn" row; `asset_detail_screen.dart`'s `onExplain` callback (passing `null` hides `KProductCard`'s Explain affordance entirely — no widget edit needed); `glossary_sheet.dart`'s "Explain further" button (`widget.allowAiFollowUp && kAiCreditsEnabled`). Confirmed by grep that these were the ONLY external entry points into `plans_screen.dart`/`refer_earn_screen.dart`/`explain_screen.dart` — their mutual cross-links (e.g. `refer_earn_screen.dart` → `Routes.acctPlans`) are internal to the now-unreachable cluster and left as-is. The glossary's static tier (`glossaryDefinition`) is untouched and unconditional. Screens, routes and repositories all still exist and still render in `shots_all.dart`. Gate `hardcoded_signals` flagged the new const (`'kAiCreditsEnabled' - constant stands in for a runtime signal`) — this is the flag's intended shape (R-6: "reversible in one edit", no backend on/off signal exists or should exist for a pending product decision), so accepted it in `scripts/gates/baseline.json` with owner + reason rather than silencing the gate. |
| D-4 | drop `document_summary_screen.dart` | Grepped every reference first: zero live `context.push`/`context.go` callers anywhere in `lib/` — the only real caller was the `GoRoute` itself, and the router's own comment already said it was "built but never wired in, found unreachable during the exactness audit." Deleted the file, its `GoRoute` (and the `DocumentSummaryArgs` extra-handling inside it), its import, `Routes.documentSummary`, and its entry in the pre-auth `gated` set and in `test/shots_all.dart`. Updated two stale comments in `legal_preview_screen.dart` and `legal_acceptance_screen.dart` that described the now-removed screen/route as still live. |
| S-7 | order book model + repository | Added `OrderBook`/`OrderBookLevel` (`lib/data/models.dart`, raw `priceKobo`/`units` ints, `fromJson` on both — mirrors `Kudimata-Securities-Backend/src/common/types/asset.types.ts` 1:1) and `AssetRepository.orderBook(String ticker)` (`GET /assets/:ticker/order-book`). Re-dispatched `asset_detail_screen.dart`'s `_OrderBookTab` in the same pass (in-scope per this agent's exception to rule 5): now a `StatefulWidget` with a `FutureBuilder` driving loading (`KLoadingView`) / error (`KErrorView`, retry re-fetches) / populated (`_OrderBookTable`: bid/ask rows best-first each side, best-buy/best-sell cells) / empty (`_OrderBookEmptyState`, only when both `bids`/`asks` come back empty — not observed against the real backend, which always returns 5 a side). Liquidity banner stays omitted per R-34/D-5. Verified on rendered PNGs (light + dark) via a throwaway test (`test/tmp_order_book_evidence_test.dart`, deleted after) seeding a real 5-level-a-side response through a wrapper adapter, since `test/fixtures/mock_api_adapter.dart` (off-limits) has no handler for the new endpoint yet — the standing `shots_substates.dart` sub-state still shows the "Depth unavailable" empty state for that reason, a fixture gap not a wiring one. `docs/redesign/BACKEND_GAPS.md`'s s26/s27 entry updated to note this. Gates: 64 fail/28 warn/1 accepted, unchanged (zero new). `flutter analyze` on the 3 touched files: clean. |

Gate/test counts, before → after this removals pass: `python3 scripts/gates/run.py` — 65 fail / 28 warn / 0 accepted → 65 fail / 28 warn / **1 accepted** (the D-3 flag, baselined, zero new fails). `flutter test` — 11/11 → 11/11. `flutter analyze` — clean before and after (8 pre-existing info-level findings in `trade_flows.dart`, unrelated). `bash scripts/design/shots.sh` — **72 screens** (down from the prior 76; `26_kyc_review`, `36_watchlist`, `11_document_summary` no longer exist) + 13 sub-states (unchanged), 0 unrenderable.

---

## Process note — worktree isolation, from wave 2

Wave 2 ran four agents against **one working tree**. One agent's mid-edit compile
error in `log_in_screen.dart` (`_LoginAvatar` undefined) broke `flutter test` and
`shots.sh` **for every other agent in the wave**, none of whom had touched that
file.

They coped — the affected agent used a throwaway render test for its evidence and
cleaned up — but the failure mode is clear: a shared working tree means any
agent's transient broken state blocks everyone else's verification, and an agent
that cannot run the gates cannot prove its own work.

**Intended fix: worktree isolation** — each agent gets its own checkout and its
own gate run, merged on completion.

**Not adopted at wave 3, deliberately.** The merge-back flow is unvalidated, and
introducing an unproven multi-branch merge on a 14-screen regulatory wave risks
losing work — a worse failure than the one it prevents. Wave 2's actual cost was
agents falling back to throwaway render tests: annoying, not damaging, and every
one of them still produced its evidence.

**Instead, wave 3 was dispatched in halves** to shrink the window in which any one
broken file blocks the others. That worked: `flutter analyze` clean, 11/11 tests,
zero cross-agent breakage.

Worktrees remain the right answer for a larger fan-out and should be validated on
a small, low-stakes wave before being trusted with one. This note is written down
rather than quietly dropped, because a process document that says one thing while
practice does another is the same defect as a code comment that lies.

## Flow pass — rulings that change the ROUTE GRAPH, and have no owner

**A structural gap, found 2026-08-27 — the third of its kind.** Waves are
per-screen and `lib/router/**` is fenced off from screen agents, so a ruling that
changes *the order screens appear in* has nobody assigned to it. It is the same
failure as the removals pass, wearing different clothes.

| # | ruling | required | status |
|---|---|---|---|
| F-1 | **R-1a**, superseded by **R-8a** (2026-08-27) — suitability + result + risk disclosure move to after OTP, before the (now three) legal documents | `otp_screen.dart` → questionnaire; `app_router.dart` gated-flow order; `app_state.dart:485`'s post-KYC trading gate **kept, not removed** — R-8a explicitly retains it as a fallback for returning investors | ✅ **DONE** by the flow pass, 2026-08-27 — see Applied section. |
| F-2 | new screens need routes | `s11` KYC checklist hub and `s07` post-signup overview needed routes; a third (`s49` `SetPriceAlertScreen`, S-11/X-7) was found unrouted too | ✅ **DONE** by the flow pass, 2026-08-27 — see Applied section. |

**R-1a is half-landed, which is worse than not started.** `approved.dart`'s
"Start investing → questionnaire" wiring was removed as ruled, so the quiz was
detached from its old home; but it was never attached to its new one. It survives
only because `app_state.dart`'s post-KYC trading gate still reaches it. A cleaner
removal would have orphaned the screen entirely and nobody would have noticed
until a user finished KYC.

**The lesson, now three times over:** a ruling is only executed if some pass owns
it. Screen waves own screens. The removals pass owns deletions. Nothing owned
*flow*, so flow changes evaporated — exactly the way the 31 unresolved `stubs.json`
entries did in the build that started all of this.

**Every future ruling must name which pass executes it** at the moment it is made.

### Flow pass — Applied, 2026-08-27

**R-8a (onboarding order).** Traced the live chain end to end rather than
inferring it: `otp_screen.dart`'s `_verify()` now calls
`context.go(Routes.questionnaire)` (was `Routes.termsOfService`).
`suitability_result_screen.dart`'s Continue button was already pushing
`Routes.riskDisclaimer` — unchanged. `risk_disclaimer_screen.dart` was
rewritten back to scroll-gated in-app rendering (see below) and its
`_accept()` now goes to `Routes.termsOfService` (was `Routes.home`).
`terms_and_privacy_screen.dart`'s bundle drops `risk_disclosure` (4 kinds →
3) and its accept action is unchanged (`Routes.createPasscode`), which
proceeds into passcode → biometric → `onboardingPersonal`/`onboardingAvatar`
→ `onboardingNextSteps` → KYC exactly as before. **Actual traced order now
matches R-8a exactly:** signup → OTP → suitability → result → risk
disclosure (own screen, scroll-gated) → 3 legal docs (phone viewer) →
passcode → biometric → KYC. `app_state.dart`'s post-KYC `tradingEligibilityGap`
fallback (`!suitabilityComplete` → questionnaire, `!riskDisclosureAccepted`
→ riskDisclaimer) is untouched — kept exactly as R-8a requires, for a
returning investor who onboarded before this order existed.

**`email` threading.** OTP → terms used to ride a single `extra`. With
suitability/result/risk-disclosure now between them, `email` can't survive
that many hops on one route `extra`. Added `AppState.pendingSignupEmail`
(set by `otp_screen.dart` right after verify, read by
`terms_and_privacy_screen.dart` when it hands off to `createPasscode`,
cleared in `_resetSessionState`) — same pattern `loginPasscodeSetup`
already uses for a value that can't ride `extra` cleanly.

**`setSignedIn(true)`.** Still fires in `risk_disclaimer_screen.dart`'s own
`_accept()`, unchanged in *how* — only *when*, since that screen now runs
right after suitability's result instead of after KYC. It is no longer the
last gated onboarding step; the router's `signedIn` branch is a pure
free-roam switch (`gated`/`preAuthOnly` sets only matter while signed out),
so firing early doesn't skip or short-circuit anything downstream — the
remaining screens (terms, passcode, biometric, avatar, KYC) are still
walked in order via explicit `context.go` calls regardless of `signedIn`.

**Bug found while tracing, fixed in the same pass:** `_gateRedirect`'s
`gated` set never included `Routes.onboardingPersonal` /
`Routes.onboardingAvatar`. Under the pre-existing (Wave 6) flow, nothing
set `AppState.signedIn` true until the very end of onboarding, so a fresh
signup hitting either screen while `signedIn == false` would have been
redirected straight back to splash — the flow was unreachable past
biometric. Added both (and the new `onboardingNextSteps`) to `gated`. Under
R-8a's order this is now moot for a fresh signup (`signedIn` is already
true by the time these screens are reached) but it's a real, independent
fix worth keeping regardless of entry order.

**Risk disclosure — restored scroll-gated in-app rendering.** Wave 6 had
rewritten `risk_disclaimer_screen.dart` to the phone-viewer/`url_launcher`
pattern. Restored the pre-Wave-6 scroll-gated version (recovered from git
history at `addc5ef`): `GET /legal-documents/content/risk_disclosure`
renders each section inline in a `SingleChildScrollView`, a
`ScrollController` listener flips `_scrolledToBottom` at
`maxScrollExtent - 24px` (plus a post-frame check for a document too short
to scroll at all), `KCheckbox` stays `disabled` until then. Added an empty
state (`doc.sections.isEmpty` — a published record with no sections yet,
distinct from a load error). R-2 still holds: the investor's computed
profile is never rendered — `RiskDisclaimerArgs.profile`/`widget.profile`
are carried only for route-contract compatibility, never read in `build()`.

**Three routes added.**
- `Routes.kycChecklist` (`/kyc/checklist`) → `KycChecklistScreen` (S-8).
  Rewired the 5 transitions X-5 names to land on the hub instead of
  hard-chaining to the next step: `chn_screen.dart` (Continue + both
  Skip paths), `checking.dart` (liveness-verify success),
  `bank_dcs_screen.dart` (both post-confirm paths),
  `declarations_screen.dart` (Continue), and `kyc_intro.dart`'s "Start"
  resume path (still fetches the draft to populate
  `AppState.kycForm.draftId` — critical, every later step screen needs it
  — but now hands off to the hub instead of jumping straight to a computed
  step; removed the now-dead `_stepRoutes` map). The "no draft yet" fresh
  start still goes straight to `Routes.kycBvn`, unchanged — X-5 only names
  the resume-map, not the first-ever entry.
- `Routes.onboardingNextSteps` (`/onboarding/next-steps`) → `WhatsNextScreen`
  (X-4). Repointed `avatar_screen.dart`'s `_skip()` and end-of-`_continue()`
  (both previously `Routes.kycIntro`) to it.
- `Routes.setPriceAlert(ticker)` (`/asset/:ticker/alert`) → `SetPriceAlertScreen`
  (S-11/X-7). Added a "Set a price alert" bell icon-button to
  `asset_detail_screen.dart`'s top bar, next to the watchlist toggle,
  calling `context.push(Routes.setPriceAlert(widget.ticker))`.

**Evidence — two previously-unrendered screens.** `bash scripts/design/shots.sh`
was run once at the end (not repeatedly, per this pass's own instruction) and
both `kyc_checklist_screen.dart` and `bank_dcs_screen.dart`'s confirm sheet
were opened and inspected; see the flow pass's own report for what was seen.

Gate/test counts before → after this pass: recorded in the flow pass's own
report rather than duplicated here.
