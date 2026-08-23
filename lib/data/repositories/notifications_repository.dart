// Kudimata Securities — Notification repository.
//
// Mirrors MockData.notifications. Follows lib/data/api/README.md's shared
// convention (shape copied from asset_repository.dart's example, not its
// field mapping).
//
// GET /notifications is a PaginatedList<Notification> per registry.json
// (Notification resource), so this parses with PaginatedResponse<T>.fromJson
// — see lib/data/api/paginated_response.dart. The notifications screen has
// no pagination UI of its own (the mock version rendered every item inside
// one hairline-divided KCard, no "load more"/infinite scroll), so `list()`
// fetches a single page sized to stand in for "all notifications" and hands
// back the flat list — matching AssetRepository.trending()'s
// Future<List<T>> shape, which is what the screen's FutureBuilder wants.
//
// Two judgment calls, flagged per README ("if a field is genuinely missing,
// that's a per-screen judgment call to flag, not silently invent"):
//
// 1. AppNotification (lib/data/models.dart) has no `id` field — the mock
//    version never needed one, since nothing ever mutated `unread`.
//    registry.json's Notification resource does have one (required by
//    `PATCH /notifications/:id/read`). models.dart is out of scope for a
//    per-screen wiring agent, so rather than change the shared model, this
//    repository wraps each AppNotification in a small NotificationItem that
//    carries that id alongside it.
// 2. registry.json's Notification.createdAt is an ISO-8601 timestamp, not
//    the preformatted "2h ago" string AppNotification.time expects (mock.dart
//    baked that formatting in statically, per notifications.json's fragment
//    note: "pre-formatted relative-time string ... not a raw timestamp").
//    This repository formats createdAt into that same short relative style
//    so it drops into AppNotification.time unchanged.
import '../api/api_client.dart';
import '../api/paginated_response.dart';
import '../models.dart';

/// Pairs a fetched [AppNotification] with the backend id needed to mark it
/// read — AppNotification itself has no id (see file header, judgment call 1).
class NotificationItem {
  const NotificationItem({required this.id, required this.notification, this.createdAt});

  final String id;
  final AppNotification notification;

  /// Raw timestamp, kept alongside [notification.time]'s pre-formatted
  /// relative string (see file header, judgment call 2) — the screen needs
  /// this to sort rows into the canvas's "Today" / "Earlier" groups (spec
  /// screen 47), which a "2h ago"-style string can't reliably answer (e.g.
  /// "23h ago" could be earlier today or yesterday depending on wall-clock
  /// time). Nullable: null just means the row falls back to "Earlier".
  final DateTime? createdAt;

  /// A copy with [notification.unread] cleared — used for the optimistic
  /// tap-to-read update in the screen.
  NotificationItem copyAsRead() => NotificationItem(
        id: id,
        createdAt: createdAt,
        notification: AppNotification(
          title: notification.title,
          body: notification.body,
          time: notification.time,
          icon: notification.icon,
          unread: false,
        ),
      );
}

class NotificationsRepository {
  const NotificationsRepository(this._client);
  final ApiClient _client;

  /// Mirrors MockData.notifications. GET /notifications — paginated per
  /// registry.json; the screen has no pagination UI, so this fetches one
  /// page large enough to stand in for "all notifications".
  Future<List<NotificationItem>> list({int page = 1, int pageSize = 50}) async {
    final response = await _client.get(
      '/notifications',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final parsed = PaginatedResponse<NotificationItem>.fromJson(
      response.data as Map<String, dynamic>,
      _fromJson,
    );
    return parsed.data;
  }

  /// PATCH /notifications/:id/read — marks a single notification read.
  Future<void> markRead(String id) async {
    await _client.patch('/notifications/$id/read');
  }

  /// PATCH /notifications/mark-all-read. Exposed for completeness (it's part
  /// of the Notification resource in registry.json), but nothing calls it:
  /// the canvas's notifications header (#s47) only carries a settings gear
  /// (→ notification preferences), not a mark-all-read affordance, so one
  /// isn't invented here.
  Future<void> markAllRead() async {
    await _client.patch('/notifications/mark-all-read');
  }

  NotificationItem _fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      notification: AppNotification(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        time: _relativeTime(json['createdAt'] as String?),
        icon: json['icon'] as String? ?? 'bell',
        unread: json['unread'] as bool? ?? false,
      ),
    );
  }

  /// Formats an ISO-8601 timestamp into the same short relative style the
  /// mock data used ("2h ago", "1d ago", "5d ago", ...).
  static String _relativeTime(String? isoTimestamp) {
    if (isoTimestamp == null) return '';
    final parsed = DateTime.tryParse(isoTimestamp);
    if (parsed == null) return '';
    final diff = DateTime.now().toUtc().difference(parsed.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}
