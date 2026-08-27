# Redesign 2026-08 — ruling sheet

Every app screen, and what the new canvas does or does not say about it.

Authority and standing rulings: `docs/redesign/DECISIONS.md`. Per-screen evidence: `docs/redesign/evidence/*.json`.

**Nothing in the build queue starts until the `needs-ruling` section is empty.**


| bucket | screens |
|---|---|
| needs-ruling | 39 |
| restyle-only | 14 |
| redesign-to-artboard | 28 |
| no-action | 10 |
| **total** | **91** |


## needs-ruling (39)

**No artboard covers these, and the reason is not obvious.** Each one is either a feature deliberately dropped from the redesign or one simply not redrawn yet. An agent cannot tell those apart, and guessing wrong either deletes a live feature or strands it on the dead design system. Rule each.

| screen | what it does | route | evidence | your ruling |
|---|---|---|---|---|
| `account/plans_screen.dart` | AI-credits subscription hub: shows remaining credits, lists plan tiers (free/plus/pro) with real prices, and … | `/account/plans (Routes.acctPlans)` | Searched the ENTIRE canvas (all 8 files) for 'AI credit', 'credit meter', 'plans & credit', and 'subscription' — zero matches anywhere, not just in the Account… | |
| `account/refer_earn_screen.dart` | Referral hub: shows the investor's referral code, copy/share actions, a friends-joined/credits-earned stats c… | `/account/refer (Routes.acctRefer)` | Searched the ENTIRE canvas for 'refer a friend', 'referral', and 'refer & earn' — zero matches anywhere in any of the 8 files. s51's Account-hub menu also has … | |
| `corporate_actions/agm_vote_screen.dart` | AGM detail: fetches the caller's most-relevant AGM meeting (open, not yet voted) and lets them cast a For/Aga… | `/corporate-actions/agm (Routes.corpActionsAgm, app_router.dart:340)` | Searched '06 Account and Support.dc.html' (the only file where 'rights issue'/'AGM' text appears) for >=2 distinctive phrases from this screen: 'Abstain' -> 0 … | |
| `corporate_actions/dividends_screen.dart` | Dividends detail: 'Paid to you this year' total via Direct Cash Settlement, an 'Unclaimed from before Kudimat… | `/corporate-actions/dividends (Routes.corpActionsDividends, app_router.dart:343)` | Searched the whole canvas for 'e-mandate' (2 hits, both in s55), 'e-dividend' (0), 'withholding'/'WHT' (0), 'dividend history' (0), 'Paid to you this year' (0)… | |
| `corporate_actions/rights_issue_screen.dart` | Rights-issue detail: shows entitlement/rights price/cost/close-date facts, then a numeric input letting the i… | `/corporate-actions/rights-issue (Routes.corpActionsRightsIssue, app_router.dart:338)` | Searched canvas for 'entitlement' -> 0 matches anywhere. 'lapse' -> 0 matches. 'Take up' (with a following number) -> 0 matches (only the fixed-label 'Take it … | |
| `home/home_screen.dart` | Home tab root. Two structurally different bodies: verified investor (balance/portfolio panel with inline wall… | `/home` | Searched canvas for 'Total wealth' and 'Grow with Kudimata' (both found in s22/s22d, lines 59 and 76 of '03 Home and Markets.dc.html') and for 'Finish verifyin… | |
| `home/notifications_screen.dart` | Pushed notifications feed: 'Today'/'Earlier' date-grouped list of pushed notifications, tap-to-open-and-mark-… | `/notifications` | Searched the entire canvas for 'notification' (case-insensitive, all *.dc.html files): the only hits are IconButton bell components on Home headers (label="not… | |
| `kyc/chn_screen.dart` | Ask whether the investor already has a CHN (CSCS number); collect it if yes, otherwise note one will be auto-… | `/kyc/chn` | Searched "Do you have a CHN" and "request one for me" (this screen's exact copy) across all 8 canvas .dc.html files — zero matches. Searched "CHN" alone — the … | |
| `kyc/next_of_kin.dart` | Collect next-of-kin name / relationship / phone / optional email (CSCS-required). Step 8 of 8 (final collecti… | `/kyc/next-of-kin` | Searched "next of kin" and "relationship" across all 8 canvas .dc.html files — zero matches. Searched "guardian" and "who to contact" (the app's own framing) —… | |
| `kyc/outcome_not_approved.dart` | Terminal non-approved KYC outcomes: rejected (resubmit if attempts remain, else contact support), flagged (ma… | `/kyc/outcome` | Searched "couldn't verify you", "Resubmit documents", "manual review", "Contact support", "verification expired", "submission expired" — zero matches across al… | |
| `kyc/review_submit_screen.dart` | Final review-before-submit screen (new, 2026-08-24): summarizes all 8 collected KYC pieces (BVN/NIN, CHN, ID,… | `/kyc/review` | Searched "Check before you send" (the screen's actual title) and "Review and submit"/"Review & submit" — zero matches anywhere in canvas. Searched "Submit for … | |
| `kyc/utility_bill.dart` | Upload a utility bill (proof of address) dated within the last 3 months. Step 5 of 8 in-app, a standalone upl… | `/kyc/utility-bill` | Searched "Where do you live?" and "utility bill" — both found in s17 (title "Where do you live?", body "A recent utility bill confirms it, any bill under 3 mon… | |
| `markets/asset_detail_screen.dart` | Pushed asset detail: back/ticker/name header with a plus-or-check watchlist toggle, hero price + range chart,… | `/asset/:ticker` | Searched for 'watchlist' and found the exact plus-icon 'add to watchlist' affordance the app implements at s26/s27's header (IconButton icon="plus" label="watc… | |
| `markets/explain_screen.dart` | Pushed AI 'Explain this investment' screen: Gemini-backed plain-English explainer with a typing/generating an… | `/explain/:topic` | Searched for 'explain' (case-insensitive, all files): only hits are marketing copy 'From ₦5,000. Explained in plain words.' on '01 Getting In.dc.html' (unrelat… | |
| `markets/price_alerts_screen.dart` | Pushed 'Price alerts' hub managing alerts across the investor's WHOLE watchlist at once: a featured card (fir… | `/watchlist/alerts` | Searched for 'preset' and '±' (percent-threshold syntax) across the whole canvas: the only hit is an unrelated 'Period presets or exact dates' phrase on the st… | |
| `markets/watchlist_screen.dart` | Pushed Watchlist: server-backed list of saved assets (AssetRow rows with a remove/X control), closed-market b… | `/watchlist` | See watchlist_finding above: searched 'watchlist' (2 hits, both the plus-icon 'add to watchlist' toggle on Asset Detail's header, s26/s27 -- no list-view scree… | |
| `onboarding/confirm_passcode_screen.dart` | Has the investor re-enter their just-chosen passcode to confirm it before it's saved; a mismatch shows an inl… | `Routes.confirmPasscode ('/passcode/confirm')` | Searched all 6 new canvas files for 'confirm passcode', 'enter it again', 're-enter' and 'passcode again' — no distinct confirm-passcode artboard exists anywhe… | |
| `onboarding/create_passcode_screen.dart` | Has the investor pick a new local passcode via a numeric keypad, then hands off to the confirm step. | `Routes.createPasscode ('/passcode/create')` | New canvas '05 · Create passcode' (#s05): title 'Create a passcode', body about opening the app on this phone, dot progress + 3x4 keypad — matches the app scre… | |
| `onboarding/document_summary_screen.dart` | Renders a single legal document's parsed heading/body text in-app, read-only, for review before or after acce… | `Routes.documentSummary ('/document-summary')` | Searched all 6 new canvas files for 'plain english', 'plain-English', and any in-app document-detail copy — none found. The new canvas's only document-list art… | |
| `onboarding/legal_preview_screen.dart` | Lets a not-yet-signed-up visitor read the legal documents — individually (LegalPreviewScreen) or as one scrol… | `Routes.legalPreviewPath ('/legal-preview/:kind') and Routes.legalBundlePreview ('/legal-preview')` | New canvas 'Reference · Terms and Disclosures, opened from the checkbox' (#s03c): 'Eight documents. Tap one to open the file', reachable from the password scre… | |
| `onboarding/personal_details_screen.dart` | Collects date of birth, residential address, city, state of residence, and phone number via an editable form,… | `Routes.onboardingPersonal ('/onboarding/personal')` | Searched all 6 new canvas files for 'date of birth', 'residential address', 'state of residence', and 'personal details' — the only DOB-bearing screen is 02 Ve… | |
| `onboarding/reset_passcode_screen.dart` | Lets a signed-out (or locally-locked-out) investor request an account password reset by email, then enter a c… | `Routes.reset ('/reset')` | New canvas '09 · Reset password' (#s09): title 'Reset your password', body 'We email a link to adebayo@email.com so you can set a new password', single 'Email … | |
| `onboarding/sign_up_screen.dart` | Collects the new investor's name, email, and password in one screen and creates the account. | `Routes.signup ('/signup')` | New canvas splits sign-up into three screens: '03 · What's your name?' (#s03, first/last name only), '03B · Email and phone' (#s03b, email + phone number), '03… | |
| `onboarding/welcome_slider_screen.dart` | A 3-slide illustrated carousel introducing the app to a first-time investor, ending in 'Get started' (sign up… | `Routes.welcome ('/welcome')` | New canvas '02 · Welcome' (#s02) is a SINGLE static screen (one growth illustration, "Own a piece of Nigeria's biggest companies." / 'From ₦5,000. Explained in… | |
| `portfolio/holding_detail_screen.dart` | Per-holding position detail: hero market value + gain/loss, Shares/Average cost/Market price/Dividends receiv… | `/portfolio/holding/:ticker (GoRoute, see lib/router/app_router.dart:275)` | Canvas 05 Portfolio and Wallet.dc.html, artboard s34 ('34 · One holding'): searched 'Your holding' -> found (s34 header 'MTNN / Your holding'); searched 'Worth… | |
| `portfolio/order_status_screen.dart` | Lists the investor's buy/sell orders (Open/All filter), per-order StatusPill, cancels the oldest pending orde… | `/orders (GoRoute Routes.orderStatus, lib/router/app_router.dart:263)` | Canvas 04 Buy and Sell.dc.html, artboard s41 ('Orders hub'): searched 'Orders' as screen title -> found (s41 header 'Orders'). Searched 'Filled so far' -> foun… | |
| `portfolio/portfolio_screen.dart` | Portfolio tab root: total value + all-time return, allocation visualization + legend, holdings-concentration … | `/portfolio (tab root, lib/router/app_router.dart:391)` | Canvas 05 Portfolio and Wallet.dc.html, artboard s33 ('33 · Portfolio'): searched 'Portfolio' title -> found. Searched app's exact digest wording 'Heavy on two… | |
| `shared/glossary_sheet.dart` | Shared 'explain this term' bottom sheet: shows a hand-written static definition (free, instant) plus an optio… | `UNROUTED (modal via showKSheet)` | Searched the whole canvas (all 8 *.dc.html files) for: 'glossary' (case-insensitive) -> 0 matches in any file; 'What does this mean' -> 0 matches; 'Explain fur… | |
| `suitability/legal_acceptance_screen.dart` | Shared, parameterized legal-document acceptance scaffold: fetches N legal documents, renders each one's FULL … | `UNROUTED itself (backs /suitability/terms via terms_and_privacy_screen.dart)` | Canvas artboard s03p ('01 Getting In.dc.html' lines 288-331, 'Create a password') has one checkbox: 'I have read and agree to the Terms and Disclosures', linki… | |
| `suitability/questionnaire_screen.dart` | The suitability quiz itself: 4 single-select radio questions (Investment Experience, Investment Objective, In… | `/suitability (Routes.questionnaire, app_router.dart)` | Searched canvas for the exact question/option text: 'Investment Experience', 'Investment Objective', 'Investment Horizon', 'Risk Tolerance', 'Capital Preservat… | |
| `suitability/risk_disclaimer_screen.dart` | Statutory Risk Disclaimer screen (Rule 76 compliance): renders the legal-team-authored risk_disclosure docume… | `/suitability/risk-disclaimer (Routes.riskDisclaimer, app_router.dart:232)` | Searched canvas for 'risk disclosure'/'Risk Disclosure' (case-insensitive) -> only 2 hits, both just the DOCUMENT NAME as a row label inside s03c's tap-to-open… | |
| `suitability/suitability_result_screen.dart` | Post-questionnaire screen. CURRENTLY shows only a generic 'Assessment complete' success message (illustration… | `/suitability/result (Routes.suitabilityResult, app_router.dart:230)` | Searched canvas for 'Assessment complete' -> 0 matches. Searched 'suitability'/'Suitability' -> 0 matches anywhere. The closest STRUCTURAL analog found: artboa… | |
| `suitability/terms_and_privacy_screen.dart` | Thin config wrapper: instantiates legal_acceptance_screen.dart with kinds=[terms_of_service, privacy_policy, … | `/suitability/terms (Routes.termsOfService, app_router.dart:247)` | Same evidence as legal_acceptance_screen.dart above: s03p's checkbox links to s03c's 8-document tap-to-open list. Additionally, this screen's own 'Step 2 of 4'… | |
| `trade/trade_flows.dart#buy_market` | LIVE buy flow (market order, market open): amount sheet (naira/shares toggle, quick-amount chips, 1.35% fee) … | `UNROUTED as a named route -- launched via showBuyFlow(context, asset) from asset-detail / holding-detail scre…` | Canvas 04 Buy and Sell.dc.html: searched 'Market buy' -> found in s29m's 'Order type' row, matching the app's own 'Order type: Market' row. Searched 'Buy MTNN'… | |
| `trade/trade_flows.dart#buy_market_closed` | LIVE buy-when-NGX-closed queuing sheet (_MarketClosedBuySheet): combined Amount + Limit-price entry in one sh… | `UNROUTED -- shown automatically by showBuyFlow(context, asset) when AppScope.marketOpen is false, in place of…` | Searched 'Waiting for the market to open' -> found in s40. Searched 'releases it back to your wallet' -> found in s40 ('Cancelling releases it back to your wal… | |
| `trade/trade_flows.dart#sell` | LIVE dedicated sell flow (spec screens 77-79): amount (shares/naira) + destination (wallet only -- bank optio… | `UNROUTED -- launched via showSellFlow(context, asset) from asset-detail / holding-detail screens; placed step…` | Searched 'Where the money goes' -> found in s48 (a real, enabled destination selector: 'First Bank ...6835' pre-selected with a checkmark, 'My Kudimata wallet'… | |
| `wallet/wallet_flows.dart#add_money` | LIVE Add Money flow: chooser (bank transfer vs card) -> bank-transfer sheet (dedicated virtual account number… | `UNROUTED -- launched via showAddMoneyFlow(context) from the Wallet screen.` | Searched 'How do you want to pay?' -> found in s36 (matches the app's chooser step). Searched 'Transfer to this account' -> found in s36, matching the app's vi… | |
| `wallet/wallet_flows.dart#withdraw_outside_hours` | LIVE 'queued withdrawal' variant (spec screen 63) shown outside ~09:00-21:00 weekdays or on weekends: same re… | `UNROUTED -- launched via showWithdrawFlow(context) from the Wallet screen; selects this variant when _isOutsi…` | Searched all *.dc.html for 'Queued for morning' (the app's own status-pill label for this state) -> 0 matches. Searched for 'Queue it for 09:00' (the app's own… | |
| `wallet/wallet_screens.dart#transaction_detail` | Pushed per-transaction detail: hero amount, status pill, Reference/Requested/Fee/Settlement rows, 'Get receip… | `/wallet/txn/:id (GoRoute, lib/router/app_router.dart:279)` | Searched 'Reference' as a row label -> found in s38 ('Reference · KD-4471902'), matching the app's own 'Reference' row. Searched 'Fees, all in' -> found in s38… | |

## restyle-only (14)

No artboard, but the screen clearly survives — bring it onto the new tokens and components without reinventing its layout. Confirm or override.

| screen | what it does | artboard | confidence | why |
|---|---|---|---|---|
| `account/bank_accounts_screen.dart` | Manage linked bank accounts: view the primary DCS-mandate account with its mandate explainer, view secondary … | — | none | Bank-account/DCS-mandate management is core regulated-broker functionality (referenced by s37's mandate copy … |
| `account/close_account_screen.dart` | Account-closure request flow: shows shares-to-move and wallet-payout summary, closure effects, links to the c… | — | none | Account closure is a required self-service/compliance flow (SEC record-keeping language already lives in the … |
| `account/dormant_account_screen.dart` | Full-screen status view shown when an account has gone dormant (12 months no sign-in): explains trading is pa… | — | none | A real account-lifecycle edge state with a live auto-redirect from login; no artboard exists anywhere, but it… |
| `account/faq_screen.dart` | General FAQ list (7 static Q&As) plus one real 'Article & Glossary' page (Settlement/T+3/DCS) reached specifi… | — | none | No FAQ/article artboard exists anywhere in the new canvas; basic customer-education content is not an obvious… |
| `account/freeze_account_screen.dart` | Confirm-and-freeze flow: shows the effects of freezing (blocks orders/withdrawals, signs out every device, re… | — | none | The freeze entry point is designed for in s54, but the actual confirmation screen this file implements has no… |
| `account/help_support_screen.dart` | Help & support hub: searchable FAQ row list, 'Talk to a person' contact card (email), a fraud-report nudge, a… | — | none | No Help & support hub artboard exists; this is basic customer-service infrastructure, not an obviously cut fe… |
| `account/legal_reference_screens.dart` | Four static reference-document viewers: Partner disclosures (who executes trades), Referral terms, Data notic… | — | none | These are real compliance/reference documents with no artboard drawn; keep and restyle, though 'Referral term… |
| `account/notifications_settings_screen.dart` | Email notification preference toggles: order updates, money-in/out & security, price alerts, and a local-only… | — | none | No artboard exists for notification preferences; this is basic account infrastructure with a real wired backe… |
| `account/security_alert_screen.dart` | Full-screen alert shown after an unrecognised sign-in (from a push notification or the notifications list): d… | — | none | A real, already-shipped security-critical screen (audit P0 per its own header comment) with no artboard anywh… |
| `account/statement_detail_screen.dart` | Per-broker breakdown of one monthly statement PDF: issuer card, a 'full breakdown is in the PDF' explainer (b… | — | none | A real, already-scoped screen (its own header comment documents exactly which backend fields are missing) wit… |
| `account/withdraw_mandate_screen.dart` | Type-to-confirm flow to withdraw the DCS mandate from a bank account: shows the effects, requires typing WITH… | — | none | A real, regulatorily-meaningful destructive action (with its own honest 'not available yet' backend gap alrea… |
| `kyc/_kyc_chrome.dart` | Shared KYC chrome: 44px top bar (back chevron + 'Verification · N of 8' step label) and a segmented step-prog… | — | likely | The header pattern (back + step label) is a genuine, repeated canvas convention. But the segmented progress-b… |
| `shared/confirm_passcode_sheet.dart` | Shared bottom sheet: confirm the user's existing 6-digit passcode (dots + numeric keypad) before a sensitive … | s08 (pattern match, full-screen not sheet) | likely | The exact passcode dots + keypad component exists in the design system (s08) and sheet-form-factor confirmati… |
| `shared/state_views.dart` | Shared library of KEmptyView / KErrorView / KLoadingView / KCentered state widgets used across nearly every s… | pattern present across many artboards, e.g. s23, s53, s35 (no single dedicated artboard) | likely | This is generic UI infrastructure, not a distinct screen concept — the design system's illustration/plate/but… |

## redesign-to-artboard (28)

Covered by a specific artboard. These need no ruling; they are the build queue. Listed so the count balances and so you can spot a wrong mapping.

| screen | what it does | artboard | confidence | why |
|---|---|---|---|---|
| `account/account_screen.dart` | Account hub tab: profile header, AI-credit meter, and a menu into every account sub-screen (personal info, ba… | s51 | likely | s51 is clearly the redesigned Account hub (same header shape, same avatar/status pattern, same Log out placem… |
| `account/complaint_screen.dart` | File a formal complaint: pick a category, optional order/transaction reference, free-text description, option… | s53 | likely | The complaints hub concept and category taxonomy are clearly designed for in s53; the detailed form fields ar… |
| `account/complaint_tracked_screen.dart` | Show one filed complaint's status: reference, category, filed/due dates, a register timeline (logged → under … | s53 | likely | The open-complaint status concept is clearly present in s53 (status pill, SLA countdown, reference), even tho… |
| `account/contract_note_screen.dart` | Show the itemised contract note for one executed order: issuer, executing broker (with logo), client/trade da… | s38 | likely | s38 is the closest new-canvas expression of a post-trade receipt naming the executing broker; the itemised fe… |
| `account/data_privacy_screen.dart` | NDPA consent hub: two toggleable consent switches (improve the app / product emails), a link to the retention… | s57 | likely | The screen's shape (consent toggles, export, delete/close, retention note) is a strong structural match to s5… |
| `account/legal_screen.dart` | Legal documents hub: lists the 4 real onboarding-acceptance documents (terms/privacy/risk/client-agreement) v… | s03c | likely | s03c is explicitly cross-referenced from Account in its own footer note, making this the one confident non-Ac… |
| `account/personal_info_screen.dart` | View locked identity fields (legal name, DOB, CHN) with a 'verified from BVN/NIN' note, and edit phone/email/… | s58 | certain | Near-exact structural and copy match — the strongest single mapping in this batch. |
| `account/security_screen.dart` | Security settings hub: change passcode, biometric-unlock toggle, always-on passcode-for-withdrawals row, sign… | s54 | certain | Strong structural match on the core security controls and devices list, with only the Log-out placement diffe… |
| `account/statements_screen.dart` | Statements & contract notes hub: a segmented Statements/Contract notes tab over one document list, 'prepare t… | s52 | certain | Direct structural and functional match — same document list concept, same downstream links to statement/contr… |
| `corporate_actions/corporate_actions_screen.dart` | Corporate-actions hub: lists pending decisions (open rights issues + open AGM votes needing an answer) and se… | s55 | certain | Direct, high-confidence match on title, structure (pending decision card + recent/settled list), and even the… |
| `home/search_screen.dart` | Pushed search screen: back + search pill header, live local-filter results list (AssetRow), persisted 'Recent… | s25 | likely | Core shell (back+pill+results list navigating to asset detail) matches s25 closely enough for a direct redesi… |
| `kyc/approved.dart` | KYC approved/success screen. Re-confirms real approval status via GET /kyc-submissions/me, shows a celebrator… | s21 | certain | s21 is a near-exact copy match for the approved/verified success state. Gap: s21's own CTAs are plain 'Add mo… |
| `kyc/bank_dcs_screen.dart` | Add a bank account for withdrawals/dividends and opt into Direct Cash Settlement (DCS); step 6 of 8 in-app. | s18, s18b | certain | Strong content/structure match (bank select, account number, auto-resolved name confirmation, DCS checkbox + … |
| `kyc/bvn_nin.dart` | Collect BVN + NIN (11 digits each), verify server-side against NIBSS, and create the draft KycSubmission. Ste… | s12, s13 | certain | Direct content match, but the canvas splits BVN/NIN into TWO screens (s12 entry + s13 confirm-details), while… |
| `kyc/checking.dart` | Interstitial while the real liveness-verification API call runs server-side; advances on success. Step 4 of 8… | s16 | certain | Copy and layout match closely. Sequencing differs: canvas's s16 goes straight to Bank (address/utility-bill w… |
| `kyc/declarations_screen.dart` | Two SEC-required declarations: PEP (politically exposed person) yes/no with who/position follow-up fields, an… | s19 | likely | PEP question is a real match on s19, but the app's actual content diverges on two points the canvas doesn't d… |
| `kyc/id_upload.dart` | Pick one ID type (Driver's licence / International passport / Voter's card / NIN) and upload/photograph it vi… | s14 | certain | Strong match on purpose/copy/layout (row-list ID picker, matching the app's 2026-08-20 fix from chips to a sh… |
| `kyc/kyc_intro.dart` | KYC intro screen: explains the (now 8-item) checklist, resumes an in-progress draft at the right step if one … | s10 | likely | s10 is the right intro-screen counterpart, but the app conflates s10 (intro) and s11 (checklist hub) into one… |
| `kyc/liveness.dart` | Real in-app camera selfie capture (live preview + shutter) with a web file-picker fallback; uploads and regis… | s15 | certain | Near-exact structural and copy match (circular camera frame, dashed guidance ring, single shutter). App addit… |
| `kyc/submitted.dart` | Post-finalize pending/review screen. Polls status every 8s (capped at 10 minutes), shows a real per-signal ch… | s20 | certain | Strong structural match — illustration, title, body copy, progress-checklist card, and CTA all present in s20… |
| `markets/markets_screen.dart` | Markets tab root: 'Markets' title + search icon button, a sector PillChip row (All + real backend sectors), o… | s24 | likely | Core purpose and list/filter structure map cleanly to s24; the missing Market-mood card and Biggest-gainers r… |
| `onboarding/avatar_screen.dart` | Lets a newly-verified investor optionally pick a character avatar (or skip, keeping just their name) right af… | s06b | likely | Same purpose and interaction as #s06b, but the canvas places avatar directly between Face ID (06) and 'What h… |
| `onboarding/biometric_screen.dart` | Offers to enable Face ID/fingerprint unlock right after passcode creation; either 'Enable' or 'Not now' signs… | s06 | certain | Near-verbatim copy and layout match to #s06; identical position in the flow (immediately after passcode) in b… |
| `onboarding/log_in_screen.dart` | The single returning-user entry point: a local passcode/biometric unlock for a trusted device, or a real emai… | s08, s08p | likely | Core two modes match #s08/#s08p well; the step-up OTP mode is real, necessary security functionality with no … |
| `onboarding/otp_screen.dart` | Has a freshly-signed-up investor enter the 6-digit code emailed to them to verify their address. | s04 | certain | Very close copy and structure match to #s04; only drift is an extra 'I can't access this email' button in the… |
| `onboarding/splash_screen.dart` | Launch screen shown briefly on cold start; decides and routes to the local-unlock screen (returning investor)… | s01 | certain | Near-exact copy and layout match to #s01; identical purpose and position (first screen, decides where to rout… |
| `wallet/wallet_flows.dart#withdraw` | LIVE Withdraw flow (normal hours, ~09:00-21:00 weekdays): amount + destination (fixed to primary/first saved … | s37, s30 | likely | Strong content and behavioral match: fee facts agree, arrival-time copy agrees, and both the live app and the… |
| `wallet/wallet_screens.dart#wallet_home` | Wallet tab root: available balance (naira), Add money / Withdraw buttons, recent transactions list, 'Orders' … | s35 | certain | Direct structural and purpose match with only copy-level differences -- a straightforward rebuild against s35. |

## no-action (10)

Helpers, barrel files and unrouted code. No design coverage owed.

| screen | what it does | artboard | confidence | why |
|---|---|---|---|---|
| `account/account_widgets.dart` | Shared local widget library for the Account section (KIconBubble, KAccountRow, KRowChevron, KAccountCard, KAc… | — | none | Pure helper/shared-widget file; design coverage is inherited from whatever screens use it, not assessed on it… |
| `account/tax_documents_screen.dart` | Tax documents screen: 'this year so far' dividend/WHT summary from real data, plus a static 'not available ye… | — | none | No artboard exists, and the screen is currently unreachable from any live UI in the app itself (hidden by dir… |
| `corporate_actions/corporate_actions_widgets.dart` | Screen-local shared widgets for this cluster: KCorpActionScaffold (detail-header + scroll body), KFactRow (la… | s55 | likely | Pure helper file — its fate follows whatever the human decides for the screens that use it (corporate_actions… |
| `kyc/kyc_form_state.dart` | Pure in-memory ChangeNotifier holding cross-screen KYC session state (draft id, next-of-kin fields, selfie-ca… | — | none | Not a design artifact. Its held fields matter only through the screens that read/write them (next_of_kin, dec… |
| `markets/market_hours.dart` | Utility file, not a screen: `isNgxOpenNow()`/`marketNextOpenLabel()`/`marketClosedBannerSubtitle()` (WAT-time… | — | none | This file is a shared utility/banner, not a page with its own route -- there is no artboard-shaped surface he… |
| `onboarding/_pickers.dart` | Provides the two reusable picker bottom-sheets (Nigerian state-of-residence, phone country-code) and the unde… | — | none | Helper/shared-widget file, not a user-facing screen — no design coverage is meaningful here. |
| `onboarding/locked_out_screen.dart` | Shows a 15-minute lockout screen after too many wrong local-passcode attempts, offering 'Reset with my email'… | — | none | Genuinely uncovered in the new canvas AND unreachable in the live app (no attempt counter exists, no caller n… |
| `onboarding/onboarding_scaffold.dart` | Shared onboarding chrome and controls (step-label top bar, passcode dots, numeric keypad, OTP cells, scrollab… | — | none | Helper/shared-widget file, not a user-facing screen. |
| `trade/order_fill_progress_screen.dart` | Dedicated part-fill progress screen (spec screen 80): fill timeline, progress bar, 'See the contract notes' +… | — | none | This app screen is dead code by its own header comment (UI-ready, not wired into any real navigation path; no… |
| `trade/price_moved_screen.dart` | Dedicated 'price moved above your limit at market open' decision screen (spec screen 62): Buy at open / Raise… | — | none | Dead code (unrouted, no trigger mechanism exists) and no canvas artboard designs this specific post-open deci… |

---

# Findings the agents were asked to answer directly


### kyc · kyc_step_sequence

```json
[
  {
    "artboard": "s10",
    "step": "Intro \u2014 \"Let's verify your identity\" / Start",
    "app_route": "/kyc"
  },
  {
    "artboard": "s11",
    "step": "Checklist hub (spine of the flow \u2014 every step returns here; lists exactly 5 tasks: BVN&NIN, Documents, Selfie, Bank account, Two questions)",
    "app_route": null
  },
  {
    "artboard": "s12",
    "step": "Step 1 of 5 \u2014 BVN & NIN entry",
    "app_route": "/kyc/bvn"
  },
  {
    "artboard": "s13",
    "step": "Step 1 of 5 \u2014 \"Is this you?\" (confirm name/DOB/phone from BVN records)",
    "app_route": null
  },
  {
    "artboard": "s14",
    "step": "Step 2 of 5 \u2014 Your documents (pick + photograph one ID type)",
    "app_route": "/kyc/id"
  },
  {
    "artboard": "s17",
    "step": "Step 2 of 5 (same step as s14) \u2014 Address (street/state/LGA) + utility-bill upload",
    "app_route": "/kyc/utility-bill"
  },
  {
    "artboard": "s15",
    "step": "Selfie check (live camera capture in circular frame)",
    "app_route": "/kyc/liveness"
  },
  {
    "artboard": "s16",
    "step": "Checking (interstitial while liveness verifies server-side)",
    "app_route": "/kyc/checking"
  },
  {
    "artboard": "s18",
    "step": "Step 4 of 5 \u2014 Add bank account + Direct Cash Settlement opt-in",
    "app_route": "/kyc/bank-dcs"
  },
  {
    "artboard": "s18b",
    "step": "Confirm-bank-account bottom sheet",
    "app_route": null
  },
  {
    "artboard": "s19",
    "step": "Step 5 of 5 \u2014 Two questions (PEP; broker/NGX-employment)",
    "app_route": "/kyc/declarations"
  },
  {
    "artboard": "s20",
    "step": "Under review (post-Finish, async pending state)",
    "app_route": "/kyc/submitted"
  },
  {
    "artboard": "s21",
    "step": "Verified (success \u2014 CTAs: Add money / Browse the market first)",
    "app_route": "/kyc/approved"
  }
]
```

### kyc · suitability_attachment_point

Attach the suitability quiz immediately after s21 'Verified' (Routes.kycApproved), before its 'Add money'/'Browse the market first' CTAs are allowed to proceed to Home — i.e. as the true last step of the KYC-and-onboarding sequence, gating entry into the rest of the app rather than being wedged into the s10-s19 document-collection steps. Evidence: (1) the app ALREADY wires this exact attachment point today — approved.dart's KMilestoneSheet 'Start investing' button calls context.go(Routes.questionnaire) per a direct, restored 2026-08-24 SEC-compliance product instruction ('please make the suitability mandatory'), so no route restructuring is needed, only restyling s21 to add the gate. (2) The canvas's own s20 'Under review' step is an ASYNC wait (1-2 business days per its copy) with no guarantee the investor is still in the app when it resolves — inserting a synchronous quiz there, or earlier among s10-s19's document-collection steps, would either block on a real KYC-review call or force an investor to answer suitability questions before their identity is even confirmed. s21 'Verified' is the first point after a synchronous, in-session decision is possible. (3) No 'risk profile'/'profiling' framing exists anywhere in the canvas's s10-s21 KYC screens (confirmed via the 'politically exposed'/PEP searches above and a full-text read of s19-s21) — the attachment point introduces the quiz cleanly without inheriting risk-profiling language from the canvas.


### markets-home · watchlist_finding

The new canvas has NO dedicated watchlist screen under any current artboard id. Full-text search of every *.dc.html file in docs/design/redesign-2026-08/ for 'watchlist' returns exactly 2 hits, both identical: an IconButton icon="plus" label="watchlist" in the Asset Detail header (lines 540 and 611 of '03 Home and Markets.dc.html', screens s26 'Asset detail · About' and s27 'Asset detail · Order book') — i.e. an 'add to watchlist' toggle with no screen anywhere that lets the investor view the resulting list. Searches for 'saved', 'following', 'star', 'my list', and 'favor(ite)' across all canvas files return zero hits — the watchlist is not designed under any alternate name either. This is a broken/incomplete flow as designed: you can add a stock to your watchlist from the asset page, but there is no artboard showing 'my watchlist'. The app's own watchlist_screen.dart (lib/screens/markets/watchlist_screen.dart, lines 170-181) already documents half of this: its code comments say the PRE-CONSOLIDATION canvas ('grew 66 -> 97 screens', per price_alerts_screen.dart's header) had a Watchlist screen at old-id s46 whose footer note named it as one of only two entry points into a Price Alerts screen at old-id s86. That old s46 has been dropped entirely from the current 56-artboard canvas (current s46 is 'Sell step 2 - Your price per share' in '04 Buy and Sell.dc.html', an unrelated screen) and was never replaced with a new watchlist artboard. Price alerts ARE fully designed in the current canvas, but as a self-contained loop that does not depend on a watchlist screen: 'Set a price alert' (s49) is reached from the Asset Detail page itself (specifically its market-closed variant, s39, via a 'Set a price alert' button — the open-market asset page s26/s27 does not show this button anywhere), and s49 links to 'My alerts' (s50), a flat list of the investor's alerts (each with its own absolute rises-above/falls-below price threshold) with a 'New alert' button that loops back to s49. So: the canvas's price-alerts feature is complete and does not require a watchlist screen to function, but the app's actual watchlist_screen.dart is architecturally load-bearing in the live app — Routes.priceAlerts has exactly one call site in the whole codebase, watchlist_screen.dart's 'Manage price alerts' button — so deleting/redesigning Watchlist without adding a replacement entry point would strand the app's real, backend-CRUD-wired Price Alerts management screen (lib/screens/markets/price_alerts_screen.dart) with no way to reach it, even though the canvas's OWN price-alert flow doesn't need that entry point. Separately, the app's alert data model (percent-of-day-move presets '±3%/±5%/±10%' plus a per-watchlist-hub editor) does not match the canvas's model (one alert per asset, absolute ₦ price + direction, set from that asset's own page) at all -- see price_alerts_screen.dart's evidence entry below.


### markets-home · home_variants_finding

'Home Variants.dc.html' is a standalone, orphaned exploration file: nothing in any other canvas file links to it (grepped 'Home Variants' and '#l1'/'#3e'/'nav.l1'/'nav.3e' across every *.dc.html — the only hits are the file's own internal self-links). Its own heading text (line 34) reads 'Kudimata Invest · home · 3E approved, light reworked' and the section title (line 35) is 'Home, final pair'. Artboard id="l1" is captioned 'Light · reworked' with a closing note 'Light card: paper + hairline, purple tint chips, illustration locked into the top row.' Artboard id="3e" is captioned 'Dark · approved' with closing note 'Approved: neutral charcoal, dark grey money card, purple accents, clean navbar.' Together they read as a two-artboard exercise to finalize ONE visual detail (the money-card surface treatment and a 4-action evenly-spaced quick-action row: Add/Withdraw/Invest/Learn, no Orders action) across light and dark, not a competing full Home design. The canonical, currently-wired Home is s22 ('22 · Home, verified') and s23 ('23 · Home, first time (verification not finished)') in '03 Home and Markets.dc.html', section 3 of 6 -- confirmed canonical because every other canvas file that refers to Home does so by that section/screen number ('01 Getting In.dc.html' line 677: 'Look around → Section 3 (Home)'; '02 Verification.dc.html' line 751: 'Browse → Section 3 (Markets)'), and s22/s23 are the versions all downstream screens (s24 Markets, s26/27 Asset detail, etc.) link back to via their own nav objects. Note s22/s23 themselves diverge from what l1/3e (and s22/23's own section-header prose) describe: the header text for section 3 promises 'four round actions' but s22/s23 actually render FIVE (Add/Withdraw/Invest/Orders/Learn) in a horizontal-scroll row, whereas l1/3e literally have four, evenly spaced, with no Orders action -- i.e. l1/3e is closer to the file's own written spec than s22/23 is. That inconsistency is itself worth flagging to the human, but does not change which pair is canonical: s22/s23 are.


### suitability-corp · profiling_language

```json
[
  {
    "location": "lib/screens/suitability/risk_disclaimer_screen.dart:176-193 (comment block, code REMOVED 2026-08-24)",
    "status": "REMOVED from the live UI, but documented in a comment as the exact copy that used to render",
    "quote": "you have been categorized as a [Conservative / Moderate / Aggressive] investor. Investing in assets outside of your designated risk profile can lead to severe financial distress.",
    "note": "Comment explicitly flags this as NOT silently dropped: 'that field is the one element the compliance doc explicitly requires ON THIS SCREEN... the app no longer shows the investor their categorisation anywhere, which compliance should sign off before go-live.' The direct product instruction that triggered removal: \"There is still an investor profile on the risk legal doc view on kyc please remove that container\"."
  },
  {
    "location": "lib/screens/suitability/suitability_result_screen.dart:91-104 (comment block, code REMOVED 2026-08-24)",
    "status": "REMOVED from the live UI, but documented in a comment as the exact copy that used to render",
    "quote": "this screen used to announce the computed profile (\"YOUR PROFILE / Conservative\" + rationale) and carry a \"What this unlocks\" card whose second row read \"Only Nigerian shares for now \u2014 no foreign stocks\".",
    "note": "Direct product instruction that triggered removal (quoted verbatim in the code comment): \"WHY ARE WE STILL PROFILING???? AND WHY ARE WE SAYING ONLY NIGERIAN SHARES FOR NOW??? A SIMPLE COMPLETION OR SUCCESS SCREEN IS ENOUGH.\" Current live copy is generic: 'Assessment complete' / \"Thanks \u2014 that helps us keep what you see here suited to you. There's one short notice to read, then you're ready to invest.\""
  },
  {
    "location": "lib/screens/suitability/questionnaire_screen.dart:49-80",
    "status": "LIVE \u2014 question/option wording, not a result display",
    "quote": "The Risk Tolerance question's own options are the document's literal (Conservative)/(Moderate)/(Aggressive) labels... 'If my investment portfolio drops by 20% in a month, I will: Panic and liquidate all assets immediately (Conservative) / Do nothing and wait for recovery (Moderate) / View it as a buying opportunity and invest more (Aggressive)'",
    "note": "This is question INPUT wording (asking the investor to self-assess), not a classification shown back to them \u2014 does not present a computed risk profile, so it is the questionnaire itself, which the product owner ruled SURVIVES."
  },
  {
    "location": "lib/data/repositories/suitability_repository.dart:1-84 (LIVE, backend-facing only)",
    "status": "LIVE \u2014 computation still happens, but the result is not displayed anywhere in the UI",
    "quote": "The backend (Kudimata-Securities-Backend src/suitability-result/scoring.ts) derives a real risk profile from the submitted answers... GET /suitability-result/me -> SuitabilityResult { profile, rationale }",
    "note": "`SuitabilityResult.profile` is fetched and threaded through (suitability_result_screen.dart passes it into `RiskDisclaimerArgs(profile: result.profile)`), but as of the 2026-08-24 removals documented above, NO screen currently reads or displays that `profile` value anywhere. The classification is computed and persisted server-side but invisible to the user in the app's current state \u2014 this already matches the 'we are not profiling anything' framing at the UI layer, though the underlying scoring model/field still exists."
  }
]
```

### suitability-corp · suitability_quiz_shape

```json
{
  "step_count": 4,
  "questions": [
    {
      "prompt": "Investment Experience",
      "options": [
        "No experience (Beginner)",
        "Limited experience (Have bought basic stocks/mutual funds)",
        "Extensive experience (Active trader, familiar with derivatives/leverage)"
      ]
    },
    {
      "prompt": "Investment Objective",
      "options": [
        "Capital Preservation (Low risk, safety of principal)",
        "Balanced Growth (Medium risk, capital growth + income)",
        "Aggressive Growth (High risk, maximum capital appreciation)"
      ]
    },
    {
      "prompt": "Investment Horizon",
      "options": [
        "Short-term (Less than 1 year)",
        "Medium-term (1 to 3 years)",
        "Long-term (More than 3 years)"
      ],
      "note": "Carries a 'What does this mean?' glossary-sheet link (static, hand-written definition, no AI) because the term is jargon."
    },
    {
      "prompt": "If my investment portfolio drops by 20% in a month, I will:",
      "options": [
        "Panic and liquidate all assets immediately (Conservative)",
        "Do nothing and wait for recovery (Moderate)",
        "View it as a buying opportunity and invest more (Aggressive)"
      ]
    }
  ],
  "interaction": "Linear, one question per screen, single-select radio cards (no pre-selected default), a slim step-progress bar (i.e. 'Question N of 4'), Back/Next buttons, Next disabled until the current question has an answer. Submits all 4 answers as one POST /suitability-result on the last question, then navigates to the (now profile-free) result screen.",
  "source_of_truth": "Wording is verbatim from the firm's real SEC-facing compliance intake document ('My observations on KSL papers.docx'), replacing a previous invented 7-question set on 2026-08-24 \u2014 this is the authoritative shape to rebuild, not the old 7-question version."
}
```

### suitability-corp · glossary_finding

```json
{
  "designed_in_new_canvas": false,
  "evidence": "Grepped all 8 files under docs/design/redesign-2026-08/*.dc.html, case-insensitive, for 'glossary' -> zero matches in any file (confirms the word-count hint: 7 old / 0 new). Also searched for the MECHANISM independent of the word 'glossary' \u2014 'What does this mean', 'Explain further', 'Still don't understand' \u2014 zero matches for all three anywhere in the canvas. There is no dedicated glossary index/list screen anywhere in the current app either (no glossary_screen.dart exists); the app's only 'glossary' surface is lib/screens/shared/glossary_sheet.dart, a tap-a-term bottom sheet used app-wide (asset detail, trade flows, FAQ, and this batch's questionnaire_screen.dart for its one jargon term, 'Investment Horizon').",
  "conclusion": "The glossary sheet MECHANISM (not just the word) is genuinely absent from the new design system. Since the surviving suitability questionnaire currently depends on it for one term, and other surviving screens (trade flows, FAQ, asset detail) also depend on it, this needs a ruling: either the new design system needs a defined 'explain a term' pattern designed, or the existing sheet ships restyled-but-not-redesigned."
}
```

### trade-wallet · buy_sell_journey

```json
{
  "source": "04 Buy and Sell.dc.html (34 artboards -- the largest canvas file), read in on-page order",
  "note": "The canvas's buy/sell paradigm is 'name your price' (limit order) FIRST, with 'buy now'/'sell now' (market order) as an explicit alternate branch chosen up front on a dedicated 'How to buy'/'How to sell' screen -- structurally different from the live app, where a market order is simply the unlabelled default and there is no such up-front choice screen.",
  "ordered_sections": [
    {
      "header": "Step 1 \u00b7 How to buy",
      "artboards": [
        "s42",
        "s42d"
      ]
    },
    {
      "header": "Step 2 \u00b7 Your price per share (naming your price)",
      "artboards": [
        "s43",
        "s43d"
      ]
    },
    {
      "header": "Step 3 \u00b7 How many shares (naming your price)",
      "artboards": [
        "s43b",
        "s43bd"
      ]
    },
    {
      "header": "Step 4 \u00b7 Review, naming your price",
      "artboards": [
        "s29",
        "s29d"
      ]
    },
    {
      "header": "Step 5 \u00b7 Market closed sheet, over the review",
      "artboards": [
        "s29c",
        "s29cd"
      ]
    },
    {
      "header": "Step 3 (buy now) \u00b7 How many shares",
      "artboards": [
        "s43m",
        "s43md"
      ]
    },
    {
      "header": "Step 4 (buy now) \u00b7 Review",
      "artboards": [
        "s29m",
        "s29md"
      ]
    },
    {
      "header": "Step 6 \u00b7 PIN, then order placed",
      "artboards": [
        "s30",
        "s30d"
      ]
    },
    {
      "header": "(unlabelled -- literal 's31' header text in the source, likely a placeholder left in the canvas)",
      "artboards": [
        "s31",
        "s31d"
      ]
    },
    {
      "header": "Step 7 \u00b7 Bought, at the real prices",
      "artboards": [
        "s44",
        "s44d"
      ]
    },
    {
      "header": "Orders hub \u00b7 reached from the home quick actions",
      "artboards": [
        "s41",
        "s41d"
      ]
    },
    {
      "header": "Sell step 1 \u00b7 How to sell",
      "artboards": [
        "s45",
        "s45d"
      ]
    },
    {
      "header": "Sell step 2 \u00b7 Your price per share",
      "artboards": [
        "s46",
        "s46d"
      ]
    },
    {
      "header": "Sell step 3 \u00b7 How many shares (naming your price)",
      "artboards": [
        "s47",
        "s47d"
      ]
    },
    {
      "header": "Sell step 4 \u00b7 Review the sale",
      "artboards": [
        "s48",
        "s48d"
      ]
    },
    {
      "header": "Sell step 3 (sell now) \u00b7 How many shares",
      "artboards": [
        "s46m",
        "s46md"
      ]
    },
    {
      "header": "Sell step 4 (sell now) \u00b7 Review",
      "artboards": [
        "s48m",
        "s48md"
      ]
    }
  ]
}
```

### trade-wallet · dead_flows

```json
[
  {
    "flow": "lib/screens/trade/order_fill_progress_screen.dart (whole screen, spec screen 80)",
    "evidence": "File header: 'UI-ready, NOT wired into any real navigation path... no partial-fill DATA exists anywhere in this app's model.' Confirmed no call site in lib/router/*.dart (grep for OrderFillProgressScreen: zero matches)."
  },
  {
    "flow": "lib/screens/trade/price_moved_screen.dart (whole screen, spec screen 62)",
    "evidence": "File header: 'UI-ready, NOT wired into a route... reaching it for real needs an event this mobile client has no way to receive yet.' Confirmed no call site in lib/router/*.dart (grep for PriceMovedScreen: zero matches)."
  },
  {
    "flow": "lib/screens/trade/trade_flows.dart -- the shared _AmountSheet/_ReviewSheet/_OrderPlacedScreen's `_Side.sell` branches (the pre-77-79 generic sell path)",
    "evidence": "File header, 2026-08-23 pass: 'The `_Side.sell` branches left in the shared sheets below are dead code as of this pass (nothing calls them with `side: _Side.sell` anymore) -- kept rather than stripped to limit the size of this diff.' Confirmed: showSellFlow() calls _runSellFlow() (the dedicated 77-79 implementation), never _runTradeFlow(..., side: _Side.sell); showBuyFlow() is the only caller of _runTradeFlow and always passes side: _Side.buy."
  },
  {
    "flow": "lib/screens/wallet/wallet_screens.dart -- TxnType.convert handling in _TxnRow (icon/color switch cases)",
    "evidence": "File header: 'NGX-only: no USD wallet / Convert flow in the UI (HIDE phase -- TxnType.convert stays as dead code below).' The enum case is handled defensively in _icon/_iconColors but the backend has no way to actually produce a convert-type Txn for an NGX-only product; wallet_flows.dart's own header separately confirms 'the Convert (\u20a6 -> $) flow was removed.'"
  }
]
```
