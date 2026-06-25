// Stage 9 — Legal (pushed). Document rows (version + date). Mirrors `Legal` in
// settings-screens.jsx. No fixed income — these are the trading/risk/privacy docs only.
import 'package:flutter/material.dart';
import 'account_widgets.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const List<(String title, String sub)> _docs = [
    ('Risk Disclosure', 'Version 1.0 · 25 Jun 2026'),
    ('Client Agreement', 'Version 1.0 · 25 Jun 2026'),
    ('Privacy policy (NDPA)', 'Version 1.2 · 14 May 2026'),
  ];

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Legal',
      child: KAccountCard(
        children: [
          for (var i = 0; i < _docs.length; i++)
            KAccountRow(
              icon: 'card',
              title: _docs[i].$1,
              sub: _docs[i].$2,
              right: const KRowChevron(),
              first: i == 0,
              // SEAM: open the bundled legal document plugs in here.
              onTap: () {},
            ),
        ],
      ),
    );
  }
}
