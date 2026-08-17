// Notifications feed (pushed) — NotificationsRepository in a hairline card.
// Ported from extra-screens.jsx `NotificationsFeed`. Pushed screen: own Scaffold
// with KDetailHeader (back chevron, no tab bar).
//
// Wired per lib/data/api/README.md's FutureBuilder convention. Tap a row to
// mark it read (optimistic update, PATCH /notifications/:id/read); reverts
// on failure. There is no mark-all-read affordance in this screen's design
// (KDetailHeader has no trailing action slot), so NotificationsRepository's
// markAllRead() exists but is intentionally left unwired — see its doc
// comment.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/notifications_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Notifications'),
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
          return _NotificationsList(items: items, onTapItem: (i) => _markRead(i, items));
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
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        Padding(
          padding: _gut,
          child: KCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTapItem(i),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: i == 0
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
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon});
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KColor.bg,
        shape: BoxShape.circle,
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: KIcon(KIcon.has(icon) ? icon : 'bell', size: 18, color: KColor.ink),
    );
  }
}
