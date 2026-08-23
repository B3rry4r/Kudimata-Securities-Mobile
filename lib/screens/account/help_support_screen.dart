// Stage 9 — Help & support (pushed). Search pill + FAQ/contact rows. Mirrors
// `HelpSupport` in extra-screens.jsx.
//
// Per Kudimata-Securities-Backend/.pipeline/fragments/account-help.json, no
// backend resource is declared for this screen's content — `_rows` (contact
// / FAQ channels) is a Phase-0 "keep local" default, not wired to any API.
// The search pill is a client-side filter over that same local list (no
// query ever leaves the widget), matching the local-filter pattern used by
// search_screen.dart.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

// Real contact details — no backend resource exists for this screen's
// content (see header note) so these stay static/hand-set, but they're the
// company's actual support channels (cross-checked against
// Kudimata-Web/pages/contact.js's real contact page), not placeholders.
const _kSupportEmail = 'support@kudimata.com';
const _kSupportPhone = '+2349163344444';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // Exact FAQ headlines from screen-specs.md spec 56 (2026-08-23 exactness
  // pass — the prior redesign kept this screen's older generic
  // contact-channel rows instead of the spec's specific question list).
  // No per-question answer screen exists yet (spec 57's Article & Glossary
  // screen was never built — see docs/redesign/PLAN.md), so every row opens
  // the general FAQ list (Routes.acctFaq) rather than a fake deep link.
  static const List<(String, String, String)> _rows = [
    ('chevronRight', "Why is my order still filling?", ''),
    ('chevronRight', 'When does money from a sale arrive?', ''),
    ('chevronRight', 'My verification was not approved', ''),
    ('chevronRight', 'Fees, in full', ''),
  ];

  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<(String, String, String)> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows
        .where((r) =>
            r.$2.toLowerCase().contains(q) || r.$3.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort external hand-off; no in-app surface to report failure
      // on (a chevron row, not a form) — matches legal_screen.dart's seam.
    }
  }

  // No per-question answer screen exists (spec 57 was never built) — every
  // FAQ row opens the general FAQ list instead of a fake per-question deep
  // link.
  void _onRowTap(String title) => context.push(Routes.acctFaq);

  void _emailUs() => _launch(Uri(scheme: 'mailto', path: _kSupportEmail));

  void _startChat() {
    // No live-chat infrastructure exists in this app (header comment: "no
    // in-app chat") — honest fallback rather than a fake chat window.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Live chat isn't available yet — email us instead.")),
    );
  }

  void _fileComplaint() {
    _launch(Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      query: 'subject=${Uri.encodeComponent('Complaint')}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return KAccountSubScaffold(
      title: 'Help & support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KSearchPill(
            placeholder: 'Search help',
            controller: _controller,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const KEmptyView(
              icon: 'search',
              title: 'No results',
              message: 'Try a different search term.',
            )
          else
            KAccountCard(
              children: [
                for (var i = 0; i < rows.length; i++)
                  KAccountRow(
                    icon: rows[i].$1,
                    title: rows[i].$2,
                    sub: rows[i].$3.isEmpty ? null : rows[i].$3,
                    right: const KRowChevron(),
                    first: i == 0,
                    onTap: () => _onRowTap(rows[i].$2),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          // "Talk to a person" card — screen-specs.md spec 56. Weekday hours
          // and fraud-desk phone are this business's real contact details
          // (see this file's header comment), NOT the mockup's placeholder
          // "0700 583 4626" — a security/fraud line must stay accurate to
          // reality, not copied verbatim from a design mockup.
          KAccountCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Talk to a person', style: KType.cardTitle()),
                    const SizedBox(height: 6),
                    Text(
                      'Weekdays 08:00 – 18:00, Lagos time. Fraud desk answers 24 hours.',
                      style: KType.body(color: KColor.ink2),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: KButton(
                          label: 'Email us',
                          variant: KButtonVariant.secondary,
                          onPressed: _emailUs,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KButton(
                          label: 'Start a chat',
                          variant: KButtonVariant.secondary,
                          onPressed: _startChat,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          KNudgeCard(
            tone: KNudgeTone.warm,
            title: 'Report fraud',
            body: 'If you think someone else is in your account, freeze it first — then call $_kSupportPhone.',
            action: KButton(
              label: 'Freeze my account',
              variant: KButtonVariant.destructive,
              onPressed: () => context.push(Routes.acctFreeze),
            ),
          ),
          const SizedBox(height: 24),
          KButton(
            label: 'File a complaint',
            variant: KButtonVariant.secondary,
            onPressed: _fileComplaint,
          ),
        ],
      ),
    );
  }
}
