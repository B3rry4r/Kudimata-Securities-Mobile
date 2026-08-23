// Kudimata Invest — Stage 6: Trade buy/sell flows as bottom sheets.
// Mirrors trade-screens.jsx: AmountSheet (+ over-limit error state), ReviewSheet,
// SuccessSheet — shared between Buy and Sell via a `side` flag. Each flow is a
// sequence of showKSheet presentations; the launching screen (asset detail) stays
// behind the scrim, so we don't re-render the design's TradeBackdrop here.
//
// WIRED: order placement calls OrderPlacementRepository.placeOrder ->
// `POST /orders` (see lib/data/repositories/order_placement_repository.dart).
// On ApiException the Review sheet swaps to KErrorView.orderFailed instead of
// silently "succeeding".
//
// FIXED BUG (was: Review sheet never received what the investor actually
// typed in the Amount sheet — it always showed a hardcoded "₦50,000"/
// "186.3 shares" regardless of input, so a real order would have submitted
// the wrong amount). The Amount sheet now computes an [_OrderInput] (naira
// value + share units, whichever the investor actually entered, per the
// naira/shares toggle) and threads it through Review -> confirm -> the
// `POST /orders` payload -> the Success message.
//
// FIXED BUG (was: the Amount sheet's "Balance"/"Holding" line was a
// hardcoded "₦310,400" / "120 shares · ₦32,208" literal, unrelated to the
// investor's real wallet balance or real position size). The Amount sheet
// now fetches WalletRepository.balance() (buy, `GET /wallet-balance`) or
// HoldingsRepository.byTicker (sell, `GET /holdings/:ticker`) once in
// initState and shows the resolved figure — "…" while loading, "—" if the
// fetch fails, since this is a secondary informational element and must not
// block or crash the trade flow.
//
// 2026-08-23 "Soft Landing" exactness pass, spec screens 77-79: the shared
// _AmountSheet/_ReviewSheet/_showSuccessSheet below (and the `side` flag
// that picks between Buy/Sell inside them) are now BUY-ONLY. They were
// written before spec 77-79 existed, when "the sell flow was never detailed
// in this canvas" was literally true — it no longer is, and 77-79's shape
// (a proceeds-destination choice, an explicit fee %, a capital-gains note,
// no risk checkbox) is structurally different enough from the buy sheets
// that reusing them would mean threading a maze of `if (isSell)` branches
// through code written for a different screen. [showSellFlow] now runs its
// own dedicated flow (see "SELL FLOW" section near the end of this file)
// instead. The `_Side.sell` branches left in the shared sheets below are
// dead code as of this pass (nothing calls them with `side: _Side.sell`
// anymore) — kept rather than stripped to limit the size of this diff; a
// follow-up cleanup could remove them.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/order_placement_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/data/repositories/holdings_repository.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart'
    show BankAccountSummary;
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/markets/market_hours.dart';
import 'package:kudimata_invest/screens/wallet/wallet_flows.dart' show showAddMoneyFlow;
import 'package:go_router/go_router.dart';

// Mock daily order limit (₦). Amounts above this trip the over-limit state.
const double _kDailyLimit = 500000;

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// ─────────────────────────────────────────────────────────────────────────────

/// Buy flow: amount → (over-limit?) → review → success. Gated on
/// [tradingEligibilityGap] — browsing an asset's detail page never requires
/// KYC/suitability, only actually trading does (also enforced server-side,
/// OrdersService.assertEligibleToTrade, since this check alone is
/// bypassable).
Future<void> showBuyFlow(BuildContext context, Asset asset) async {
  if (!await _ensureEligibleToTrade(context)) return;
  if (!context.mounted) return;
  await _runTradeFlow(context, asset, side: _Side.buy);
}

/// Sell flow: amount + destination → review → placed (spec screens 77-79 —
/// see "SELL FLOW" section near the end of this file). Same gate as
/// [showBuyFlow].
Future<void> showSellFlow(BuildContext context, Asset asset) async {
  if (!await _ensureEligibleToTrade(context)) return;
  if (!context.mounted) return;
  await _runSellFlow(context, asset);
}

/// Runs the three sheets in sequence, each one only opening once the
/// previous has FULLY dismissed (awaiting showKSheet's own returned Future,
/// which resolves exactly when that sheet's route is gone) — rather than
/// each sheet manually `Navigator.pop()`ing itself and immediately opening
/// the next sheet on the same still-transitioning root navigator. That
/// pop-then-immediately-push-again pattern is a known source of a stale
/// modal barrier (from the sheet still mid-exit-animation) sitting above
/// the newly-presented sheet and absorbing its taps — reported live as
/// "even the success purchase modal, the buttons don't respond" (2026-08-15).
/// Each sheet now returns its result through the SAME showKSheet Future
/// instead of reaching for Navigator/context itself to chain onward.
Future<void> _runTradeFlow(BuildContext context, Asset asset, {required _Side side}) async {
  // BUY-ONLY as of the 2026-08-23 pass — see this file's header comment.
  // Flow G, spec screens 60-61 — a BUY while the NGX is shut queues instead
  // of going through the normal amount/review/confirm chain (spec 61's own
  // nav note: "Queue -> 62", a LATER/separate screen, not this flow's
  // success step).
  if (side == _Side.buy && !isNgxOpenNow()) {
    await _showMarketClosedBuySheet(context, asset);
    return;
  }

  final amountInput = await _showAmountSheet(context, asset, side: side);
  if (amountInput == null || !context.mounted) return;

  final placedInput = await _showReviewSheet(context, asset, side: side, input: amountInput);
  if (placedInput == null || !context.mounted) return;

  await _showSuccessSheet(context, asset, side: side, input: placedInput);
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

enum _Side { buy, sell }

extension on _Side {
  bool get isSell => this == _Side.sell;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared amount/price helpers.
// ─────────────────────────────────────────────────────────────────────────────

/// Asset.price arrives as a preformatted display string ("₦268.40" /
/// "$228.10") — strip the currency symbol/commas to get a usable double.
double _parsePrice(String price) =>
    double.tryParse(price.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

/// Whole-naira value -> "₦50,000" (no decimals, matching this flow's mock
/// figures — Fee/Amount/Total were always shown as whole naira).
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

/// Naira value -> "₦16,104.00" (2 decimals, kobo-precise) — for the sell
/// flow's spec-exact figures (gross/fee/proceeds/gain), which the mockup
/// shows to the kobo, unlike the buy flow's whole-naira mock figures above.
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
/// needed) — matches the mockup's plain integer share counts without adding
/// a false ".0" to every figure.
String _formatShares(double units) =>
    units == units.roundToDouble() ? units.toStringAsFixed(0) : units.toStringAsFixed(1);

/// The next NGX trading session's date, skipping weekends — client-clock
/// heuristic only, same class of approximation as market_hours.dart's
/// isNgxOpenNow() (good enough to label a queued order's UI, not
/// authoritative exchange-calendar data — a public holiday isn't accounted
/// for, same gap isNgxOpenNow() already has). If it's currently a weekday
/// before 10:00 (the sheet can still be reached then — see isNgxOpenNow),
/// the next session is TODAY, not tomorrow.
String _nextTradingSessionLabel() {
  final now = DateTime.now();
  final isWeekday = now.weekday != DateTime.saturday && now.weekday != DateTime.sunday;
  final minutesSinceMidnight = now.hour * 60 + now.minute;
  var day = now;
  if (!(isWeekday && minutesSinceMidnight < 10 * 60)) {
    do {
      day = day.add(const Duration(days: 1));
    } while (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday);
  }
  const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdayNames[day.weekday - 1]} ${day.day} ${months[day.month - 1]}';
}

/// A bordered, optionally-tinted radio row — the visual shape s61/s77 both
/// draw a selectable option in (Radio + title + description inside a
/// hairline/indicator-bordered card). Local to this file's screens rather
/// than a design-system component: it composes existing KRadio/KColor/KType
/// primitives for a single app-level layout pattern, not a new primitive
/// itself.
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

// ─────────────────────────────────────────────────────────────────────────────
// Flow G, spec screen 61 — "Buy · market closed". A limit order placed now
// genuinely sits `pending` server-side until the broker adapter fills it
// (confirmed real: applyHoldingSideEffect/applyWalletSideEffect already only
// run once an order's status becomes 'approved' — an unfilled limit order is
// a real, existing state, not something invented for this screen). The
// "fill at the opening price" market-order radio is NOT offered here: this
// mobile client has no way to verify the broker adapter actually defers a
// market order until a real market-open event rather than filling it
// immediately against the last-known price, and offering that choice would
// risk promising a queuing behaviour that isn't real. Only the limit-price
// path ships — which the spec's own mockup already shows pre-selected by
// default anyway ("Only up to ₦275.00 a share (selected)").
//
// 2026-08-23 exactness pass: s61.html renders "Buy MTNN" and the "Market
// closed" StatusPill in the SAME row inside the sheet body, not via the
// sheet's own separate title bar — the sheet is opened untitled and that row
// built explicitly, matching s77/s63's identical pattern for the same
// reason. The surviving limit-price option is now the same bordered/tinted
// radio-card treatment s61 draws it as (shared _RadioOptionCard, also reused
// by the new sell flow below) rather than plain paragraph text.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showMarketClosedBuySheet(BuildContext context, Asset asset) {
  return showKSheet<void>(
    context,
    child: _MarketClosedBuySheet(asset: asset),
  );
}

class _MarketClosedBuySheet extends StatefulWidget {
  const _MarketClosedBuySheet({required this.asset});
  final Asset asset;

  @override
  State<_MarketClosedBuySheet> createState() => _MarketClosedBuySheetState();
}

class _MarketClosedBuySheetState extends State<_MarketClosedBuySheet> {
  late final TextEditingController _amount = TextEditingController(text: '50,000');
  late final TextEditingController _limitPrice = TextEditingController(
    // Default limit ~2.5% above the last close, matching the spec example's
    // proportions (close ₦268.40 -> limit ₦275.00 is +2.46%).
    text: (_parsePrice(widget.asset.price) * 1.025).toStringAsFixed(2),
  );
  late final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
  bool _placing = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _limitPrice.dispose();
    super.dispose();
  }

  double get _amountNaira => double.tryParse(_amount.text.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
  double get _limit => double.tryParse(_limitPrice.text.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

  Future<void> _queue() async {
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      await _repo.placeOrder(
        ticker: widget.asset.ticker,
        side: OrderSide.buy,
        amountKobo: (_amountNaira * 100).round(),
        orderType: OrderType.limit,
        limitPrice: (_limit * 100).round(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Queued — ${widget.asset.ticker} will try to fill at the next market open.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // s61.html: "Buy MTNN" + the "Market closed" pill share one row —
        // see _showMarketClosedBuySheet's doc comment.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Buy ${widget.asset.ticker}', style: KType.section()),
            const KStatusPill(status: KStatus.pending, label: 'Market closed', small: true),
          ],
        ),
        const SizedBox(height: 14),
        KInput(
          label: 'Amount',
          controller: _amount,
          numeric: true,
          amount: true,
          prefix: '₦',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          'Last close ${widget.asset.price} · minimum ₦5,000',
          style: KType.micro(color: KColor.ink3),
        ),
        const SizedBox(height: 14),
        // s61.html's surviving radio card (the market-order radio above it
        // is deliberately dropped — see this class's doc comment). The
        // limit price itself is still editable underneath: the mockup shows
        // a fixed "₦275.00" as example data, but a real order needs a real
        // investor-chosen figure, not a hardcoded one.
        _RadioOptionCard(
          checked: true,
          title: 'Only up to ₦${_limitPrice.text} a share',
          description: 'A limit — if it opens above this, nothing is bought',
        ),
        const SizedBox(height: 10),
        KInput(
          label: 'Limit price',
          controller: _limitPrice,
          numeric: true,
          amount: true,
          prefix: '₦',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _SummaryRow(label: 'Queued for', value: '${_nextTradingSessionLabel()} · 10:00'),
        _SummaryRow(label: 'Held from your wallet', value: _formatNaira(_amountNaira)),
        _SummaryRow(label: 'Cancel any time', value: 'Until it fills'),
        const SizedBox(height: 14),
        Text(
          'We hold the money now so the order can go out at the open. It '
          'returns to your wallet if nothing fills.',
          style: KType.body(color: KColor.ink3),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: KType.body(color: KColor.loss)),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: KButton(
                label: 'Cancel',
                variant: KButtonVariant.secondary,
                onPressed: _placing ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KButton(
                label: 'Queue for 10:00',
                loading: _placing,
                onPressed: _placing ? null : _queue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the investor actually entered in the Amount sheet, resolved to both
/// units — this is what threads through Review -> confirm -> the order
/// payload -> the Success message, replacing the old hardcoded figures.
class _OrderInput {
  const _OrderInput({
    required this.unit,
    required this.amountNaira,
    required this.units,
  });

  /// 'naira' or 'shares' — mirrors the Amount sheet's KSegmentedControl
  /// toggle; decides which of amountNaira/units is the investor's real
  /// input and which is the derived estimate.
  final String unit;
  final double amountNaira;
  final double units;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Amount entry (shared). Naira/shares unit toggle + quick-amount chips.
// ─────────────────────────────────────────────────────────────────────────────

// Screens 35/36's exact "Fees · 1.35%" rate, applied to the naira amount.
// A separate constant from the sell flow's `_kSellFeeRate` (same value)
// rather than sharing one, since that constant belongs to code this pass
// must not touch.
const double _kBuyFeeRate = 0.0135;

Future<_OrderInput?> _showAmountSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
}) {
  // No `title:` here — screen 35 puts the sheet title on the SAME row as
  // the Naira/Shares segmented control, which KSheet's own title slot (a
  // bare, full-width Text) can't do; _AmountSheet renders that header row
  // itself instead.
  return showKSheet<_OrderInput>(
    context,
    child: _AmountSheet(asset: asset, side: side),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.asset, required this.side});
  final Asset asset;
  final _Side side;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _amount = TextEditingController(text: '50,000');
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  String _unit = 'naira';
  late String _quick = widget.side.isSell ? '50%' : '₦50,000';

  // Balance (buy) / Holding (sell) line — fetched once when the sheet opens
  // (GET /wallet-balance or GET /holdings/:ticker), replacing the old
  // hardcoded '₦310,400' / '120 shares · ₦32,208' literals. null while the
  // fetch is in flight; '—' if it fails — this is a secondary informational
  // element, not the core trade flow, so a failure here must not block or
  // crash the sheet.
  String? _balanceOrHolding;

  // Raw numeric mirrors of the above (both repos return pre-formatted
  // display strings) — needed so the quick-amount chips below can compute
  // an actual value rather than just a label. null until the fetch above
  // resolves; the "Max"/percentage chips no-op until then.
  double? _walletBalanceNaira;
  double? _holdingUnits;

  @override
  void initState() {
    super.initState();
    _loadBalanceOrHolding();
  }

  Future<void> _loadBalanceOrHolding() async {
    try {
      if (widget.side.isSell) {
        final h = await _holdingsRepo.byTicker(widget.asset.ticker);
        if (!mounted) return;
        setState(() {
          _balanceOrHolding = '${h.units} shares · ${h.marketValue}';
          _holdingUnits = double.tryParse(h.units.replaceAll(RegExp('[^0-9.]'), ''));
        });
      } else {
        final balance = await _walletRepo.balance();
        if (!mounted) return;
        setState(() {
          _balanceOrHolding = balance;
          _walletBalanceNaira = double.tryParse(balance.replaceAll(RegExp('[^0-9.]'), ''));
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _balanceOrHolding = '—');
    }
  }

  // Resolves a tapped quick-amount chip to a naira/unit value and writes it
  // into the amount field in whichever unit [_unit] is currently showing.
  // Fixed-naira buy chips (₦10k/₦25k/₦50k) always work; "Max" and every sell
  // percentage chip depend on the balance/holding fetch above and no-op
  // until it resolves.
  void _applyQuick(String chip) {
    double? naira;
    double? units;

    if (widget.side.isSell) {
      final holding = _holdingUnits;
      if (holding == null) return;
      final pct = switch (chip) {
        '25%' => 0.25,
        '50%' => 0.50,
        '75%' => 0.75,
        'All' => 1.0,
        _ => null,
      };
      if (pct == null) return;
      units = holding * pct;
    } else {
      naira = switch (chip) {
        '₦5,000' => 5000.0,
        '₦50,000' => 50000.0,
        '₦100,000' => 100000.0,
        'Max' => _walletBalanceNaira,
        _ => null,
      };
      if (naira == null) return;
    }

    setState(() {
      _quick = chip;
      if (_unit == 'naira') {
        final value = naira ?? (units! * _price);
        _amount.text = _formatNaira(value).replaceFirst('₦', '');
      } else {
        final value = units ?? (_price > 0 ? naira! / _price : 0);
        _amount.text = value.toStringAsFixed(1);
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  // Parse the (comma-grouped) figure the investor typed — its meaning
  // (naira amount vs share units) depends on [_unit].
  double get _amountValue =>
      double.tryParse(_amount.text.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

  double get _price => _parsePrice(widget.asset.price);

  /// Share units, whichever way the investor entered the order.
  double get _units =>
      _unit == 'shares' ? _amountValue : (_price > 0 ? _amountValue / _price : 0);

  /// Naira value, whichever way the investor entered the order.
  double get _amountNaira => _unit == 'naira' ? _amountValue : _amountValue * _price;

  bool get _overLimit => !widget.side.isSell && _amountNaira > _kDailyLimit;

  @override
  Widget build(BuildContext context) {
    final isSell = widget.side.isSell;
    // Exact spec-35 pill values (were the rounder ₦10k/₦25k/₦50k shorthand
    // before this exactness pass).
    final chips = isSell
        ? const ['25%', '50%', '75%', 'All']
        : const ['₦5,000', '₦50,000', '₦100,000', 'Max'];

    // Insufficient wallet balance (buy only, once the real figure has
    // loaded) — spec 35's own nav note: "not enough in the wallet routes to
    // 41 Add money" instead of letting the order proceed.
    final insufficientBalance =
        !isSell && _walletBalanceNaira != null && _amountNaira > _walletBalanceNaira!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title + Naira/Shares toggle share one row — screen 35 puts the
        // sheet's own title text here (not in KSheet's separate title
        // slot) so it can sit beside the compact segmented control.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                isSell ? 'Sell ${widget.asset.ticker}' : 'Buy ${widget.asset.ticker}',
                style: KType.section(),
              ),
            ),
            const SizedBox(width: 10),
            KSegmentedControl(
              compact: true,
              value: _unit,
              onChanged: (v) => setState(() => _unit = v),
              options: const [
                KSegmentOption(value: 'naira', label: 'Naira'),
                KSegmentOption(value: 'shares', label: 'Shares'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        KInput(
          controller: _amount,
          numeric: true,
          amount: true,
          prefix: _unit == 'naira' ? '₦' : null,
          suffix: _unit == 'shares' ? 'shares' : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          // Screen 35's helper is one line: the estimate, the minimum order
          // (matches the smallest quick-amount chip below), and the real
          // wallet balance/holding — not a separate "Balance" row with a
          // ghost "Add money" shortcut that did nothing.
          helper: _overLimit
              ? null
              : (isSell
                  ? '≈ ${_unit == 'shares' ? _formatNaira(_amountNaira) : '${_units.floor()} shares at ${widget.asset.price}'} · holding ${_balanceOrHolding ?? '…'}'
                  : '≈ ${_unit == 'naira' ? '${_units.floor()} shares at ${widget.asset.price}' : _formatNaira(_amountNaira)} · minimum ₦5,000 · wallet ${_balanceOrHolding ?? '…'}'),
          error: _overLimit
              ? 'This order exceeds your daily limit of ₦500,000.'
              : null,
        ),

        // Quick-amount chips.
        const SizedBox(height: 12),
        Row(
          children: [
            for (final c in chips) ...[
              if (c != chips.first) const SizedBox(width: 8),
              Expanded(
                child: KPillChip(
                  label: c,
                  selected: _quick == c,
                  onTap: () => _applyQuick(c),
                ),
              ),
            ],
          ],
        ),

        // Order type / fees / total to pay — screen 35's mini-table.
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: KColor.bg,
            border: Border.all(color: KColor.hairline, width: 1),
            borderRadius: KRadii.cardR,
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Order type', value: 'Market', verticalPadding: 10),
              _SummaryRow(
                label: 'Fees · ${(_kBuyFeeRate * 100).toStringAsFixed(2)}%',
                value: _formatNaira(_amountNaira * _kBuyFeeRate),
                divider: !isSell,
                verticalPadding: 10,
              ),
              if (!isSell)
                _SummaryRow(
                  label: 'Total to pay',
                  value: _formatNaira(_amountNaira + _amountNaira * _kBuyFeeRate),
                  emphasize: true,
                  divider: false,
                  verticalPadding: 10,
                ),
            ],
          ),
        ),

        // Footnote — spec 35's exact wording.
        if (!isSell) ...[
          const SizedBox(height: 12),
          Text(
            'The NGX closes at 14:30. Orders placed after that queue for the next trading day.',
            style: KType.data(color: KColor.ink3),
          ),
        ],

        // Cancel / primary action — spec lists an explicit "Cancel" button
        // alongside "Review order", not just the sheet's own swipe-to-dismiss.
        const SizedBox(height: 16),
        Row(
          children: [
            KButton(
              label: 'Cancel',
              variant: KButtonVariant.ghost,
              fullWidth: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _overLimit
                  ? KButton(
                      label: 'Adjust amount',
                      onPressed: () {
                        // Stay on the amount sheet so the user can lower the figure.
                        setState(() => _amount.text = '50,000');
                      },
                    )
                  : KButton(
                      label: 'Review order',
                      onPressed: insufficientBalance
                          ? () {
                              Navigator.of(context).pop();
                              showAddMoneyFlow(context);
                            }
                          : () {
                              // Pop WITH the result rather than popping-then-immediately-
                              // showing the review sheet ourselves — see _runTradeFlow's
                              // doc comment for why that pattern is unsafe here.
                              Navigator.of(context).pop(_OrderInput(
                                unit: _unit,
                                amountNaira: _amountNaira,
                                units: _units,
                              ));
                            },
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Review order (shared). Summary rows + risk ack + confirm.
// ─────────────────────────────────────────────────────────────────────────────

Future<_OrderInput?> _showReviewSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
  required _OrderInput input,
}) {
  return showKSheet<_OrderInput>(
    context,
    title: 'Review order',
    child: _ReviewSheet(asset: asset, side: side, input: input),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.asset, required this.side, required this.input});
  final Asset asset;
  final _Side side;
  final _OrderInput input;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
  bool _agreed = false;
  bool _placing = false;
  bool _failed = false;

  /// The real backend reason for the most recent failure (e.g. "Your wallet
  /// balance is not sufficient to cover this order.") — 2026-08-20 fix, see
  /// KErrorView.orderFailed's doc comment. Null falls back to that
  /// constructor's generic copy (a genuine network/unknown failure).
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

    final isSell = widget.side.isSell;
    final input = widget.input;
    final fee = input.amountNaira * _kBuyFeeRate;
    final total = isSell ? input.amountNaira - fee : input.amountNaira + fee;
    // T+3 from today, skipping weekends — reuses SalePlacedScreen's own
    // settlement-date heuristic (same file, read-only) rather than
    // duplicating it a third time.
    final settleDate = SalePlacedScreen._settleLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Screen 36's exact row set/order/labels — was a different,
        // generic "Asset/Type/Amount/Est. shares/Est. price/Fee" shape
        // before this exactness pass, and folded the total into a bespoke
        // line below the box instead of the box's own last row.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: KColor.bg,
            border: Border.all(color: KColor.hairline, width: 1),
            borderRadius: KRadii.cardR,
          ),
          child: Column(
            children: [
              _SummaryRow(
                label: isSell ? 'Selling' : 'Buying',
                value: '${widget.asset.name} · ${widget.asset.ticker}',
                verticalPadding: 11,
              ),
              _SummaryRow(
                label: 'Shares',
                value: '${input.units.floor()} · market price',
                verticalPadding: 11,
              ),
              _SummaryRow(
                label: 'Amount',
                value: _formatNaira(input.amountNaira),
                verticalPadding: 11,
              ),
              _SummaryRow(
                label: isSell ? 'Fees · 1.35%' : 'Fees · commission, NGX, SEC, CSCS',
                value: _formatNaira(fee),
                verticalPadding: 11,
              ),
              _SummaryRow(
                label: 'Settles',
                // No glossary screen/route exists yet for "T+3" to open
                // (spec's `nav.s56`) — same genuine gap as the sell flow's
                // identical GlossaryTerm a few hundred lines down, so this
                // mirrors that no-op rather than inventing a destination.
                valueWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KGlossaryTerm(text: 'T+3', onTap: () {}),
                    Text(' · $settleDate', style: KType.body(color: KColor.ink, w: KWeight.medium)),
                  ],
                ),
                verticalPadding: 11,
              ),
              _SummaryRow(
                label: isSell ? 'Proceeds' : 'Total',
                value: _formatNaira(total),
                emphasize: true,
                divider: false,
                verticalPadding: 11,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Text(
          'A market order fills at the best price available, which can differ '
          'from the price shown. Shares register to your CHN at the CSCS.',
          style: KType.data(color: KColor.ink3),
        ),

        // "I understand the risks" isn't in the mockup's screen 36 (which
        // lists only Sheet/GlossaryTerm/Button×2) — kept here deliberately:
        // it's a real risk-acknowledgment gate, not decorative copy, and
        // dropping a compliance control to match a marketing mockup exactly
        // would be the wrong kind of "exact." Flagging this explicitly
        // rather than silently diverging either way.
        const SizedBox(height: 18),
        KCheckbox(
          checked: _agreed,
          label: 'I understand the risks',
          onChanged: (v) => setState(() => _agreed = v),
        ),

        // Screen 36: "Back" is ghost and content-width, not a secondary
        // button sharing the row 50/50 with the primary CTA; the primary
        // label is "Place order", not "Confirm purchase".
        const SizedBox(height: 16),
        Row(
          children: [
            KButton(
              label: 'Back',
              variant: KButtonVariant.ghost,
              fullWidth: false,
              onPressed: _placing ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KButton(
                label: isSell ? 'Confirm sale' : 'Place order',
                loading: _placing,
                onPressed: (_agreed && !_placing) ? _confirm : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _placing = true);
    final side = widget.side.isSell ? OrderSide.sell : OrderSide.buy;
    final input = widget.input;
    try {
      if (input.unit == 'shares') {
        await _repo.placeOrder(
          ticker: widget.asset.ticker,
          side: side,
          units: input.units,
        );
      } else {
        await _repo.placeOrder(
          ticker: widget.asset.ticker,
          side: side,
          amountKobo: (input.amountNaira * 100).round(),
        );
      }
      if (!mounted) return;
      // Pop WITH the result — see _runTradeFlow's doc comment for why this
      // sheet doesn't show the success sheet itself.
      Navigator.of(context).pop(input);
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.divider = true,
    this.emphasize = false,
    this.verticalPadding = 13,
  }) : assert(value != null || valueWidget != null, '_SummaryRow needs value or valueWidget');

  final String label;
  final String? value;

  /// Overrides [value]'s plain Text — screen 36's "Settles" row embeds a
  /// tappable [KGlossaryTerm] ("T+3") ahead of the date, which a String
  /// alone can't carry. Added as a prop rather than a bespoke row widget.
  final Widget? valueWidget;

  /// False for the last row of a box (no bottom hairline) — e.g. the
  /// Amount/Review sheets' "Total"/"Total to pay" row.
  final bool divider;

  /// The box's own closing total row — bigger, bolder text-card-title on
  /// both sides instead of the regular body-weight row.
  final bool emphasize;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasize ? KType.cardTitle() : KType.body(color: KColor.ink2);
    final valueStyle = emphasize
        ? KType.cardTitle()
        : KType.body(color: KColor.ink, w: KWeight.medium);
    return Container(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
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

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Success (shared). KStatusView outcome; "View portfolio" / "Done"
// per the design. The orders screen has its own entry points (Home / Wallet).
// ─────────────────────────────────────────────────────────────────────────────

// Screen 37 is a full page (own Scaffold, centred content, buttons pinned to
// the bottom), NOT a bottom sheet over a scrim — unlike 35/36, its markup has
// no `Sheet` import at all. Was presented via showKSheet before this
// exactness pass; now pushed the same way SalePlacedScreen (this file's sell
// equivalent) already pushes its own placed-confirmation screen.
Future<void> _showSuccessSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
  required _OrderInput input,
}) async {
  HapticFeedback.lightImpact();
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => _OrderPlacedScreen(asset: asset, side: side, input: input)),
  );
}

class _OrderPlacedScreen extends StatelessWidget {
  const _OrderPlacedScreen({required this.asset, required this.side, required this.input});
  final Asset asset;
  final _Side side;
  final _OrderInput input;

  @override
  Widget build(BuildContext context) {
    final isSell = side.isSell;
    final amountStr = _formatNaira(input.amountNaira);
    // T+3 from today, skipping weekends — see SalePlacedScreen._settleLabel's
    // own doc comment for the caveats of this client-clock heuristic.
    final settleLabel = SalePlacedScreen._settleLabel();
    final total = input.amountNaira + input.amountNaira * _kBuyFeeRate;

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
                          // KMilestoneSheet (2026-08-22 "Soft Landing", spec
                          // screen 37's celebratory "first trade" pattern) —
                          // shown for every order for now, not just a genuine
                          // first trade: this app doesn't track "has this
                          // investor ever traded before" anywhere yet, and
                          // adding that state is out of scope for this
                          // redesign pass. The spec itself notes the
                          // milestone treatment is meant to run once then
                          // fall back to a plain confirmation — worth
                          // revisiting once first-trade tracking exists.
                          child: KMilestoneSheet(
                            illustrationName: 'milestone-first-trade',
                            // Exact spec-37 eyebrow for the buy path; spec
                            // never covers a sell flow (screen 33's own nav
                            // note says the sell mockup was never detailed),
                            // so the sell-side copy stays a reasonable
                            // extension.
                            eyebrow: isSell ? 'Order placed' : 'Your first order',
                            title: 'Order placed',
                            // Exact spec-37 wording for the buy path: leads
                            // with the fill (shares · total, including fees)
                            // then the settlement clause — was a terser "You
                            // bought ₦X of TICKER. Shares settle T+3."
                            // before this exactness pass.
                            message: isSell
                                ? 'You sold $amountStr of ${asset.ticker}. Proceeds settle T+3.'
                                : '${input.units.floor()} ${asset.ticker} shares for '
                                    '${_formatNaira(total)}. It fills while the NGX is open '
                                    'and settles on $settleLabel.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Spec 37's centred StatusPill under the milestone
                        // card — was missing entirely.
                        const KStatusPill(status: KStatus.pending, label: 'Filling'),
                      ],
                    ),
                  ),
                ),
              ),
              // Exact spec-37 labels/targets: "Track this order" -> Orders
              // (44), "Go to my portfolio" -> Portfolio (38) — were "View
              // portfolio" (-> Portfolio) / "Done" (-> just dismiss) before
              // this exactness pass.
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    KButton(
                      label: 'Track this order',
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.push(Routes.orderStatus);
                      },
                    ),
                    const SizedBox(height: 10),
                    KButton(
                      label: 'Go to my portfolio',
                      variant: KButtonVariant.ghost,
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.go(Routes.portfolio);
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
}

// ─────────────────────────────────────────────────────────────────────────────
// SELL FLOW — spec screens 77 (amount + destination) → 78 (review) → 79
// (placed). Dedicated implementation, not a reuse of the buy-only shared
// sheets above — see this file's header comment for why.
//
// REAL BACKEND GAP, flagged rather than faked — CORRECTED 2026-08-24: the
// backend DOES have a `destinationBankAccountId` field on the Order
// resource now (`POST /orders`, validated server-side to be the investor's
// real primary/DCS bank account — see OrdersService), so this comment
// previously overstated the gap by claiming "no field for it." The field
// exists and is stored; what's still deferred is the actual money
// movement: `OrdersService.applyWalletSideEffect` credits the wallet for
// EVERY sell regardless of destination right now (see that method's own
// gap comment) — redirecting proceeds to the bank account instead requires
// reusing TransactionsService's payout/Flutterwave-transfer logic, not yet
// wired in. Selecting "straight to bank" today would silently not do what
// it says, which is worse than the gap itself — so that row stays disabled
// with an honest inline note; "My Kudimata wallet" — the one real outcome
// — is the only selectable option, pre-selected, matching the spec's own
// default. Also note: `OrderPlacementRepository.placeOrder` itself doesn't
// even accept a `destinationBankAccountId` param yet — a second, smaller
// wiring gap on top of the payout one, left as-is for the same reason
// (nothing to safely wire it to on the backend side yet).
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _runSellFlow(BuildContext context, Asset asset) async {
  final amountInput = await showKSheet<SellOrderInput>(
    context,
    child: _SellAmountSheet(asset: asset),
  );
  if (amountInput == null || !context.mounted) return;

  final placed = await showKSheet<SellOrderInput>(
    context,
    title: 'Review sale',
    child: _SellReviewSheet(asset: asset, input: amountInput),
  );
  if (placed == null || !context.mounted) return;

  // Pushed directly (MaterialPageRoute, not a named go_router route) — see
  // SalePlacedScreen's own doc comment for why.
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => SalePlacedScreen(asset: asset, input: placed)),
  );
}

/// Mock sell fee rate (spec 78's exact "Fees · 1.35%") — same class of
/// placeholder as the buy flow's `_kBuyFeeRate`: the Order resource has no
/// fee field, so this is a fixed design figure, not a real backend rate.
const double _kSellFeeRate = 0.0135;

/// What the investor chose on the Amount+destination sheet, threaded through
/// Review -> confirm -> [SalePlacedScreen].
class SellOrderInput {
  const SellOrderInput({
    required this.units,
    required this.holdingTotalUnits,
    required this.gross,
    required this.fee,
    required this.net,
    required this.avgPrice,
    required this.price,
    this.reference,
  });

  final double units;
  final double holdingTotalUnits;
  final double gross;
  final double fee;
  final double net;
  final double avgPrice;
  final double price;

  /// Investor-facing order reference (e.g. "KDM-SL-9021") returned by
  /// `POST /orders` (OrderPlacementRepository.placeOrder) once the sell
  /// order is actually placed — null until `_SellReviewSheetState._confirm`
  /// attaches it via [copyWith], and stays null in the (now rare) case the
  /// backend doesn't return one. [SalePlacedScreen] omits its "Reference"
  /// row rather than ever rendering the literal string "null".
  final String? reference;

  SellOrderInput copyWith({String? reference}) => SellOrderInput(
        units: units,
        holdingTotalUnits: holdingTotalUnits,
        gross: gross,
        fee: fee,
        net: net,
        avgPrice: avgPrice,
        price: price,
        reference: reference ?? this.reference,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sell — Step 1: amount + (real-gap-flagged) destination.
// ─────────────────────────────────────────────────────────────────────────────

class _SellAmountSheet extends StatefulWidget {
  const _SellAmountSheet({required this.asset});
  final Asset asset;

  @override
  State<_SellAmountSheet> createState() => _SellAmountSheetState();
}

class _SellAmountSheetState extends State<_SellAmountSheet> {
  late final TextEditingController _amount = TextEditingController(text: '60');
  late final _holdingsRepo = HoldingsRepository(AppScope.read(context).apiClient);
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late Future<(Holding, List<BankAccountSummary>)> _future = _load();

  // Naira/Shares toggle — spec 77 places it in the header row (a
  // SegmentedControl next to "Sell MTNN"), not below the input like the
  // buy-only _AmountSheet above.
  String _unit = 'shares';

  Future<(Holding, List<BankAccountSummary>)> _load() =>
      (_holdingsRepo.byTicker(widget.asset.ticker), _walletRepo.bankAccounts()).wait;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _price => _parsePrice(widget.asset.price);
  double get _amountValue => double.tryParse(_amount.text.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
  double get _units => _unit == 'shares' ? _amountValue : (_price > 0 ? _amountValue / _price : 0);
  double get _amountNaira => _unit == 'naira' ? _amountValue : _amountValue * _price;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Holding, List<BankAccountSummary>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: KLoadingView(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: KErrorView(onPrimary: () => setState(() => _future = _load())),
          );
        }
        final (holding, accounts) = snapshot.data!;
        final holdingUnits = double.tryParse(holding.units.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;
        final avgPrice = _parsePrice(holding.avgPrice);
        final gross = _amountNaira;
        final fee = gross * _kSellFeeRate;

        BankAccountSummary? primary;
        for (final a in accounts) {
          if (a.primary) {
            primary = a;
            break;
          }
        }
        primary ??= accounts.isEmpty ? null : accounts.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sell ${widget.asset.ticker}', style: KType.section()),
                SizedBox(
                  width: 150,
                  child: KSegmentedControl(
                    value: _unit,
                    onChanged: (v) => setState(() => _unit = v),
                    options: const [
                      KSegmentOption(value: 'naira', label: '₦'),
                      KSegmentOption(value: 'shares', label: 'Shares'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            KInput(
              controller: _amount,
              numeric: true,
              amount: true,
              prefix: _unit == 'naira' ? '₦' : null,
              suffix: _unit == 'shares' ? 'of ${_formatShares(holdingUnits)}' : null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              helper: '≈ ${_formatNairaDecimal(gross)} at ${widget.asset.price} · '
                  'fees ${_formatNairaDecimal(fee)}',
            ),
            const SizedBox(height: 16),
            const KEyebrow('Send the money to'),
            const SizedBox(height: 8),
            _RadioOptionCard(
              checked: true,
              title: 'My Kudimata wallet',
              description: 'Ready to buy something else once this sale settles',
            ),
            const SizedBox(height: 10),
            _RadioOptionCard(
              checked: false,
              disabled: true,
              title: primary == null
                  ? 'Straight to your bank'
                  : 'Straight to ${primary.bankName} ${primary.accountNumberMasked}',
              description: 'Not available yet — sale proceeds always go to your wallet for now',
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: KType.data(color: KColor.ink3),
                children: [
                  const TextSpan(text: 'Proceeds settle '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    // No glossary/explainer screen to link to yet — same
                    // "shortcut affordance, no-op here" pattern as the
                    // Amount sheet's ghost buttons above.
                    child: KGlossaryTerm(text: 'T+3', onTap: () {}),
                  ),
                  const TextSpan(text: ' and land in your wallet. Nothing is available before then.'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: KButton(
                    label: 'Cancel',
                    variant: KButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KButton(
                    label: 'Review sale',
                    onPressed: _units <= 0
                        ? null
                        : () => Navigator.of(context).pop(SellOrderInput(
                              units: _units,
                              holdingTotalUnits: holdingUnits,
                              gross: gross,
                              fee: fee,
                              net: gross - fee,
                              avgPrice: avgPrice,
                              price: _price,
                            )),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sell — Step 2: review + confirm (spec 78).
// ─────────────────────────────────────────────────────────────────────────────

class _SellReviewSheet extends StatefulWidget {
  const _SellReviewSheet({required this.asset, required this.input});
  final Asset asset;
  final SellOrderInput input;

  @override
  State<_SellReviewSheet> createState() => _SellReviewSheetState();
}

class _SellReviewSheetState extends State<_SellReviewSheet> {
  late final _repo = OrderPlacementRepository(AppScope.read(context).apiClient);
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

    final input = widget.input;
    final gain = (input.price - input.avgPrice) * input.units;
    final gainLabel = gain >= 0
        ? 'realises a gain of ${_formatNairaDecimal(gain)}'
        : 'realises a loss of ${_formatNairaDecimal(-gain)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(
          label: 'Selling',
          value: '${_formatShares(input.units)} of ${_formatShares(input.holdingTotalUnits)} '
              '${widget.asset.ticker}',
        ),
        _SummaryRow(label: 'At market', value: '≈ ${widget.asset.price}'),
        _SummaryRow(label: 'Gross', value: _formatNairaDecimal(input.gross)),
        _SummaryRow(label: 'Fees · 1.35%', value: '−${_formatNairaDecimal(input.fee)}'),
        // Real gap: always "Your wallet" — see this section's header comment.
        _SummaryRow(label: 'Goes to', value: 'Your wallet'),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 15, 0, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('You receive', style: KType.cardTitle(w: KWeight.semibold)),
              Text(_formatNairaDecimal(input.net),
                  style: KType.section().tnum.copyWith(fontWeight: KWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: KColor.sunTint, borderRadius: KRadii.cardR),
          child: Text(
            'You bought these at ${_formatNairaDecimal(input.avgPrice)}, so this sale '
            '$gainLabel. Nigeria charges no capital gains tax on NGX-listed shares held over a year.',
            style: KType.data(color: KColor.ink2),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: KButton(
                label: 'Back',
                variant: KButtonVariant.ghost,
                onPressed: _placing ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KButton(
                label: 'Place sell order',
                loading: _placing,
                onPressed: _placing ? null : _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _placing = true);
    try {
      final order = await _repo.placeOrder(
        ticker: widget.asset.ticker,
        side: OrderSide.sell,
        units: widget.input.units,
      );
      if (!mounted) return;
      Navigator.of(context).pop(widget.input.copyWith(reference: order.reference));
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
// Sell — Step 3: placed (spec 79). A real, pushed screen — not a sheet, per
// the mockup (full status-bar chrome, no scrim/drag-handle). Pushed directly
// via MaterialPageRoute (see _runSellFlow) rather than a named go_router
// route: Routes.salePlaced doesn't exist yet, per this build's constraint
// not to touch lib/router/*. The central route-wiring pass can register a
// named route pointing at this same screen and swap that direct push for
// `context.push(Routes.salePlaced)` without anything here needing to change.
//
// RESOLVED 2026-08-24 (was a REAL BACKEND GAP): `POST /orders` now returns a
// real `Order.reference` (e.g. "KDM-SL-9021", distinct from the order's
// uuid `id`) and OrderPlacementRepository.placeOrder() parses and returns
// it instead of discarding the response body. `_SellReviewSheetState._confirm`
// threads it onto [SellOrderInput.reference], so spec 79's "Reference ·
// KDM-SL-9021" row below is real data, not invented — and degrades
// gracefully (the row is simply omitted) for the rare case `reference` is
// still null (e.g. an order created before this field existed).
// ─────────────────────────────────────────────────────────────────────────────

class SalePlacedScreen extends StatelessWidget {
  const SalePlacedScreen({super.key, required this.asset, required this.input});
  final Asset asset;
  final SellOrderInput input;

  /// T+3 settlement date computed from TODAY (the real placement moment) by
  /// skipping weekends — client-clock heuristic only, same class of
  /// approximation as market_hours.dart's isNgxOpenNow(); not authoritative
  /// settlement-calendar data (a public holiday isn't accounted for).
  static String _settleLabel() {
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
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final settleLabel = _settleLabel();
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, 28),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KStatusView(
                          tone: KStatusTone.pending,
                          illustrationName: 'portfolio-growth',
                          title: 'Sell order placed',
                          message: '${_formatShares(input.units)} ${asset.ticker} shares are on '
                              'the market. The money reaches your wallet on $settleLabel, once '
                              'the CSCS settles the trade.',
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
                              // Spec 79's "Reference · KDM-SL-9021" row —
                              // real Order.reference now, omitted (not
                              // "null") when it isn't set. See this
                              // section's header comment.
                              if (input.reference != null)
                                _SummaryRow(label: 'Reference', value: input.reference!),
                              _SummaryRow(label: 'Settles', value: '$settleLabel · T+3'),
                              _SummaryRow(label: 'Then goes to', value: 'Your wallet'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              KButton(
                label: 'Follow this order',
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  context.push(Routes.orderStatus);
                },
              ),
              const SizedBox(height: 10),
              KButton(
                label: 'Back to my portfolio',
                variant: KButtonVariant.ghost,
                onPressed: () => context.go(Routes.portfolio),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
