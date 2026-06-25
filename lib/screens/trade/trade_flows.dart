// Kudimata Securities — Stage 6: Trade buy/sell flows as bottom sheets.
// Mirrors trade-screens.jsx: AmountSheet (+ over-limit error state), ReviewSheet,
// SuccessSheet — shared between Buy and Sell via a `side` flag. Each flow is a
// sequence of showKSheet presentations; the launching screen (asset detail) stays
// behind the scrim, so we don't re-render the design's TradeBackdrop here.
//
// SEAM: the order itself is mocked — a delay + KStatusView stands in for the real
// sponsoring-broker order API. No real trading happens.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:go_router/go_router.dart';

// Mock daily order limit (₦). Amounts above this trip the over-limit state.
const double _kDailyLimit = 500000;

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// ─────────────────────────────────────────────────────────────────────────────

/// Buy flow: amount → (over-limit?) → review → success.
Future<void> showBuyFlow(BuildContext context, Asset asset) =>
    _showAmountSheet(context, asset, side: _Side.buy);

/// Sell flow: amount → review → success.
Future<void> showSellFlow(BuildContext context, Asset asset) =>
    _showAmountSheet(context, asset, side: _Side.sell);

enum _Side { buy, sell }

extension on _Side {
  bool get isSell => this == _Side.sell;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Amount entry (shared). Naira/shares unit toggle + quick-amount chips.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showAmountSheet(
  BuildContext context,
  Asset asset, {
  required _Side side,
}) {
  return showKSheet<void>(
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
  String _unit = 'naira';
  late String _quick = widget.side.isSell ? '50%' : '₦50k';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  // Parse the (comma-grouped) naira amount for the limit check.
  double get _amountValue =>
      double.tryParse(_amount.text.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

  bool get _overLimit => !widget.side.isSell && _amountValue > _kDailyLimit;

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
          label: 'Amount',
          controller: _amount,
          numeric: true,
          prefix: '₦',
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
          Text('≈ 186.3 shares',
              style: KType.micro(color: KColor.ink3).tnum.copyWith(letterSpacing: 0.04 * 10)),
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
                      text: isSell ? '120 shares · ₦32,208' : '₦310,400',
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
                  Navigator.of(context).pop();
                  _showReviewSheet(context, widget.asset, side: widget.side);
                },
              ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Review order (shared). Summary rows + risk ack + confirm.
// ─────────────────────────────────────────────────────────────────────────────

void _showReviewSheet(BuildContext context, Asset asset, {required _Side side}) {
  showKSheet<void>(
    context,
    title: 'Review order',
    child: _ReviewSheet(asset: asset, side: side),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.asset, required this.side});
  final Asset asset;
  final _Side side;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool _agreed = false;
  bool _placing = false;

  @override
  Widget build(BuildContext context) {
    final isSell = widget.side.isSell;
    final rows = isSell
        ? const [
            ('Asset', 'MTNN'),
            ('Type', 'Market'),
            ('Shares', '186.3'),
            ('Est. price', '₦268.40'),
            ('Fee', '₦125'),
          ]
        : const [
            ('Asset', 'MTNN'),
            ('Type', 'Market'),
            ('Amount', '₦50,000'),
            ('Est. shares', '186.3'),
            ('Est. price', '₦268.40'),
            ('Fee', '₦125'),
          ];

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
              Text(isSell ? '₦49,875' : '₦50,125',
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
    // SEAM: sponsoring-broker order API call goes here. Mocked with a short delay;
    // a real placement would return an order id / status to thread into Orders.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop();
    _showSuccessSheet(context, widget.asset, side: widget.side);
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
      decoration: const BoxDecoration(
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

void _showSuccessSheet(BuildContext context, Asset asset, {required _Side side}) {
  HapticFeedback.lightImpact();
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.success,
        title: 'Order placed',
        message: side.isSell
            ? 'You sold ₦50,000 of ${asset.ticker}. Proceeds settle T+3.'
            : 'You bought ₦50,000 of ${asset.ticker}. Shares settle T+3.',
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
