// Kudimata Invest — buy and sell flows, redesign 2026-08 (canvas
// `04 Buy and Sell.dc.html`, artboards s42/s43/s43b/s29/s29c/s43m/s29m/s30
// for buy, s45/s46/s47/s48/s46m/s48m for sell, s30 shared for the PIN step).
// Artboard ids in this header come from the task brief that dispatched this
// file's rewrite, never from an older comment — see
// docs/redesign/DECISIONS.md R-5.
//
// SHAPE: "name your price" (a limit order) is the primary path, with
// "buy now"/"sell now" (a market order) as an explicit branch chosen up
// front on a chooser screen — the inverse of the previous build, where a
// market order was the unlabelled default with no chooser at all.
//
//   chooser (s42/s45) ─┬─ name your price → price (s43/s46) → shares
//                       │    (s43b/s47) → review (s29/s48)
//                       └─ buy/sell now → shares (s43m/s46m)
//                            → review (s29m/s48m)
//   review → [market closed? → s29c interstitial] → PIN (s30, the app's
//   existing 6-digit passcode — R-31) → placed (s31)
//
// WIRED: order placement calls OrderPlacementRepository.placeOrder ->
// `POST /orders` (see lib/data/repositories/order_placement_repository.dart).
// On ApiException the Review sheet swaps to KErrorView.orderFailed instead of
// silently "succeeding".
//
// R-31: the PIN step reuses the app's existing passcode
// (lib/screens/shared/confirm_passcode_sheet.dart's `confirmPasscode`,
// PasscodeStore, salted SHA-256 in flutter_secure_storage) rather than a
// second credential — confirmation is local, the order call is unchanged.
//
// R-34 / C-1, the highest-priority rule for this file: NO CLIENT-SIDE FEE
// CONSTANT, EVER. This file used to carry `_kBuyFeeRate`/`_kSellFeeRate`
// (a flat 1.35%). fees.ts's own header records what that caused: the app
// displayed "Fees · 1.35%" on every review screen while the backend charged
// nothing at all, so an investor was quoted a total the platform never
// collected. Both constants are gone. Every fee/commission/total/proceeds
// figure below is either read from the wire or, where the wire has nothing
// to read, omitted with the row kept and the gap filed —
// see BACKEND_GAPS.md's "Buy and sell — fees are unreachable anywhere in
// this flow" entry. Checked directly against the backend for this pass:
// `POST /orders`'s response type (`Order` in
// Kudimata-Securities-Backend/src/common/types/order.types.ts) carries no
// commission/exchange-fee/VAT/total field at all, and the one endpoint that
// does compute them (`GET /orders/contract-note/:ref`) needs a
// `contractNoteRef` the client is never given. So no step in this flow —
// not the shares estimate, not the review, not the placed screen — has a
// real fee figure to show, at any point, today.
//
// The consideration (units × price) is NOT a fee — it is the investor's own
// input times a real quote, computable and shown throughout.
//
// The "nearest seller"/"best buyer now" reference price the canvas shows
// distinct from a plain last-traded price implies live bid/ask depth. No
// such feed exists (`SimulatedNgxBroker` is the only `BrokerAdapter` and
// gives one plausible-per-ticker quote, not a book — the same root cause
// DECISIONS.md's B-2 already used to justify hiding the asset-detail Order
// Book tab). This flow uses the one real quote (`Asset.price`) for both
// roles rather than inventing a spread, and that is filed too.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/data/repositories/order_placement_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart'
    show BankAccountSummary;
import 'package:kudimata_invest/screens/shared/confirm_passcode_sheet.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/wallet/wallet_flows.dart' show showAddMoneyFlow;
import 'package:go_router/go_router.dart';

/// Smallest single buy order — mirrors the backend's MIN_ORDER_KOBO
/// (src/common/minimums.ts), which is the authoritative check. The new
/// flow enters a share count rather than a naira amount, so this is
/// converted to a minimum share count against whichever reference price
/// applies (the investor's own limit, or the live quote for a now-order).
const double _kMinOrderNaira = 5000;

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// Signatures unchanged: asset_detail_screen.dart, holding_detail_screen.dart
// and explain_screen.dart all call these with (context, asset).
// ─────────────────────────────────────────────────────────────────────────────

/// Buy flow: chooser → [price] → shares → review → PIN → placed. Gated on
/// [tradingEligibilityGap] — browsing an asset's detail page never requires
/// KYC/suitability, only actually trading does (also enforced server-side,
/// OrdersService.assertEligibleToTrade, since this check alone is
/// bypassable).
Future<void> showBuyFlow(BuildContext context, Asset asset) async {
  if (!await _ensureEligibleToTrade(context)) return;
  if (!context.mounted) return;
  await _runBuyFlow(context, asset);
}

/// Sell flow: chooser → [price] → shares → review (destination included) →
/// PIN → placed. Same gate as [showBuyFlow].
Future<void> showSellFlow(BuildContext context, Asset asset) async {
  if (!await _ensureEligibleToTrade(context)) return;
  if (!context.mounted) return;
  await _runSellFlow(context, asset);
}

/// Shows a sheet pointing the investor at whichever KYC/suitability step
/// they're missing instead of opening the trade sheet. Returns true (no
/// sheet shown) once they're actually eligible.
Future<bool> _ensureEligibleToTrade(BuildContext context) async {
  final gap = tradingEligibilityGap(AppScope.read(context));
  if (gap == null) return true;
  await showKSheet<void>(
    context,
    child: KStatusView(
      tone: KStatusTone.pending,
      title: gap.title,
      message: gap.message,
      primary: 'Continue',
      onPrimary: () {
        Navigator.of(context).pop();
        context.push(gap.route);
      },
      secondary: 'Not now',
      onSecondary: () => Navigator.of(context).pop(),
    ),
  );
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step-navigation plumbing. Each step sheet returns either a real payload
// (moving forward), `_back` (return to the previous step), or `null` (the
// sheet was dismissed — end the flow). Kept as a tiny marker class rather
// than a bigger state-machine package: four steps, two flows.
//
// Each step is presented as its OWN showKSheet call, awaited fully before
// the next opens — never popped-then-immediately-reopened on the same
// still-transitioning navigator. That pop-then-push pattern is a known
// source of a stale modal barrier sitting above the newly-presented sheet
// and absorbing its taps (reported live as "even the success purchase
// modal, the buttons don't respond", 2026-08-15).
// ─────────────────────────────────────────────────────────────────────────────

class _Back {
  const _Back();
}

const _back = _Back();

enum _Kind { now, limit }

// ─────────────────────────────────────────────────────────────────────────────
// Shared formatting/parsing helpers.
// ─────────────────────────────────────────────────────────────────────────────

/// Asset.price arrives as a preformatted display string ("₦268.40" /
/// "$228.10") — strip the currency symbol/commas to get a usable double.
double _parsePrice(String price) =>
    double.tryParse(price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

double _parseNum(String s) => double.tryParse(s.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

/// Whole-naira value -> "₦50,000" (no decimals — every naira figure in this
/// flow is either a share price or a consideration, never a kobo-precise
/// fee breakdown, since no fee figure is ever shown here — see this file's
/// header comment).
String _formatNaira(double value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final abs = negative ? -rounded : rounded;
  final s = abs.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buf.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return '${negative ? '−' : ''}₦$buf';
}

/// Naira value -> "₦226.00" (2 decimals) — for a per-share price, which the
/// canvas always shows to the kobo.
String _formatNairaDecimal(double value) {
  final kobo = (value * 100).round();
  final negative = kobo < 0;
  final absKobo = negative ? -kobo : kobo;
  final wholeNaira = absKobo ~/ 100;
  final koboRemainder = absKobo % 100;
  final wholeStr = wholeNaira.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '${negative ? '−' : ''}₦$wholeStr.${koboRemainder.toString().padLeft(2, '0')}';
}

/// Share-units value -> "60" (whole) or "60.5" (one decimal only when
/// needed).
String _formatShares(double units) =>
    units == units.roundToDouble() ? units.toStringAsFixed(0) : units.toStringAsFixed(1);

/// The next NGX trading session's date, skipping weekends — client-clock
/// heuristic only, same class of approximation as market_hours.dart's
/// isNgxOpenNow() (good enough to label a queued order's UI, not
/// authoritative exchange-calendar data — a public holiday isn't
/// accounted for, same gap isNgxOpenNow() already has).
String _nextTradingSessionLabel() {
  final now = DateTime.now();
  var day = now.add(const Duration(days: 1));
  while (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
    day = day.add(const Duration(days: 1));
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${day.day} ${months[day.month - 1]}';
}

/// T+3 settlement date from today, skipping weekends — same heuristic class
/// as [_nextTradingSessionLabel]; matches the backend's real T+3 convention
/// (fees.ts's `settlementDate`, verified in DECISIONS.md's FACT-CONFLICTS.md
/// C-5 as accurate) without being authoritative holiday-calendar data.
String _settleLabel() {
  var day = DateTime.now();
  var remaining = 3;
  while (remaining > 0) {
    day = day.add(const Duration(days: 1));
    if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) remaining--;
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${day.day} ${months[day.month - 1]}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared screen-local widgets.
// ─────────────────────────────────────────────────────────────────────────────

/// The ticker-initials circle above "Review order"/"Review sale" (s29/s48
/// etc). Local to this file rather than a fork of `KAssetRow` (which draws
/// a full name+ticker+price row, not a standalone centred avatar).
class _AssetAvatar extends StatelessWidget {
  const _AssetAvatar({required this.asset});
  final Asset asset;

  String get _initials {
    final letters = asset.ticker.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: asset.logoColor ?? KColor.indicatorTint,
            borderRadius: KRadii.cardR,
          ),
          child: Text(_initials, style: KType.cardTitle(w: KWeight.bold)),
        ),
        const SizedBox(height: 10),
        Text(asset.name, style: KType.body(w: KWeight.semibold)),
      ],
    );
  }
}

/// A tappable icon+title+description card — the chooser screens' (s42/s45)
/// two option cards. Distinct from [_RadioOptionCard] below: no radio
/// indicator, whole card is the tap target.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KRadii.cardR,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(color: KColor.hairline, width: 1),
          borderRadius: KRadii.cardR,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, borderRadius: KRadii.pillR),
              child: KIcon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.body(w: KWeight.semibold)),
                  const SizedBox(height: 4),
                  Text(description, style: KType.data(color: KColor.ink2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bordered, optionally-tinted radio row — the sell review's "Where the
/// money goes" destination options (s48). Local to this file rather than a
/// design-system component: composes existing KRadio/KColor/KType
/// primitives for a single app-level layout pattern.
class _RadioOptionCard extends StatelessWidget {
  const _RadioOptionCard({
    required this.checked,
    required this.title,
    required this.description,
    this.disabled = false,
  });

  final bool checked;
  final String title;
  final String description;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 15),
        decoration: BoxDecoration(
          color: checked ? KColor.indicatorTint : KColor.bg,
          border: Border.all(
            color: checked ? KColor.indicator : KColor.hairline,
            width: checked ? 1.5 : 1,
          ),
          borderRadius: KRadii.cardR,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KRadio(checked: checked, disabled: disabled),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.body(color: KColor.ink)),
                  const SizedBox(height: 2),
                  Text(description, style: KType.data(color: KColor.ink2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bottom Back/Cancel + primary action row — every step sheet's footer.
/// This app presents every step of this flow as a bottom sheet (established
/// by this file before the redesign, kept deliberately: KSheet has no
/// built-in back affordance and a top-left circular arrow — the artboards'
/// own control, drawn for a full-screen mockup — has no natural home inside
/// a modal sheet). A bottom ghost "Back"/"Cancel" button carries the same
/// job the artboards' arrow does; step 1 shows "Cancel" (nothing to go back
/// to), every later step shows "Back".
class _StepFooter extends StatelessWidget {
  const _StepFooter({
    required this.backLabel,
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
  });

  final String backLabel;
  final VoidCallback? onBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KButton(
          label: backLabel,
          variant: KButtonVariant.ghost,
          fullWidth: false,
          onPressed: onBack,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: KButton(
            label: primaryLabel,
            loading: primaryLoading,
            onPressed: onPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.divider = true,
    this.emphasize = false,
  }) : assert(value != null || valueWidget != null, '_SummaryRow needs value or valueWidget');

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool divider;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasize ? KType.cardTitle() : KType.body(color: KColor.ink2);
    final valueStyle = emphasize
        ? KType.cardTitle()
        : KType.body(color: KColor.ink, w: KWeight.medium);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: KColor.hairline, width: 1)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          valueWidget ?? Text(value!, style: valueStyle.tnum),
        ],
      ),
    );
  }
}

/// A fee/total figure this flow has no data source for — see this file's
/// header comment. Renders in place of a number rather than inventing one
/// (R-34) or silently dropping the row (rule 2 of the screen-agent brief).
const String _feeUnknown = 'Added when your order fills';

// ─────────────────────────────────────────────────────────────────────────────
// BUY FLOW
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _runBuyFlow(BuildContext context, Asset asset) async {
  var step = 0;
  _Kind? kind;
  double? limitPrice;
  double? units;

  while (true) {
    switch (step) {
      case 0:
        // Nothing committed yet — just about to open the first step sheet.
        // Reached fresh on the first pass, or via the loop's back-edge from
        // case 1's "Back". Either way, if the widget is gone there is no
        // sheet to open and no order in flight, so ending the flow silently
        // is correct.
        if (!context.mounted) return;
        final res = await _showChooserSheet(context, asset: asset, isSell: false);
        if (res == null || !context.mounted) return;
        kind = res as _Kind;
        step = kind == _Kind.now ? 2 : 1;
        break;

      case 1:
        // Same reasoning as case 0: opening the price sheet, nothing
        // committed. Reached from case 0 forward or case 2's "Back".
        if (!context.mounted) return;
        final res = await _showPriceSheet(
          context,
          asset: asset,
          isSell: false,
          initial: limitPrice,
          referenceLabel: 'Nearest seller',
          belowHint: (p) => 'Below $p you wait for a seller to come down to your price.',
        );
        if (!context.mounted) return;
        if (res == _back) {
          step = 0;
          break;
        }
        if (res == null) return;
        limitPrice = res as double;
        step = 2;
        break;

      case 2:
        final refPrice = kind == _Kind.now ? _parsePrice(asset.price) : limitPrice!;
        // Opening the shares sheet — still nothing committed (shares aren't
        // chosen yet). Reached from case 0/1 forward or case 3's "Back".
        if (!context.mounted) return;
        final res = await _showBuySharesSheet(
          context,
          asset: asset,
          kind: kind!,
          price: refPrice,
        );
        if (!context.mounted) return;
        if (res == _back) {
          step = kind == _Kind.now ? 0 : 1;
          break;
        }
        if (res == null) return;
        units = res as double;
        step = 3;
        break;

      case 3:
        final refPrice = kind == _Kind.now ? _parsePrice(asset.price) : limitPrice!;
        // Opening the review sheet. This still precedes order placement —
        // placing the order happens inside _BuyReviewSheetState._confirm,
        // which already guards on its own State.mounted before touching
        // context or state. So there is still nothing committed at this
        // point; returning silently is safe.
        if (!context.mounted) return;
        final order = await _showBuyReviewSheet(
          context,
          asset: asset,
          kind: kind!,
          price: refPrice,
          units: units!,
        );
        if (!context.mounted) return;
        if (order == _back) {
          step = 2;
          break;
        }
        if (order == null) return;
        await _pushPlacedScreen(
          context,
          asset: asset,
          isSell: false,
          units: units,
          order: order as Order,
        );
        return;
    }
  }
}

/// s42 "How to buy". Subtitle: "{name}, last traded {price}" — real, the
/// same [Asset.price] shown everywhere else in the app.
Future<Object?> _showChooserSheet(
  BuildContext context, {
  required Asset asset,
  required bool isSell,
}) {
  if (!isSell) {
    return showKSheet<Object>(
      context,
      child: _StaticChooser(
        title: 'How do you want to buy?',
        subtitle: '${asset.name}, last traded ${asset.price}',
        nowIcon: 'arrowUpRight',
        nowTitle: 'Buy now',
        nowDescription:
            'Takes the cheapest shares on sale right now. If nobody is selling, nothing happens.',
        onNow: () => Navigator.of(context).pop(_Kind.now),
        limitTitle: 'Name your price',
        limitDescription:
            'You set the price per share. Your order waits in the queue until someone sells at '
            'that price, or the market closes.',
        onLimit: () => Navigator.of(context).pop(_Kind.limit),
      ),
    );
  }
  // Sell chooser needs the real holding (for "You hold N shares") before it
  // can render — see [_SellChooserSheet].
  return showKSheet<Object>(context, child: _SellChooserSheet(asset: asset));
}

class _StaticChooser extends StatelessWidget {
  const _StaticChooser({
    required this.title,
    required this.subtitle,
    required this.nowIcon,
    required this.nowTitle,
    required this.nowDescription,
    required this.onNow,
    required this.limitTitle,
    required this.limitDescription,
    required this.onLimit,
  });

  final String title;
  final String subtitle;
  final String nowIcon;
  final String nowTitle;
  final String nowDescription;
  final VoidCallback onNow;
  final String limitTitle;
  final String limitDescription;
  final VoidCallback onLimit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: KType.title()),
        const SizedBox(height: 6),
        Text(subtitle, style: KType.body(color: KColor.ink2)),
        const SizedBox(height: 20),
        _ChoiceCard(
          icon: nowIcon,
          iconColor: KColor.gain,
          iconBg: KColor.gain.withValues(alpha: 0.12),
          title: nowTitle,
          description: nowDescription,
          onTap: onNow,
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: 'clock',
          iconColor: KColor.indicator,
          iconBg: KColor.indicatorTint,
          title: limitTitle,
          description: limitDescription,
          onTap: onLimit,
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: KButton(
            label: 'Cancel',
            variant: KButtonVariant.ghost,
            fullWidth: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step (limit only) — price per share (s43 buy, s46 sell).
// ─────────────────────────────────────────────────────────────────────────────

Future<Object?> _showPriceSheet(
  BuildContext context, {
  required Asset asset,
  required bool isSell,
  required double? initial,
  required String referenceLabel,
  required String Function(String priceLabel) belowHint,
  String? avgPriceLabel,
}) {
  return showKSheet<Object>(
    context,
    child: _PriceSheet(
      asset: asset,
      isSell: isSell,
      initial: initial,
      referenceLabel: referenceLabel,
      belowHint: belowHint,
      avgPriceLabel: avgPriceLabel,
    ),
  );
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet({
    required this.asset,
    required this.isSell,
    required this.initial,
    required this.referenceLabel,
    required this.belowHint,
    this.avgPriceLabel,
  });

  final Asset asset;
  final bool isSell;
  final double? initial;
  final String referenceLabel;
  final String Function(String priceLabel) belowHint;

  /// The real [Holding.avgPrice] display string, for the sell side's "you
  /// paid X a share on average" line — null on the buy side, where no
  /// average-cost concept applies.
  final String? avgPriceLabel;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final TextEditingController _price = TextEditingController(
    text: (widget.initial ?? _parsePrice(widget.asset.price)).toStringAsFixed(2),
  );

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  double get _value => _parseNum(_price.text);

  @override
  Widget build(BuildContext context) {
    final referencePrice = _parsePrice(widget.asset.price);
    final referenceLabelStr = _formatNairaDecimal(referencePrice);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.isSell ? 'Sell ${widget.asset.ticker}' : 'Buy ${widget.asset.ticker}',
          style: KType.section(),
        ),
        const SizedBox(height: 14),
        Text(
          widget.isSell ? 'What must one share fetch?' : 'What will you pay per share?',
          style: KType.title(),
        ),
        const SizedBox(height: 6),
        // Naming-your-price context. The canvas separately quotes a buy-ask
        // and a sell-bid (a real bid/ask spread); this backend has no order
        // book depth feed (see this file's header comment), so the one real
        // quote this app has — Asset.price — stands in for both roles.
        Text(
          widget.isSell
              ? 'Naming your price. You paid ${widget.avgPriceLabel ?? "—"} a share on average.'
              : 'Naming your price. The last traded price is ${widget.asset.price}.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 18),
        KInput(
          controller: _price,
          numeric: true,
          amount: true,
          prefix: '₦',
          suffix: 'per share',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          error: _value <= 0 ? 'Enter a price above zero.' : null,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(widget.referenceLabel, style: KType.body(color: KColor.ink2)),
            Text(referenceLabelStr, style: KType.title().tnum),
          ],
        ),
        const SizedBox(height: 6),
        Text(widget.belowHint(referenceLabelStr), style: KType.data(color: KColor.ink3)),
        const SizedBox(height: 20),
        _StepFooter(
          backLabel: 'Back',
          onBack: () => Navigator.of(context).pop(_back),
          primaryLabel: 'Continue',
          onPrimary: _value > 0 ? () => Navigator.of(context).pop(_value) : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step — how many shares (s43b/s43m buy, s47/s46m sell).
// ─────────────────────────────────────────────────────────────────────────────

Future<Object?> _showBuySharesSheet(
  BuildContext context, {
  required Asset asset,
  required _Kind kind,
  required double price,
}) {
  return showKSheet<Object>(
    context,
    child: _BuySharesSheet(asset: asset, kind: kind, price: price),
  );
}

class _BuySharesSheet extends StatefulWidget {
  const _BuySharesSheet({required this.asset, required this.kind, required this.price});
  final Asset asset;
  final _Kind kind;
  final double price;

  @override
  State<_BuySharesSheet> createState() => _BuySharesSheetState();
}

class _BuySharesSheetState extends State<_BuySharesSheet> {
  late final TextEditingController _shares = TextEditingController(text: '');
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  double? _walletBalanceNaira;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final balance = await _walletRepo.balance();
      if (!mounted) return;
      setState(() => _walletBalanceNaira = _parseNum(balance));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  double get _units => double.tryParse(_shares.text) ?? 0;
  double get _cost => _units * widget.price;
  int get _minShares => widget.price > 0 ? (_kMinOrderNaira / widget.price).ceil().clamp(1, 1 << 30) : 1;
  int? get _maxShares =>
      _walletBalanceNaira == null || widget.price <= 0 ? null : (_walletBalanceNaira! / widget.price).floor();

  bool get _belowMinimum => _units > 0 && _units < _minShares;
  bool get _insufficientBalance =>
      _walletBalanceNaira != null && _units > 0 && _cost > _walletBalanceNaira!;

  @override
  Widget build(BuildContext context) {
    final isNow = widget.kind == _Kind.now;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Buy ${widget.asset.ticker}', style: KType.section()),
        const SizedBox(height: 14),
        Text('How many shares?', style: KType.title()),
        const SizedBox(height: 6),
        Text(
          isNow
              ? 'Buying now at the best price on sale, ${widget.asset.price}.'
              : 'At your price of ${_formatNairaDecimal(widget.price)} a share.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 18),
        KInput(
          controller: _shares,
          numeric: true,
          amount: true,
          suffix: 'shares',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          error: _belowMinimum
              ? 'The smallest order is $_minShares shares at this price.'
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Min $_minShares share${_minShares == 1 ? '' : 's'}',
                style: KType.data(color: KColor.ink3)),
            Text(
              _loadFailed
                  ? 'Max —'
                  : (_maxShares == null ? 'Max …' : 'Max $_maxShares with your cash'),
              style: KType.data(color: KColor.ink3),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(isNow ? 'Estimated total' : 'Total to pay', style: KType.body(color: KColor.ink2)),
            Text(_feeUnknown, style: KType.body(color: KColor.ink3)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isNow
              ? 'The final price can move a little while the order fills. Fees are calculated '
                  'by Kudimata when your order fills — not shown here yet.'
              : 'Fees are calculated by Kudimata when your order fills — not shown here yet.',
          style: KType.data(color: KColor.ink3),
        ),
        const SizedBox(height: 20),
        _StepFooter(
          backLabel: 'Back',
          onBack: () => Navigator.of(context).pop(_back),
          primaryLabel: 'Review order',
          onPrimary: (_units <= 0 || _belowMinimum)
              ? null
              : _insufficientBalance
                  ? () {
                      Navigator.of(context).pop();
                      showAddMoneyFlow(context);
                    }
                  : () => Navigator.of(context).pop(_units),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step — review (s29 limit / s29m market).
// ─────────────────────────────────────────────────────────────────────────────

Future<Object?> _showBuyReviewSheet(
  BuildContext context, {
  required Asset asset,
  required _Kind kind,
  required double price,
  required double units,
}) {
  return showKSheet<Object>(
    context,
    child: _BuyReviewSheet(asset: asset, kind: kind, price: price, units: units),
  );
}

class _BuyReviewSheet extends StatefulWidget {
  const _BuyReviewSheet({
    required this.asset,
    required this.kind,
    required this.price,
    required this.units,
  });
  final Asset asset;
  final _Kind kind;
  final double price;
  final double units;

  @override
  State<_BuyReviewSheet> createState() => _BuyReviewSheetState();
}

class _BuyReviewSheetState extends State<_BuyReviewSheet> {
  late final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
  bool _agreed = false;
  bool _placing = false;
  bool _failed = false;
  String? _failureMessage;

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return KErrorView.orderFailed(
        message: _failureMessage,
        onPrimary: () {
          setState(() => _failed = false);
          _confirm();
        },
        onSecondary: () => Navigator.of(context).pop(),
      );
    }

    final isLimit = widget.kind == _Kind.limit;
    final consideration = widget.units * widget.price;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Review order', style: KType.section()),
        const SizedBox(height: 16),
        _AssetAvatar(asset: widget.asset),
        const SizedBox(height: 16),
        Column(
          children: [
            _SummaryRow(label: 'Order type', value: isLimit ? 'Limit buy' : 'Market buy'),
            _SummaryRow(label: 'Number of shares', value: _formatShares(widget.units)),
            _SummaryRow(
              label: isLimit ? 'Your price per share' : 'Best price now',
              value: _formatNairaDecimal(widget.price),
            ),
            _SummaryRow(label: 'Estimated amount', value: _formatNaira(consideration)),
            _SummaryRow(label: 'Estimated commission', value: _feeUnknown),
            _SummaryRow(label: 'Total amount', value: _feeUnknown, divider: false, emphasize: true),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.cardR),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLimit
                    ? 'Your order fills at or near ${_formatNairaDecimal(widget.price)}. It cannot '
                        'be cancelled once the market opens.'
                    : 'You buy at the best prices on sale right now, so the final price per share '
                        'can differ slightly.',
                style: KType.data(color: KColor.ink2),
              ),
              const SizedBox(height: 7),
              Text(
                isLimit
                    ? 'Anything unfilled expires at 4:30pm. You can place a new order from 10:00am '
                        'tomorrow.'
                    : 'If nobody is selling, the order fails and nothing leaves your wallet.',
                style: KType.data(color: KColor.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // A real, live compliance ack, not decoration — kept even though the
        // canvas doesn't draw it (dropping a risk acknowledgement to match a
        // mockup exactly would be the wrong kind of exact).
        KCheckbox(
          checked: _agreed,
          label: 'I understand the risks',
          onChanged: (v) => setState(() => _agreed = v),
        ),
        const SizedBox(height: 16),
        _StepFooter(
          backLabel: 'Back',
          onBack: _placing ? null : () => Navigator.of(context).pop(_back),
          primaryLabel: 'Place order',
          primaryLoading: _placing,
          onPrimary: (_agreed && !_placing) ? _confirm : null,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    if (!AppScope.read(context).marketOpen) {
      final cont = await _showMarketClosedInterstitial(context, asset: widget.asset);
      if (cont != true || !mounted) return;
    }
    final confirmed = await confirmPasscode(
      context,
      store: PasscodeStore(),
      title: 'Confirm your purchase',
      message: 'Enter your passcode to place this order for ${widget.asset.ticker}.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _placing = true);
    try {
      final order = await _repo.placeOrder(
        ticker: widget.asset.ticker,
        side: OrderSide.buy,
        units: widget.units,
        orderType: widget.kind == _Kind.limit ? OrderType.limit : OrderType.market,
        limitPrice: widget.kind == _Kind.limit ? (widget.price * 100).round() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _failed = true;
        _failureMessage = e.message;
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Market-closed interstitial (s29c) — appears over the review whenever the
// NGX is shut, for both buy and sell (the canvas only draws a buy variant;
// the copy generalises cleanly to a sell, and no dedicated sell artboard
// exists to diverge from — see this file's report for this reuse).
// ─────────────────────────────────────────────────────────────────────────────

Future<bool?> _showMarketClosedInterstitial(BuildContext context, {required Asset asset}) {
  return showKSheet<bool>(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        KIllustration('timeout', role: KIlloRole.state),
        const SizedBox(height: 18),
        Text('The market is closed right now',
            textAlign: TextAlign.center, style: KType.title()),
        const SizedBox(height: 12),
        Text(
          'Your order goes to market when it reopens at 10:00am, ${_nextTradingSessionLabel()}, '
          'and fills at the price then, not right now\'s price.',
          textAlign: TextAlign.center,
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 10),
        Text(
          'You can cancel it up to 5 minutes before the market opens.',
          textAlign: TextAlign.center,
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 20),
        KButton(label: 'Continue', onPressed: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Placed screen (s31) — pushed full-screen (matches the canvas: own status
// bar, no scrim/drag-handle, not a sheet), same pattern the buy/sell flows
// already used for their terminal screen before this pass.
//
// s44 ("Bought, at the real prices") is a separate later artboard in the
// same canvas section that this build does not reach. It needs a per-leg
// fill breakdown (e.g. "64 shares at ₦228.50 / 45 shares at ₦229.10") and a
// fee total — the Order model stores one fill price, never several, and
// (per this file's header comment) `POST /orders`'s response carries no fee
// field at all. Both are filed in BACKEND_GAPS.md; this flow's terminal
// screen is s31, which every real signal below (order created, order
// status, settlement estimate) can actually back.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _pushPlacedScreen(
  BuildContext context, {
  required Asset asset,
  required bool isSell,
  required double units,
  required Order order,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => _PlacedScreen(asset: asset, isSell: isSell, units: units, order: order),
    ),
  );
}

class _PlacedScreen extends StatelessWidget {
  const _PlacedScreen({
    required this.asset,
    required this.isSell,
    required this.units,
    required this.order,
  });
  final Asset asset;
  final bool isSell;
  final double units;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final filled = order.status == 'approved';
    final settleLabel = _settleLabel();
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: KMilestoneSheet(
                            illustrationName: 'milestone-first-trade',
                            eyebrow: isSell ? 'Sale placed' : 'Order placed',
                            title: isSell ? 'Sale placed' : 'Order placed',
                            // The canvas's message also states a total ("for
                            // ₦25,000") — a fee-dependent figure this flow
                            // has no source for (see this file's header
                            // comment), so it is omitted rather than shown
                            // wrong; the share count is real.
                            message: '${_formatShares(units)} shares of ${asset.name}'
                                '${isSell ? ' sold.' : '.'}',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: KColor.paper,
                            border: Border.all(color: KColor.hairline, width: 1),
                            borderRadius: KRadii.cardR,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Column(
                            children: [
                              _tracker('Sent to the market', done: true),
                              _tracker(
                                isSell ? 'Selling your shares' : 'Buying your shares',
                                done: filled,
                                inProgress: !filled,
                              ),
                              _tracker('Shares settled, $settleLabel', done: false, divider: false),
                            ],
                          ),
                        ),
                        if (order.reference != null) ...[
                          const SizedBox(height: 12),
                          Text('Reference · ${order.reference}',
                              style: KType.data(color: KColor.ink3)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    KButton(
                      label: 'Go to portfolio',
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.go(Routes.portfolio);
                      },
                    ),
                    const SizedBox(height: 10),
                    KButton(
                      label: 'View this order',
                      variant: KButtonVariant.ghost,
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.push(Routes.orderStatus);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tracker(String label, {required bool done, bool inProgress = false, bool divider = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: KColor.hairline, width: 1)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? KColor.gain : (inProgress ? KColor.indicator : KColor.track),
              shape: BoxShape.circle,
            ),
            child: done
                ? KIcon('check', size: 13, color: KColor.bg)
                : (inProgress ? const KSpinner(size: 12, color: Colors.white) : null),
          ),
          const SizedBox(width: 12),
          Text(label, style: KType.body(color: done || inProgress ? KColor.ink : KColor.ink2)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELL FLOW
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _runSellFlow(BuildContext context, Asset asset) async {
  var step = 0;
  _Kind? kind;
  double? limitPrice;
  double? units;
  Holding? holding;

  while (true) {
    switch (step) {
      case 0:
        // Nothing committed yet — opening the sell chooser (which itself
        // just reads the holding, doesn't mutate anything). Reached fresh
        // or via case 1's "Back".
        if (!context.mounted) return;
        final res = await showKSheet<Object>(
          context,
          child: _SellChooserSheet(asset: asset),
        );
        if (res == null || !context.mounted) return;
        if (res is _SellChooserResult) {
          kind = res.kind;
          holding = res.holding;
        }
        step = kind == _Kind.now ? 2 : 1;
        break;

      case 1:
        // Opening the price sheet, still nothing committed. Reached from
        // case 0 forward or case 2's "Back".
        if (!context.mounted) return;
        final res = await _showPriceSheet(
          context,
          asset: asset,
          isSell: true,
          initial: limitPrice,
          referenceLabel: 'Best buyer now',
          belowHint: (p) => 'Above $p your shares wait until a buyer pays your price.',
          avgPriceLabel: holding?.avgPrice,
        );
        if (!context.mounted) return;
        if (res == _back) {
          step = 0;
          break;
        }
        if (res == null) return;
        limitPrice = res as double;
        step = 2;
        break;

      case 2:
        final refPrice = kind == _Kind.now ? _parsePrice(asset.price) : limitPrice!;
        // Opening the shares sheet — shares not yet chosen, nothing
        // committed. Reached from case 0/1 forward or case 3's "Back".
        if (!context.mounted) return;
        final res = await _showSellSharesSheet(
          context,
          asset: asset,
          kind: kind!,
          price: refPrice,
          holding: holding!,
        );
        if (!context.mounted) return;
        if (res == _back) {
          step = kind == _Kind.now ? 0 : 1;
          break;
        }
        if (res == null) return;
        units = res as double;
        step = 3;
        break;

      case 3:
        final refPrice = kind == _Kind.now ? _parsePrice(asset.price) : limitPrice!;
        // Opening the review sheet, still before order placement — placing
        // the sell order happens inside _SellReviewSheetState._confirm,
        // which already guards on its own State.mounted. Nothing committed
        // here yet, so returning silently is safe.
        if (!context.mounted) return;
        final order = await _showSellReviewSheet(
          context,
          asset: asset,
          kind: kind!,
          price: refPrice,
          units: units!,
          holding: holding!,
        );
        if (!context.mounted) return;
        if (order == _back) {
          step = 2;
          break;
        }
        if (order == null) return;
        await _pushPlacedScreen(
          context,
          asset: asset,
          isSell: true,
          units: units,
          order: order as Order,
        );
        return;
    }
  }
}

class _SellChooserResult {
  const _SellChooserResult(this.kind, this.holding);
  final _Kind kind;
  final Holding holding;
}

/// s45 "How to sell". Loads the real [Holding] first (needed for "You hold
/// N shares" and, downstream, "you paid X on average") — own loading/error
/// state, since this is the sell flow's very first real network read.
class _SellChooserSheet extends StatefulWidget {
  const _SellChooserSheet({required this.asset});
  final Asset asset;

  @override
  State<_SellChooserSheet> createState() => _SellChooserSheetState();
}

class _SellChooserSheetState extends State<_SellChooserSheet> {
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  late Future<Holding> _future = _holdingsRepo.byTicker(widget.asset.ticker);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Holding>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: KLoadingView(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: KErrorView(
              onPrimary: () => setState(
                () => _future = _holdingsRepo.byTicker(widget.asset.ticker),
              ),
            ),
          );
        }
        final holding = snapshot.data!;
        return _StaticChooser(
          title: 'How do you want to sell?',
          subtitle: 'You hold ${holding.units} ${widget.asset.name} shares',
          nowIcon: 'arrowDownLeft',
          nowTitle: 'Sell now',
          nowDescription:
              'Sells to whoever is paying the most right now, currently ${widget.asset.price}. If '
              'nobody is buying, nothing happens.',
          onNow: () => Navigator.of(context).pop(_SellChooserResult(_Kind.now, holding)),
          limitTitle: 'Name your price',
          limitDescription:
              'You set what one share must fetch. It waits in the queue until a buyer pays it, or '
              'the market closes.',
          onLimit: () => Navigator.of(context).pop(_SellChooserResult(_Kind.limit, holding)),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step — how many shares to sell (s47 limit / s46m now).
// ─────────────────────────────────────────────────────────────────────────────

Future<Object?> _showSellSharesSheet(
  BuildContext context, {
  required Asset asset,
  required _Kind kind,
  required double price,
  required Holding holding,
}) {
  return showKSheet<Object>(
    context,
    child: _SellSharesSheet(asset: asset, kind: kind, price: price, holding: holding),
  );
}

class _SellSharesSheet extends StatefulWidget {
  const _SellSharesSheet({
    required this.asset,
    required this.kind,
    required this.price,
    required this.holding,
  });
  final Asset asset;
  final _Kind kind;
  final double price;
  final Holding holding;

  @override
  State<_SellSharesSheet> createState() => _SellSharesSheetState();
}

class _SellSharesSheetState extends State<_SellSharesSheet> {
  late final TextEditingController _shares = TextEditingController(text: '');
  late final double _holdingUnits = _parseNum(widget.holding.units);

  double get _units => double.tryParse(_shares.text) ?? 0;
  bool get _overHolding => _units > _holdingUnits;

  @override
  Widget build(BuildContext context) {
    final isNow = widget.kind == _Kind.now;
    final remaining = (_holdingUnits - _units).clamp(0, _holdingUnits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sell ${widget.asset.ticker}', style: KType.section()),
        const SizedBox(height: 14),
        Text('How many shares?', style: KType.title()),
        const SizedBox(height: 6),
        Text(
          isNow
              ? 'Selling now to the best buyer, ${widget.asset.price} a share.'
              : 'At your price of ${_formatNairaDecimal(widget.price)} a share.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 18),
        KInput(
          controller: _shares,
          numeric: true,
          amount: true,
          suffix: 'of ${_formatShares(_holdingUnits)}',
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          error: _overHolding ? 'You only hold ${_formatShares(_holdingUnits)} shares.' : null,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Min 1 share', style: KType.data(color: KColor.ink3)),
            Text('Max All ${_formatShares(_holdingUnits)}', style: KType.data(color: KColor.ink3)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(isNow ? 'You should receive' : 'You receive', style: KType.body(color: KColor.ink2)),
            Text(_feeUnknown, style: KType.body(color: KColor.ink3)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Fees are calculated by Kudimata when your order fills — not shown here yet. '
          '${_formatShares(remaining.toDouble())} shares left.',
          style: KType.data(color: KColor.ink3),
        ),
        const SizedBox(height: 20),
        _StepFooter(
          backLabel: 'Back',
          onBack: () => Navigator.of(context).pop(_back),
          primaryLabel: 'Review sale',
          onPrimary: (_units <= 0 || _overHolding) ? null : () => Navigator.of(context).pop(_units),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step — review the sale (s48 limit / s48m now), including "Where the
// money goes".
//
// REAL BACKEND GAP — sale proceeds always go to the wallet. The Order
// resource does have a `destinationBankAccountId` field, but
// `OrdersService.applyWalletSideEffect` credits the wallet for EVERY sell
// regardless of what's set there — redirecting proceeds to a bank account
// still needs TransactionsService's payout logic, not wired into
// OrdersService today. The canvas pre-selects a bank destination; this
// screen keeps the bank row visible but disabled, with an honest inline
// note, and defaults to (and only offers) the wallet — visibly unavailable
// rather than silently not doing what it says. Filed in BACKEND_GAPS.md.
// ─────────────────────────────────────────────────────────────────────────────

Future<Object?> _showSellReviewSheet(
  BuildContext context, {
  required Asset asset,
  required _Kind kind,
  required double price,
  required double units,
  required Holding holding,
}) {
  return showKSheet<Object>(
    context,
    child: _SellReviewSheet(asset: asset, kind: kind, price: price, units: units, holding: holding),
  );
}

class _SellReviewSheet extends StatefulWidget {
  const _SellReviewSheet({
    required this.asset,
    required this.kind,
    required this.price,
    required this.units,
    required this.holding,
  });
  final Asset asset;
  final _Kind kind;
  final double price;
  final double units;
  final Holding holding;

  @override
  State<_SellReviewSheet> createState() => _SellReviewSheetState();
}

class _SellReviewSheetState extends State<_SellReviewSheet> {
  late final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late final Future<List<BankAccountSummary>> _accountsFuture = _walletRepo.bankAccounts();
  bool _placing = false;
  bool _failed = false;
  String? _failureMessage;

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return KErrorView.orderFailed(
        message: _failureMessage,
        onPrimary: () {
          setState(() => _failed = false);
          _confirm();
        },
        onSecondary: () => Navigator.of(context).pop(),
      );
    }

    final isLimit = widget.kind == _Kind.limit;
    final holdingUnits = _parseNum(widget.holding.units);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Review sale', style: KType.section()),
        const SizedBox(height: 16),
        _AssetAvatar(asset: widget.asset),
        const SizedBox(height: 16),
        Column(
          children: [
            _SummaryRow(label: 'Order type', value: isLimit ? 'Limit sell' : 'Market sell'),
            _SummaryRow(
              label: 'Shares you are selling',
              value: '${_formatShares(widget.units)} of ${_formatShares(holdingUnits)}',
            ),
            _SummaryRow(
              label: isLimit ? 'Your price per share' : 'Best buyer now',
              value: _formatNairaDecimal(widget.price),
            ),
            _SummaryRow(label: 'Fees and stamp duty', value: _feeUnknown),
            _SummaryRow(label: 'You receive', value: _feeUnknown, divider: false, emphasize: true),
          ],
        ),
        const SizedBox(height: 16),
        const KEyebrow('Where the money goes'),
        const SizedBox(height: 8),
        FutureBuilder<List<BankAccountSummary>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            BankAccountSummary? primary;
            if (snapshot.hasData) {
              for (final a in snapshot.data!) {
                if (a.primary) {
                  primary = a;
                  break;
                }
              }
              primary ??= snapshot.data!.isEmpty ? null : snapshot.data!.first;
            }
            return Column(
              children: [
                const _RadioOptionCard(
                  checked: true,
                  title: 'My Kudimata wallet',
                  description: 'Ready to invest again, same 3 days',
                ),
                const SizedBox(height: 10),
                _RadioOptionCard(
                  checked: false,
                  disabled: true,
                  title: primary == null
                      ? 'Straight to your bank'
                      : 'Straight to ${primary.bankName} ${primary.accountNumberMasked}',
                  description: 'Not available yet — sale proceeds always go to your wallet',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          isLimit
              ? 'Unfilled sell orders expire at 4:30pm. Nothing leaves your holding until a buyer '
                  'takes it.'
              : 'If nobody is buying, the order fails and your shares stay where they are.',
          style: KType.data(color: KColor.ink3),
        ),
        const SizedBox(height: 18),
        _StepFooter(
          backLabel: 'Back',
          onBack: _placing ? null : () => Navigator.of(context).pop(_back),
          primaryLabel: 'Place sell order',
          primaryLoading: _placing,
          onPrimary: _placing ? null : _confirm,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    if (!AppScope.read(context).marketOpen) {
      final cont = await _showMarketClosedInterstitial(context, asset: widget.asset);
      if (cont != true || !mounted) return;
    }
    final confirmed = await confirmPasscode(
      context,
      store: PasscodeStore(),
      title: 'Confirm your sale',
      message: 'Enter your passcode to place this order for ${widget.asset.ticker}.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _placing = true);
    try {
      final order = await _repo.placeOrder(
        ticker: widget.asset.ticker,
        side: OrderSide.sell,
        units: widget.units,
        orderType: widget.kind == _Kind.limit ? OrderType.limit : OrderType.market,
        limitPrice: widget.kind == _Kind.limit ? (widget.price * 100).round() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _failed = true;
        _failureMessage = e.message;
      });
    }
  }
}
