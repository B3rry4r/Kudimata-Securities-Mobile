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

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/orders_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  late final _repo = OrdersRepository(AppScope.read(context).apiClient);
  late Future<List<Txn>> _future = _repo.orders();

  // "Open"/"All" (spec 44's SegmentedControl, default "Open"). Txn.status
  // here is already the 3-value collapsed view (completed/pending/failed —
  // see OrdersRepository._statusFromJson), so "Open" == still-pending;
  // there is no separate "queued" sub-state to filter on at this layer.
  String _filter = 'open';

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
            final all = snapshot.data!;
            final orders =
                _filter == 'open' ? all.where((t) => t.status == TxnStatus.pending).toList() : all;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(KSpace.gutter, 16, KSpace.gutter, 0),
                  child: KSegmentedControl(
                    value: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                    options: const [
                      KSegmentOption(value: 'open', label: 'Open'),
                      KSegmentOption(value: 'all', label: 'All'),
                    ],
                  ),
                ),
                Expanded(
                  child: orders.isEmpty
                      ? const _EmptyOrders()
                      : _OrderList(orders: orders),
                ),
              ],
            );
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
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 24),
      children: [
        // mockup-raw/s44.html: SegmentedControl (in the parent Scaffold)
        // goes straight into the card — no "Recent orders" eyebrow between.
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
        const SizedBox(height: 16),
        // Static explainer nudge (2026-08-22 "Soft Landing" —
        // screen-specs.md #44). No "Cancel order" action added here: there
        // is no OrdersRepository cancel endpoint to wire it to yet.
        const KNudgeCard(
          title: 'Why is my order still filling?',
          body:
              'A market order fills in pieces when a company trades thinly. '
              "You'll get a notification the moment it completes.",
          tone: KNudgeTone.grape,
        ),
        const SizedBox(height: 16),
        KButton(
          label: 'Go to my portfolio',
          variant: KButtonVariant.ghost,
          onPressed: () => context.go(Routes.portfolio),
        ),
      ],
    );
  }
}

/// One order row — title + units/price subtitle, StatusPill inline to the
/// right. mockup-raw/s44.html: `[title+subtitle flex:1] [StatusPill]` — was
/// stacking the pill below the subtitle and adding an amount/date column
/// the mockup doesn't show in this list (that pairing belongs to the
/// Wallet activity list, s40, not Orders).
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.txn});
  final Txn txn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(txn.title, style: KType.cardTitle().copyWith(height: 20 / 15)),
                const SizedBox(height: 4),
                Text(txn.subtitle, style: KType.micro(color: KColor.ink3).tnum),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusBadge(status: txn.status),
        ],
      ),
    );
  }
}

/// Status pill mapped from TxnStatus (2026-08-22 "Soft Landing" —
/// screen-specs.md #44 calls for the shared StatusPill vocabulary, not a
/// bespoke badge).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TxnStatus status;

  @override
  Widget build(BuildContext context) {
    final (KStatus status_, String label) = switch (status) {
      TxnStatus.completed => (KStatus.approved, 'Filled'),
      TxnStatus.pending => (KStatus.review, 'Filling'),
      TxnStatus.failed => (KStatus.rejected, 'Cancelled'),
    };
    return KStatusPill(status: status_, label: label, small: true);
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
