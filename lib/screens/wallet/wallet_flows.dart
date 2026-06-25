// Kudimata Securities — Stage 8: Wallet money-movement flows as bottom sheets.
// Mirrors wallet-screens.jsx (AddMoney / Withdraw / Convert) as showKSheet
// sequences: amount → method/bank/rate → review → KStatusView success. The
// launching wallet screen stays behind the scrim.
//
// SEAM: every flow stops at a MOCKED processor result — a short delay + a
// KStatusView success stands in for the real wallet funding processor / payout
// rail / FX rate engine. No real payments, withdrawals, or currency conversion
// happen here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public flow launchers (cross-stage contract — see BUILD_CONTRACT.md §d).
// ─────────────────────────────────────────────────────────────────────────────

/// Add money: amount + method → review → success.
Future<void> showAddMoneyFlow(BuildContext context) => showKSheet<void>(
      context,
      title: 'Add money',
      child: const _AddMoneySheet(),
    );

/// Withdraw: amount + destination bank → review → success.
Future<void> showWithdrawFlow(BuildContext context) => showKSheet<void>(
      context,
      title: 'Withdraw',
      child: const _WithdrawSheet(),
    );

/// Convert: ₦ → \$ amounts at a fixed mock rate → review → success.
Future<void> showConvertFlow(BuildContext context) => showKSheet<void>(
      context,
      title: 'Convert',
      child: const _ConvertSheet(),
    );

// Mock FX rate (₦ per $1). SEAM: real rate comes from the FX engine.
const double _kRate = 1580;

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits.
// ─────────────────────────────────────────────────────────────────────────────

// A selectable row inside a hairline card (method / destination).
class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.selected = false,
    this.trailingChevron = false,
    required this.first,
    this.onTap,
  });

  final String icon;
  final String title;
  final String sub;
  final bool selected;
  final bool trailingChevron;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: KColor.bg,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: KColor.hairline, width: 1)),
              ),
              child: KIcon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.cardTitle()),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: KType.micro(color: KColor.ink3)
                          .copyWith(letterSpacing: 0.04 * 10, height: 15 / 10)
                          .tnum),
                ],
              ),
            ),
            if (selected) const KIcon('check', size: 20),
            if (trailingChevron) const KIcon('chevronRight', size: 20, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}

// Summary row for review sheets — label left, tabular value right.
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

void _showSuccessSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  HapticFeedback.lightImpact();
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.success,
        title: title,
        message: message,
        primary: 'Done',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

// Quick-amount chips that overwrite the amount field.
class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({required this.values, required this.onPick});
  final List<(String label, String value)> values;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, value) in values) ...[
          if (label != values.first.$1) const SizedBox(width: 8),
          Expanded(
            child: KPillChip(label: label, onTap: () => onPick(value)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MONEY — Step 1: amount + payment method.
// ─────────────────────────────────────────────────────────────────────────────

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet();
  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  late final TextEditingController _amount = TextEditingController(text: '50,000');
  String _method = 'bank'; // bank | card

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        ),
        const SizedBox(height: 14),
        _QuickAmounts(
          values: const [('₦10k', '10,000'), ('₦50k', '50,000'), ('₦100k', '100,000')],
          onPick: (v) => setState(() => _amount.text = v),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: KEyebrow('Pay with'),
        ),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _SelectRow(
                icon: 'transfer',
                title: 'Bank transfer',
                sub: 'Reflects within minutes',
                selected: _method == 'bank',
                first: true,
                onTap: () => setState(() => _method = 'bank'),
              ),
              _SelectRow(
                icon: 'card',
                title: 'Debit card',
                sub: 'Instant · 1.4% fee',
                selected: _method == 'card',
                first: false,
                onTap: () => setState(() => _method = 'card'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Bank transfers reflect within minutes.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Continue',
          onPressed: () {
            Navigator.of(context).pop();
            _showAddMoneyReview(context, amount: _amount.text, method: _method);
          },
        ),
      ],
    );
  }
}

void _showAddMoneyReview(BuildContext context,
    {required String amount, required String method}) {
  showKSheet<void>(
    context,
    title: 'Review',
    child: _AddMoneyReview(amount: amount, method: method),
  );
}

class _AddMoneyReview extends StatefulWidget {
  const _AddMoneyReview({required this.amount, required this.method});
  final String amount;
  final String method;
  @override
  State<_AddMoneyReview> createState() => _AddMoneyReviewState();
}

class _AddMoneyReviewState extends State<_AddMoneyReview> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final methodLabel = widget.method == 'card' ? 'Debit card' : 'Bank transfer';
    final fee = widget.method == 'card' ? '1.4%' : '₦0.00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(label: 'Amount', value: '₦${widget.amount}'),
        _SummaryRow(label: 'Method', value: methodLabel),
        _SummaryRow(label: 'Fee', value: fee),
        const SizedBox(height: 18),
        Text('Funds appear in your naira wallet once confirmed.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Add money',
          loading: _busy,
          onPressed: _busy ? null : _confirm,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    // SEAM: real wallet funding processor (bank-transfer rail / card charge)
    // plugs in here. Mocked with a short delay.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop();
    _showSuccessSheet(context,
        title: 'Money added',
        message: '₦${widget.amount} is on the way to your naira wallet.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WITHDRAW — Step 1: amount + destination bank.
// ─────────────────────────────────────────────────────────────────────────────

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet();
  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final TextEditingController _amount = TextEditingController(text: '20,000');

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          helper: 'Balance ₦310,400.00',
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: KEyebrow('To'),
        ),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SelectRow(
            icon: 'wallet',
            title: 'GTBank',
            sub: '••• 4821',
            trailingChevron: true,
            first: true,
            onTap: () {}, // SEAM: bank picker (saved payout accounts) plugs in here.
          ),
        ),
        const SizedBox(height: 12),
        Text('Withdrawals arrive within 1 business day.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Withdraw',
          onPressed: () {
            Navigator.of(context).pop();
            _showWithdrawReview(context, amount: _amount.text);
          },
        ),
      ],
    );
  }
}

void _showWithdrawReview(BuildContext context, {required String amount}) {
  showKSheet<void>(
    context,
    title: 'Review',
    child: _WithdrawReview(amount: amount),
  );
}

class _WithdrawReview extends StatefulWidget {
  const _WithdrawReview({required this.amount});
  final String amount;
  @override
  State<_WithdrawReview> createState() => _WithdrawReviewState();
}

class _WithdrawReviewState extends State<_WithdrawReview> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(label: 'Amount', value: '₦${widget.amount}'),
        _SummaryRow(label: 'To', value: 'GTBank ••• 4821'),
        _SummaryRow(label: 'Fee', value: '₦0.00'),
        const SizedBox(height: 18),
        Text('Withdrawals arrive within 1 business day.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Withdraw',
          loading: _busy,
          onPressed: _busy ? null : _confirm,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    // SEAM: real payout rail (bank transfer to the saved account) plugs in here.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop();
    _showSuccessSheet(context,
        title: 'Withdrawal started',
        message: '₦${widget.amount} is on its way to GTBank ••• 4821.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERT — Step 1: ₦ → $ at a fixed mock rate.
// ─────────────────────────────────────────────────────────────────────────────

class _ConvertSheet extends StatefulWidget {
  const _ConvertSheet();
  @override
  State<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<_ConvertSheet> {
  late final TextEditingController _from = TextEditingController(text: '158,000');
  late final TextEditingController _to = TextEditingController(text: '100.00');

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  double _num(String s) => double.tryParse(s.replaceAll(RegExp('[^0-9.]'), '')) ?? 0;

  String _fmtUsd(double v) => v.toStringAsFixed(2);
  String _fmtNgn(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                KInput(
                  label: 'From',
                  controller: _from,
                  numeric: true,
                  prefix: '₦',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => _to.text = _fmtUsd(_num(v) / _kRate),
                ),
                const SizedBox(height: 10),
                KInput(
                  label: 'To',
                  controller: _to,
                  numeric: true,
                  prefix: '\$',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => _from.text = _fmtNgn(_num(v) * _kRate),
                ),
              ],
            ),
            // The swap medallion straddling the two fields.
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KColor.ink,
                shape: BoxShape.circle,
                border: Border.all(color: KColor.paper, width: 3),
              ),
              child: const KIcon('transfer', size: 16, color: KColor.paper),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rate'.upper, style: KType.label()),
              const SizedBox(width: 8),
              Text('₦1,580 = \$1',
                  style: KType.body(color: KColor.ink, w: KWeight.medium).tnum),
            ],
          ),
        ),
        const SizedBox(height: 22),
        KButton(
          label: 'Convert',
          onPressed: () {
            Navigator.of(context).pop();
            _showConvertReview(context, from: _from.text, to: _to.text);
          },
        ),
      ],
    );
  }
}

void _showConvertReview(BuildContext context,
    {required String from, required String to}) {
  showKSheet<void>(
    context,
    title: 'Review',
    child: _ConvertReview(from: from, to: to),
  );
}

class _ConvertReview extends StatefulWidget {
  const _ConvertReview({required this.from, required this.to});
  final String from;
  final String to;
  @override
  State<_ConvertReview> createState() => _ConvertReviewState();
}

class _ConvertReviewState extends State<_ConvertReview> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(label: 'From', value: '₦${widget.from}'),
        _SummaryRow(label: 'To', value: '\$${widget.to}'),
        _SummaryRow(label: 'Rate', value: '₦1,580 = \$1'),
        const SizedBox(height: 18),
        Text('The dollar amount lands in your USD wallet.',
            style: KType.body(color: KColor.ink3)),
        const SizedBox(height: 22),
        KButton(
          label: 'Convert',
          loading: _busy,
          onPressed: _busy ? null : _confirm,
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    // SEAM: real FX engine + settlement plug in here (rate lock, ledger move).
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop();
    _showSuccessSheet(context,
        title: 'Converted',
        message: '\$${widget.to} is now in your USD wallet.');
  }
}
