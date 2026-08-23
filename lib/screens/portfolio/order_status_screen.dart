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
                  // mockup-raw/s44.html line 9: padding-top 12, not 16.
                  padding: const EdgeInsets.fromLTRB(KSpace.gutter, 12, KSpace.gutter, 0),
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
        // Card padding is 18px horizontal (line 13), not 16.
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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
        // screen-specs.md #44).
        const KNudgeCard(
          title: 'Why is my order still filling?',
          body:
              'A market order fills in pieces when a company trades thinly. '
              "You'll get a notification the moment it completes.",
          tone: KNudgeTone.grape,
        ),
        // mockup-raw/s44.html line 22: footer padding-top is 18, not 16.
        const SizedBox(height: 18),
        // mockup-raw/s44.html line 23: a destructive "Cancel the MTNN
        // order" button precedes "Go to my portfolio" — still deliberately
        // NOT added, but the reason has narrowed (2026-08-24 re-check):
        //
        // The backend NOW has a real, working cancel endpoint —
        // `PATCH /orders/:id/cancel` (investor role, own order only, 422
        // via ApiException.message if the order isn't `pending` any more)
        // — and OrdersRepository.cancel(orderId) above calls it correctly.
        // That part of the old gap is closed.
        //
        // What's NOT closed: this screen's list is sourced from
        // `GET /transactions` (see OrdersRepository's own header comment —
        // investors have no `GET /orders` list endpoint, only
        // staff/compliance roles do), and the wire `Transaction` shape
        // carries no `orderId` field at all — confirmed against
        // Kudimata-Securities-Backend/src/common/types/transaction.types.ts
        // and prisma/schema.prisma's `Transaction.orderId` comment ("NOT a
        // registry.json wire field... Internal linkage only"). So every
        // `Txn` row here only has a *Transaction* id, never the *Order* id
        // `cancel()` needs — passing `txn.id` to it would 404 against the
        // Order table on every single call, not genuinely cancel anything.
        // Wiring the button against that id would be exactly the kind of
        // "looks wired, silently fails" affordance this app's own
        // conventions rule out.
        //
        // (Independently re-confirmed while researching this: no code path
        // in TransactionsService ever creates a buy/sell Transaction row
        // today either, so this screen's list is empty against the live
        // backend regardless — a separate, deeper, pre-existing gap, not
        // introduced by this pass.)
        //
        // Real fix needs either an investor-scoped `GET /orders` list, or
        // `orderId` added to the Transaction wire shape — backend work, out
        // of scope for a mobile-only pass. Once either lands, wire this
        // button using OrdersRepository.cancel(orderId), with a confirm
        // dialog (see freeze_account_screen.dart's AlertDialog pattern) and
        // a `setState(() => _future = _repo.orders())` refresh on success —
        // exactly the shape this repository's cancel() is already built to
        // support.
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
      // mockup-raw/s44.html row: "14px 0" — 0 horizontal (the card above
      // already carries the 18px horizontal inset).
      padding: const EdgeInsets.symmetric(vertical: 14),
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
          // mockup-raw/s44.html footer note: "empty state points at 32
          // Markets" — was just popping the screen instead of actually
          // routing there.
          onPrimary: () => context.go(Routes.markets),
        ),
      ),
    );
  }
}
