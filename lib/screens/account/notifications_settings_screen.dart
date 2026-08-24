// Stage 9 — Notifications settings (pushed). Mirrors `Notifications` in
// settings-screens.jsx; re-verified against screen-specs.md spec 48
// (2026-08-23 exactness pass — the prior redesign left this screen on the
// bare token cascade without checking copy).
//
// Wired per lib/data/api/README.md's FutureBuilder convention against
// NotificationPreferencesRepository (GET/PUT /notification-preferences/me).
// Per dispatcher ruling C-5 / UA-19, the real backend models EMAIL ONLY —
// exactly THREE booleans (ordersEmail/priceAlertsEmail/accountEmail). Spec
// 48 mocks five switches ("Order updates", "Money in and out", "Price
// alerts", "Weekly digest", "Security") plus a Push/Email/SMS "How we reach
// you" section. That's a real data-model gap, not a mobile oversight —
// resolved per-item below rather than either faking backend capability that
// doesn't exist, or silently dropping spec copy:
//   - "Order updates" -> ordersEmail. Exact 1:1 match.
//   - "Price alerts" -> priceAlertsEmail. Exact 1:1 match.
//   - "Money in and out" + "Security" both collapse onto the ONE remaining
//     field, accountEmail — the backend has no separate money-vs-security
//     split. Spec disables "Security" (always-on) but leaves "Money in and
//     out" real/toggleable; since one field can't be both, this screen
//     keeps accountEmail a real, interactive toggle (money movement is the
//     more clearly opt-out-able of the two) and merges both spec
//     descriptions into one honest label/helper rather than picking one and
//     silently dropping the other.
//   - "Weekly digest" has no backend field at all (ties to the DigestCard
//     AI feature, itself still a static/local preview everywhere else in
//     this app per docs/redesign/PLAN.md). Shown as a real-looking switch
//     for visual completeness, consistent with that same stub precedent,
//     but it is LOCAL STATE ONLY — never sent to the backend, never
//     persisted across app restarts. Do not wire this to a real field until
//     the digest-scheduling backend exists.
//   - "How we reach you" (Push/Email/SMS) is skipped entirely, not shown in
//     any form — there is no push-notification or SMS infrastructure
//     anywhere in this app to even stub honestly (unlike the AI-preview
//     items above, this would be pure fiction about device capabilities,
//     not a known-future feature preview).
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/notification_preferences_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  late final _repo =
      NotificationPreferencesRepository(AppScope.read(context).apiClient);
  late Future<NotificationPreferences> _future = _repo.me();

  // Local-only, per this file's header comment — never persisted.
  bool _weeklyDigest = false;

  Future<void> _toggleOrders(NotificationPreferences prefs, bool value) async {
    final previous = prefs.ordersEmail;
    setState(() => prefs.ordersEmail = value);
    try {
      await _repo.update(prefs);
    } catch (_) {
      // No offline/retry machinery in this app (README.md) — just revert the
      // optimistic change so the switch reflects the last-saved state.
      if (mounted) setState(() => prefs.ordersEmail = previous);
    }
  }

  Future<void> _togglePriceAlerts(NotificationPreferences prefs, bool value) async {
    final previous = prefs.priceAlertsEmail;
    setState(() => prefs.priceAlertsEmail = value);
    try {
      await _repo.update(prefs);
    } catch (_) {
      if (mounted) setState(() => prefs.priceAlertsEmail = previous);
    }
  }

  Future<void> _toggleAccount(NotificationPreferences prefs, bool value) async {
    final previous = prefs.accountEmail;
    setState(() => prefs.accountEmail = value);
    try {
      await _repo.update(prefs);
    } catch (_) {
      if (mounted) setState(() => prefs.accountEmail = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Notifications',
      child: FutureBuilder<NotificationPreferences>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: () => setState(() => _future = _repo.me()),
            );
          }
          final prefs = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We only send what changes something you own. No daily market noise.',
                style: KType.body(color: KColor.ink2),
              ),
              const SizedBox(height: 20),
              KAccountCard(
                children: [
                  KSwitch(
                    label: 'Order updates',
                    description: 'Filled, part-filled, cancelled',
                    checked: prefs.ordersEmail,
                    onChanged: (v) => _toggleOrders(prefs, v),
                  ),
                  Divider(height: 1, color: KColor.hairline),
                  // Canvas order (screen 48): Order updates, Money in and
                  // out, Price alerts, Weekly digest, Security — this row
                  // sits second, matching the "Money in and out" slot it's
                  // merged onto (see this file's header comment for why it
                  // also carries "Security").
                  KSwitch(
                    label: 'Money in and out, and security',
                    description:
                        'Deposits, withdrawals, dividends, sign-ins and account changes',
                    checked: prefs.accountEmail,
                    onChanged: (v) => _toggleAccount(prefs, v),
                  ),
                  Divider(height: 1, color: KColor.hairline),
                  KSwitch(
                    label: 'Price alerts',
                    description: 'Only names on your watchlist, over 5% in a day',
                    checked: prefs.priceAlertsEmail,
                    onChanged: (v) => _togglePriceAlerts(prefs, v),
                  ),
                  Divider(height: 1, color: KColor.hairline),
                  KSwitch(
                    label: 'Weekly digest',
                    description: 'One written summary of your portfolio, on Sundays',
                    checked: _weeklyDigest,
                    onChanged: (v) => setState(() => _weeklyDigest = v),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
