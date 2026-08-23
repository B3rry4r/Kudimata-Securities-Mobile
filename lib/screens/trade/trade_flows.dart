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
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/markets/market_hours.dart';
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

/// Sell flow: amount → review → success. Same gate as [showBuyFlow].
Future<void> showSellFlow(BuildContext context, Asset asset) async {
  if (!await _ensureEligibleToTrade(context)) return;
  if (!context.mounted) return;
  await _runTradeFlow(context, asset, side: _Side.sell);
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
  // Flow G, spec screens 60-61 — a BUY while the NGX is shut queues instead
  // of going through the normal amount/review/confirm chain (spec 61's own
  // nav note: "Queue -> 62", a LATER/separate screen, not this flow's
  // success step). Sell isn't covered by the mockup at all here (spec 33's
  // own note: the sell flow was never detailed in this canvas) — sell stays
  // on the normal flow regardless of market hours.
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
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showMarketClosedBuySheet(BuildContext context, Asset asset) {
  return showKSheet<void>(
    context,
    title: 'Buy ${asset.ticker}',
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
        const KStatusPill(status: KStatus.pending, label: 'Market closed', small: true),
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
        const SizedBox(height: 18),
        Text('Only up to a limit price a share', style: KType.cardTitle()),
        const SizedBox(height: 4),
        Text(
          'If it opens above this, nothing is bought — your money stays in your wallet.',
          style: KType.body(color: KColor.ink3),
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
        _SummaryRow(label: 'Queued for', value: 'Next market open · 10:00'),
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

Future<_OrderInput?> _showAmountSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
}) {
  return showKSheet<_OrderInput>(
    context,
    title: side.isSell ? 'Sell ${asset.ticker}' : 'Buy ${asset.ticker}',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KInput(
          label: _unit == 'naira' ? 'Amount' : 'Shares',
          controller: _amount,
          numeric: true,
          amount: true,
          prefix: _unit == 'naira' ? '₦' : null,
          suffix: _unit == 'shares' ? 'shares' : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          error: _overLimit
              ? 'This order exceeds your daily limit of ₦500,000.'
              : null,
        ),
        const SizedBox(height: 14),
        KSegmentedControl(
          value: _unit,
          onChanged: (v) => setState(() => _unit = v),
          options: const [
            KSegmentOption(value: 'naira', label: '₦'),
            KSegmentOption(value: 'shares', label: 'Shares'),
          ],
        ),
        if (!_overLimit) ...[
          const SizedBox(height: 10),
          Text(
            _unit == 'naira'
                ? '≈ ${_units.toStringAsFixed(1)} shares'
                : '≈ ${_formatNaira(_amountNaira)}',
            style: KType.micro(color: KColor.ink3).tnum.copyWith(letterSpacing: 0.04 * 10),
          ),
        ],

        // Holding / balance line + ghost shortcut.
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: KType.body(color: KColor.ink2),
                  children: [
                    TextSpan(text: isSell ? 'Holding ' : 'Balance '),
                    TextSpan(
                      text: _balanceOrHolding ?? '…',
                      style: KType.body(color: KColor.ink, w: KWeight.medium).tnum,
                    ),
                  ],
                ),
              ),
            ),
            KButton(
              label: isSell ? 'Sell all' : 'Add money',
              variant: KButtonVariant.ghost,
              size: KButtonSize.sm,
              fullWidth: false,
              onPressed: () {}, // shortcut affordance — mirrors design (no-op here)
            ),
          ],
        ),

        // Quick-amount chips.
        const SizedBox(height: 16),
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

        // Footnote — was missing entirely; spec 35's exact wording.
        if (!isSell) ...[
          const SizedBox(height: 18),
          Text(
            'The NGX closes at 14:30. Orders placed after that queue for the next trading day.',
            style: KType.micro(color: KColor.ink3),
          ),
        ],

        // Cancel / primary action — spec lists an explicit "Cancel" button
        // alongside "Review order", not just the sheet's own swipe-to-dismiss.
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: KButton(
                label: 'Cancel',
                variant: KButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
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
                      onPressed: () {
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

// Flat mock fee — registry.json's Order resource has no fee field, so
// unlike amount/units (the investor's real input) this stays a fixed design
// figure, same as before.
const double _kFeeNaira = 125;

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
    final ticker = widget.asset.ticker;
    final price = widget.asset.price;

    // Rows now reflect the investor's actual input: whichever of
    // amount/shares they typed is shown as the primary figure, the other is
    // the derived estimate — replacing the old hardcoded '₦50,000'/'186.3'.
    final rows = <(String, String)>[
      ('Asset', ticker),
      ('Type', 'Market'),
      if (input.unit == 'naira') ...[
        ('Amount', _formatNaira(input.amountNaira)),
        ('Est. shares', input.units.toStringAsFixed(1)),
      ] else ...[
        ('Shares', input.units.toStringAsFixed(1)),
        ('Est. amount', _formatNaira(input.amountNaira)),
      ],
      ('Est. price', price),
      ('Fee', _formatNaira(_kFeeNaira)),
    ];

    final total = isSell ? input.amountNaira - _kFeeNaira : input.amountNaira + _kFeeNaira;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (k, v) in rows) _SummaryRow(label: k, value: v),

        // Total / proceeds emphasis line.
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 15, 0, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isSell ? 'Proceeds' : 'Total',
                  style: KType.cardTitle(w: KWeight.semibold)),
              Text(_formatNaira(total),
                  style: KType.section().tnum.copyWith(fontWeight: KWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 14),
        // Exact spec-36 wording (was a shorter paraphrase before this
        // exactness pass).
        Text(
          'A market order fills at the best price available, which can differ '
          'from the price shown. Shares register to your CHN at the CSCS.',
          style: KType.body(color: KColor.ink3),
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

        // "Back" was missing — spec's exact button pair is "Back" / "Place
        // order"; this sheet only ever had the one confirm button before.
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: KButton(
                label: 'Back',
                variant: KButtonVariant.secondary,
                onPressed: _placing ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KButton(
                label: isSell ? 'Confirm sale' : 'Confirm purchase',
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
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KType.body(color: KColor.ink2)),
          Text(value, style: KType.body(color: KColor.ink, w: KWeight.medium).tnum),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Success (shared). KStatusView outcome; "View portfolio" / "Done"
// per the design. The orders screen has its own entry points (Home / Wallet).
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showSuccessSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
  required _OrderInput input,
}) {
  HapticFeedback.lightImpact();
  final amountStr = _formatNaira(input.amountNaira);
  // KMilestoneSheet (2026-08-22 "Soft Landing", spec screen 37's celebratory
  // "first trade" pattern) — shown for every order for now, not just a
  // genuine first trade: this app doesn't track "has this investor ever
  // traded before" anywhere yet, and adding that state is out of scope for
  // this redesign pass. The spec itself notes the milestone treatment is
  // meant to run once then fall back to a plain confirmation — worth
  // revisiting once first-trade tracking exists.
  return showKSheet<void>(
    context,
    child: KMilestoneSheet(
      illustrationName: 'milestone-first-trade',
      // Exact spec-37 eyebrow for the buy path; spec never covers a sell
      // flow (screen 33's own nav note says the sell mockup was never
      // detailed), so the sell-side copy stays a reasonable extension.
      eyebrow: side.isSell ? 'Order placed' : 'Your first order',
      title: 'Order placed',
      message: side.isSell
          ? 'You sold $amountStr of ${asset.ticker}. Proceeds settle T+3.'
          : 'You bought $amountStr of ${asset.ticker}. Shares settle T+3.',
      // fullWidth: false — KMilestoneSheet lays these out in a Wrap (natural
      // width, can wrap to a new line), and a fullWidth (the KButton
      // default) button asks Wrap for infinite width, which renders as a
      // visible overflow glitch (found live via test/shots.dart on the
      // structurally-identical security-alert screen).
      //
      // Exact spec-37 labels/targets: "Track this order" -> Orders (44),
      // "Go to my portfolio" -> Portfolio (38) — were "View portfolio"
      // (-> Portfolio) / "Done" (-> just dismiss) before this exactness pass.
      primary: KButton(
        label: 'Track this order',
        fullWidth: false,
        onPressed: () {
          Navigator.of(context).pop();
          context.push(Routes.orderStatus);
        },
      ),
      secondary: KButton(
        label: 'Go to my portfolio',
        variant: KButtonVariant.ghost,
        fullWidth: false,
        onPressed: () {
          Navigator.of(context).pop();
          context.go(Routes.portfolio);
        },
      ),
    ),
  );
}
