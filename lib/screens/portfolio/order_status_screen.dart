// Stage 7 · Order status (pushed; route Routes.orderStatus). Lists the user's
// buy/sell orders with per-order status via KBadge. Empty state uses
// KStatusView. KDetailHeader (back chevron, no tab bar).
//
// Wired to GET /transactions (buy/sell subset) via OrdersRepository.orders()
// — see lib/data/repositories/orders_repository.dart for why this screen's
// data comes from the Transaction resource rather than registry.json's Order
// resource, and lib/data/api/README.md for the FutureBuilder convention this
// follows.
import 'package:flutter/material.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/data/repositories/orders_repository.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  late final _repo = OrdersRepository(AppScope.read(context).apiClient);
  late Future<List<Txn>> _future = _repo.orders();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Orders'),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<Txn>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                title: "Couldn't load orders",
                onPrimary: () => setState(() => _future = _repo.orders()),
              );
            }
            final orders = snapshot.data!;
            return orders.isEmpty ? const _EmptyOrders() : _OrderList(orders: orders);
          },
        ),
      ),
    );
  }
}

/// The list of order rows — identical to the mock version's widget tree,
/// just fed from live `Txn` data instead of `MockData.txns`.
class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});
  final List<Txn> orders;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 16, KSpace.gutter, 24),
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
                        : Border(top: BorderSide(color: KColor.hairline, width: 1)),
                  ),
                  child: _OrderRow(txn: orders[i]),
                ),
            ],
          ),
        ),
      ],
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
