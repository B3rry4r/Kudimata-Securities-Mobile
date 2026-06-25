// Kudimata Securities — Stage 8: Wallet screens. Mirrors wallet-screens.jsx:
// WalletScreen (root tab — naira BalancePanel + $ sub-balance, action row, recent
// transactions) and TransactionDetailScreen (pushed; KStatusView-style summary +
// detail rows). The three money-movement flows (Add money / Withdraw / Convert)
// live in wallet_flows.dart as bottom-sheet sequences.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/router/routes.dart';

import 'wallet_flows.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1 · WALLET HOME (root tab — shell provides the bottom nav).
// ─────────────────────────────────────────────────────────────────────────────

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txns = MockData.txns;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 100),
          children: [
            const KScreenHead(title: 'Wallet'),
            const SizedBox(height: 16),

            // Naira wallet — the one rich ink surface on this screen.
            const KBalancePanel(label: 'Naira wallet', balance: '₦310,400.00'),
            const SizedBox(height: 12),

            // USD sub-balance — plain hairline card with a currency glyph badge.
            const KCard(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _CurrencyBadge(glyph: '\$'),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DollarsTitle(),
                        SizedBox(height: 2),
                        _UsdEyebrow(),
                      ],
                    ),
                  ),
                  _UsdValue(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action row — Add money / Withdraw / Convert (sheet flows).
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: 'arrowDownLeft',
                    label: 'Add money',
                    onTap: () => showAddMoneyFlow(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: 'arrowUp',
                    label: 'Withdraw',
                    onTap: () => showWithdrawFlow(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: 'transfer',
                    label: 'Convert',
                    onTap: () => showConvertFlow(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Recent header — eyebrow + Orders shortcut.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const KEyebrow('Recent'),
                  GestureDetector(
                    onTap: () => context.push(Routes.orderStatus),
                    behavior: HitTestBehavior.opaque,
                    child: Text('Orders',
                        style: KType.label(color: KColor.ink2, w: KWeight.semibold)),
                  ),
                ],
              ),
            ),

            // Transactions list — tap a row → transaction detail.
            KCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < txns.length; i++)
                    _TxnRow(txn: txns[i], first: i == 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Currency glyph in a neutral hairline circle — never a flag.
class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.glyph});
  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: KColor.bg,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Text(glyph,
          style: KType.cardTitle(w: KWeight.semibold).copyWith(fontSize: 17, height: 1.0)),
    );
  }
}

class _DollarsTitle extends StatelessWidget {
  const _DollarsTitle();
  @override
  Widget build(BuildContext context) =>
      Text('Dollars', style: KType.cardTitle().copyWith(height: 20 / 15));
}

class _UsdValue extends StatelessWidget {
  const _UsdValue();
  @override
  Widget build(BuildContext context) =>
      Text('\$1,204.55', style: KType.section().tnum);
}

class _UsdEyebrow extends StatelessWidget {
  const _UsdEyebrow();
  @override
  Widget build(BuildContext context) => Text('USD wallet'.upper, style: KType.label());
}

// 1/3-width action tile — line icon over a label.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KIcon(icon, size: 22),
            const SizedBox(height: 8),
            Text(label,
                style: KType.label(color: KColor.ink).copyWith(letterSpacing: 0, height: 1.0)),
          ],
        ),
      ),
    );
  }
}

// One ledger row: icon medallion · title + date · signed tabular amount.
class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn, required this.first});
  final Txn txn;
  final bool first;

  // Map ledger type to a glyph from the fixed KIcon set.
  String get _icon => switch (txn.type) {
        TxnType.fund => 'arrowDownLeft',
        TxnType.withdraw => 'arrowUp',
        TxnType.buy => 'markets',
        TxnType.sell => 'markets',
        TxnType.convert => 'transfer',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(Routes.transactionDetail(txn.id)),
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
              child: KIcon(_icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(txn.title, style: KType.cardTitle().copyWith(height: 20 / 15)),
                  const SizedBox(height: 2),
                  Text(txn.subtitle,
                      style: KType.micro(color: KColor.ink3)
                          .copyWith(letterSpacing: 0.04 * 10, height: 15 / 10)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(txn.amount,
                style: KType.cardTitle(
                  color: txn.incoming ? KColor.gain : KColor.ink,
                  w: KWeight.semibold,
                ).copyWith(height: 20 / 15).tnum),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2 · TRANSACTION DETAIL (pushed — KDetailHeader, no tab bar).
// ─────────────────────────────────────────────────────────────────────────────

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.id});
  final String id;

  // Human label for the ledger type (sentence case).
  String _typeLabel(Txn t) => switch (t.type) {
        TxnType.fund => 'Add money',
        TxnType.withdraw => 'Withdrawal',
        TxnType.buy => 'Buy',
        TxnType.sell => 'Sell',
        TxnType.convert => 'Conversion',
      };

  (KStatusTone, String, Color) _status(TxnStatus s) => switch (s) {
        TxnStatus.completed => (KStatusTone.success, 'Completed', KColor.gain),
        TxnStatus.pending => (KStatusTone.pending, 'Pending', KColor.ink2),
        TxnStatus.failed => (KStatusTone.error, 'Failed', KColor.loss),
      };

  @override
  Widget build(BuildContext context) {
    final txn = MockData.txnById(id);

    if (txn == null) {
      return Scaffold(
        backgroundColor: KColor.bg,
        appBar: const KDetailHeader(title: 'Transaction'),
        body: const Center(
          child: Text('Transaction not found', style: TextStyle(color: KColor.ink2)),
        ),
      );
    }

    final (_, statusLabel, dotColor) = _status(txn.status);
    final amountColor = txn.incoming ? KColor.gain : KColor.ink;

    final rows = <(String, String)>[
      ('Type', '${_typeLabel(txn)} · ${txn.title.replaceFirst(RegExp(r'^(Buy|Sell)\s+'), '')}'),
      ('Reference', txn.id),
      ('Date & time', txn.date),
      ('Status', statusLabel),
    ];

    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Transaction'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 20, KSpace.gutter, 24),
          children: [
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status pill + hero amount, centred over a hairline.
                  Container(
                    padding: const EdgeInsets.only(bottom: 18),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
                    ),
                    child: Column(
                      children: [
                        _StatusPill(label: statusLabel, dotColor: dotColor),
                        const SizedBox(height: 16),
                        Text(txn.amount,
                            style: KType.hero(color: amountColor).tnum),
                      ],
                    ),
                  ),
                  // Detail rows.
                  for (var i = 0; i < rows.length; i++)
                    _DetailRow(label: rows[i].$1, value: rows[i].$2, last: i == rows.length - 1),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // SEAM: real receipt generation (PDF / statement service) plugs in here.
            KButton(
              label: 'Get receipt',
              variant: KButtonVariant.ghost,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.dotColor});
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: KColor.bg,
        borderRadius: BorderRadius.circular(KRadii.pill),
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label.upper, style: KType.label(color: KColor.ink2)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, required this.last});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KType.body(color: KColor.ink2)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: KType.body(color: KColor.ink, w: KWeight.medium).tnum),
          ),
        ],
      ),
    );
  }
}
