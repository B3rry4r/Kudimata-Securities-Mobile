// Stage 9 — Statements & documents (pushed). Monthly statements + contract
// notes, each a file row with a download control. Mirrors `Statements` in
// settings-screens.jsx.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class StatementsScreen extends StatelessWidget {
  const StatementsScreen({super.key});

  static const List<(String title, String sub)> _statements = [
    ('May 2026 statement', 'PDF · 240 KB'),
    ('April 2026 statement', 'PDF · 240 KB'),
    ('March 2026 statement', 'PDF · 240 KB'),
  ];

  // Scope is NGX / US / ETF only — no fixed income contract notes.
  static const List<(String title, String sub)> _notes = [
    ('Contract note · MTNN', '25 Jun 2026 · Buy'),
    ('Contract note · AAPL', '18 Jun 2026 · Buy'),
    ('Contract note · DANGCEM', '20 May 2026 · Sell'),
  ];

  Widget _download() => KIconButton(
        icon: 'arrowDown',
        semanticLabel: 'Download',
        // SEAM: real file download/share plugs in here.
        onPressed: () {},
      );

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Statements & documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KEyebrow('Monthly statements'),
          const SizedBox(height: 10),
          KAccountCard(
            children: [
              for (var i = 0; i < _statements.length; i++)
                KAccountRow(
                  icon: 'card',
                  title: _statements[i].$1,
                  sub: _statements[i].$2,
                  right: _download(),
                  first: i == 0,
                ),
            ],
          ),
          const SizedBox(height: 24),
          const KEyebrow('Contract notes'),
          const SizedBox(height: 10),
          KAccountCard(
            children: [
              for (var i = 0; i < _notes.length; i++)
                KAccountRow(
                  icon: 'card',
                  title: _notes[i].$1,
                  sub: _notes[i].$2,
                  right: _download(),
                  first: i == 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
