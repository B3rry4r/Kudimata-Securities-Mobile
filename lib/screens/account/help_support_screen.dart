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
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

// PLACEHOLDER contact details — no backend resource exists for this
// screen's content (see header note), so these are static, hand-set
// values. Replace with the real support desk's address/number/URL before
// release.
const _kSupportEmail = 'support@kudimatasecurities.com';
const _kSupportPhone = '+2348000000000'; // placeholder Nigerian E.164 number
const _kHelpCenterUrl = 'https://kudimatasecurities.com/help';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // (icon, title, sub). Icons map to the fixed KIcon set.
  static const List<(String, String, String)> _rows = [
    ('search', 'Browse FAQs', 'Funding, orders, withdrawals'),
    ('send', 'Message support', 'Replies within a few hours'),
    ('bell', 'Report a problem', 'Something not working?'),
    ('profile', 'Call us', 'Mon–Fri, 8am–6pm'),
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

  // Each row is matched by title, not list index, since `_filtered` can
  // reorder/drop rows under search.
  void _onRowTap(String title) {
    switch (title) {
      case 'Browse FAQs':
        _launch(Uri.parse(_kHelpCenterUrl));
        break;
      case 'Message support':
        _launch(Uri(scheme: 'mailto', path: _kSupportEmail));
        break;
      case 'Report a problem':
        // SEAM: no dedicated bug-report channel exists (no ticketing API,
        // no in-app chat) — intentionally left as a no-op rather than
        // fabricating one. Wire this up once a target exists.
        break;
      case 'Call us':
        _launch(Uri(scheme: 'tel', path: _kSupportPhone));
        break;
    }
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
                    sub: rows[i].$3,
                    right: const KRowChevron(),
                    first: i == 0,
                    onTap: () => _onRowTap(rows[i].$2),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
