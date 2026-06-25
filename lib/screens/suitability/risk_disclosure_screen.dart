// Suitability — risk disclosure. Scrollable plain-language legal copy inside a
// hairline card, a KCheckbox acknowledgement, then a primary Agree button that
// unlocks once acknowledged. Ported from risk-screens.jsx (RiskDisclosure).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_securities/widgets/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/router/routes.dart';

/// One eyebrow-led legal section.
class _Section {
  const _Section(this.eyebrow, this.body);
  final String eyebrow;
  final String body;
}

class RiskDisclosureScreen extends StatefulWidget {
  const RiskDisclosureScreen({super.key});

  @override
  State<RiskDisclosureScreen> createState() => _RiskDisclosureScreenState();
}

class _RiskDisclosureScreenState extends State<RiskDisclosureScreen> {
  bool _agreed = false;

  static const List<_Section> _sections = [
    _Section('What this is',
        'This is a plain-language summary of the risks of investing through '
            'Kudimata Securities. It does not replace the full terms.'),
    _Section('The risks',
        'The value of investments can fall as well as rise. You may get back '
            'less than you put in. Past performance does not predict future '
            'returns. Prices can move quickly and markets can close.'),
    _Section('Your responsibilities',
        'You decide which investments to buy and sell. You confirm the '
            'information you gave us is true. You keep your passcode and device '
            'secure.'),
    _Section('Fees',
        'Fees are shown before you confirm any order. Some products carry '
            'charges from third parties. Currency conversion may apply to US '
            'assets.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KScreenHead(title: 'Risk disclosure'),
              const SizedBox(height: 16),
              // Scrollable legal copy in a hairline card.
              Expanded(
                child: KCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < _sections.length; i++) ...[
                          if (i != 0) const SizedBox(height: 22),
                          KEyebrow(_sections[i].eyebrow),
                          const SizedBox(height: 8),
                          Text(_sections[i].body, style: KType.body(color: KColor.ink2)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Acknowledgement + primary action.
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KCheckbox(
                      checked: _agreed,
                      onChanged: (v) => setState(() => _agreed = v),
                      label: 'I have read and understood the risks',
                    ),
                    const SizedBox(height: 16),
                    KButton(
                      label: 'Agree',
                      onPressed: _agreed
                          ? () => context.go(Routes.clientAgreement)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
