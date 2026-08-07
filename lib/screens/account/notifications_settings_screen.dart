// Stage 9 — Notifications settings (pushed). Mirrors `Notifications` in
// settings-screens.jsx.
//
// Wired per lib/data/api/README.md's FutureBuilder convention against
// NotificationPreferencesRepository (GET/PUT /notification-preferences/me).
// Per dispatcher ruling C-5 / UA-19, the real backend models EMAIL ONLY
// (ordersEmail/priceAlertsEmail/accountEmail) — there is no Push or SMS
// channel. The screen used to render a 3-channel (Push/Email/SMS) grid per
// group, all local `setState` only; the Push and SMS columns have been
// removed here (not just left inert) since there is no backend to wire them
// to — only the Email toggle remains per group, same card/row styling as
// before. Each toggle is an optimistic update (mirrors
// notifications_screen.dart's `_markRead`): flip immediately, PATCH
// /notification-preferences/me, revert on failure.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/repositories/notification_preferences_repository.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
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
              const KEyebrow('Orders'),
              const SizedBox(height: 10),
              KAccountCard(
                children: [
                  _ToggleRow(
                    label: 'Email',
                    checked: prefs.ordersEmail,
                    first: true,
                    onChanged: (v) => _toggleOrders(prefs, v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const KEyebrow('Price alerts'),
              const SizedBox(height: 10),
              KAccountCard(
                children: [
                  _ToggleRow(
                    label: 'Email',
                    checked: prefs.priceAlertsEmail,
                    first: true,
                    onChanged: (v) => _togglePriceAlerts(prefs, v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const KEyebrow('Account'),
              const SizedBox(height: 10),
              KAccountCard(
                children: [
                  _ToggleRow(
                    label: 'Email',
                    checked: prefs.accountEmail,
                    first: true,
                    onChanged: (v) => _toggleAccount(prefs, v),
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.checked,
    required this.first,
    required this.onChanged,
  });
  final String label;
  final bool checked;
  final bool first;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? BorderSide.none
              : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KType.body(color: KColor.ink))),
          KSwitch(checked: checked, onChanged: onChanged),
        ],
      ),
    );
  }
}
