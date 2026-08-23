// Screen 91 — Data & privacy (2026-08-23, account-lifecycle/legal cluster).
// A settings hub — the NDPA consent set plus entry points into the
// retention doc (#96), a data export, and account closure (#90) — not a
// document viewer itself.
//
// Wired 2026-08-24 per lib/data/api/README.md's FutureBuilder convention
// against NotificationPreferencesRepository (GET/PUT
// /notification-preferences/me), whose NotificationPreference resource now
// carries `improveAppConsent`/`productEmailsConsent` alongside the three
// existing email-channel fields (Kudimata-Securities-Backend
// src/common/types/notification.types.ts). The two switches below
// ("Improve the app" / "Product emails") read their initial state from the
// real GET on load and persist through the real PUT (full replace — the
// backend requires all five fields together, so every update sends the
// current in-memory preference object, not just the two fields this screen
// renders) on each toggle, optimistically, reverting with a real error
// message on failure — same technique
// notifications_settings_screen.dart uses for its own three switches.
//
// "Download my data" (canvas screen #93, an emailed-ZIP export) is outside
// this cluster's 8 screens and has no route/repository anywhere in this app
// yet — tapping it surfaces a known "not available yet" message, the same
// established pattern statements_screen.dart / withdraw_mandate_screen.dart
// already use for a real, known, unbuilt capability.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/notification_preferences_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';
import 'close_account_screen.dart';
import 'legal_reference_screens.dart';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  late final _repo = NotificationPreferencesRepository(AppScope.read(context).apiClient);
  late Future<NotificationPreferences> _future = _repo.me();

  void _openDataNotice() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DataNoticeScreen()),
    );
  }

  void _openClose() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CloseAccountScreen()),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Data export isn't available yet — contact support.")),
    );
  }

  Future<void> _toggleImproveApp(NotificationPreferences prefs, bool value) async {
    final previous = prefs.improveAppConsent;
    setState(() => prefs.improveAppConsent = value);
    try {
      await _repo.update(prefs);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => prefs.improveAppConsent = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => prefs.improveAppConsent = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  Future<void> _toggleProductEmails(NotificationPreferences prefs, bool value) async {
    final previous = prefs.productEmailsConsent;
    setState(() => prefs.productEmailsConsent = value);
    try {
      await _repo.update(prefs);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => prefs.productEmailsConsent = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => prefs.productEmailsConsent = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  Widget _switchRow({
    required bool checked,
    required String label,
    required String description,
    bool first = false,
    ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      child: KSwitch(
        checked: checked,
        label: label,
        description: description,
        disabled: onChanged == null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _body(NotificationPreferences prefs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Under the Nigeria Data Protection Act you decide what we may do beyond running '
          'your account.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 16),
        KAccountCard(
          children: [
            _switchRow(
              checked: true,
              label: 'Run my account',
              description: 'Required — KYC, trading, statements, tax',
              first: true,
            ),
            _switchRow(
              checked: prefs.improveAppConsent,
              label: 'Improve the app',
              description: 'Anonymous usage, no holdings data',
              onChanged: (v) => _toggleImproveApp(prefs, v),
            ),
            _switchRow(
              checked: prefs.productEmailsConsent,
              label: 'Product emails',
              description: 'New features and market explainers',
              onChanged: (v) => _toggleProductEmails(prefs, v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        KAccountCard(
          children: [
            KAccountRow(
              title: 'How long we keep things',
              sub: 'Trading records 6 years, as the SEC requires',
              right: const KRowChevron(),
              first: true,
              onTap: _openDataNotice,
            ),
            KAccountRow(
              title: 'Download my data',
              sub: 'Emailed as a ZIP',
              right: const KRowChevron(),
              onTap: _exportData,
            ),
            KAccountRow(
              title: 'Close my account and delete what you can',
              titleColor: KColor.loss,
              right: const KRowChevron(),
              onTap: _openClose,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Turning off the optional switches never limits trading, and we don't sell data to "
          'anyone.',
          style: KType.data(color: KColor.ink3),
        ),
        const SizedBox(height: 24),
        KButton(label: 'Done', onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Data & privacy',
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
          return _body(snapshot.data!);
        },
      ),
    );
  }
}
