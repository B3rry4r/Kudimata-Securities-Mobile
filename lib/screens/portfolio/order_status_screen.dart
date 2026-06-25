// Stage 7 · Order status (pushed; route Routes.orderStatus). Lists the user's
// buy/sell orders from MockData.txns with per-order status via KBadge. Empty
// state uses KStatusView. KDetailHeader (back chevron, no tab bar).
//
// SEAM: order records are mock. Live order state (placed → filled / failed)
// streams from the sponsoring-broker order API here.
import 'package:flutter/material.dart';

import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Orders = buy/sell ledger entries only (funding/withdrawal live in Wallet).
    final orders = MockData.txns
        .where((t) => t.type == TxnType.buy || t.type == TxnType.sell)
        .toList();

    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Orders'),
      body: SafeArea(
        top: false,
        child: orders.isEmpty
            ? const _EmptyOrders()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 16, KSpace.gutter, 24),
                children: [
                  const KEyebrow('Recent orders'),
                  const SizedBox(height: 12),
                  KCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < orders.length; i++)
                          Container(
                            decoration: BoxDecoration(
                              border: i == 0
                                  ? null
                                  : const Border(
                                      top: BorderSide(color: KColor.hairline, width: 1)),
                            ),
                            child: _OrderRow(txn: orders[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// One order row — title + units/price subtitle · amount + status badge.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.txn});
  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final amountColor = txn.incoming ? KColor.gain : KColor.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(txn.title, style: KType.cardTitle().copyWith(height: 20 / 15)),
                const SizedBox(height: 4),
                Text(txn.subtitle, style: KType.micro(color: KColor.ink3).tnum),
                const SizedBox(height: 6),
                _StatusBadge(status: txn.status),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(txn.amount,
                  style: KType.cardTitle(color: amountColor).copyWith(height: 20 / 15).tnum),
              const SizedBox(height: 4),
              Text(txn.date, style: KType.micro(color: KColor.ink3).tnum),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status pill mapped from TxnStatus.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TxnStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, KBadgeTone tone, String icon) = switch (status) {
      TxnStatus.completed => ('Filled', KBadgeTone.gain, 'check'),
      TxnStatus.pending => ('Pending', KBadgeTone.indicator, 'transfer'),
      TxnStatus.failed => ('Failed', KBadgeTone.loss, 'close'),
    };
    final color = switch (tone) {
      KBadgeTone.gain => KColor.gain,
      KBadgeTone.loss => KColor.loss,
      KBadgeTone.indicator => KColor.indicator,
      KBadgeTone.neutral => KColor.ink2,
    };
    return KBadge(
      label: label,
      tone: tone,
      icon: KIcon(icon, size: 12, color: color),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.gutter),
        child: KStatusView(
          tone: KStatusTone.pending,
          title: 'No orders yet',
          message: 'Your buy and sell orders will appear here once you place a trade.',
          primary: 'Browse markets',
          onPrimary: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
