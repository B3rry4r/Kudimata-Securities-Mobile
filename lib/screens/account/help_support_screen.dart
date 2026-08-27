// Account → Help & support — no artboard. RULINGS.md (docs/redesign/
// evidence/account.json): searched the whole 56-artboard canvas for "help" +
// "support" together, "contact us" and "live chat" — no dedicated hub
// artboard anywhere (s51 links straight to Complaints and Terms; s53
// Complaints is the closest neighbour but is entirely about complaint
// categories/status, not FAQs or a contact card). Ruling: `restyle-only` —
// basic customer-service infrastructure, not an obviously cut feature, kept
// and brought onto the new design system's tokens.
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
import 'faq_screen.dart' show kSettlementArticleQuestion;

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
  // R-5: an earlier pass sourced these 4 headlines and their no-leading-icon
  // row treatment from an older, pre-redesign spec doc's "screen 56"/"screen
  // 57" — ids from a superseded artifact, not the current 56-artboard
  // canvas (which, per this file's header, draws no Help & support artboard
  // at all). Kept here purely as real, specific customer-question copy —
  // NOT as a claim of current-canvas backing. See faq_screen.dart's header
  // for how these rows reach the real "Settlement" article vs. the general
  // FAQ list fallback. Rows carry no leading icon, just title text and a
  // trailing chevron — the first tuple field used to be fed straight into
  // KAccountRow's LEADING icon slot as the literal string 'chevronRight',
  // which rendered a stray chevron glyph on the left of every row in
  // addition to the real trailing KRowChevron on the right; a visual bug,
  // not a design choice, so that field was dropped.
  static const List<(String, String)> _rows = [
    ("Why is my order still filling?", ''),
    (kSettlementArticleQuestion, ''),
    ('My verification was not approved', ''),
    ('Fees, in full', ''),
  ];

  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<(String, String)> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows
        .where((r) => r.$1.toLowerCase().contains(q) || r.$2.toLowerCase().contains(q))
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

  // Every row pushes the one FAQ route (Routes.acctFaq), passing the tapped
  // question as `extra`. FaqScreen renders the real, grounded "Settlement"
  // article when it recognises the question ("When does money from a sale
  // arrive?"); every other question falls back to the general FAQ list
  // there, since there's no per-question route to deep-link into and no
  // other real article content written yet.
  void _onRowTap(String question) => context.push(Routes.acctFaq, extra: question);

  void _emailUs() => _launch(Uri(scheme: 'mailto', path: _kSupportEmail));

  // A real Complaints hub (s53, complaint_screen.dart) exists, so this no
  // longer bounces straight out to a bare mailto: link.
  void _fileComplaint() {
    context.push(Routes.acctComplaint);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return KAccountSubScaffold(
      title: 'Help & support',
      // "File a complaint" is pinned to the bottom of the screen, not as
      // the last item in the scrolling list.
      footer: KButton(
        label: 'File a complaint',
        variant: KButtonVariant.secondary,
        onPressed: _fileComplaint,
      ),
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
                    title: rows[i].$1,
                    sub: rows[i].$2.isEmpty ? null : rows[i].$2,
                    right: const KRowChevron(),
                    first: i == 0,
                    onTap: () => _onRowTap(rows[i].$1),
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
                    // 2026-08-24: dropped "Start a chat" (direct product
                    // instruction) — no live-chat infrastructure exists in
                    // this app (see _startChat's old doc comment, removed
                    // alongside it); the button only ever showed a "not
                    // available yet" snackbar, which isn't a real feature to
                    // offer. "Email us" is real (a plain mailto: link) and
                    // is now the sole action here.
                    KButton(
                      label: 'Email us',
                      iconLeft: 'mail',
                      onPressed: _emailUs,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // "Report fraud" carries no action button of its own — freezing
          // the account is a separate, real entry point on the Security
          // screen (Routes.acctFreeze) that this card doesn't duplicate.
          KNudgeCard(
            tone: KNudgeTone.warm,
            title: 'Report fraud',
            body: 'If you think someone else is in your account, freeze it first — then call $_kSupportPhone.',
          ),
        ],
      ),
    );
  }
}
