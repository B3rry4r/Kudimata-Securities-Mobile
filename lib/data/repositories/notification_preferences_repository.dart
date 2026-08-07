// Kudimata Securities — Notification preferences repository.
//
// Mirrors the `_groups` seed list notifications_settings_screen.dart used to
// hardcode. Follows lib/data/api/README.md's shared convention (shape copied
// from asset_repository.dart's example, not its field mapping).
//
// registry.json's NotificationPreference resource (dispatcher ruling C-5,
// UA-19) is EMAIL-ONLY: `{userId, ordersEmail, priceAlertsEmail,
// accountEmail}` via `GET /notification-preferences/me` /
// `PUT /notification-preferences/me`. There is no backend concept of a Push
// or SMS channel — the screen's former 3-channel (Push/Email/SMS) grid was
// pared down to the Email column only as part of this wiring; see the
// screen file for that UI change.
//
// Judgment call (flagged per README's "if a field is genuinely missing,
// that's a per-screen judgment call to flag" precedent, extended here to a
// missing HTTP verb): registry.json documents the update endpoint as
// `PUT /notification-preferences/me`, but ApiClient
// (lib/data/api/api_client.dart — out of scope for a per-screen wiring
// agent) only exposes get/post/patch/delete convenience verbs, no put.
// PATCH is the closest supported update-in-place semantics, so [update]
// calls `_client.patch`.
import '../api/api_client.dart';

/// Email-only notification preferences (userId omitted — the screen never
/// needs to render or send it back; each request is scoped to the signed-in
/// investor via `/me`). Fields are mutable so the screen can apply an
/// optimistic toggle in place and revert it on a failed [update], the same
/// technique `NotificationItem`/`AppNotification` use in
/// notifications_repository.dart.
class NotificationPreferences {
  NotificationPreferences({
    required this.ordersEmail,
    required this.priceAlertsEmail,
    required this.accountEmail,
  });

  bool ordersEmail;
  bool priceAlertsEmail;
  bool accountEmail;
}

class NotificationPreferencesRepository {
  const NotificationPreferencesRepository(this._client);
  final ApiClient _client;

  /// Mirrors the old hardcoded `_groups` seed (Email column only).
  /// GET /notification-preferences/me — a bare (non-paginated)
  /// `NotificationPreference` object per registry.json.
  Future<NotificationPreferences> me() async {
    final response = await _client.get('/notification-preferences/me');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// Persists all three email toggles at once — registry.json's payload for
  /// `updateNotificationPreferences`/`PUT /notification-preferences/me` is
  /// the full object, not a per-field patch, so the screen always sends the
  /// current in-memory [prefs] after applying one optimistic change.
  Future<NotificationPreferences> update(NotificationPreferences prefs) async {
    final response = await _client.patch(
      '/notification-preferences/me',
      data: {
        'ordersEmail': prefs.ordersEmail,
        'priceAlertsEmail': prefs.priceAlertsEmail,
        'accountEmail': prefs.accountEmail,
      },
    );
    return _fromJson(response.data as Map<String, dynamic>);
  }

  NotificationPreferences _fromJson(Map<String, dynamic> json) => NotificationPreferences(
        ordersEmail: json['ordersEmail'] as bool? ?? false,
        priceAlertsEmail: json['priceAlertsEmail'] as bool? ?? false,
        accountEmail: json['accountEmail'] as bool? ?? false,
      );
}
