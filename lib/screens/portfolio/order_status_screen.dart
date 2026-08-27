// Orders hub (pushed; route Routes.orderStatus, reached from Home's Orders
// quick action). Artboard: s41 / s41d (docs/design/redesign-2026-08/04 Buy
// and Sell.dc.html) — id per docs/redesign/RULINGS.md, never a code
// comment (R-5; this file used to cite the stale #s44 from the old
// 97-screen canvas, now corrected).
//
// R-17: Cancel is a real, live, wired action (PATCH /orders/:id/cancel via
// OrdersRepository.cancel()) and stays even though s41 doesn't draw it — the
// alternative is phoning support to stop a trade. Kept per-row, inline next
// to that order's status pill: s41 draws one card per order (not one shared
// list), so a per-card Cancel fits its layout, and it lets an investor with
// several pending orders cancel the one they're actually looking at (a
// single bottom button targeting "the" pending order — the old design —
// can't do that once there's more than one).
//
// Wired to the real `GET /orders` via OrdersRepository.myOrders() —
// investor-scoped, real Order rows.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/orders_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/markets/market_hours.dart';
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

  // s41's three filter chips: Open / Done / Cancelled — covers every real
  // Order.status ('pending' / 'approved' / 'rejected' / 'cancelled') with no
  // leftover "All" bucket, unlike the old Open/All segmented control.
  String _filter = 'open';

  bool _matchesFilter(Order o) => switch (_filter) {
    'open' => o.status == 'pending',
    'done' => o.status == 'approved',
    _ => o.status == 'rejected' || o.status == 'cancelled',
  };

  Future<void> _cancel(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel the ${order.ticker} order?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
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
        child: Column(
          children: [
            // s41: "padding:16px 24px 0", chips hugging their own width
            // (not a full-width segmented track).
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Open',
                    selected: _filter == 'open',
                    onTap: () => setState(() => _filter = 'open'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Done',
                    selected: _filter == 'done',
                    onTap: () => setState(() => _filter = 'done'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Cancelled',
                    selected: _filter == 'cancelled',
                    onTap: () => setState(() => _filter = 'cancelled'),
                  ),
                ],
              ),
            ),
            Expanded(
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
                  if (all.isEmpty) return const _EmptyOrders();
                  final orders = all.where(_matchesFilter).toList();
                  if (orders.isEmpty) return _EmptyFilter(filter: _filter);
                  return _OrderList(
                    orders: orders,
                    marketOpen: marketOpen,
                    onCancel: (o) => _cancel(context, o),
                  );
                },
              ),
            ),
            // s41: "margin-top:auto;padding:16px 24px 32px;border-top:1px
            // solid var(--hairline)" — persistent footer, not part of the
            // scrolling list. No ticker-agnostic "start a new order" entry
            // exists yet (R-33's s42/s45 chooser expects a specific asset,
            // same as the real showBuyFlow/showSellFlow this app already
            // has), so this routes to Markets to pick one — filed in
            // BACKEND_GAPS.md.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
              ),
              child: KButton(
                label: 'Place a new order',
                onPressed: () => context.go(Routes.markets),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// s41's chip row: unlike KPillChip/KSegmentedControl, the selected fill is
/// var(--ink) in light but var(--indicator-soft) in dark (both artboards
/// drawn that way — not a R-26-style inconsistency to flatten), and chips
/// hug their own text width rather than sharing a track. Screen-local per
/// rule 5: no shared K* widget matches this exact look.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = KColor.active.brightness == Brightness.dark;
    final fill = selected ? (dark ? KColor.indicatorSoft : KColor.ink) : KColor.paper;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: KRadii.pillR,
          border: (!selected && !dark) ? Border.all(color: KColor.hairline, width: 1) : null,
        ),
        child: Text(
          label,
          style: KType.data(
            color: selected ? KColor.featureInk : KColor.ink,
            w: selected ? KWeight.bold : KWeight.semibold,
          ),
        ),
      ),
    );
  }
}

/// The scrolling body once at least one order matches the active filter:
/// one card per order (s41's per-order-card layout, not a single bordered
/// list) plus the "What these mean" explainer, shown only while the Open
/// tab actually has an in-queue/queued order on screen for it to explain.
class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.marketOpen, required this.onCancel});
  final List<Order> orders;
  final bool marketOpen;
  final void Function(Order) onCancel;

  @override
  Widget build(BuildContext context) {
    final hasPending = orders.any((o) => o.status == 'pending');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        for (var i = 0; i < orders.length; i++) ...[
          _OrderCard(
            order: orders[i],
            marketOpen: marketOpen,
            onCancel: orders[i].status == 'pending' ? () => onCancel(orders[i]) : null,
          ),
          if (i != orders.length - 1) const SizedBox(height: 12),
        ],
        if (hasPending) ...[
          const SizedBox(height: 24),
          const _WhatTheseMean(),
        ],
      ],
    );
  }
}

/// One order card — avatar + title/subtitle + status pill, with an inline
/// Cancel (R-17) when the order is still pending. mockup-raw s41: rounded-20
/// card, 16px padding.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.marketOpen, this.onCancel});
  final Order order;
  final bool marketOpen;
  final VoidCallback? onCancel;

  String get _title {
    final verb = order.side == 'sell' ? 'Sell' : 'Buy';
    return '$verb ${order.ticker} · ${order.units} shares';
  }

  String get _orderTypeLabel => order.orderType == 'limit' ? 'Limit' : 'Market';

  String get _subtitle {
    switch (order.status) {
      case 'approved':
        return '$_orderTypeLabel · ${_formatKobo(order.value)} · ${_formatDateTime(order.createdAt)}';
      case 'pending':
        if (!marketOpen) {
          return 'Waiting for the market · opens ${marketNextOpenLabel()} 10:00am';
        }
        if (order.orderType == 'limit' && order.limitPrice != null) {
          return 'Your price ${_formatKobo(order.limitPrice)} · placed ${_formatTime(order.createdAt)}';
        }
        return '$_orderTypeLabel · ${_formatKobo(order.value)} · placed ${_formatTime(order.createdAt)}';
      case 'rejected':
      case 'cancelled':
      default:
        return '$_orderTypeLabel order · not completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TickerBadge(ticker: order.ticker),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_title, style: KType.cardTitle().copyWith(height: 20 / 15)),
                    const SizedBox(height: 2),
                    Text(_subtitle, style: KType.micro(color: KColor.ink3).tnum),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: order.status, marketOpen: marketOpen),
            ],
          ),
          // "Filled so far" progress bar (R-34): s41 draws it for the
          // partially-filled MTNN example, but no field on Order carries how
          // many units of a pending order have filled — filed in
          // BACKEND_GAPS.md rather than shown as a fabricated fraction.
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onCancel,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'Cancel',
                    style: KType.micro(color: KColor.loss, w: KWeight.semibold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ticker-initial avatar. Order carries no per-instrument colour, so this
/// uses the same null-logoColor fallback every asset row elsewhere in the
/// app already falls back to (indicatorTint/indicator) rather than
/// inventing a colour-per-ticker mapping.
class _TickerBadge extends StatelessWidget {
  const _TickerBadge({required this.ticker});
  final String ticker;

  String get _initials {
    final letters = ticker.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: KColor.indicatorTint, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: KType.label(color: KColor.indicator, w: KWeight.semibold)
            .copyWith(fontSize: 12, letterSpacing: 0.24, height: 1.0),
      ),
    );
  }
}

/// Status pill mapped from the real Order.status. s41 distinguishes "In
/// queue" (market open, indicator-tinted) from "Queued" (market closed,
/// neutral track-tinted) — both are the real `pending` status; the split
/// uses the same client-side market-hours heuristic markets_screen.dart
/// already relies on (no separate "queued" field exists on Order).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.marketOpen});
  final String status;
  final bool marketOpen;

  @override
  Widget build(BuildContext context) {
    final (KStatus status_, String label) = switch (status) {
      'approved' => (KStatus.approved, 'Filled'),
      'pending' => marketOpen ? (KStatus.review, 'In queue') : (KStatus.pending, 'Queued'),
      _ => (KStatus.rejected, 'Cancelled'),
    };
    return KStatusPill(status: status_, label: label, small: true, dot: false);
  }
}

/// s41's static explainer block under the order cards.
class _WhatTheseMean extends StatelessWidget {
  const _WhatTheseMean();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What these mean', style: KType.cardTitle()),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: KType.body(color: KColor.ink2).copyWith(fontSize: 14, height: 21 / 14),
            children: [
              TextSpan(
                text: 'In queue',
                style: TextStyle(fontWeight: KWeight.bold, color: KColor.ink),
              ),
              const TextSpan(
                text: ' means the market is open and we are waiting for a seller at your price. ',
              ),
              TextSpan(
                text: 'Queued',
                style: TextStyle(fontWeight: KWeight.bold, color: KColor.ink),
              ),
              const TextSpan(
                text: ' means the market is shut and your order goes in when it opens.',
              ),
            ],
          ),
        ),
      ],
    );
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

/// ISO-8601 timestamp -> "9:20am" (s41's "placed 9:20am" copy).
String _formatTime(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final period = dt.hour >= 12 ? 'pm' : 'am';
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$mm$period';
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
          onPrimary: () => context.go(Routes.markets),
        ),
      ),
    );
  }
}

/// Empty state entered when the investor has orders overall, but none match
/// the active filter tab — distinct from [_EmptyOrders] (no orders at all).
class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final (String title, String message) = switch (filter) {
      'open' => (
          'No open orders',
          'Orders you place will show here until they fill or the market closes.',
        ),
      'done' => (
          'No completed orders yet',
          'Orders that have fully filled will show up here.',
        ),
      _ => (
          'No cancelled orders',
          'Orders you cancel, or that get rejected, will show up here.',
        ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.gutter),
        child: KStatusView(tone: KStatusTone.pending, title: title, message: message),
      ),
    );
  }
}
