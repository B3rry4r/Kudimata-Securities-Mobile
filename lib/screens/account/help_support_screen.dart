// Stage 9 — Help & support (pushed). Search pill + FAQ/contact rows. Mirrors
// `HelpSupport` in extra-screens.jsx.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // (icon, title, sub). Icons map to the fixed KIcon set.
  static const List<(String, String, String)> _rows = [
    ('search', 'Browse FAQs', 'Funding, orders, withdrawals'),
    ('send', 'Message support', 'Replies within a few hours'),
    ('bell', 'Report a problem', 'Something not working?'),
    ('profile', 'Call us', 'Mon–Fri, 8am–6pm'),
  ];

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Help & support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEAM: help-center search plugs in here.
          const KSearchPill(placeholder: 'Search help', readOnly: true),
          const SizedBox(height: 18),
          KAccountCard(
            children: [
              for (var i = 0; i < _rows.length; i++)
                KAccountRow(
                  icon: _rows[i].$1,
                  title: _rows[i].$2,
                  sub: _rows[i].$3,
                  right: const KRowChevron(),
                  first: i == 0,
                  // SEAM: each contact channel (chat/email/phone) plugs in here.
                  onTap: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}
