// Notifications feed (pushed) — NotificationsRepository in a hairline card.
// Ported from extra-screens.jsx `NotificationsFeed`. Pushed screen: own Scaffold
// with KDetailHeader (back chevron, no tab bar).
//
// Wired per lib/data/api/README.md's FutureBuilder convention. Tap a row to
// mark it read (optimistic update, PATCH /notifications/:id/read) AND
// navigate to whatever the row is about — the canvas (#s47) is explicit:
// "every row opens the thing it is about · security items go straight to
// 51". KDetailHeader DOES carry a trailing-action slot (added generically
// for spec screen 80's status pill, see its own doc comment) — the header's
// settings gear (nav to Account → Notifications) and the bottom "Choose
// what we notify you about" ghost button both use it, wired to the same
// Routes.acctNotifications destination the canvas points at (#s48).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/notifications_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final _repo = NotificationsRepository(AppScope.read(context).apiClient);
  late Future<List<NotificationItem>> _future = _repo.list();

  Future<void> _markRead(int index, List<NotificationItem> items) async {
    final item = items[index];
    if (!item.notification.unread) return;
    setState(() => items[index] = item.copyAsRead());
    try {
      await _repo.markRead(item.id);
    } catch (_) {
      // No offline/retry machinery in this app (README.md) — just revert the
      // optimistic change so the dot comes back rather than lying about state.
      if (mounted) setState(() => items[index] = item);
    }
  }

  /// Canvas mapping (#s47): shield → security alert (51), markets (order
  /// filled) → Orders, wallet/arrowDown (money in / dividend) → the tab it
  /// landed in, check (account live) → Home. AppNotification carries no
  /// ticker/order id to deep-link to the exact record, so this routes to
  /// the screen the row is ABOUT, same as every other icon-typed row here.
  void _open(String icon) {
    switch (icon) {
      case 'shield':
        context.push(Routes.securityAlert);
      case 'markets':
        context.push(Routes.orderStatus);
      case 'wallet':
        context.go(Routes.wallet);
      case 'arrowDown':
        context.go(Routes.portfolio);
      case 'check':
        context.go(Routes.home);
    }
  }

  void _onTapItem(int index, List<NotificationItem> items) {
    _open(items[index].notification.icon);
    _markRead(index, items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(
        title: 'Notifications',
        trailing: KIconButton(
          icon: 'settings',
          semanticLabel: 'settings',
          onPressed: () => context.push(Routes.acctNotifications),
        ),
      ),
      body: FutureBuilder<List<NotificationItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: () => setState(() => _future = _repo.list()),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const KEmptyView(
              icon: 'bell',
              title: 'No notifications yet',
              message: 'Updates on your orders, wallet and price alerts will show here.',
            );
          }
          return _NotificationsList(
            items: items,
            onTapItem: (i) => _onTapItem(i, items),
          );
        },
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.items, required this.onTapItem});

  final List<NotificationItem> items;
  final ValueChanged<int> onTapItem;

  @override
  Widget build(BuildContext context) {
    // Canvas (#s47): two date-grouped sections, "Today" and "Earlier",
    // each its own eyebrow + hairline card — not one undivided list.
    final now = DateTime.now();
    bool isToday(NotificationItem item) {
      final c = item.createdAt?.toLocal();
      return c != null && c.year == now.year && c.month == now.month && c.day == now.day;
    }

    final todayIndices = <int>[];
    final earlierIndices = <int>[];
    for (var i = 0; i < items.length; i++) {
      (isToday(items[i]) ? todayIndices : earlierIndices).add(i);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 28),
      children: [
        if (todayIndices.isNotEmpty) ...[
          const Padding(padding: _gut, child: KEyebrow('Today')),
          const SizedBox(height: 10),
          Padding(
            padding: _gut,
            child: _NotificationGroup(items: items, indices: todayIndices, onTapItem: onTapItem),
          ),
          const SizedBox(height: 16),
        ],
        if (earlierIndices.isNotEmpty) ...[
          const Padding(padding: _gut, child: KEyebrow('Earlier')),
          const SizedBox(height: 10),
          Padding(
            padding: _gut,
            child: _NotificationGroup(items: items, indices: earlierIndices, onTapItem: onTapItem),
          ),
        ],
        const SizedBox(height: 18),
        // Canvas footer: ghost "Choose what we notify you about" → the same
        // notification-preferences destination (Routes.acctNotifications)
        // as the header's settings gear.
        Padding(
          padding: _gut,
          child: KButton(
            label: 'Choose what we notify you about',
            variant: KButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => context.push(Routes.acctNotifications),
          ),
        ),
      ],
    );
  }
}

/// One date-grouped hairline card ("Today" or "Earlier") of notification
/// rows — [indices] selects which of [items] belong in this group, so row
/// taps still resolve back to the right index in the original list.
class _NotificationGroup extends StatelessWidget {
  const _NotificationGroup({required this.items, required this.indices, required this.onTapItem});

  final List<NotificationItem> items;
  final List<int> indices;
  final ValueChanged<int> onTapItem;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var g = 0; g < indices.length; g++)
            Builder(builder: (context) {
              final i = indices[g];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTapItem(i),
                child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: g == 0
                              ? BorderSide.none
                              : BorderSide(color: KColor.hairline, width: 1),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bubble(icon: items[i].notification.icon),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(items[i].notification.title,
                                            style: KType.cardTitle()),
                                      ),
                                      if (items[i].notification.unread) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: KColor.indicator,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(items[i].notification.body,
                                      style: KType.body(color: KColor.ink2)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(items[i].notification.time,
                                style: KType.micro(color: KColor.ink3)
                                    .copyWith(letterSpacing: 0.04 * 10)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
        ],
      ),
    );
  }
}

/// Category-tinted 34px badge — screen-specs.md 47 / the canvas mockup's
/// #s47 block colour each notification's icon by what it's about (security
/// = loss-red, markets = indicator-grape, money-in/dividend = sun,
/// verified/success = gain-green), not one flat neutral circle for every
/// row (2026-08-23 exactness pass — the prior port dropped this).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon});
  final String icon;

  (Color bg, Color fg) get _tone => switch (icon) {
        'shield' => (KColor.statusRejectedTint, KColor.loss),
        'markets' => (KColor.indicatorTint, KColor.indicator),
        'wallet' || 'arrowDown' => (KColor.sunTint, KColor.sunPress),
        'check' => (KColor.statusApprovedTint, KColor.gain),
        _ => (KColor.track, KColor.ink2),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tone;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: KIcon(KIcon.has(icon) ? icon : 'bell', size: 16, color: fg),
    );
  }
}
