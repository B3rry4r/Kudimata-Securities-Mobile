# Kudimata Securities — Build Contract (for screen agents)

Stage 1 (design tokens + shared widgets) is **DONE and frozen**. Build every
screen from the K-widgets below. Do **not** edit anything in `lib/widgets/` or
`lib/theme/`. This contract is the single source of truth for the widget API,
data API, routes, and cross-stage flow launchers.

Quick rules: 20px gutters · `.tnum` on every number · sentence case everywhere
except tracked UPPERCASE eyebrows/labels · movement colour on numbers only ·
NGX / US / ETF only (**no fixed income**) · leave seam comments where real
trading / payments / KYC plug in.

Import the whole widget library with:

```dart
import 'package:kudimata_securities/widgets/widgets.dart'; // adjust to your import root
```

---

## (a) WIDGET API

All widgets are `const`-constructible unless noted. Defaults shown as `= x`.
Colours/spacing come from `lib/theme/tokens.dart` (`KColor`, `KSpace`, `KRadii`,
`KShadow`, `KMotion`, `KWeight`, `KType`). `KType` styles are methods returning
`TextStyle`; apply `.tnum` (extension) to any numeric style.

### `widgets/k_icon.dart`
```dart
KIcon(String name, {double size = 20, double stroke = 1.75, Color color = KColor.ink})
static bool KIcon.has(String name)
```
Valid `name`s (no others exist): `home portfolio markets wallet profile search
filter bell back chevronRight plus close arrowUp arrowDown arrowUpRight
arrowDownLeft check eye card transfer send fingerprint`.

### `widgets/brand.dart`
```dart
KMark({double size = 30, bool white = false})            // K mark only; height = size*248/228
KWordmark({double size = 30, bool center = false, bool white = false})
```

### `widgets/buttons.dart`
```dart
enum KButtonVariant { primary, secondary, ghost }
enum KButtonSize    { lg, md, sm }              // heights 50 / 44 / 36
KButton({
  required String label,
  VoidCallback? onPressed,                       // null → disabled
  KButtonVariant variant = KButtonVariant.primary,
  KButtonSize size = KButtonSize.lg,
  bool fullWidth = true,
  bool loading = false,
  String? iconLeft,                              // KIcon name
  String? iconRight,
})

enum KIconButtonVariant { solid, float }         // float adds soft shadow
KIconButton({
  required String icon,                          // KIcon name
  VoidCallback? onPressed,
  double size = 40,
  KIconButtonVariant variant = KIconButtonVariant.solid,
  String? semanticLabel,
})
```
`primary` = the one purple moment per view.

### `widgets/spinner.dart`
```dart
KSpinner({double size = 18, double stroke = 2, Color color = KColor.indicator, double trackOpacity = 0.18})
```

### `widgets/surfaces.dart`
```dart
KCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  bool border = true,                            // 1px hairline, NO shadow
  double radius = KRadii.card,                   // 16
  VoidCallback? onTap,
  Color color = KColor.paper,
})

enum KBadgeTone { neutral, gain, loss, indicator }
KBadge({ required String label, KBadgeTone tone = KBadgeTone.neutral, Widget? icon })
```

### `widgets/inputs.dart`
```dart
KInput({
  String? label,                                 // rendered UPPERCASE tracked
  TextEditingController? controller,
  String? value,
  ValueChanged<String>? onChanged,
  String? placeholder,
  String? icon,                                  // KIcon name (leading)
  String? prefix,                                // e.g. "₦"
  String? suffix,
  String? helper,
  String? error,                                 // error overrides helper, turns field red
  bool disabled = false,
  bool numeric = false,                          // tabular medium figures
  bool obscure = false,
  TextInputType? keyboardType,
  Widget? trailing,
})

KSearchPill({
  String placeholder = 'Search',
  TextEditingController? controller,
  ValueChanged<String>? onChanged,
  VoidCallback? onFilter,
  bool showFilter = false,
  bool readOnly = false,                         // set true + onTap to push a search screen
  VoidCallback? onTap,
})

class KSegmentOption { const KSegmentOption({required String value, required String label, String? icon}); }
KSegmentedControl({
  required List<KSegmentOption> options,
  required String value,
  required ValueChanged<String> onChanged,
})                                               // white active segment, NOT purple

KPillChip({ required String label, bool selected = false, VoidCallback? onTap })  // selected = purple

class KFileInfo { const KFileInfo({required String name, int? size}); String get sizeLabel; }
KFileUpload({
  String? label,
  String hint   = 'PDF, PNG or JPG · up to 10 MB',
  String prompt = 'Tap to upload, or take a photo',
  String? helper,
  String? error,
  bool disabled = false,
  KFileInfo? file,                               // null → dropzone; set → file row
  VoidCallback? onPick,                          // SEAM: real picker plugs in here
  VoidCallback? onRemove,
})
// DottedBorder is also exported but is internal to KFileUpload — don't use directly.
```

### `widgets/forms.dart`
Each takes `bool checked`, `ValueChanged<bool>? onChanged`, `String? label`,
`String? description`, `bool disabled = false`.
```dart
KCheckbox({ required bool checked, ValueChanged<bool>? onChanged, String? label, String? description, bool disabled = false })
KRadio   ({ required bool checked, ValueChanged<bool>? onChanged, String? label, String? description, bool disabled = false }) // onChanged only fires with true
KSwitch  ({ required bool checked, ValueChanged<bool>? onChanged, String? label, String? description, bool disabled = false }) // label/desc render LEFT, knob right
```
Purple owns the "on" state for all three.

### `widgets/charts.dart`
```dart
enum KTrend { gain, loss }                       // chart/finance trend (mirror of data Trend)

KSparkline({ required List<double> data, double width = 64, double height = 28, KTrend trend = KTrend.gain, double strokeWidth = 1.5 })

KLineChart({
  required List<double> data,
  List<String> ranges = const ['1D','1W','1M','1Y','ALL'],
  String? range,                                 // controlled active range (else internal)
  ValueChanged<String>? onRangeChange,
  KTrend trend = KTrend.gain,
  double height = 160,
  bool onDark = false,                           // true when placed inside KBalancePanel
})

class KDonutSegment { const KDonutSegment({required double value, String? label, Color? color}); }
KAllocationDonut({
  required List<KDonutSegment> segments,         // colour defaults to brand purple ramp
  double size = 140,
  double thickness = 18,
  String? centerLabel,
  String? centerValue,
})
// KAllocationDonut.ramp is the 5-stop purple ramp (static const).
```

### `widgets/finance.dart`
```dart
KAssetRow({
  required String name,
  required String ticker,
  Widget? logo,                                  // real mark; null → ticker initials on logoColor circle
  Color logoColor = KColor.ink,
  String? price,
  String? change,                                // movement colour auto-derived from leading sign if trend null
  KTrend? trend,
  List<double>? sparkline,                       // pass asset.sparkline to show it
  VoidCallback? onTap,
})

enum KSubTone { neutral, gain, loss }
KStatCard({ Widget? icon, required String label, required String value, String? sub, KSubTone subTone = KSubTone.neutral })

KBalancePanel({                                  // the ONE rich ink surface — max one per screen
  required String label,
  required String balance,
  String? change,
  KTrend changeTone = KTrend.gain,
  Widget? chart,                                 // pass KLineChart(onDark: true)
  Widget? action,
})
```

### `widgets/feedback.dart`
```dart
enum KToastTone { success, error, info }
KToast({ KToastTone tone = KToastTone.info, String? title, String? message, String? action, VoidCallback? onAction, VoidCallback? onClose })

enum KStatusTone { success, error, pending }
KStatusView({                                    // big centred outcome (success/fail/pending screens & sheets)
  KStatusTone tone = KStatusTone.success,
  String? title, String? message,
  String? primary, VoidCallback? onPrimary,
  String? secondary, VoidCallback? onSecondary,
})
```

### `widgets/navigation.dart`
```dart
class KNavItem { const KNavItem({required String id, required String icon, required String label}); }
const kDefaultNavItems  // home/portfolio/markets/wallet/profile(Account)
KBottomNav({ List<KNavItem> items = kDefaultNavItems, required String active, required ValueChanged<String> onChange })
```
The shell owns this; screens don't place it. Active item ids are
`home portfolio markets wallet profile` (note Account's id is `profile`).

### `widgets/overlays.dart`
```dart
KSheet({ String? title, required Widget child, Widget? footer })   // body widget; usually use the helper:
Future<T?> showKSheet<T>(BuildContext context, { String? title, required Widget child, Widget? footer, bool isScrollControlled = true })
```
Use `showKSheet` for buy/sell, confirmations, filters, pickers. Opaque white,
drag handle, soft shadow — never frosted.

### `widgets/scaffold.dart`
```dart
KEyebrow(String text, {Color color = KColor.ink3})              // tracked UPPERCASE eyebrow
KScreenHead({ required String title, String? body })           // titled ROOT header block
KDetailHeader({ required String title, VoidCallback? onBack })  // PUSHED screen header: back chevron, NO tab bar
```
`KDetailHeader` implements `PreferredSizeWidget` (height 52) — usable as an
`AppBar`. Default `onBack` does `Navigator.maybePop()`.

---

## (b) DATA API

`import 'package:kudimata_securities/data/models.dart';`
`import 'package:kudimata_securities/data/mock.dart';`

### Models (`lib/data/models.dart`)
```dart
enum Trend { gain, loss }
enum AssetClass { ngx, us, etf }
class Asset    { String name, ticker, price, change; Trend trend; AssetClass assetClass; Color? logoColor;
                 List<double> get sparkline; }   // price/change are preformatted strings
class Holding  { Asset asset; String units, marketValue, avgPrice, totalReturn, returnPct; Trend returnTrend; }
enum TxnType   { fund, withdraw, buy, sell, convert }
enum TxnStatus { completed, pending, failed }
class Txn      { String id, title, subtitle, amount, date; TxnType type; TxnStatus status; bool incoming; }
class AppNotification { String title, body, time, icon; bool unread; }
class UserProfile     { String fullName, email, phone, tier, memberSince; }
```
`Asset.price`/`change` are display strings exactly like the design
(`"₦268.40"`, `"+1.94%"`, `"−0.62%"` — loss uses unicode minus U+2212). Map
`Asset.trend`/`Holding.returnTrend` (`Trend`) to widgets' `KTrend` 1:1.

### Accessors (`MockData`, all static)
```dart
MockData.homeSeries / .mtnnSeries          // List<double> feature-chart series
MockData.ngStocks / .trending / .usStocks / .etfs / .watchlist   // List<Asset>
MockData.allAssets                          // every quotable asset
MockData.assetByTicker(String)              // Asset?
MockData.holdings                           // List<Asset> (the 3 held names)
MockData.portfolioHoldings                  // List<Holding>
MockData.holdingByTicker(String)            // Holding?
MockData.txns / MockData.txnById(String)    // List<Txn> / Txn?
MockData.notifications                       // List<AppNotification>
MockData.user                                // UserProfile (Ada Okeke, Premium)
spark(bool up, [int n = 16])                 // top-level — same formula as the design
```

---

## (c) ROUTES

`import 'package:kudimata_securities/router/routes.dart';` → all paths on `Routes`.

| Group | Constant | Path |
|---|---|---|
| gated | `splash` | `/` |
| | `signup` | `/signup` |
| | `otp` | `/otp` |
| | `createPasscode` | `/passcode/create` |
| | `confirmPasscode` | `/passcode/confirm` |
| | `biometric` | `/biometric` |
| | `login` | `/login` |
| | `reset` | `/reset` |
| kyc | `kycIntro` | `/kyc` |
| | `kycPersonal` | `/kyc/personal` |
| | `kycBvn` | `/kyc/bvn` |
| | `kycId` | `/kyc/id` |
| | `kycLiveness` | `/kyc/liveness` |
| | `kycChecking` | `/kyc/checking` |
| | `kycNextOfKin` | `/kyc/next-of-kin` |
| | `kycSubmitted` | `/kyc/submitted` |
| | `kycApproved` | `/kyc/approved` |
| suitability | `questionnaire` | `/suitability` |
| | `suitabilityResult` | `/suitability/result` |
| | `riskDisclosure` | `/suitability/risk` |
| | `clientAgreement` | `/suitability/agreement` |
| tabs | `home` | `/home` |
| | `portfolio` | `/portfolio` |
| | `markets` | `/markets` |
| | `wallet` | `/wallet` |
| | `account` | `/account` |
| pushed | `notifications` | `/notifications` |
| | `search` | `/search` |
| | `orderStatus` | `/orders` |
| | `assetList` | `/assets` |
| | `watchlist` | `/watchlist` |
| pushed (dynamic) | `assetDetail(ticker)` | `/asset/<ticker>` |
| | `holdingDetail(ticker)` | `/portfolio/holding/<ticker>` |
| | `transactionDetail(id)` | `/wallet/txn/<id>` |
| account subs | `acctPersonal` | `/account/personal` |
| | `acctBanks` | `/account/banks` |
| | `acctRefer` | `/account/refer` |
| | `acctHelp` | `/account/help` |
| | `acctSecurity` | `/account/security` |
| | `acctNotifications` | `/account/notifications` |
| | `acctLegal` | `/account/legal` |
| | `acctStatements` | `/account/statements` |

Path patterns for `GoRoute` registration: `Routes.assetDetailPath`
(`/asset/:ticker`), `Routes.holdingDetailPath`, `Routes.transactionDetailPath`.
`Routes.tabs` lists the 5 roots in shell-branch order.

**How to navigate**
- Gated linear steps (splash → signup → otp → passcode → biometric → KYC →
  suitability → home): `context.go(Routes.xxx)` — replaces, no back stack.
- Pushed detail screens (asset/holding/txn detail, notifications, search,
  account subs, etc.): `context.push(Routes.xxx)` or `context.push(Routes.assetDetail(t))`.
- Dismiss a pushed screen: `context.pop()` (or `KDetailHeader`'s default back).
- **Pushed detail routes are TOP-LEVEL** — they cover the shell, so they have NO
  tab bar (use `KDetailHeader`). The 5 tab roots live inside a
  `StatefulShellRoute.indexedStack`; only those show `KBottomNav` (owned by the
  shell).

`AppState` gating: `import '.../app/app_state.dart';` → `AppScope.of(context)`
(listening) / `AppScope.read(context)` (mutating). Flags: `passcodeSet`,
`biometricEnabled`, `kycSubmitted`, `kycApproved`, `suitabilityComplete`,
`signedIn`; watchlist via `isWatched/toggleWatch/addWatch/removeWatch` +
`watchlistTickers`.

---

## (d) FLOW LAUNCHERS (cross-stage contract)

Producers MUST create these exact files with these exact signatures; consumers
import and call them (typically from an asset/holding/wallet screen's primary
action). Each opens its flow via `showKSheet`. Until a producer ships, callers
may assume the file exists at the path below.

```dart
// lib/screens/trade/trade_flows.dart
Future<void> showBuyFlow(BuildContext context, Asset asset);
Future<void> showSellFlow(BuildContext context, Asset asset);

// lib/screens/wallet/wallet_flows.dart
Future<void> showAddMoneyFlow(BuildContext context);
Future<void> showWithdrawFlow(BuildContext context);
Future<void> showConvertFlow(BuildContext context);
```

`Asset` is `lib/data/models.dart`. **SEAM:** the buy/sell flows stop at a mocked
order confirmation (sponsoring-broker order API plugs in there); add money /
withdraw / convert stop at a mocked processor result (wallet processor + FX rate
plug in there). Do **not** implement real trading, payments, FX, or KYC.

---

## (e) CONVENTIONS RECAP

- **Gutters:** 20px screen side padding (`KSpace.gutter`).
- **Headers:** `KScreenHead` for titled tab roots; `KDetailHeader` (back
  chevron, no tab bar) for pushed screens.
- **Overlays:** `showKSheet(...)` for every sheet (buy/sell, confirm, filter,
  picker). Soft shadow lives only on bottom nav + sheets.
- **Numbers:** `.tnum` on every price/balance/percentage; **never truncate**
  them. Movement colour (gain green `KColor.gain` / loss red `KColor.loss`) on
  NUMBERS only — derive from `Trend`/leading sign.
- **Type case:** tracked UPPERCASE only for eyebrows/labels (`KEyebrow`,
  `KType.label`, `KInput.label`); everything else sentence case.
- **Surfaces:** content cards = 1px hairline, NO shadow (`KCard`). One
  `KBalancePanel` (solid ink) max per screen. Opaque surfaces, no glass.
- **Colour:** near-monochrome; purple (`KColor.indicator`) is the interactive
  layer only (primary `KButton`, selected `KPillChip`, active toggles, active
  nav, donut ramp).
- **Icons:** `KIcon` only, 1.5px stroke idiom, names from the fixed set above.
- **Scope:** NGX, US stocks, ETFs only. **No fixed income anywhere** — ignore
  the design README's mention of it.
- **Seams:** leave clearly-commented `// SEAM:` markers where the sponsoring-
  broker order API / wallet processor / FX / KYC provider plug in. Mock only.

---

## (f) COMPILE CHECKLIST

1. Import widgets via `widgets/widgets.dart`; data via `data/models.dart` +
   `data/mock.dart`; routes via `router/routes.dart`.
2. Map data `Trend` → widget `KTrend` (same two cases).
3. Pass preformatted `price`/`change` strings straight through — don't reformat.
4. Use only `KIcon` names from the fixed set (or `KIcon.has(name)` to guard).
5. Tab roots: no `KBottomNav`/no `Scaffold` chrome the shell already provides.
   Pushed screens: use `KDetailHeader`.
6. `context.go` for gated steps, `context.push` for pushed detail, `context.pop`
   to dismiss. Use `Routes.*` constants/helpers — never hardcode paths.
7. `flutter analyze` clean before handoff. Match Stage-1 style: K-prefixed local
   widgets, terse comments, no shadows on content cards.
