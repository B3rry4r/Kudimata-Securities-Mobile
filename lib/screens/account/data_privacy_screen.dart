// Screen 91 — Data & privacy (2026-08-23, account-lifecycle/legal cluster).
// A settings hub — the NDPA consent set plus entry points into the
// retention doc (#96) and account closure (#90) — not a document viewer
// itself. (Originally also a data-export entry point; removed 2026-08-29,
// see below.)
//
// R-5 correction (2026-08-27, docs/redesign/DECISIONS.md): "screen 91"
// above is the OLD 97-screen canvas's numbering. The real, current artboard
// is `06 Account and Support.dc.html#s57` ("57 · Data and privacy"),
// rebuilt against below:
//  - Added: the "Your data" hero heading + subtitle s57 opens with (this
//    screen previously jumped straight into the NDPA sentence with no
//    heading at all).
//  - NOT relabelled: s57's two toggles are "Market news and tips" (sub
//    "Email and push") and "Offers from partners" (sub "You can say no,
//    nothing changes"). This app's two real consent fields
//    (`improveAppConsent`/`productEmailsConsent`, see below) are anonymous
//    app-improvement analytics and marketing emails — neither is a
//    third-party data-sharing consent ("offers from partners" implies
//    sharing data with partners, a materially different, more
//    legally-sensitive consent than either real field backs), and the
//    backend has no push-notification channel at all (checked
//    notification_preferences_repository.dart's own header — email only).
//    Relabelling a real toggle to say something it doesn't do would be
//    actively misleading on an NDPA consent screen — worse than a wrong
//    figure, same class the brief's R-34 "claims" rule exists for. The
//    existing accurate labels/descriptions are kept instead.
//  - Restyled: "How long we keep things"/"Close my account" moved out of
//    the scrolling body into a pinned footer (`KAccountSubScaffold.footer`)
//    with a destructive button, matching s57's own pinned "Delete my data"
//    treatment — this app's real destructive action is account closure
//    (close_account_screen.dart), not a separate "delete my data" capability.
//  - NOT transcribed: s57's retention clause says "six years"; this app's
//    own legal/data-notice content (legal_reference_screens.dart) says "12
//    years" consistently, several times over, each citing the SEC. Two
//    different sources disagree on a compliance figure — exactly
//    C-1/C-4-shaped territory in FACT-CONFLICTS.md — so a new row (C-6) is
//    filed there and the existing, more-corroborated "12 years" stands
//    pending a ruling, per R-7.
//  - "Save choices" button dropped — s57 has no terminal save/done button
//    at all (every toggle already autosaves; this button only ever closed
//    the screen, which the header back button already does).
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
// "Download my data" — s57's own row ("One file, emailed within 7 days") —
// is REMOVED (2026-08-29, product owner: "remove download my data and
// improve the app from data privacy"). It was built and tappable but had no
// route/repository behind it anywhere in this app (grepped
// Kudimata-Securities-Backend: no data-export/GDPR-style-download endpoint
// of any kind), so tapping it only ever surfaced "Data export isn't
// available yet — contact support". A control whose only possible outcome
// is a refusal is a dead control, not a real capability with an honest
// caveat — the distinction the established "not available yet" pattern
// (statements_screen.dart / withdraw_mandate_screen.dart) relies on for a
// capability that's merely incomplete, not absent. Removed rather than kept
// showing; docs/redesign/BACKEND_GAPS.md's "s57 — Data and privacy" entry
// is updated to say so instead of describing a still-visible row.
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
        // s57's own hero heading + subtitle — added, this screen previously
        // had no heading at all above the NDPA sentence.
        Text('Your data', style: KType.hero()),
        const SizedBox(height: 6),
        Text(
          'Choose what we may send you, take a copy, or ask us to delete it.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 12),
        Text(
          'Under the Nigeria Data Protection Act you decide what we may do beyond running '
          'your account.',
          style: KType.data(color: KColor.ink3),
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
            // s57 draws "Market news and tips"/"Offers from partners" here
            // — NOT relabelled to that copy; see this file's header note
            // for why the real fields these toggles control don't match
            // that framing.
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
              // s57 says "six years" — NOT adopted; see this file's header
              // note (FACT-CONFLICTS.md C-6) for why the existing, more
              // corroborated "12 years" stands pending a ruling.
              sub: 'Trading records 12 years, as the SEC requires',
              right: const KRowChevron(),
              first: true,
              onTap: _openDataNotice,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Turning off the optional switches never limits trading, and we don't sell data to "
          'anyone.',
          style: KType.data(color: KColor.ink3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Data & privacy',
      // s57's own pinned-bottom footer (retention line + a destructive
      // button) — this app's real destructive action here is account
      // closure, not a separate "delete my data" capability, so "Close my
      // account and delete what you can" (close_account_screen.dart) moved
      // here from the scrolling body to match s57's shape.
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We must keep your trading records for 12 years, as the SEC requires, even '
              'after you close the account. Everything else can go.',
              style: KType.data(color: KColor.ink3),
            ),
            const SizedBox(height: 9),
            KButton(
              label: 'Close my account and delete what you can',
              variant: KButtonVariant.destructive,
              onPressed: _openClose,
            ),
          ],
        ),
      ),
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
