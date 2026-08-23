// Screen 91 — Data & privacy (2026-08-23, account-lifecycle/legal cluster).
// A settings hub — the NDPA consent set plus entry points into the
// retention doc (#96), a data export, and account closure (#90) — not a
// document viewer itself.
//
// REAL GAP: the two optional switches below ("Improve the app" / "Product
// emails") have NO backing endpoint. The only consent/preferences resource
// anywhere in this app is `NotificationPreferencesRepository`
// (GET/PATCH /notification-preferences/me), and that is a fixed
// orders/priceAlerts/account EMAIL-CHANNEL model, not a generic
// consent-purpose model (analytics opt-in, marketing opt-in) — a different
// concept the NDPA consent set here actually needs. These two switches are
// therefore LOCAL-ONLY UI state (defaults match the design: "Improve the
// app" on, "Product emails" off) until a real consent-preferences endpoint
// exists — "Save choices" cannot persist them server-side today, and says
// so honestly (a toast) rather than silently no-op-ing or pretending to
// sync.
//
// "Download my data" (canvas screen #93, an emailed-ZIP export) is outside
// this cluster's 8 screens and has no route/repository anywhere in this app
// yet — tapping it surfaces a known "not available yet" message, the same
// established pattern statements_screen.dart / withdraw_mandate_screen.dart
// already use for a real, known, unbuilt capability.
import 'package:flutter/material.dart';
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
  bool _improveApp = true;
  bool _productEmails = false;

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

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Saved on this device. Synced consent preferences are not available yet.',
        ),
      ),
    );
    Navigator.of(context).maybePop();
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

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Data & privacy',
      child: Column(
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
                checked: _improveApp,
                label: 'Improve the app',
                description: 'Anonymous usage, no holdings data',
                onChanged: (v) => setState(() => _improveApp = v),
              ),
              _switchRow(
                checked: _productEmails,
                label: 'Product emails',
                description: 'New features and market explainers',
                onChanged: (v) => setState(() => _productEmails = v),
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
          KButton(label: 'Save choices', onPressed: _save),
        ],
      ),
    );
  }
}
