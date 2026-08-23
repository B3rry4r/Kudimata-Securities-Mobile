# Kudimata Invest — Design System

**The product is Kudimata Invest.** That is the app name, and what appears on screens, in email
headers and in the wordmark. **Kudimata Securities Ltd** is the legal entity — it appears only in
legal, compliance and regulatory copy (risk disclosures, the client agreement, email footers). Never
use "Kudimata Securities" as the app name.

Kudimata Securities is a Nigerian retail stock-trading broker. The existing product is a Flutter
mobile app (NGX + US equities + ETFs, naira wallet, KYC/suitability onboarding). This design system
extracts that product's visual language and adapts it for a **desktop internal admin dashboard**
("the desk") used by compliance and operations staff who review clients, KYC cases, withdrawals and
order flow all day.

The system has since moved off that app's original language. The August 2026 product audit
(`uploads/Kudimata_Full_Audit.docx`) found the old "editorial mono" system coherent but built for a
compliance officer rather than a first-time Nigerian investor — near-monochrome, zero illustration,
every screen resolving to cards in a list. This version is the direction change it called for:
**"Soft Landing"** — warm paper, rounded type, a grape accent with two warm accents beside it, and a
real illustration system with a recurring character. The restraint and legibility survive; the
formality does not.

## Sources used

| Source | What was read |
| --- | --- |
| `uploads/Kudimata-Securities-Mobile-main/` (Flutter repo, uploaded as `Kudimata-Securities-Mobile-main.zip`) | The whole app |
| `lib/theme/tokens.dart` | **Source of truth** for colour, type, spacing, radii, elevation, motion. Every token here traces to it |
| `lib/widgets/*.dart` (`brand`, `buttons`, `surfaces`, `inputs`, `forms`, `charts`, `finance`, `feedback`, `navigation`, `overlays`, `scaffold`, `spinner`, `k_icon`) | The `K*` component inventory — naming, states, exact metrics |
| `lib/screens/**` (home, portfolio, wallet, markets, kyc, onboarding, account, suitability, trade) | Tone, copy, and how the system is applied — reference only, not layout |
| `lib/data/mock.dart`, `lib/data/models.dart` | Client names, NGX instruments, price formats used in the UI kit |
| `assets/brand/*.svg`, `assets/fonts/SpaceGrotesk-*.ttf`, `assets/icon/icon.png` | Copied verbatim into `assets/` |

The Dart source repeatedly notes it was itself "ported 1:1 from the design system (`_ds/.../tokens/*.css`)"
— that original CSS was **not** in the upload, so `tokens/` here is reconstructed from the Dart constants.
Values match; token *names* are our own (`--ink-2` for `KColor.ink2`, etc.).

No Figma file, deck, or marketing site was provided.

---

## CONTENT FUNDAMENTALS

**Voice: a calm, competent broker's clerk.** Plain, specific, never salesy. Financial products are
described in terms of what happens next, not how exciting they are.

- **Person.** "We" for the company, "you"/"your" for the reader: *"We're reviewing your details."*
  *"We'll notify you when you're verified."* In the dashboard, the staff user is also "you"
  (*"Nothing waiting on you"*), and the client is named (*"Adebayo Okonkwo is now verified"*).
- **Casing.** Sentence case everywhere in prose, buttons and labels. Uppercase only as a *typographic*
  device — the tracked 11px eyebrow, table headers, status pills — and those strings are written in
  sentence case in code and uppercased by the component. Never SHOUT in a sentence.
- **Length.** Titles 2–5 words (*"Upload your ID"*, *"KYC queue"*, *"Desk overview"*). Body copy is one
  sentence, occasionally two. Helper lines are fragments: *"JPG or PDF, up to 10MB"*.
- **Buttons are verbs**, one or two words: *Continue · Approve · Reject · Request info · Add money ·
  Withdraw · Export CSV*. Never "Submit", never "Click here".
- **Waiting states say how long and what next.** *"This usually takes a few minutes. We'll notify you
  when you're verified."* Not *"Processing…"*.
- **Errors name the fix, not the fault.** *"BVN must be 11 digits."* *"Ask the client to re-upload in
  daylight."*
- **Numbers are literal and formatted.** `₦268.40`, `₦2,418,650.00`, `+1.94%`, `−0.62%`. Naira sign
  always; typographic minus (−) for losses; percentages to two decimals; thousands separated. Money is
  never rounded to "₦2.4m" in a table — only in a headline stat.
- **The middot is the system's connective tissue.** `Submitted 14 Mar 2026 · Lagos · Tier 2`,
  `JPG · 2.4 MB`, `+₦34,210 · 1.43% today`. Prefer it to commas or pipes for metadata runs.
- **Nigerian domain vocabulary, unexplained**: NGX, NIN, BVN, CSCS, Tier 1/2/3, sponsoring broker,
  suitability, next of kin. Staff and clients know these words.
- **No emoji. Anywhere.** No exclamation marks. No "Oops". No first-person-plural cheerleading.
- **Dashboard-specific:** every list column header is a noun (*Client, Case, Document, Tier, Status,
  Portfolio, Waiting*); every state is one or two words (*Pending, Under review, Approved, Rejected,
  Flagged, Expired*); empty states describe the mechanism (*"New submissions land here as clients
  finish onboarding."*).

---

## VISUAL FOUNDATIONS

**The idea.** Calm, warm and personal — a knowledgeable friend rather than a compliance desk.
Warm paper, rounded type, generous corners, and illustration doing the work that dense text used to.
Colour still means something; there is simply more than one warm colour in the room now.

**Light mode is the system.** Every value, component and specimen here is designed and judged in
light, and `tokens/base.css` declares `color-scheme: light` so nothing inherits a dark canvas from the
OS. A draft dark theme is parked in `tokens/theme-dark.css`, deliberately **not** imported by
`styles.css` — no surface, illustration plate or contrast pair has been designed against it yet.

### Colour
- Two surfaces: `--paper` #FFFFFF (cards, rows, sheets) on `--bg` #FFFDF9 (the page) — warm, never
  grey. `--track` #EFE9DE is the only recessed tone (control tracks, skeletons).
- Three inks: `--ink` #20201E primary, `--ink-2` #5C564E secondary/body, `--ink-3` #726B62
  tertiary/labels/placeholders. `--hairline` #EBE6DD draws every rule.
- **All three inks clear AA at any size on `--paper` and `--bg`.** `--ink-3` measures 4.9:1 on
  paper — it was #8F877C and failed at 3.5:1, which mattered because the system leans on it for
  every eyebrow, table header and micro-label.
- **`--ink-3` is still a paper-only value.** On the filled `--track` it measures 3.9:1 and fails
  for body sizes, so text on `--track` — inactive segments, the expired status pill, disabled
  fields — uses `--ink-2` (6.4:1).
- **Primary accent**: `--indicator` #6524A8 grape, press `#4A1A80`, tint `#F0E7FA`. Still disciplined —
  the one primary button, a selected chip or nav row, the "under review" status, and the comprehension
  layer's own surface.
- **Two warm accents**: `--warm` #F07A45 coral and `--sun` #F5C542. These carry celebration, nudges
  and personality. They are **never** used for gain/loss and **never** for errors — that separation is
  what stops warmth from becoming noise.
- **One rich surface per screen**: `--feature` #6524A8 — a *grape* panel, not a near-black one. It is
  the balance panel, and it should read as the warmest moment on the screen rather than the heaviest.
  `--gain-on-feature` / `--loss-on-feature` brighten movement figures against it.
- **Semantics**: `--gain` #2AA36B, `--loss` #D0503F — on figures only, never as a fill.
- **Status inherits the movement logic**: approved = gain, rejected/flagged = loss, pending = neutral
  ink, under review = grape, expired = grey. Status pills are the one place a semantic colour gets a
  12%-alpha tint behind it.
- The **grape ramp** (`--ramp-1…5`) exists only for allocation donuts. No other multi-hue palette.

### Illustration
- **35 scenes** in `assets/illustrations/`, from Semcore (MIT), every one reduced to the seven values
  in `tokens/illustration.css` — including the neutrals, which are warm plum, not grey.
- **Characters are generated**, not drawn: Adventurer (CC BY 4.0), seeded from the user id, with dark
  skin tones set explicitly. One pinned guide character is the face of the comprehension layer and the
  AI mark; everything else is per-user.
- Scenes sit on a **plate** — grape by default, warm for money and nudges, sun for milestones — and
  their height is resolved by role (hero 200 · state 160 · banner 140 · small 120), never by the
  source viewBox.
- **One illustration per view.** Never inside data, never behind a figure, never as texture or
  wallpaper, never two styles on one screen. Still no photography and no emoji.

### AI pricing
Generated answers are metered in credits, and **there is no unlimited tier** — an unmetered plan on a
per-call API is an open-ended liability. One credit ≈ ₦3 of real model cost, and every tier is priced at
**full burn with a 55% gross-margin floor** — the meter exists to make a margin, not to recover
costs. Plus is ₦500/month for 60 credits (60%), Pro ₦2,000 for 250 (58%), top-ups ₦300 for 30 (66%). Cheap mechanical calls (glossary, Pidgin re-register, prices,
fees, risk labels) are free on every tier. Routing, per-call costs and the FX re-price trigger are in
[`ai-cost-model.md`](ai-cost-model.md); `CreditMeter`, `CreditGate` and `PlanCard` must agree with it.

### The one rule that keeps it unified
**Tracked uppercase is reserved.** It appears in exactly three places: `Eyebrow`, data-table column
headers, and metadata micro-labels (tickers, timestamps, register tags). Form labels, chips, buttons,
segmented controls, toast actions and card titles are all **sentence case in the display face**.
Using tracked caps everywhere is precisely what made the old system read as a compliance tool, and
it is the fastest way to make a new component look like it came from the old one.

### Typography
- **Two faces: Nunito for feeling, Nunito Sans for information.** Nunito (700/800) carries headlines,
  balances and milestones — rounded terminals are most of what separates calm from strict. Nunito Sans
  (400/500/600/700) carries body copy, data and labels. No third family.
- Eight roles: hero 40/44 −0.025em 800 · title 26/32 −0.02em 700 · section 19/25 −0.015em 700 ·
  card title 16/22 −0.01em 700 · body 15/24 400 · **label 11/14 +0.14em 600 uppercase** ·
  micro 10/13 +0.04em 600 · data 14/20 −0.005em 400.
- Tracking is the signature: tight and negative as sizes grow, wide and positive on the 11px label.
- **Every figure is tabular** (`font-variant-numeric: tabular-nums`) — prices, balances, percentages,
  counts, refs, times. Non-negotiable; columns must align down a 25-row table.
- Body copy is `--ink-2`, not ink. Headings are ink. Labels are `--ink-3`.
- `text-wrap: pretty` on paragraphs; text is never truncated in mobile asset rows.

### Space & layout
- 8-pt grid with 4 as the half step: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40.
- Rhythm: **12 inside a group, 16 between rows, 32 between sections.** Mobile gutter 20; desktop gutter
  32; content capped at 1440 and centred.
- Desk chrome: sidebar 236, top bar 60, table row 52 (44 dense), cell padding 16.
- Layout is grid/flex with `gap` — no margin stacking. Fixed elements: sidebar and top bar are static
  chrome; the mobile bottom nav floats (not carried into the desk); toasts pin bottom-right at 24.

### Surfaces, borders, radii
- **Cards: white, one 1px hairline, radius 20, and at most `--shadow-card`.** Shadows are warm-tinted,
  never grey, and never a substitute for the hairline.
- Radii: button/input 14 · card 20 · table 18 · feature panel 24 · sheet 28 · illustration plate 18 ·
  segment 10 · chip 10 · pill 999. Everything is rounder than the system this replaces — roundness is
  most of what separates calm from strict.
  Nothing is fully rounded except pills, avatars and dots.
- **Shadow floats chrome only**: `--shadow-float` 0 8 24 / 6% (active segment, floating icon button),
  `--shadow-nav` 0 12 32 / 10% (toast, menus, mobile nav), `--shadow-sheet` 0 −12 40 / 14% (bottom
  sheet). Hairline and shadow never appear on the same element by accident.
- Dashed borders exist in exactly one place: the 1.5px file dropzone.

### Motion
- **One curve** — `cubic-bezier(.32,.72,0,1)` — and three durations: 120ms (press, hover, focus),
  220ms (toggles, sliding knobs, transforms), 360ms (sheets, page transitions).
- Nothing bounces, nothing springs, nothing eases-in-out. No parallax, no scroll-jacking, no
  entrance animations on lists or cards.
- **Press states are physical**: buttons scale to 0.98 and the grape darkens to `--indicator-press`;
  icon buttons scale to 0.96. Radio dots and switch knobs animate scale/position, not colour alone.
- **Hover (desktop only)**: table rows and nav rows go to `--bg`; ghost buttons go to `--bg`; links
  move ink → `--indicator`. Never opacity fades, never lightening a fill.
- **Focus**: the input's hairline goes solid `--ink` — not a coloured ring. `--focus-ring` (grape at 3px) is reserved for keyboard focus on controls that have no border to change.

### Motion
- Two curves: `--ease-soft` for everything functional, `--ease-settle` for the moments meant to feel
  like a gift. Nothing bounces, nothing springs, no confetti — the audit asks for delight, the category
  asks for restraint.
- Four durations: fast 120 (press, hover), base 220 (state change), slow 360 (sheet, reveal),
  **settle 640** — reserved for the milestone reveal and the comprehension panel opening.
- **Generated text is the one animated content in the system.** `GeneratingText` shimmers while
  thinking and types while writing, because a spinner tells a first-time investor nothing about
  whether the app is stuck or working. Everything honours `prefers-reduced-motion`, which resolves the
  text instantly rather than animating faster.

### Imagery, transparency, texture
- **Illustration is a first-class part of the system** — 35 scenes in `assets/illustrations/`, sourced
  from Semcore (MIT) and reduced to seven values, plus generated Adventurer characters (CC BY 4.0) for
  the guide, avatars and the AI mark. One illustration per view; never inside data, never behind a
  figure, never as texture or wallpaper. Still no photography, no gradient backgrounds, no grain.
- Gradients appear only as chart fills — one colour fading 14% → 0 (32% on ink).
- **Transparency and blur are almost absent.** The scrim behind a dialog is `--scrim` `rgba(43,26,61,.36)`;
  bottom sheets are explicitly *opaque, never frosted*. The single blurred element in the whole
  system is the page/zoom capsule floating over the document viewer.
- Charts: single 1.75px stroke, no gridlines, no axes, no tooltips, straight segments (never smoothed).
- Asset circles may carry a real brand tint (MTN amber, Dangote red); everything else is ink.

### ICONOGRAPHY
- **One family, drawn in the Lucide idiom**: 24×24 viewBox, 1.5–1.75px stroke, round caps and joins,
  **no fills**, monochrome, rendered at 16–22px. The mobile app inlines the path data in
  `lib/widgets/k_icon.dart` rather than shipping an icon font or sprite; those exact paths are ported
  into `components/icons/Icon.jsx`, so the geometry is the app's, not a font's.
- There is **no icon font, no SVG sprite, and no PNG icon set** in the repo — nothing to copy but the
  path data, which we did. Two glyphs (`portfolio`, `fingerprint`) are custom to Kudimata.
- Dashboard-only glyphs (`chevronDown/Up/Left`, `sort`, `more`, `users`, `doc`, `download`, `clock`,
  `alert`, `shield`, `logout`, `refresh`, `zoomIn/Out`, `rotate`, `settings`, `flag`, `lock`, `mail`,
  `minus`) were added in the same idiom. **Flagged substitution:** these follow Lucide's geometry, the
  same source the app's own set was drawn from — if the brand has authored alternatives, swap the path
  data in `ICONS` and everything updates.
- Icons are always monochrome and inherit text colour: `--ink` for actions, `--ink-3` for decoration
  or inactive, `--indicator` only when the element is selected. The one exception is `AIMark`, whose spark glyph is always grape — it is a signature, not an icon.
- **Emoji are never used.** Unicode is used typographically, not as iconography: middot `·`,
  typographic minus `−`, naira `₦`.
- Colour is never applied to an icon to indicate status — the pill next to it does that.

### Logo & brand assets
- **The mark is four rising bars and a descender — no shield.** `kudimata-mark.svg` (gradient,
  native 15.06 × 24.6, so it is taller than it is wide), `kudimata-mark-flat.svg` for small sizes and
  single-colour print, `kudimata-mark-white.svg` for the grape feature panel. `Mark`'s `size` prop
  sets the **height**, since that is what optically matches adjacent type.
- The brand gradient runs #5D1AA3 → #7225AE → #802DB5. `--indicator` #6524A8 sits inside that range
  deliberately, so UI grape and brand grape read as one colour.
- Supplied artwork lives alongside as PNG: `kudimata-lockup.png`, `-white`, `-whitetext`, and
  `kudimata-vertical.png` (with "Securities Ltd" — entity artwork, for legal and print use).
  `app-icon.svg` is the launcher icon. The vendor SVG exports arrived with their `<style>` blocks
  stripped, so the marks were rewritten with explicit fills; the path geometry is untouched.
- The wordmark is typographic, not an asset: **"Kudimata" semibold ink + "Securities" regular grey**,
  17px, −0.17px tracking, mark at 10px gap. Built as `Wordmark`.
- Never recolour, outline, rotate or redraw the mark. One lockup per view.

---

## Foundations index (`tokens/`)

| File | Contents |
| --- | --- |
| `tokens/fonts.css` | Nunito + Nunito Sans import, `--font-display` / `--font-core` / `--font-numeric` |
| `tokens/colors.css` | Surfaces, ink, hairline, accent, semantic, status, ramp, dark scope |
| `tokens/typography.css` | Sizes, line-heights, tracking, weights, `--text-*` shorthands |
| `tokens/spacing.css` | 8-pt scale, rhythm gaps, desk chrome metrics |
| `tokens/radii.css` | Radii per element class |
| `tokens/elevation.css` | Shadow + focus-ring tokens |
| `tokens/motion.css` | Durations, easing, press scales |
| `tokens/illustration.css` | Scene palette, plates, drawn sizes, avatar sizes, `.k-illo` / `.k-avatar` |
| `tokens/theme-dark.css` | Draft dark theme. Not imported — light is the system. |
| `tokens/base.css` | Element resets, link colours, `.k-tnum`, `.k-eyebrow` |

`styles.css` at the root imports all of them and is the only file consumers need to link.
Specimen cards for each concern live in `guidelines/*.card.html`.

## Components

Grouped by concern under `components/`. Every family below has a counterpart in `lib/widgets/`
except those marked **added**.

**`components/icons/`** — `Icon` (with the `ICONS` path map)
**`components/brand/`** — `Mark`, `Wordmark`
**`components/illustration/`** — `Illustration`, `Avatar`, `AvatarCluster`
**`components/comprehension/`** — `AIMark`, `ExplainTrigger`, `ExplainPanel`, `GeneratingText`,
`GlossaryTerm`, `DocumentSummary`, `DigestCard`, `NudgeCard`, `RegisterTag`, `LanguageSwitch`,
`CreditMeter`, `CreditGate`
**`components/mobile/`** — `OnboardingSlide`, `MilestoneSheet`, `BottomNav`, `Sheet`
**`components/security/`** — `SecurityAlert`, `FreezeConfirm`
**`components/email/`** — `EmailShell`, `EmailReceipt`
**`components/core/`** — `Button`, `IconButton`, `Card`, `Badge`, `Spinner`, `SearchPill`,
`SegmentedControl`, `PillChip`
**`components/forms/`** — `Input`, `Checkbox`, `Radio`, `Switch`, `FileUpload`, `Select`
**`components/finance/`** — `StatCard`, `BalancePanel`, `AssetRow`, `ProductCard`, `Sparkline`,
`LineChart`, `AllocationDonut`
**`components/feedback/`** — `Toast`, `StatusView`
**`components/data/`** — `DataTable`, `StatusPill`, `Pagination`, `DocumentPreview`
**`components/navigation/`** — `SideNav`, `TopBar`
**`components/layout/`** — `Eyebrow`, `PageHead`, `Modal`

### The AI / comprehension layer

The audit's section 6.7 asks for these to have their own visual language rather than being one
more row in a settings list. Every one of them is generated content, and the user must always be able
to tell that at a glance — that is what `AIMark` is for, and it appears on all of them.

| Component | What it answers in the audit |
| --- | --- |
| `ExplainTrigger` | "A persistent, obviously-tappable affordance next to any product, term or filing — not a buried help-article link." Three variants: pill on a card, inline in a sentence, 44px icon. |
| `GeneratingText` | The states while Kudimata writes: **thinking** (shimmer, no text yet), **writing** (text arriving with a caret), **done**. A spinner tells a first-time investor nothing. Honours `prefers-reduced-motion`. |
| `ExplainPanel` | The conversational layout — guide character, roomier than a card, "more illustration, more white space". |
| `DocumentSummary` | Plain English **above** the raw NGX filing by default, original always one tap away. A first-class screen, not a collapsed accordion. |
| `GlossaryTerm` | The term glossary, marked in place and tappable — not hover-only. |
| `DigestCard` | Portfolio summaries and research digests, visually distinct from a holding row. |
| `NudgeCard` | Warm, dismissible, never red — gentle encouragement, not a compliance notice. |
| `RegisterTag`, `LanguageSwitch` | English/Pidgin as a persistent one-tap switch, and a visible cue for which register you are reading. Legal text stays authoritative in English. |
| `CreditMeter`, `CreditGate` | Generated answers cost real money. The balance is visible **before** the tap, the gate appears **instead of** an answer rather than after charging, and it always names what stays free. |

| --- | --- |
| `Illustration`, `Avatar` | The audit's single biggest finding: not one illustrated moment existed anywhere in the app. |
| `ExplainPanel`, `NudgeCard`, `DigestCard`, `RegisterTag` | The comprehension layer — the product's actual differentiator — needs its own visual language, warmer and roomier than a card. |
| `OnboardingSlide`, `MilestoneSheet`, `BottomNav`, `Sheet` | Mobile-first surfaces. The system had drifted desk-only; these bring it back to the app the audit is about. |
| `ProductCard` | Risk, fees, liquidity and minimum belong on the card, not behind a tap — and not as more text rows on the old one. |
| `DataTable`, `Pagination` | The desk is table-first; the mobile app had rows and cards only. |
| `StatusPill` | Workflow state (pending / under review / approved / rejected) needs its own vocabulary, tied to the existing gain/loss semantics. |
| `DocumentPreview` | KYC review needs a document viewer; mobile only ever *uploaded* documents. |
| `Select` | Desktop filter bars need a compact dropdown; mobile used sheets and chips. |
| `SideNav`, `TopBar` | Desktop chrome, replacing `KBottomNav` and `KDetailHeader`. |
| `Modal` | Desktop stand-in for `KSheet` (bottom sheet), same opaque-never-frosted rule. |
| `PageHead` | Desktop descendant of `KScreenHead`, with room for status + actions. |

### Deliberately not carried over

`KBottomNav` (mobile-only pattern), `KSheet` (replaced by `Modal`), `KDetailHeader` (replaced by
`TopBar` breadcrumbs), the passcode/biometric onboarding widgets (staff auth is email + authenticator).

## UI kit

`ui_kits/admin-dashboard/` — **Kudimata Desk**, the staff dashboard. Sign-in → overview → KYC queue →
case review → clients / withdrawals / orders. See its own `README.md` for the screen map and
click-through. Open `ui_kits/admin-dashboard/index.html`.

No UI kit was built for the mobile app: the brief is explicit that the mobile screens are a reference
for tone, not something to recreate.

## Root manifest

| Path | What it is |
| --- | --- |
| `readme.md` | This file — context, content and visual foundations, component index |
| `SKILL.md` | Agent-skill entry point for using this system outside this project |
| `styles.css` | The only stylesheet consumers link; imports everything in `tokens/` |
| `thumbnail.html` | Homepage tile for the design system |
| `tokens/` | Token CSS, one file per concern |
| `guidelines/` | 16 foundation specimen cards (Colors, Type, Spacing, Brand) |
| `components/` | 10 groups, 36 exported components |
| `ui_kits/admin-dashboard/` | The desk dashboard recreation |
| `assets/brand/` | Mark (purple + white), app icon |
| `assets/fonts/` | Space Grotesk TTF (retired — kept for the legacy mobile build) |
| `assets/illustrations/` | 35 recoloured Semcore scenes + 9 Adventurer characters |
| `explorations/` | The direction exploration: type options, illustration options, the full set |

## Templates

Consuming projects start from a template rather than a bare component:

| Template | What it is |
|---|---|
| `templates/mobile-screen/` | The app home screen — top bar, balance panel, Explain panel, nudge, holding row, bottom nav |
| `templates/onboarding/` | The illustrated welcome slider a first-time investor sees before any price |
| `templates/plans/` | Metered AI pricing — three tiers, each stating its credit count |

Each folder has a `ds-base.js` with one `base` line to point at this system. `@startingPoint` tags were
dropped: consuming projects no longer offer them, and templates cover the same ground better.

**Templates mount the real components** via
`<x-import component-from-global-scope="KudimataDesignSystem_b88dc9.ExplainPanel">`, and every colour,
font and radius in their own page-level markup is a `var(--token)`. Nothing is hand-duplicated: a
template that re-implements `ExplainPanel` as raw divs with hex values drifts the moment a token
changes, which is exactly the "some parts feel new, some feel old" failure this system exists to
prevent.
