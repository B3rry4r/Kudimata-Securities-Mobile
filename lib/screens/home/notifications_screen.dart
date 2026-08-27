// Notifications feed (pushed) — NotificationsRepository in a hairline card.
//
// R-25 (docs/redesign/DECISIONS.md): "Kept, restyled." No artboard anywhere
// in the redesign-2026-08 canvas covers this screen — R-5 correction
// 2026-08-27: this file used to cite "#s47"/"#s48" for its row-tap and
// settings-gear destinations, ids from the OLD 97-screen canvas that in the
// current 56-artboard canvas point at unrelated screens (Buy/Sell). There is
// no real replacement id, so those citations are removed rather than
// re-pointed. Layout/structure below are this screen's own, restyled onto
// the current tokens/component idiom (KDetailHeader, KEyebrow, KCard,
// KIcon-badge rows) to match already-rebuilt screens
// (account_screen.dart, statements_screen.dart) rather than inventing a
// parallel interpretation.
//
// Pushed screen: own Scaffold with KDetailHeader (back chevron, no tab bar).
//
// Wired per lib/data/api/README.md's FutureBuilder convention. Tap a row to
// mark it read (optimistic update, PATCH /notifications/:id/read) AND
// navigate to whatever the row is about — every row opens the thing it is
// about (security items go to the security-alert screen, markets items to
// order status, wallet/dividend items to the tab they landed in, an
// account-live check to Home). KDetailHeader's trailing-action slot carries
// the header's settings gear (nav to Account → Notifications) and the
// bottom "Choose what we notify you about" ghost button reuses the same
// slot pattern, both wired to Routes.acctNotifications.
//
// R-41 (docs/redesign/DECISIONS.md): also wired to `notification:new`
// (RealtimeClient.notifications) — each decoded Notification is prepended
// straight onto [_NotificationsScreenState._items], with NO network call
// on receipt. On reconnect after a drop (RealtimeClient.reconnected), this
// refetches ONCE via the same [_load]/NotificationsRepository.list() this
// screen already uses for its first load — the one legitimate fetch in
// this path.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/realtime/realtime_client.dart';
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
  late final RealtimeClient _realtime = AppScope.read(context).realtimeClient;
  late Future<List<NotificationItem>> _future = _load();

  /// The freshest known list — same override pattern as
  /// order_status_screen.dart/wallet_screens.dart. Once loaded, this (not
  /// the FutureBuilder's own snapshot) is what's rendered and what
  /// [_markRead] mutates.
  List<NotificationItem>? _items;

  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  StreamSubscription<void>? _reconnectSub;

  Future<List<NotificationItem>> _load() async {
    final items = await _repo.list();
    if (mounted) setState(() => _items = items);
    return items;
  }

  @override
  void initState() {
    super.initState();
    _notificationSub = _realtime.notifications.listen(_onNotification);
    _reconnectSub = _realtime.reconnected.listen((_) => _load());
  }

  /// Applies a decoded `notification:new` payload directly — prepends it
  /// to [_items] via NotificationsRepository.notificationFromJson (reusing
  /// [NotificationsRepository]'s own parser, not a second one). No network
  /// call.
  void _onNotification(Map<String, dynamic> json) {
    if (!mounted) return;
    final item = NotificationsRepository.notificationFromJson(json);
    setState(() => _items = [item, ...(_items ?? const <NotificationItem>[])]);
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

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

  /// Icon-to-destination mapping (R-25, no artboard): shield → security
  /// alert, markets (order filled) → Orders, wallet/arrowDown (money in /
  /// dividend) → the tab it landed in, check (account live) → Home.
  /// AppNotification carries no ticker/order id to deep-link to the exact
  /// record, so this routes to the screen the row is ABOUT, same as every
  /// other icon-typed row here.
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
          // Prefer the freshest known list (kept live by notification:new,
          // see file header) over the FutureBuilder's own snapshot — same
          // pattern order_status_screen.dart/wallet_screens.dart use.
          final effective = _items ?? snapshot.data;
          if (effective == null) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                onPrimary: () => setState(() => _future = _load()),
              );
            }
          }
          final items = effective!;
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
    // Two date-grouped sections, "Today" and "Earlier", each its own
    // eyebrow + hairline card — not one undivided list.
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

/// Category-tinted 34px badge — colours each notification's icon by what
/// it's about (security = loss-red, markets = indicator-grape,
/// money-in/dividend = sun, verified/success = gain-green), not one flat
/// neutral circle for every row (2026-08-23 exactness pass — the prior port
/// dropped this).
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
