// Notifications settings (pushed, restyled 2026-08-27 — no artboard in the
// redesign-2026-08 canvas; RULINGS.md keeps this as live account
// infrastructure). Mirrors `Notifications` in settings-screens.jsx.
//
// Wired per lib/data/api/README.md's FutureBuilder convention against
// NotificationPreferencesRepository (GET/PUT /notification-preferences/me).
// The real backend models EMAIL ONLY — exactly THREE booleans
// (ordersEmail/priceAlertsEmail/accountEmail). The older mockup this screen
// was originally built from drew five switches plus a Push/Email/SMS "How we
// reach you" section; that's a data-model gap, resolved per-item rather than
// faking backend capability that doesn't exist or silently dropping copy:
//   - "Order updates" -> ordersEmail. Exact 1:1 match.
//   - "Price alerts" -> priceAlertsEmail. Exact 1:1 match.
//   - "Money in and out" + "Security" both collapse onto the ONE remaining
//     field, accountEmail — the backend has no separate money-vs-security
//     split, so this screen keeps accountEmail a real, interactive toggle
//     (money movement is the more clearly opt-out-able of the two) and
//     merges both descriptions into one honest label/helper rather than
//     picking one and silently dropping the other.
//   - "Weekly digest" is REMOVED, not shown even as a preview. It has no
//     backend field, and the feature it would summarise — the AI portfolio
//     digest — is itself parked with every entry point removed elsewhere in
//     the app (R-6, docs/redesign/DECISIONS.md; see home_screen.dart's own
//     "REMOVED per R-6" note). A switch that opts into an email nobody can
//     ever receive is a promise nothing keeps, the same defect class R-34
//     names for a rendered figure with no writer — so it stays off the
//     screen here too rather than as a decorative, unpersisted toggle. Gap
//     filed in docs/redesign/BACKEND_GAPS.md for when R-6 is revisited.
//   - "How we reach you" (Push/Email/SMS) is skipped entirely, not shown in
//     any form — there is no push-notification or SMS infrastructure
//     anywhere in this app to even stub honestly.
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
              // 2026-08-24 fix — reported live: the switch rows had no
              // vertical padding at all (a bare KSwitch directly inside
              // KAccountCard, separated only by a plain Divider), so every
              // label sat cramped flush against its neighbours' dividers
              // and the switch knob read as vertically misaligned against
              // its own two-line label/description block. Every other
              // KSwitch consumer in this app (security_screen.dart,
              // data_privacy_screen.dart, price_alerts_screen.dart) wraps
              // each row in `Container(padding: vertical 13, border: top
              // hairline)` instead of a bare Divider — matching that
              // established convention here instead of inventing a new one.
              KAccountCard(
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: Border(
                          top: i == 0
                              ? BorderSide.none
                              : BorderSide(color: KColor.hairline, width: 1),
                        ),
                      ),
                      child: switch (i) {
                        0 => KSwitch(
                            label: 'Order updates',
                            description: 'Filled, part-filled, cancelled',
                            checked: prefs.ordersEmail,
                            onChanged: (v) => _toggleOrders(prefs, v),
                          ),
                        // Merged row — see this file's header comment for
                        // why "Money in and out" and "Security" share the
                        // one backend field, accountEmail.
                        1 => KSwitch(
                            label: 'Money in and out, and security',
                            description:
                                'Deposits, withdrawals, dividends, sign-ins and account changes',
                            checked: prefs.accountEmail,
                            onChanged: (v) => _toggleAccount(prefs, v),
                          ),
                        _ => KSwitch(
                            label: 'Price alerts',
                            description: 'Only names on your watchlist, over 5% in a day',
                            checked: prefs.priceAlertsEmail,
                            onChanged: (v) => _togglePriceAlerts(prefs, v),
                          ),
                      },
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
