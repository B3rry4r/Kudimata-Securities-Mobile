// Stage 7 · Order status (pushed; route Routes.orderStatus). Lists the user's
// buy/sell orders with per-order status via KStatusPill. KDetailHeader (back
// chevron, no tab bar).
//
// 2026-08-24 rewrite: wired to the REAL `GET /orders` resource via
// OrdersRepository.myOrders() — see that repository's header comment for why
// this is now correct (investor-scoped GET /orders exists for real, and real
// Order rows exist for real — the previous Transaction-based approach was
// permanently empty against the live backend). Also wires the real "Cancel"
// button: PATCH /orders/:id/cancel via OrdersRepository.cancel(), previously
// impossible to reach a valid order id from this screen's old data source.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
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
  late Future<List<Order>> _future = _repo.myOrders();

  // "Open"/"All" (spec 44's SegmentedControl, default "Open"). "Open" means
  // still-pending (not yet filled, rejected or cancelled) — the real Order
  // resource's own `status` field, not a derived collapse.
  String _filter = 'open';

  Future<void> _cancel(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel the ${order.ticker} order?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep order')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await _repo.cancel(order.id);
      if (!context.mounted) return;
      setState(() => _future = _repo.myOrders());
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketOpen = AppScope.of(context).marketOpen;
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Orders'),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                title: "Couldn't load orders",
                onPrimary: () => setState(() => _future = _repo.myOrders()),
              );
            }
            final all = snapshot.data!;
            final orders =
                _filter == 'open' ? all.where((o) => o.status == 'pending').toList() : all;
            // Canvas s44's single destructive button cancels "the" one
            // pending order — this app's real data can have zero, one, or
            // several. Matches the canvas exactly for the common (single
            // pending order) case; with more than one, cancelling the
            // OLDEST pending order first (a reasonable, honest default —
            // there is no per-row cancel affordance in the canvas to defer
            // to instead).
            final cancellable = all.where((o) => o.status == 'pending').toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            final toCancel = cancellable.isEmpty ? null : cancellable.first;
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
                      : _OrderList(
                          orders: orders,
                          marketOpen: marketOpen,
                          cancellableOrder: toCancel,
                          onCancel: () => _cancel(context, toCancel!),
                          onCancelOrder: (o) => _cancel(context, o),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The list of order rows — fed from live `Order` data (see
/// OrdersRepository.myOrders).
class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.marketOpen,
    required this.cancellableOrder,
    required this.onCancel,
    required this.onCancelOrder,
  });
  final List<Order> orders;
  final bool marketOpen;
  final Order? cancellableOrder;
  final VoidCallback onCancel;

  /// Cancels one specific order — see _OrderRow.onCancel.
  final void Function(Order) onCancelOrder;

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
                  child: _OrderRow(
                    order: orders[i],
                    marketOpen: marketOpen,
                    onCancel: orders[i].status == 'pending'
                        ? () => onCancelOrder(orders[i])
                        : null,
                  ),
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
        // mockup-raw/s44.html line 23: a destructive "Cancel the {ticker}
        // order" button — real now (PATCH /orders/:id/cancel via
        // OrdersRepository.cancel, real order id from the real GET /orders
        // list). Canvas shows exactly one cancellable order; this app's
        // real data can have several pending at once, so the button
        // targets the OLDEST pending order (see build()'s `cancellableOrder`
        // — a reasonable, honest default since the canvas gives no
        // per-row cancel affordance to defer to instead) and is simply
        // absent when nothing is cancellable.
        if (cancellableOrder != null) ...[
          KButton(
            label: 'Cancel the ${cancellableOrder!.ticker} order',
            variant: KButtonVariant.destructive,
            onPressed: onCancel,
          ),
          const SizedBox(height: 10),
        ],
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
/// right. mockup-raw/s44.html: `[title+subtitle flex:1] [StatusPill]`.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.marketOpen, this.onCancel});
  final Order order;
  final bool marketOpen;

  /// Cancels THIS order. Null when the order isn't cancellable (anything
  /// past 'pending'). 2026-08-24: cancellation used to live in a single
  /// button BELOW the whole list that always targeted the OLDEST pending
  /// order — so with more than one queued you could not cancel the one you
  /// were looking at, and with a long list you could not find it at all.
  /// Reported as "where is cancelation????".
  final VoidCallback? onCancel;

  String get _title {
    final verb = order.side == 'sell' ? 'Sell' : 'Buy';
    return '$verb ${order.ticker} · ${order.units}';
  }

  String get _orderTypeLabel => order.orderType == 'limit' ? 'Limit' : 'Market';

  String get _subtitle {
    switch (order.status) {
      case 'approved':
        return '$_orderTypeLabel · ${_formatKobo(order.value)} · ${_formatDateTime(order.createdAt)}';
      case 'pending':
        return marketOpen
            ? '$_orderTypeLabel · ${_formatKobo(order.value)} · ${_formatDateTime(order.createdAt)}'
            : 'Queued · market opens 10:00';
      case 'rejected':
      case 'cancelled':
      default:
        return '$_orderTypeLabel order · not completed';
    }
  }

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
                Text(_title, style: KType.cardTitle().copyWith(height: 20 / 15)),
                const SizedBox(height: 4),
                Text(_subtitle, style: KType.micro(color: KColor.ink3).tnum),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusBadge(status: order.status, marketOpen: marketOpen),
          if (onCancel != null) ...[
            const SizedBox(width: 8),
            // Text, not an icon: "cancel an order" is destructive and
            // irreversible, and an unlabelled glyph beside a status pill is
            // exactly the kind of thing people tap by accident.
            GestureDetector(
              onTap: onCancel,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Cancel',
                  style: KType.micro(color: KColor.loss, w: KWeight.semibold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status pill mapped from the real Order.status (2026-08-22 "Soft Landing"
/// — screen-specs.md #44 calls for the shared StatusPill vocabulary).
/// Canvas distinguishes "Filling" (actively in progress) from "Queued"
/// (held until the NGX reopens) — both are the real `pending` status; the
/// split uses the same client-side market-hours heuristic markets_screen.dart
/// already relies on (no separate "queued" field exists on Order).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.marketOpen});
  final String status;
  final bool marketOpen;

  @override
  Widget build(BuildContext context) {
    final (KStatus status_, String label) = switch (status) {
      'approved' => (KStatus.approved, 'Filled'),
      'pending' => marketOpen ? (KStatus.pending, 'Filling') : (KStatus.review, 'Queued'),
      _ => (KStatus.rejected, 'Cancelled'),
    };
    return KStatusPill(status: status_, label: label, small: true);
  }
}

/// Minor-unit integer (kobo) -> "₦1,234.56" with thousands separators —
/// same grouping convention as every other repository's own `_formatKobo`.
String _formatKobo(int? minorUnits) {
  final abs = (minorUnits ?? 0).abs();
  final major = abs ~/ 100;
  final minor = (abs % 100).toString().padLeft(2, '0');
  final majorStr = major.toString();
  final buf = StringBuffer();
  for (var i = 0; i < majorStr.length; i++) {
    final posFromEnd = majorStr.length - i;
    buf.write(majorStr[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return '₦$buf.$minor';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// ISO-8601 timestamp -> "24 Jun 2026 · 14:35" (matching the rest of the app).
String _formatDateTime(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year} · $hh:$mm';
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
