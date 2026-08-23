# Kudimata Invest — Mobile Redesign Screen Specs

Source: "Soft Landing" redesign canvas mockup (single long HTML doc, `design_doc_mode: canvas`), 73 numbered blocks total. Screens 01–66 are 390×880 phone frames (mobile app, in scope). Screens 67–73 are 600px-wide email templates (`EmailShell` component) — **out of scope for this mobile spec**, listed briefly at the end for reference only.

Design tokens referenced throughout (do not redefine, pull from design-system tokens/colors.css etc.): `--paper`, `--bg`, `--ink`, `--ink-2`, `--ink-3`, `--indicator` (grape accent), `--indicator-press`, `--feature` (grape plate bg used for Splash), `--feature-ink`, `--feature-ink-2`, `--warm`, `--sun`, `--gain` (green), `--loss` (red), `--track` (neutral fill/divider), `--hairline` (1px border), `--r-card`, `--r-input`, `--r-feature`, plus type tokens `--text-hero/title/section/card-title/body/data/label/micro` each with matching `--track-*` letter-spacing, and `--font-core`/`--font-display`.

Every screen shows a status bar row (`9:41` / `LTE`, or local time in Flow G) at the very top — noted once here, only called out per-screen when the time differs (Flow G) or the bar is unusual.

Flow ids in the doc map 1:1 to screens (`nav.sNN`, `#sNN` anchors) — these are the canonical screen IDs; keep them as code/route names where convenient (s01…s66).

---

## Flow A · Getting in (Screens 01–12)
Entry: cold app launch.

### 01 — Splash
- **Copy:** "Kudimata Invest" (display wordmark) · "Own a piece of Nigeria's biggest companies" · footer: "Kudimata Securities Ltd · SEC registered"
- **Layout:** Status bar → centered column (flex:1, centered both axes): brand Mark (86px, white) + wordmark title + tagline → bottom area: Spinner (20px) + regulatory footer line, uppercase micro text.
- **Components:** `Mark` (size 86, white=true, asset-base assets/brand), `Spinner` (size 20).
- **Illustration:** none (brand mark only, not an illustration asset).
- **Colour notes:** Whole phone frame background is `var(--feature)` (grape plate), not `var(--bg)` — the only screen with a feature-tinted full-bleed background. Text uses `--feature-ink` / `--feature-ink-2` (light-on-grape), not standard ink tokens.
- **Nav:** First launch → 02; returning signed-out → 11; session alive → Home (phase 2, not in this doc).
- **Status:** Reskin of existing splash screen.

### 02 — Welcome slider
- **Copy:** Slide 1 title "Investing, explained as you go"; body "Buy shares in MTN, Dangote and 140 other companies on the Nigerian Exchange from ₦5,000. We explain every term the first time you meet it."; buttons "Get started" / "I already have an account".
- **Layout:** Status bar → header row (Wordmark + LanguageSwitch) → OnboardingSlide (illustration + title + body, index 0/3, dot progress) → bottom-pinned 2-button stack.
- **Components:** `Wordmark` (size 20, sub "Invest"), `LanguageSwitch` (value "en"), `OnboardingSlide` (name onboarding-welcome, index 0, count 3), `Button` (primary lg full-width "Get started"), `Button` (ghost lg full-width "I already have an account").
- **Illustration:** `onboarding-welcome` inside OnboardingSlide, ~470px tall, full width.
- **Nav:** From 01 · Get started → 03 · Log in → 11.
- **Status:** Reskin. Note: `LanguageSwitch` present with value "en" — **NEW: language switch (English/other, e.g. Pidgin) is a first-class header control**, appears on multiple screens.

### 03 — Create your account
- **Copy:** Title "Create your account"; subhead "Two minutes now. Verification comes after."; field labels: Full name (placeholder "Adebayo Okonkwo"), Email (placeholder "you@email.com", helper "We send your verification code here"), Phone number (prefix +234, placeholder "801 234 5678"), Referral code (placeholder/suffix "Optional"); legal line "By continuing you agree to our Terms of Service, Privacy Policy and Risk Disclosure." (each a link); button "Continue".
- **Layout:** Status bar → Wordmark → title block → 4 stacked Inputs → bottom-pinned legal text + Continue button.
- **Components:** `Wordmark`, `Input` ×4 (one with `icon="mail"`, one with `prefix="+234"` `numeric`), `Button` (primary).
- **Nav:** From 02 · Continue → 04 · doc links → 06.
- **Status:** Reskin.

### 04 — Verify your email
- **Copy:** "Step 1 of 4"; title "Check your email"; body "We sent a 6-digit code to adebayo@email.com."; helper "Resend code in 00:42 · Change email"; buttons "Verify email" / "I can't access this email".
- **Layout:** Status bar → back button + step indicator → Illustration banner → title/body → 6-cell OTP input row (3 filled digits, 1 focused/empty w/ focus ring, 2 empty) → resend/change-email line → bottom 2-button stack.
- **Components:** `IconButton` (back), `Illustration` (name "email-sent", role banner, plate default, ~180px), `Button` ×2 (primary "Verify email", ghost "I can't access this email").
- **Illustration:** `email-sent`, banner role, default plate, 180px tall.
- **Nav:** From 03 · Verify → 05 · no access → 12.
- **Status:** Reskin.

### 05 — Terms & disclosures
- **Copy:** "Step 2 of 4"; title "Terms & disclosures"; body "Four documents, one agreement. Each one has a plain-English summary."; document list rows: "Terms of Service" (v4 · Read), "Privacy Policy" (v2 · Read), "Risk Disclosure" (v3 · Read), "Client Agreement" (v4 · Read); NudgeCard body "Share prices fall as well as rise. Only invest money you won't need for the next few years."; checkbox label "I have read and agree to all four documents" / description "Terms of Service · Privacy Policy · Risk Disclosure · Client Agreement"; button "Accept and continue".
- **Layout:** back+step → title/body → 4-row bordered document list card (each row = doc name + version/Read tag, tappable) → NudgeCard (grape tone) → Checkbox → bottom Accept button.
- **Components:** `IconButton`, `NudgeCard` (tone="grape", guide-src avatar illustration), `Checkbox` (checked, with description), `Button` (primary).
- **Illustration:** small guide avatar (`assets/illustrations/avatars/guide.svg`) inside NudgeCard.
- **Colour notes:** NudgeCard explicitly grape-toned (not warm) for the "you can lose money" risk warning.
- **Nav:** From 04 · any doc → 06 · Accept → 07.
- **Status:** Reskin.

### 06 — Document, in plain English
- **Copy:** Header "Risk Disclosure"; DocumentSummary title "What this document says"; summary "Trading shares can lose you money, and Kudimata cannot promise any return. You are the one deciding what to buy."; footnote "The English original is the authoritative version. Summaries are generated and free on every plan."; button "Back to the agreement".
- **Layout:** back + doc-name header + LanguageSwitch → DocumentSummary card (kind "Legal document", bullet points from data) → footnote → bottom secondary button.
- **Components:** `IconButton`, `LanguageSwitch`, `DocumentSummary` (kind, title, summary, points list, ~430px), `Button` (secondary).
- **Status:** **NEW: AI/plain-English legal-document summarizer** — a generated, per-document plain-language explainer layer over the raw legal text (explicitly "summaries are generated"), not a typical KYC-app screen. Reachable both mid-onboarding and later from Account → Legal.

### 07 — Create a passcode
- **Copy:** "Step 3 of 4"; title "Create a passcode"; body "Six digits. You'll use it to open the app and to approve withdrawals."
- **Layout:** back+step → centered title/body + 6-dot progress (3 filled indicator-colored, 3 empty track-colored) → bottom-pinned numeric keypad (1-9, blank, 0, back-icon key).
- **Components:** `IconButton`, `Icon` (back, in keypad).
- **Nav:** From 05 · 6 digits entered → 08.
- **Status:** Reskin.

### 08 — Confirm your passcode
- **Copy:** "Step 3 of 4"; title "Enter it again"; error body "That didn't match. Try the six digits again." (in `--loss` red); same numeric keypad.
- **Layout:** identical to 07 but 6-dot progress rendered in `--loss` red (all filled, since it's showing a mismatch state) and body text in loss color.
- **Colour notes:** Error/mismatch state uses `--loss` for both the dots and the message — a real validation-error styling, not just a generic warning.
- **Nav:** From 07 · match → 09 · mismatch stays on 08.
- **Status:** Reskin.

### 09 — Unlock faster
- **Copy:** "Step 4 of 4"; StatusView title "Unlock with your face"; message "Skip the passcode next time. Your face never leaves your phone — we only ever see a yes or a no."; buttons "Turn on Face ID" / "Not now".
- **Layout:** step label → centered StatusView (illustration + title + message) filling remaining space → bottom 2-button stack.
- **Components:** `StatusView` (name "sign-in", tone "pending", plate default, ~420px), `Button` ×2 (primary with icon-left fingerprint, ghost).
- **Illustration:** StatusView's "sign-in" illustration, pending tone, default plate.
- **Nav:** From 08 · either action → 10 · later changeable in Account → Security.
- **Status:** Reskin.

### 10 — A few more details
- **Copy:** Title "A few more details"; body "This keeps your account secure and compliant."; fields: Date of birth (placeholder "14 Mar 1994"), Gender (Select, value "Male"), State of residence (Select, value "Lagos"), Residential address (placeholder "12 Bourdillon Road, Ikoyi"), Employment status (Select, value "Employed"); button "Continue".
- **Layout:** title/body → 5 stacked form fields (mix of Input/Select) → bottom Continue button.
- **Components:** `Input` ×2, `Select` ×3.
- **Nav:** From 09 · Continue → 13.
- **Status:** Reskin.

### 11 — Log in
- **Copy:** Greeting "Welcome back, Adebayo" / email "adebayo@email.com"; Password field (dots shown, icon lock); link "Forgot your password?"; buttons "Log in" / "Use Face ID"; footer "New here? Create an account".
- **Layout:** Wordmark → Avatar + greeting row → Password Input + forgot-password link → bottom 2 buttons + footer link.
- **Components:** `Wordmark`, `Avatar` (src per-user illustration/photo placeholder, size 56), `Input` (password, icon lock), `Button` (primary "Log in"), `Button` (secondary, icon-left fingerprint, "Use Face ID").
- **Nav:** From 01/02 · Log in → Home or 13 if KYC unfinished · Forgot → 12.
- **Status:** Reskin.

### 12 — Reset your password
- **Copy:** "Reset · step 2 of 2"; title "Choose a new password"; body "Enter the code sent to adebayo@email.com and your new password."; fields: Reset code (6 digits), New password (helper "At least 8 characters, one number"), Confirm new password (shows error "Passwords don't match yet"); buttons "Save and log in" / "Resend the code".
- **Layout:** back+step → title/body → 3 stacked inputs (one showing an inline error state) → bottom 2-button stack.
- **Components:** `IconButton`, `Input` ×3 (password type, one with `error` prop).
- **Nav:** From 11 or 04 · Save → 11.
- **Status:** Reskin.

---

## Flow B · Verification / KYC (Screens 13–26)
Entry: after sign-up, or the Home banner. Screens 14–21 share a common chrome: back button + "Verification · N of 8" micro label + an 8-segment progress bar (filled segments = `--indicator`, unfilled = `--track`).

### 13 — Verify to start investing
- **Copy:** Title "Verify to start investing"; body "The NGX requires this before your CSCS account can open. Eight steps, about six minutes."; numbered checklist (1–8): "BVN and NIN", "CHN, if you already have one" (tagged Optional), "A photo of your ID", "A quick selfie check", "A utility bill", "Bank account for Direct Cash Settlement", "Two declarations", "Next of kin"; footnote "Then we provision your NGX account — that part is on us, and takes up to one business day."; buttons "Start verification" / "Look around first".
- **Layout:** small Illustration banner → title/body → bordered card with 8 numbered rows (circular number badge, indicator-tinted) → footnote → bottom 2-button stack.
- **Components:** `Illustration` (name "kyc-intro", role small, ~130px), `Button` ×2.
- **Nav:** From 10 or Home banner · Start → 14 · Look around → Home browse-only mode.
- **Status:** Reskin (standard KYC intro/checklist).

### 14 — BVN & NIN
- **Copy:** "Verification · 1 of 8"; title "Verify your identity"; body "We check these with NIBSS. Nothing is shared with anyone else."; fields: BVN (11 digits, helper "Dial *565*0# on your registered line to see yours"), NIN (11 digits); ExplainPanel "What is a BVN for?" — "It's the number your bank already uses to prove you are you. We use it to match your name to your bank account so your money can only ever come back to you."; button "Continue".
- **Components:** `Input` ×2, `ExplainPanel` (title, guide-src avatar, ~240px).
- **Status:** Reskin, but the `ExplainPanel` inline jargon-explainer pattern recurs — **note as part of the same AI/comprehension layer as screen 06**.

### 15 — CHN · optional
- **Copy:** "Verification · 2 of 8 · optional"; title "Do you have a CHN?"; body "Only if you've invested on the NGX before. If not, we'll get one for you — nothing to do here."; radio options "Yes, I have a CHN" (selected, indicator-tinted card) / "No, or I'm not sure — request one for me"; CHN input (placeholder "e.g. 1234567890", helper "On any old contract note, or ask your previous broker"); ExplainPanel "What is a CHN?" — "Your permanent ID at the CSCS, the register of who owns which Nigerian shares. One person, one CHN, for life."; buttons "Continue" / "Skip — create one for me".
- **Components:** `Radio` ×2, `Input`, `ExplainPanel`, `Button` ×2.
- **Colour notes:** Selected radio option card is indicator-tinted with 1.5px indicator border vs plain paper/hairline for the unselected option — this selected-card treatment recurs for radio/choice groups throughout (20, etc).
- **Nav:** Continue/Skip → 16 · mismatched CHN → 26 (manual review).

### 16 — Upload your ID
- **Copy:** "Verification · 3 of 8"; title "Upload your ID"; body "All four corners visible, no glare."; "ID type" label with PillChips: "Driver's licence" (selected), "Passport", "Voter's card", "NIN slip"; FileUpload "Front" (file already attached) and "Back" (prompt "Take a photo, or choose a file", hint "JPG or PDF · up to 10 MB"); button "Continue".
- **Components:** `PillChip` ×4, `FileUpload` ×2.
- **Status:** Reskin. Note: mockup copy still says plain "Passport" (recent app changes rename this to "International passport" and added "Voter's card" — voter's card is already present here, but the passport rename is not reflected in this mockup — flag as a copy discrepancy to reconcile against current app strings, not a new feature).

### 17 — Selfie check
- **Copy:** "Verification · 4 of 8"; title "Look straight ahead"; body "Good light, no hat, no glasses. Fill the frame with your face and take one photo."; footnote "We check the photo against your ID after you send it — that takes a few seconds, and you can retake it if it fails."; buttons "Take the photo" / "My camera won't work".
- **Layout:** oval camera-guide frame (250×330, pill/oval radius 140px, dashed indicator-soft border, indicator-tint fill) containing an Avatar placeholder.
- **Components:** `Avatar` (160px, inside the oval guide).
- **Nav:** pass → 18 · fail returns to 17 with reason · camera problem → 26.

### 18 — Utility bill
- **Copy:** "Verification · 5 of 8"; title "Upload a utility bill"; body "Dated in the last three months and showing the address you gave us."; FileUpload "Proof of address"; "We accept" card: "PHCN or IBEDC bill · water bill · waste bill · bank statement with your address · tenancy agreement"; NudgeCard "Bill not in your name?" — "Upload it anyway and add a short note in the next step — our desk reviews these by hand."; button "Continue".
- **Components:** `FileUpload`, `NudgeCard` (default tone, guide avatar).
- **Nav:** Continue → 19.

### 19 — Bank & Direct Cash Settlement
- **Copy:** "Verification · 6 of 8"; title "Add your bank account"; body "One account, in your own name. Dividends and sale proceeds land here directly."; Bank select (value "Guaranty Trust Bank"); Account number (value "0123456789"); name-match confirmation row "ADEBAYO OKONKWO" / "Name matches your BVN" (green check icon); DCS explainer block: "Direct Cash Settlement" / tag "Required by the NGX" / body "With DCS, money from a sale or a dividend goes from the CSCS to your bank account — it never sits with a broker. That includes us." / checkbox "Use this account for Direct Cash Settlement" (checked); footnote "Withdrawals can only ever go to a DCS account in your name. You can add another later in Account → Bank accounts."; button "Continue".
- **Components:** `Select`, `Input`, `Icon` (check, gain-colored), `Checkbox`, `Button`.
- **Colour notes:** DCS explainer block sits on a full `--indicator-tint` plate (`--r-feature` radius) — a distinct "grape feature card" treatment used for the single most legally-important disclosure on this screen.
- **Nav:** Continue → 20 · name mismatch → 26.
- **Status:** Reskin, standard for NGX brokers, but the DCS explainer treatment is worth flagging as a comprehension-layer touch.

### 20 — Declarations · PEP
- **Copy:** "Verification · 7 of 8"; title "Two declarations"; body "The SEC requires both. A yes is fine — it only means a person reviews your file."; Q1 card: "Do you, a family member or a close associate hold public office?" / helper "Elected office, a government or military post, a party role." / Yes (selected) / No radios / Select "Who holds the position?" (value "A family member") / Input "Position and body" (placeholder "e.g. Commissioner, Lagos State"); second card: Checkbox "I trade for myself, with my own money" / description "Trading for someone else needs a different account type" (checked); footnote "A false declaration can close your account. Nothing here is shared outside Kudimata Securities Ltd and the regulator."; button "Continue".
- **Components:** `Radio` ×2, `Select`, `Input`, `Checkbox`, `Button`.
- **Nav:** Continue → 21 · a "yes" PEP declaration routes to enhanced review (visible on 23 and 26).

### 21 — Next of kin
- **Copy:** "Verification · 8 of 8"; title "Next of kin"; body "Who should we contact about your account if we can't reach you? The CSCS requires this."; fields: Full name (placeholder "Ngozi Okonkwo"), Relationship (Select, value "Sibling"), Phone number (+234, placeholder "802 987 6543"), Email (placeholder "Optional"); button "Review and submit".
- **Components:** `Input` ×3, `Select`.
- **Nav:** → 22.

### 22 — Review & submit
- **Copy:** Header "Check before you send"; summary rows (each with an "Edit"/"Retake" link back to its step): "BVN · NIN" (masked "2214••••901 · 7788••••120"), "CHN" ("1234567890 · existing"), "ID" ("Driver's licence · 2 files"), "Selfie" ("Captured 14 Mar 2026 · 09:38", link "Retake"), "Proof of address" ("IBEDC bill · Feb 2026 · 2.4 MB"), "Bank · DCS" ("GTB ••••6789 · Direct Cash Settlement on"), "Declarations" ("Public office · family member · trading for myself"), "Next of kin" ("Ngozi Okonkwo · Sibling"); optional note field "Anything we should know?"; footnote "By submitting you confirm these details are yours and accurate. Kudimata Securities Ltd is required to verify them before your CSCS account opens."; button "Submit for verification".
- **Layout:** single bordered card listing all prior-step answers as rows, each row right-aligned with an Edit/Retake link jumping back to that step.
- **Components:** `Input` (note), `Button`.
- **Nav:** any Edit → back to that step · Submit → 23.

### 23 — Checking your details
- **Copy:** StatusView title "Checking your details" / message "This usually takes a few minutes. We'll notify you when you're verified — you can close the app."; checklist: "BVN matched" (check/gain), "ID read" (check/gain), "Address and bank name under review" (spinner), "Public-office declaration · enhanced review" (spinner); button "Look around while you wait".
- **Components:** `StatusView` (name "kyc-checking", tone pending, ~400px), `Icon` (check, gain) ×2, `Spinner` ×2, `Button` (secondary).
- **Nav:** checks pass → 24 · needs a human → 26.

### 24 — NGX account under review
- **Copy:** Title "Your NGX account is being opened"; body "Your details are verified. The exchange has to provision your trading account before your first order — up to one business day. We'll notify you."; checklist: "Identity verified" (check), "CHN 1234567890 assigned" (check), "DCS account linked · GTB ••••6789" (check), "NGX trading account · submitted 14 Mar 2026" (spinner) + StatusPill "Under review"; footnote "You can fund your wallet now — your first order goes through the moment the exchange confirms."; buttons "Add money to my wallet" / "Browse the market meanwhile".
- **Components:** `Illustration` (name "loading", small, ~150px), `Icon` (check ×3), `Spinner`, `StatusPill` (status "review"), `Button` ×2.
- **Nav:** exchange confirms → 25 · rejected by NGX → 26.

### 25 — You're verified
- **Copy:** MilestoneSheet eyebrow "NGX account live · 14 Mar 2026"; title "You're ready to invest"; body "Your NGX trading account is open and your CHN is registered. One short questionnaire and we'll know which products suit you."; button "Answer 7 questions".
- **Components:** `MilestoneSheet` (name "kyc-approved", ~470px, celebratory full-bleed milestone card), `Button`.
- **Nav:** → 27 (Suitability).
- **Status:** Reskin (celebratory milestone pattern, common in fintech onboarding).

### 26 — Needs manual review
- **Copy:** StatusView title "A person needs to look at this"; message "Your utility bill is in another name, so our desk reviews it by hand. We'll email you within one business day."; StatusPill "Under review"; buttons "Upload a different bill" / "Talk to support".
- **Components:** `StatusView` (name "kyc-not-approved", tone pending, ~400px), `StatusPill` (status review), `Button` ×2.
- **Nav:** From 23, 24 or 17 · re-upload → 18 · support → 56 (Help). Explicitly designed to "never be a dead end."
- **Status:** Reskin.

---

## Flow C · Suitability (Screens 27–28)
Entry: after verification, last gate before Home.

### 27 — Suitability questionnaire
- **Copy:** "Question 3 of 7"; question "Your shares drop 20% in a month. What do you do?"; options: "Sell everything — I can't watch that" / "Hold and wait it out" (selected) / "Buy more at the lower price"; inline link "What is this question for?"; buttons "Back" / "Next question".
- **Layout:** back + step label + 7-segment progress bar → question text → 3 radio-option cards (selected one indicator-tinted) → inline ExplainTrigger link → bottom Back (fixed-width secondary) + Next (full-width primary) button pair.
- **Components:** `Radio` ×3, `ExplainTrigger` (variant inline, "What is this question for?"), `Button` (secondary, fixed 100px) + `Button` (primary, full-width).
- **Status:** Reskin, but the per-question `ExplainTrigger` ("what is this question for?") is another instance of the same **AI/comprehension layer** as screens 06 and 14.

### 28 — Your investor profile
- **Copy:** Eyebrow "Your profile"; result "Balanced"; body "You'll take some ups and downs for better long-term returns, but not wild swings."; "What this unlocks" card: check "NGX shares and ETFs", check "NGX-listed ETFs and bonds", alert-icon "Only NGX-listed instruments for now — no foreign stocks"; footnote "You can retake this any time in Account → Personal info."; buttons "Go to my home" / "Change an answer".
- **Components:** `Illustration` (name "suitability-accepted", role banner, **plate="sun"**, ~180px), `Icon` (check ×2 gain, alert ×1 ink-3), `Button` ×2.
- **Colour notes:** Illustration plate is `sun` (warm-yellow) — the one screen in this flow that breaks from the default/grape plate convention, signaling a positive milestone.
- **Nav:** → phase-2 Home · Change an answer → 27.
- **Status:** Reskin (standard risk-profile result screen for a regulated broker).

---

## Flow D · Home, markets and trading (Screens 29–37)
Entry: the Home tab. NGX-listed instruments only.

### 29 — Home · verified
- **Copy:** Greeting "Good morning" / "Adebayo"; BalancePanel label "Portfolio value", balance "₦2,418,650.00", change "+₦34,210 · 1.43% today"; quick actions "Add money" / "Buy shares" / "Orders"; DigestCard "Your week on the NGX" — "Banking shares carried your portfolio this week — GTCO is up 4.1% since Monday. MTN slipped 0.8% after its tariff filing. Nothing here needs a decision from you today."; "Your holdings" list (MTNN 120 shares ₦268.40 +1.94%, GTCO 400 shares ₦48.15 +4.10%).
- **Layout:** avatar+greeting+search+bell header → BalancePanel → 3-up quick-action grid → DigestCard → "Your holdings" label + AssetRow list → BottomNav (value "home").
- **Components:** `Avatar` (40px, tappable → 45), `IconButton` (search, bell), `BalancePanel`, `Icon` (plus/markets/clock in quick actions), `DigestCard` (guide avatar), `AssetRow` ×2, `BottomNav`.
- **Status:** Reskin, but the `DigestCard` — an AI-generated weekly narrative summary of the user's portfolio ("nothing here needs a decision from you today") — is **NEW: AI portfolio-digest/narrator layer**, not a typical Home screen widget.

### 30 — Home · not verified yet
- **Copy:** Header "Browse only"; onboarding-progress feature card: "Get set up · 1 of 3 done" + StatusPill "In progress"; headline "Three things and you can buy your first share"; checklist: "Account created / Email verified" (done, green check), "Verify your identity / Step 3 of 8 · about 4 minutes left" (active, indicator-highlighted, numbered "2"), "Fund your wallet / ₦5,000 minimum to buy a share" (numbered "3", greyed); button "Continue where you left off"; "Biggest mover today · NGX" row (Dangote Cement); footnote "You can follow prices and read explanations while you verify — orders open when the NGX confirms your account."
- **Components:** `StatusPill` (pending, "In progress"), `Icon` (check, chevronRight), `Button` (md), `AssetRow`, `BottomNav`.
- **Colour notes:** Setup-progress card sits on full `--indicator-tint` / `--r-feature` plate (same grape-feature treatment as screen 19's DCS block) — used consistently for "this is the one important thing" callouts.
- **Status:** Reskin (progressive-onboarding home state, common pattern), but browse-only market access pre-KYC is a deliberate UX choice worth flagging.

### 31 — Search
- **Copy:** SearchPill value "dang", placeholder "Search NGX companies"; Results: "Dangote Cement" (DANGCEM · Industrial goods, ₦486.00, −0.62%), "Dangote Sugar" (DANGSUGAR · Consumer goods, ₦58.20, +1.10%); "Recent" pills: MTNN, GTCO, NGX 30 ETF; NudgeCard (grape) "Not sure what to search for?" — "Try a sector — banking, telecoms, cement — and we'll show the NGX-listed companies in it."; button "Browse all of the market".
- **Components:** `SearchPill`, `AssetRow` ×2, `PillChip` ×3, `NudgeCard` (tone grape), `Button` (ghost).
- **Status:** Reskin.

### 32 — Markets · NGX
- **Copy:** Header "Markets"; index row "NGX All-Share" "104,562.18" "+0.84% today" "Open · closes 14:30"; SegmentedControl (value "Shares"); category PillChips "All" (selected), "Banking", "Telecoms", "Consumer"; AssetRow list (MTNN, GTCO, DANGCEM, NESTLE, ZENITHBANK) each with sparkline.
- **Components:** `IconButton` (search), `SegmentedControl`, `PillChip` ×4, `AssetRow` ×5 (with `sparkline` prop), `BottomNav` (value "markets").
- **Status:** Reskin.

### 33 — Asset detail · MTNN
- **Copy:** Header "MTN Nigeria" / "MTNN · NGX · Telecoms"; price "₦268.40" / "+₦5.10 · +1.94% today"; ProductCard: market "Ordinary shares · NGX Main Board", risk "high", fee "1.35% all-in", liquidity "Daily · T+3", minimum "₦5,000"; stat tiles "Dividend yield 6.20%" / "You own 120 shares"; buttons "Sell" / "Buy".
- **Components:** `IconButton` (back, plus→watchlist), `LineChart` (range 1M), `ProductCard` (with `onExplain` hook), `Button` ×2 (secondary "Sell", primary "Buy").
- **Nav:** Explain this → 34 · Buy/Sell → 35 (note: Sell button's nav target is written as `nav.s77` in the source, past the 73 screens actually in this doc — likely a stray reference to an un-mocked Sell flow; treat "Sell" as opening an analogous amount/review/confirm flow to Buy 35→36→37, not yet detailed in this canvas).
- **Status:** Reskin.

### 34 — Explain this · generated answer
- **Copy:** Header "Explain MTNN"; ExplainPanel "What am I buying?" with a streaming GeneratingText answer (`explainAnswer`, state "writing"); a "thinking" state block labelled "While it thinks · before any text exists" (2-line shimmer); follow-up PillChips: "What is a dividend?", "Why T+3?", "Explain in Pidgin"; CreditMeter "7 of 10" (kind "trial"); buttons "I'm ready to buy" / "See plans and credits".
- **Components:** `IconButton` (close), `CreditMeter` (compact, in header; full below), `ExplainPanel`, `GeneratingText` (states "writing" and "thinking"), `PillChip` ×3, `Button` ×2.
- **Nav:** from 33 or any Explain trigger · thinking → writing → done (explicitly never a bare spinner) · out of credits → 54 (paywall gate) · plans → 53.
- **Status:** **NEW: full generative-AI "Explain this investment" feature** — an LLM-style streaming explainer with a trial credit meter and a monetized plans/credits upsell (see 53–55). This is the centerpiece of the "comprehension layer" theme seen in 06, 14, 15, 27. "Explain in Pidgin" also ties to the language-switch feature (02, 06).

### 35 — Buy · amount
- **Copy:** Sheet title "Buy MTNN"; SegmentedControl (Naira/Shares, value "Naira"); amount input "50,000" helper "≈ 186 shares at ₦268.40 · minimum ₦5,000 · wallet ₦214,300.00"; quick-amount pills "₦5,000" / "₦50,000" (selected) / "₦100,000" / "Max"; order summary rows "Order type: Market", "Fees · 1.35%: ₦675.00", "Total to pay: ₦50,675.00"; footnote "The NGX closes at 14:30. Orders placed after that queue for the next trading day."; buttons "Cancel" / "Review order".
- **Layout:** bottom Sheet over a scrim-dimmed background.
- **Components:** `Sheet`, `SegmentedControl` (sm), `Input` (amount, prefix ₦), `PillChip` ×4, `Button` ×2.
- **Nav:** Review → 36 · insufficient wallet balance → 41 (Add money).

### 36 — Buy · review order
- **Copy:** Sheet title "Review order"; rows: "Buying: MTN Nigeria · MTNN", "Shares: 186 · market price", "Amount: ₦50,000.00", "Fees · commission, NGX, SEC, CSCS: ₦675.00", "Settles: T+3 (glossary term) · 19 Mar 2026", "Total: ₦50,675.00"; footnote "A market order fills at the best price available, which can differ from the price shown. Shares register to your CHN at the CSCS."; buttons "Back" / "Place order".
- **Components:** `Sheet`, `GlossaryTerm` (tappable "T+3" → 56), `Button` ×2.
- **Nav:** Place order → 37 · a rejection returns here with the reason named.

### 37 — Order placed · first trade
- **Copy:** MilestoneSheet eyebrow "Your first order"; title "Order placed"; body "186 MTNN shares for ₦50,675.00. It fills while the NGX is open and settles on 19 Mar 2026."; StatusPill "Filling"; buttons "Track this order" / "Go to my portfolio".
- **Components:** `MilestoneSheet` (name "milestone-first-trade", ~430px), `StatusPill` (pending, "Filling"), `Button` ×2.
- **Nav:** Track → 44 · Portfolio → 38. Note: "the milestone sheet only shows once, then it is a plain confirmation" for subsequent orders.
- **Status:** Reskin (first-trade celebration pattern).

---

## Flow E · Portfolio, wallet and money out (Screens 38–46)
Entry: the Portfolio and Wallet tabs.

### 38 — Portfolio
- **Copy:** Header "Portfolio"; BalancePanel label "Total value", balance "₦2,418,650.00", change "+₦418,650 · 20.93% all time"; AllocationDonut center "4 holdings", legend Telecoms 42% / Banking 31% / Industrial 18% / Consumer 9%; DigestCard eyebrow "Portfolio health", title "Heavy on two names" — "MTNN and GTCO are 73% of what you own — if either falls hard, the whole portfolio feels it."; holdings list (MTNN 120 shares avg ₦241.10 → ₦32,208.00 +11.32%; GTCO 400 shares avg ₦44.02 → ₦19,260.00 +9.38%).
- **Components:** `BalancePanel`, `AllocationDonut` (size 120, ramp-1..4 colors), `DigestCard`, `AssetRow` ×2, `BottomNav` (value "portfolio").
- **Status:** Reskin, but `DigestCard` here again does **AI-generated portfolio-risk commentary** (concentration-risk narrative) — same NEW comprehension-layer component as screen 29.
- **Nav:** empty state offers Markets (32) instead of a blank list.

### 39 — Holding detail
- **Copy:** Header "MTN Nigeria" / "Your holding · MTNN"; value "₦32,208.00" / "+₦3,276.00 · +11.32% since you bought"; detail rows: Shares 120, Average cost ₦241.10, Market price ₦268.40, Dividends received ₦4,120.00, Held in "CSCS · CHN 1234567890", Executing broker "Blue Marina · BM-4471"; "Your orders in MTNN" list: "Bought 60 · ₦238.00" (04 Feb 2026 · settled, StatusPill "Filled"), "Bought 60 · ₦244.20" (27 Feb 2026 · settled, "Filled"); buttons "Sell" / "Buy more".
- **Components:** `Icon`/`IconButton`, `StatusPill` (approved, sm, "Filled") ×2, `Button` ×2.
- **Status:** Reskin. Note "Executing broker · Blue Marina · BM-4471" line — implies a **co-branded/introducing-broker model** (Kudimata + an executing broker partner), worth confirming against the business model; not a UI-only concern but changes what data the holding-detail screen must surface.

### 40 — Wallet
- **Copy:** Header "Wallet"; BalancePanel label "Available to invest", balance "₦214,300.00", change "₦50,675.00 held for a pending order" (change-tone loss); buttons "Add money" / "Withdraw"; "Recent activity" (link "See all"): "Bank transfer in" (+₦250,000.00, 14 Mar · 09:12 · GTB), "Bought MTNN · 186" (−₦50,675.00, 14 Mar · 09:41 · pending), "MTN dividend" (+₦4,120.00, 28 Feb · paid by DCS); footnote "Withdrawals go only to your DCS account · GTB ••••6789 · usually within one business day."
- **Components:** `BalancePanel`, `Button` ×2 (icon-left plus/send), `Icon` (arrowDown, markets, wallet — each in a colored circle: indicator-tint, track, sun-tint respectively), `BottomNav` (value "wallet").
- **Nav:** Add money → 41 · Withdraw → 42 · any row → 43.

### 41 — Add money
- **Copy:** Sheet title "Add money"; virtual-account plate: "Your account number" / "9902 4471 08" / "Providus Bank · Adebayo Okonkwo"; buttons "Copy number" / "Share details"; info rows "Transfer fee: Free", "Arrives: Usually under 5 minutes", "Send from: Any account in your name"; footnote "Money sent from an account that isn't yours is returned — the NGX requires the names to match."; button "I've sent it".
- **Components:** `Sheet`, `Button` ×3.
- **Colour notes:** The account-number plate uses full `--feature` grape background with `--feature-ink`/`--feature-ink-2` text and a `--sun`-colored eyebrow label — the same "feature plate" treatment as the Splash screen, reused here for the single most important piece of data on the sheet (the virtual account number).
- **Nav:** From 40, 29 or 24 · I've sent it → 40.
- **Status:** Reskin (virtual-account/dedicated-NUBAN funding pattern common in Nigerian fintech).

### 42 — Withdraw
- **Copy:** Sheet title "Withdraw"; amount input "100,000" helper "₦214,300.00 available · minimum ₦1,000 out"; destination row "GTB ••••6789 · DCS account" / "Adebayo Okonkwo" (check icon); fee rows "Fee: ₦50.00", "Arrives: Within 1 business day", "You receive: ₦99,950.00"; footnote "Money from a sale is available after it settles on T+3. Your passcode confirms this withdrawal."; buttons "Cancel" / "Review".
- **Components:** `Sheet`, `Input` (amount), `Icon` (wallet, check), `Button` ×2.
- **Nav:** Review → passcode step (not separately mocked) → 43 · no DCS account yet → 19.

### 43 — Transaction detail
- **Copy:** Header "Transaction"; amount "−₦100,000.00"; StatusPill "On its way"; body "Withdrawal to GTB ••••6789. Money usually lands the same business day."; detail rows: Reference "KDM-8841-2026", Requested "14 Mar 2026 · 09:52", Fee "₦50.00", Settlement "Direct Cash Settlement"; buttons "Download receipt" / "Back to wallet".
- **Components:** `Illustration` (name "wallet-fund", role small, **plate="warm"**, ~150px), `StatusPill` (pending, "On its way"), `Button` ×2.
- **Colour notes:** Illustration plate is `warm` here (distinct from the grape/sun plates used elsewhere) — used for neutral/in-progress money-movement states.
- **Nav:** receipt → 52 · failures name the reason and offer support.

### 44 — Orders
- **Copy:** Header "Orders"; SegmentedControl (value "Open"); order rows: "Buy MTNN · 186" (Market · ₦50,675.00 · 09:41, StatusPill pending "Filling"), "Sell GTCO · 100" (Queued for 17 Mar · market opens 10:00, StatusPill review "Queued"), "Buy DANGCEM · 20" (Cancelled · price moved past your limit, StatusPill rejected "Cancelled"); NudgeCard (grape) "Why is my order still filling?" — "A market order fills in pieces when a company trades thinly. You'll get a notification the moment it completes."; buttons "Cancel the MTNN order" (destructive) / "Go to my portfolio".
- **Components:** `SegmentedControl`, `StatusPill` ×3 (pending/review/rejected variants), `NudgeCard`, `Button` (variant "destructive") + `Button` (ghost).
- **Nav:** a queued order can be cancelled here until execution · filled orders move to 39 · empty state → 32.

### 45 — Account
- **Copy:** Name "Adebayo Okonkwo" / "CHN 1234567890 · NGX account live"; StatusPill "Verified"; CreditMeter "7 of 10" (compact) + link "Plans & credits"; menu rows: "Personal info", "Bank accounts & DCS" (value "GTB ••••6789"), "Plans & credits", "Statements & documents", "Security", "Refer & earn", "Corporate actions", "Tax documents", "Data & privacy", "Help & support", "Legal" (value "8 documents"); LanguageSwitch (value "en").
- **Components:** `Avatar` (56px), `StatusPill`, `CreditMeter` (compact), `Icon` (chevronRight ×11), `LanguageSwitch`, `BottomNav` (value "account").
- **Nav:** rows → 49, 64, 53, 52, 50, 55, 56, 06. Note: "Corporate actions" (→ s81), "Tax documents" (→ s85) and "Data & privacy" (→ s91) link to screen ids **beyond the 73 blocks present in this canvas** — they are referenced menu destinations not yet mocked here; flag as future/out-of-scope-for-this-doc screens the Flutter build will need placeholders or separate specs for.
- **Status:** Reskin (standard Account/Settings hub), but "Plans & credits" and the CreditMeter surfaced directly on this hub screen are part of the **NEW AI-credits monetization layer** (see 34, 53–55).

### 46 — Watchlist
- **Copy:** Header "Watchlist"; rows: "MTN Nigeria" (MTNN · added 12 Mar, ₦268.40, +1.94%), "Nestlé Nigeria" (NESTLE · added 09 Mar, ₦1,180.00, +0.30%); NudgeCard (tone "sun") "Price alerts" — "We'll notify you if a name on this list moves more than 5% in a day. Nothing else — no daily noise."; button "Find more on the NGX".
- **Components:** `AssetRow` ×2, `NudgeCard` (tone sun), `Button`.
- **Nav:** From 33 · rows → 33 · empty state uses a dedicated empty-watchlist illustration, points at 32.
- **Status:** Reskin.

---

## Flow F · Account, security and support (Screens 47–59)
Entry: the Account tab and notifications.

### 47 — Notifications
- **Copy:** Header "Notifications"; "Today": "New sign-in on a device we don't recognise" (Infinix Hot 30 · Ibadan · 09:48), "Your MTNN order filled" (186 shares at ₦268.40 · settles 19 Mar), "₦250,000.00 landed in your wallet" (Transfer from GTB · 09:12); "Earlier": "MTN paid you a dividend" (₦4,120.00 by Direct Cash Settlement · 28 Feb), "Your NGX account is live" (You can place orders · 14 Mar); button "Choose what we notify you about".
- **Components:** `IconButton` (back, settings), `Icon` (shield/loss-tint, markets/indicator-tint, wallet/sun-tint, arrowDown/sun-tint, check/gain-tint — each circle-badged by category), `Button` (ghost).
- **Colour notes:** The security-alert row uses a `--status-rejected-tint` circle with a loss-red shield icon — the only "alarming" icon treatment in the list, everything else uses neutral/positive tints.
- **Nav:** every row opens the thing it's about · security items → 51 · settings → 48.

### 48 — Notification settings
- **Copy:** Body "We only send what changes something you own. No daily market noise."; switches: "Order updates" (on, "Filled, part-filled, cancelled"), "Money in and out" (on, "Deposits, withdrawals, dividends"), "Price alerts" (on, "Only names on your watchlist, over 5% in a day"), "Weekly digest" (off, "One written summary of your portfolio, on Sundays"), "Security" (on, disabled, "Sign-ins and account changes · can't be turned off"); "How we reach you": "Push" (on), "Email" (on, "adebayo@email.com"), "SMS" (off, "Charged by your network"); button "Save".
- **Components:** `Switch` ×8 (one `disabled`).
- **Status:** Reskin, but note "Weekly digest" toggle ties directly to the AI DigestCard feature (29/38) — confirms the digest is a schedulable, opt-in AI content type, not just an inline widget.

### 49 — Personal info
- **Copy:** Read-only rows: Full name "Adebayo Okonkwo", Date of birth "14 Mar 1994", BVN · NIN "Verified", CHN "1234567890", Account status "Verified · no limits"; editable fields: Phone number, Residential address, Employment status (Select); "Investor profile · Balanced" card with "Retake" link; button "Save changes".
- **Components:** `Input` ×2, `Select`, `Button`.
- **Nav:** verified fields read-only · Retake → 27 · legal-name change → support (56).

### 50 — Security
- **Copy:** Row "Change passcode"; switches "Face ID" (on, "Unlock with your face instead of the passcode"), "Passcode for withdrawals" (on, "Always ask before money leaves"); "Devices signed in": "iPhone 13 · Lagos" (This device · now, StatusPill "Trusted"), "Infinix Hot 30 · Ibadan" (Signed in 09:48 today, link "Remove" in loss color); NudgeCard (grape) "Nobody from Kudimata will ask for your passcode" — "Not by call, not by WhatsApp, not by email. If someone does, it isn't us."; buttons "Freeze my account" (destructive) / "Log out".
- **Components:** `Switch` ×2, `StatusPill` (approved, "Trusted"), `NudgeCard`, `Button` (destructive) + `Button` (ghost).
- **Nav:** Change passcode reuses 07/08 · Freeze and Remove device → 51 · Log out → 11.
- **Status:** **NEW: self-service account freeze entry point** lives here, plus a device-management list — both are the launchpad for the freeze flow spec'd next.

### 51 — Security alert
- **Copy:** SecurityAlert device "Infinix Hot 30", location "Ibadan, Oyo", when "Today · 09:48", fraud-desk "Fraud desk · 0700 583 4626, 24 hours"; buttons "Freeze my account and sign that device out" (destructive) / "That was me" (secondary); footnote "Freezing stops orders and withdrawals straight away. Your shares stay yours at the CSCS — nothing is sold."
- **Components:** `SecurityAlert` (~480px, a dedicated composite component: device/location/time + fraud-desk contact + illustration), `Button` ×2.
- **Nav:** Entry: push notification or 47 · either action → 50 · a freeze also emails a receipt.
- **Status:** **NEW: self-service account freeze flow** (as anticipated) — a full unrecognized-device security alert screen with an immediate one-tap "freeze and sign out" destructive action, distinct from a typical KYC/trading app's settings-only security page. This is one of the clearest genuinely-new features in the whole redesign.

### 52 — Statements & documents
- **Copy:** Header "Statements"; SegmentedControl (value "Statements"); broker filter pills "All brokers" (selected) / "Blue Marina"; documents: "February 2026" (Consolidated · 1 broker · PDF 214 KB), "January 2026" (Consolidated · 1 broker · PDF 198 KB), "Contract note · MTNN" (Blue Marina · 14 Mar 2026 · PDF 86 KB); NudgeCard (grape) "What is a contract note?" — "The receipt for one trade — what you bought, at what price, and every fee inside it. Free to read in plain English."; buttons "Email me a statement" / "See the empty state".
- **Components:** `SegmentedControl`, `PillChip` ×2, `Icon` (download ×3), `NudgeCard`, `Button` ×2.
- **Nav:** From 45 or a receipt in 43 · filterable by broker (multi-broker awareness, consistent with the "Blue Marina" executing-broker note on screen 39) · rows → 76 (statement) / 66 (contract note) · empty state → 58. Note: "Email me a statement" targets `nav.s93`, past the 73 blocks in this canvas — an unmocked future screen.

### 53 — Plans & credits
- **Copy:** Body "Every plan states how many written answers you get. There is no unlimited tier."; PlanCard "Plus" — ₦500, 60 credits, button "Choose Plus"; PlanCard "Pro" (featured) — ₦2,000, 250 credits, button "Choose Pro" (variant "warm"); footnote "Top up any time: ₦300 for 30 answers. Prices, fees, risk labels, the glossary and Pidgin re-reads stay free on every plan — what happens when I run out."
- **Components:** `PlanCard` ×2 (one `featured`), nested `Button` ×2.
- **Colour notes:** The featured "Pro" plan's CTA uses the `warm` button variant (distinct from the default indicator/grape button) to visually differentiate the upsell tier.
- **Nav:** From 45 or 34 · choosing a plan returns to 45 · running out → 54.
- **Status:** **NEW: AI-credit subscription/paywall system** — a metered, tiered pricing model (Plus/Pro + top-ups) gating the "Explain this" generative feature. Explicitly framed as "no unlimited tier," with core compliance content (prices, fees, risk labels, glossary, Pidgin re-reads) kept free regardless of plan.

### 54 — Out of credits
- **Copy:** Header "Explain MTNN"; CreditMeter "10 of 10" (compact); CreditGate message "You've read all 10 free explanations. Plus gives you 60 a month for ₦500, or top up 30 for ₦300." / price "₦500 · 60 answers a month" / free-alternative "Still free, always: prices, fees, risk labels, the glossary and Pidgin re-reads."; buttons "See plans" (warm) / "Read the free glossary instead" (secondary); footnote "The gate appears instead of an answer — you are never charged for something you didn't get."
- **Components:** `CreditMeter` (compact), `CreditGate` (~420px composite paywall component), `Button` ×2.
- **Nav:** Replaces the answer on 34 when the meter hits zero · plans → 53 · free route → 57 (Glossary).
- **Status:** **NEW: hard paywall gate** for the AI explain feature — same feature family as 34/53.

### 55 — Refer & earn
- **Copy:** Title "Bring a friend in"; body "You both get 20 free explanations when they finish verification and place their first order."; code plate "Your code" / "ADEBAYO24"; buttons "Copy code" / "Share"; stats: "Friends joined 3", "Still verifying 1", "Explanations earned 40"; footnote "We never pay for orders placed — only for a friend who gets verified. Rewards are credits, never cash. Referral terms."; button "See how credits work".
- **Components:** `Illustration` (name "support-chat", role small, **plate="sun"**, ~150px — note: illustration name seems mismatched/reused from a support context, flag for design-system cleanup), code plate on full `--feature` background (same "feature plate" treatment as 01/41/45's code/account-number surfaces), `Button` ×3.
- **Nav:** From 45 · a friend's code enters at sign-up (03) · credits → 53. "Referral terms" link targets `nav.s95`, beyond this canvas's 73 blocks — unmocked future screen.
- **Status:** **NEW: referral program paid entirely in AI explanation credits** (not cash) — reinforces that credits are the app's core secondary currency, tightly coupled to the Explain-this feature (34/53/54).

### 56 — Help & support
- **Copy:** SearchPill "Search help"; FAQ list: "Why is my order still filling?", "When does money from a sale arrive?", "My verification was not approved", "Fees, in full"; "Talk to a person" card — "Weekdays 08:00 – 18:00, Lagos time. Fraud desk answers 24 hours." — buttons "Email us" / "Start a chat"; NudgeCard (tone "warm") "Report fraud" — "If you think someone else is in your account, freeze it first — then call 0700 583 4626."; button "File a complaint".
- **Components:** `SearchPill`, `Icon` (chevronRight ×4), `Button` ×3, `NudgeCard` (tone warm).
- **Nav:** From 45, 26 or any failure state · articles → 57 · complaint → `nav.s87` (beyond this canvas's 73 blocks — unmocked future screen) · freeze lives on 50.

### 57 — Article & glossary
- **Copy:** Header "Settlement"; title "When does money from a sale arrive?"; body "Three business days after your sale fills. The NGX calls this T+3 [glossary term] — trade day plus three. On that day the money moves from the CSCS to your bank account by Direct Cash Settlement [glossary term], so it never sits with us."; Glossary card "Glossary · free on every plan": "T+3" — "The three business days between a trade and the money or shares actually changing hands.", "Direct Cash Settlement" — "Money from sales and dividends goes straight from the CSCS to your own bank account.", "CSCS" — "The register that records which Nigerian shares you own, under your CHN."; pills "Read in Pidgin" / "Fees, in full"; button "This didn't answer it".
- **Components:** `LanguageSwitch`, `GlossaryTerm` ×2 (inline tappable terms), `PillChip` ×2, `Button` (secondary).
- **Nav:** From 56 or any tapped glossary term app-wide · Pidgin is a free re-read (not credit-gated) · unresolved → 56.
- **Status:** Reskin of a help-center article, but the free/always-available glossary + Pidgin-language re-read is explicitly carved out as **not part of the paid AI-credit system** — an important product/business-logic distinction to encode, not just a UI note.

### 58 — Empty states (pattern reference, not a unique screen)
- **Copy:** Header "Portfolio"; StatusView title "Nothing here yet" — "Your first NGX shares will show up here, with what you paid and what they're worth today."; buttons "Browse the NGX" / "Add money first".
- **Components:** `StatusView` (name "empty-portfolio", tone "empty", ~400px), `Button` ×2, `BottomNav`.
- **Note:** Explicitly documented in the source as "the pattern for every empty list — wallet, watchlist, orders, statements, notifications: one scene, what will land here, and the action that starts it." Build as a single reusable empty-state widget (illustration + title + message + 1–2 CTAs) rather than per-screen bespoke empties.

### 59 — Offline & error (pattern reference, not a unique screen)
- **Copy:** Status bar shows "No service" instead of "LTE"; header "Markets"; StatusView title "You're offline" — "Prices need a connection. Your holdings and last known prices are below, from 09:41."; stale AssetRow "MTN Nigeria" (MTNN · last seen 09:41, ₦268.40, +1.94%); buttons "Try again" / "Get help".
- **Components:** `StatusView` (name "offline", tone pending, ~380px), `AssetRow` (stale/no onClick), `Button` ×2 (icon-left refresh).
- **Note:** "Same pattern for a failed request and for maintenance: name what broke, show what we still have, one retry, one way to a person." Build as a reusable offline/error state, reapplied to any screen that depends on live data.

---

## Flow G · Market hours, mandate and receipts (Screens 60–66)
Entry varies; the NGX trades 10:00–14:30 weekdays only, so this flow specs the after-hours/limit-order/settlement edge cases. Status bars show local times other than 9:41 to signal off-hours context.

### 60 — Markets · closed
- **Copy:** Status bar "16:20"; banner "The NGX is closed" — "Opens tomorrow at 10:00 · prices below are Friday's close"; index row "NGX All-Share · close 104,562.18 +0.84%"; AssetRows suffixed "closed at 14:30" (MTNN, GTCO, DANGCEM); NudgeCard (grape) "You can still place an order" — "It queues for 10:00 tomorrow and fills at the opening price, which may differ from what you see now."
- **Components:** `IconButton` (search), `Icon` (clock), `AssetRow` ×3, `NudgeCard`, `BottomNav` (value "markets").
- **Nav:** same tab as 32, shown after 14:30 or on a weekend · a row still opens 33, where Buy becomes "Queue for 10:00" (61).
- **Status:** Reskin, market-hours-aware state.

### 61 — Buy · market closed
- **Copy:** Sheet title "Buy MTNN"; StatusPill "Market closed"; amount input "50,000" helper "Friday's close ₦268.40 · minimum ₦5,000"; order-type radios: "Fill at the opening price" — "Whatever MTNN opens at tomorrow" / "Only up to ₦275.00 a share" (selected) — "A limit — if it opens above this, nothing is bought"; summary rows "Queued for: Mon 17 Mar · 10:00", "Held from your wallet: ₦50,675.00", "Cancel any time: Until it fills"; footnote "We hold the money now so the order can go out at the open. It returns to your wallet if nothing fills."; buttons "Cancel" / "Queue for 10:00".
- **Components:** `Sheet`, `StatusPill` (pending, sm, "Market closed"), `Input` (amount), `Radio` ×2, `Button` ×2.
- **Nav:** From 60 or 33 after hours · Queue → 62 · a limit that misses returns the money and notifies.
- **Status:** **NEW-ish: limit-order queuing UX for a closed exchange** — not unusual for brokers generally, but a deliberate, carefully-explained mechanic worth flagging as non-trivial to build (holds funds, releases on miss, self-cancels at close).

### 62 — Price moved at the open
- **Copy:** Header "Queued order"; feature callout (warm-tinted) "Needs your decision" — "MTNN opened at ₦281.00 — above your ₦275.00 limit" — "Nothing was bought and nothing was charged. Your ₦50,675.00 is still held for this order until 14:30 today."; detail rows: "You queued: Fri 14 Mar · 16:20", "Friday's close: ₦268.40", "Opened at: ₦281.00 · +4.69%" (in loss-red), "Your limit: ₦275.00"; NudgeCard (grape) "Why did it move?" — "MTN filed results after Friday's close. Opening prices carry the weekend's news — that is exactly what a limit protects you from."; buttons "Buy at ₦281.00 instead" / "Raise my limit" (secondary) / "Cancel and return the money" (ghost).
- **Components:** `IconButton` (back), `NudgeCard`, `Button` ×3.
- **Colour notes:** The "Needs your decision" callout uses `--warm-tint` background / `--warm-press` label (not grape, not sun) — a distinct warm-amber "action needed" treatment reserved for this kind of decision-required state, differentiating it from routine info cards.
- **Nav:** Entry: push at 10:00, or the order in 44 · three non-silent exits · at 14:30 an unactioned order self-cancels and releases the hold.
- **Status:** Reskin of a standard limit-order miss notification, but thoroughly and thoughtfully specified — three explicit resolution paths, no silent auto-cancel without exposition.

### 63 — Withdraw · outside hours
- **Copy:** Status bar "21:05"; Sheet title "Withdraw"; StatusPill "Queued for morning"; amount input "100,000" helper "₦214,300.00 available · ₦180,000 of it still settling"; summary rows "Requested: Tonight · 21:05", "Sent to your bank: Tomorrow from 09:00", "Fee: ₦50.00", "You receive: ₦99,950.00"; sun-tinted note "Money from Friday's MTNN sale settles on T+3 [glossary], Wednesday 19 Mar. Until then it can't be withdrawn — the CSCS hasn't released it yet."; buttons "Cancel" / "Queue it for 09:00".
- **Components:** `Sheet`, `StatusPill` (pending, "Queued for morning"), `Input`, `GlossaryTerm`, `Button` ×2.
- **Colour notes:** Settlement-timing note sits on `--sun-tint` (distinct from the warm/grape treatments used elsewhere) — sun tint appears to be reserved for "informational, money-timing" context notes.
- **Nav:** From 40 at night/weekend/with unsettled cash · Queue → 43 (shown as "Queued") · settled and unsettled money are never mixed in one figure.

### 64 — Bank accounts & mandate
- **Copy:** Header "Bank accounts"; account card "GTB ••••6789" / "Adebayo Okonkwo · added 14 Mar 2026" / StatusPill "DCS active"; body "Your Direct Cash Settlement mandate sends sale proceeds and dividends from the CSCS to this account."; buttons "See the mandate" / "Withdraw mandate" (destructive); second account "Access ••••1204" / "Adebayo Okonkwo · funding only" / StatusPill "No mandate"; button "Add another account"; footnote "Every account must be in your own name, matched to your BVN. One account carries the DCS mandate at a time."; button "What is a DCS mandate?"
- **Components:** `Icon` (wallet ×2, one indicator-tint circle, one track/neutral circle), `StatusPill` ×2 (approved "DCS active", pending "No mandate"), `Button` ×4 (one destructive).
- **Nav:** add → 19 (same form as KYC) · withdraw mandate → 65 · glossary → 56.

### 65 — Withdraw the DCS mandate
- **Copy:** Sheet: FreezeConfirm title "Withdraw your mandate on GTB ••••6789?" with a list of effects; confirmation input "Type WITHDRAW to confirm" (placeholder "WITHDRAW"); footnote "The CSCS takes up to two business days to remove a mandate. We email you a copy of the instruction either way."; buttons "Keep it" (secondary) / "Withdraw mandate" (destructive).
- **Components:** `Sheet`, `FreezeConfirm` (~300px — a generic "confirm a serious, hard-to-reverse account action" component, reused here for mandate withdrawal rather than only account freezing), `Input` (type-to-confirm pattern), `Button` ×2.
- **Nav:** From 64 · either action returns to 64, showing "Mandate withdrawn · pending CSCS" · withdrawals blocked until a new mandate is active.
- **Status:** Reskin of a serious account-security confirmation, but notably reuses the same `FreezeConfirm` component named for the account-freeze flow (51) — confirms the design system treats "freeze account" and "withdraw DCS mandate" as the same class of type-to-confirm destructive action, worth mirroring in the Flutter component architecture (one shared confirm-dialog widget, not two).

### 66 — Contract note · the document
- **Copy:** Header "Contract note"; document card: brand mark + "Kudimata Securities Ltd" / "Contract note · KDM-CN-4471"; "Executed through" + partner logos row; Client "Adebayo Okonkwo" / "CHN 1234567890"; Trade date "14 Mar 2026 · 09:41" / "Settles 19 Mar · T+3"; line items: Bought "MTN Nigeria · MTNN", Shares · price "186 · ₦268.40", Consideration "₦49,922.40", Broker commission "₦449.30", NGX · SEC · CSCS fees "₦225.70", VAT on fees "₦77.60", Total paid "₦50,675.00"; legal footer "Kudimata Securities Ltd, SEC-registered · shares registered to your CHN at the CSCS on settlement · this is a record of an executed order, not advice · fees comprise broker commission plus NGX, SEC and CSCS charges and VAT."; note below the document "₦752.60 of the total is fees. Commission is ours; the rest belongs to the exchange and the regulator."; buttons "Download PDF" / "Email me this receipt".
- **Layout:** rendered as an actual printable-document card (paper background, card shadow, rounded 12px) inside the phone frame — the in-app view IS the PDF layout, not a separate summary.
- **Components:** `IconButton` (back, download), `Mark` (brand, 30px), `Button` ×2.
- **Nav:** From a filled order (37, 39 or 52) · same document goes out as the email template (69).
- **Status:** Reskin (standard contract-note/trade-confirmation document), but note the explicit **co-branded "Executed through" partner-logo slot** — confirms the introducing-broker model (Kudimata + Blue Marina, per screen 39) extends to the legal trade documents themselves, not just internal metadata.

---

## Out of scope for mobile: Email templates (Screens 67–73)
These are 600px-wide desktop email layouts (`EmailShell` component), not phone screens — noted briefly for reference only, not spec'd in detail per the task brief:

- **67 — Email · verify your email**: OTP code email ("Your code is 491 208"), sent from screen 03, code entered on 04.
- **68 — Email · your NGX account is live**: verification-complete notice, sent when the exchange confirms (24); variants exist for not-approved / enhanced-review outcomes using the same shell.
- **69 — Email · order filled receipt**: matches the in-app contract note (66); a part-fill sends one email per fill.
- **70 — Email · withdrawal receipt**: matches screen 43; a queued night-time request (63) sends a "queued for 09:00" variant.
- **71 — Email · security alert**: matches the push/in-app flow that opens screen 51; also sent on passcode change, new bank account, or mandate withdrawal.
- **72 — Email · dividend paid**: same shell reused for monthly statements and price alerts; in-app equivalents live on 47 (notification) and 39 (holding detail).
- **73**: (final block in the canvas — an `EmailShell` example, effectively a continuation/variant of the pattern above; not separately itemized here since it carries no new mobile-relevant information.)

All six confirm one thing worth carrying into the Flutter build even though the templates themselves are out of scope: every transactional email has a matching in-app screen with the same copy and figures, so the backend/notification layer should treat "email body" and "in-app receipt" as the same content rendered twice, not two separate copy sources.

---

## Cross-cutting notes for the Flutter rebuild

**Recurring composite components to build once, reuse everywhere** (from `x-import` usage across all 66 screens): `Button` (variants: primary/default, secondary, ghost, destructive, warm), `Input`, `Select`, `Radio`, `Checkbox`, `Switch`, `PillChip`, `FileUpload`, `AssetRow`, `BalancePanel`, `StatusPill` (statuses: approved, pending, review, rejected), `StatusView` (full-screen state scenes: empty, pending, offline), `MilestoneSheet` (one-time celebration screens), `Sheet` (bottom sheet over a `--scrim` backdrop), `NudgeCard` (tones: default, grape, warm, sun), `ExplainPanel` / `ExplainTrigger` / `GeneratingText` / `CreditMeter` / `CreditGate` / `PlanCard` (the AI-explain feature family), `DigestCard` (AI portfolio narrator), `GlossaryTerm`, `DocumentSummary`, `SecurityAlert`, `FreezeConfirm` (shared by account-freeze and mandate-withdrawal), `Illustration` (plates: default, warm, sun, feature/grape — role: banner/small), `LanguageSwitch`, `BottomNav`, `SegmentedControl`, `SearchPill`, `LineChart`, `AllocationDonut`, `ProductCard`, `Avatar`, `Wordmark`/`Mark` (brand).

**Genuinely NEW features/screens flagged throughout** (not reskins of typical KYC/trading-app screens):
1. Plain-English AI legal-document summarizer (screen 06), extending into inline jargon `ExplainPanel`/`ExplainTrigger` moments at 14, 15, 27.
2. Full generative "Explain this investment" AI feature with streaming answer, thinking/writing states, and a metered trial (screen 34).
3. AI portfolio-digest/narrator widget on Home and Portfolio (screens 29, 38) — a written weekly/contextual summary, not just numbers.
4. AI-credit subscription/paywall system — Plus/Pro plans + top-ups, hard credit gate (screens 53, 54).
5. Referral program paid in AI-explanation credits rather than cash (screen 55).
6. Self-service account-freeze flow triggered from an unrecognized-device security alert (screens 50, 51), sharing its confirm-dialog pattern with DCS-mandate withdrawal (65).
7. English/Pidgin language switch as a first-class, recurring header control (screens 02, 06, 29 area via Account, 45, 57) plus "Explain in Pidgin" as a free (non-credit-gated) AI re-read.
8. Limit-order queuing for a closed exchange with an explicit "price moved at the open" decision screen (screens 61, 62).
9. Multi-broker / introducing-broker awareness surfaced directly to the end user (executing broker named on holding detail 39, broker filter on statements 52, co-branded contract note 66).

**Screen-id references beyond this canvas's 73 blocks** (menu destinations or CTAs pointing at ids not mocked here — treat as placeholders/future screens needing their own spec before build): `s76`, `s77`, `s81`, `s85`, `s87`, `s91`, `s93`, `s94`, `s95`.
</content>
