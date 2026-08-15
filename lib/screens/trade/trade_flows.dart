// Kudimata Securities — Stage 6: Trade buy/sell flows as bottom sheets.
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

import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/order_placement_repository.dart';
import 'package:kudimata_securities/data/repositories/wallet_repository.dart';
import 'package:kudimata_securities/data/repositories/holdings_repository.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/router/routes.dart';
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
  late String _quick = widget.side.isSell ? '50%' : '₦50k';

  // Balance (buy) / Holding (sell) line — fetched once when the sheet opens
  // (GET /wallet-balance or GET /holdings/:ticker), replacing the old
  // hardcoded '₦310,400' / '120 shares · ₦32,208' literals. null while the
  // fetch is in flight; '—' if it fails — this is a secondary informational
  // element, not the core trade flow, so a failure here must not block or
  // crash the sheet.
  String? _balanceOrHolding;

  @override
  void initState() {
    super.initState();
    _loadBalanceOrHolding();
  }

  Future<void> _loadBalanceOrHolding() async {
    try {
      final text = widget.side.isSell
          ? await _holdingsRepo
              .byTicker(widget.asset.ticker)
              .then((h) => '${h.units} shares · ${h.marketValue}')
          : await _walletRepo.balance();
      if (!mounted) return;
      setState(() => _balanceOrHolding = text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _balanceOrHolding = '—');
    }
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
    final chips =
        isSell ? const ['25%', '50%', '75%', 'All'] : const ['₦10k', '₦25k', '₦50k', 'Max'];

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
                  onTap: () => setState(() => _quick = c),
                ),
              ),
            ],
          ],
        ),

        // Primary action — turns into "Adjust amount" while over limit.
        const SizedBox(height: 22),
        _overLimit
            ? KButton(
                label: 'Adjust amount',
                variant: KButtonVariant.secondary,
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

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return KErrorView.orderFailed(
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
        Text(
          'Prices move; your order fills at the best available price.',
          style: KType.body(color: KColor.ink3),
        ),

        const SizedBox(height: 18),
        KCheckbox(
          checked: _agreed,
          label: 'I understand the risks',
          onChanged: (v) => setState(() => _agreed = v),
        ),

        const SizedBox(height: 22),
        KButton(
          label: isSell ? 'Confirm sale' : 'Confirm purchase',
          loading: _placing,
          onPressed: (_agreed && !_placing) ? _confirm : null,
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
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _failed = true;
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
  return showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.success,
        title: 'Order placed',
        message: side.isSell
            ? 'You sold $amountStr of ${asset.ticker}. Proceeds settle T+3.'
            : 'You bought $amountStr of ${asset.ticker}. Shares settle T+3.',
        primary: 'View portfolio',
        onPrimary: () {
          Navigator.of(context).pop();
          context.go(Routes.portfolio);
        },
        secondary: 'Done',
        onSecondary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}
