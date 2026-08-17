// Suitability — risk disclosure. Scrollable plain-language legal copy inside a
// hairline card, a KCheckbox acknowledgement, then a primary Agree button that
// unlocks once acknowledged. Ported from risk-screens.jsx (RiskDisclosure).
//
// Tapping "Agree" persists the acknowledgement server-side (POST
// /compliance-acknowledgements) via ComplianceRepository before navigating on
// — see STUB-risk-disclosure-1 in
// Kudimata-Securities-Backend/.pipeline/fragments/risk-disclosure.json, which
// flagged the previous pure-navigation tap as having no durable record of
// consent. `_documentVersion` is a simple hardcoded label (this screen's copy
// carries no version marker of its own to match) identifying which revision
// of the _sections legal copy below the user agreed to.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/compliance_repository.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/router/routes.dart';

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
  bool _submitting = false;

  /// Document version this screen's static legal copy (_sections below)
  /// corresponds to — sent alongside the acknowledgement so a future revision
  /// of this copy can be told apart from what the user actually agreed to.
  /// No version label is shown in this screen's UI to match, so this is a
  /// simple hardcoded starting label.
  static const _documentVersion = 'v1';

  static const List<_Section> _sections = [
    _Section('What this is',
        'This is a plain-language summary of the risks of investing through '
            'Kudimata Invest. It does not replace the full terms.'),
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

  Future<void> _agree() async {
    setState(() => _submitting = true);
    final repo = ComplianceRepository(AppScope.read(context).apiClient);
    try {
      await repo.acknowledge(kind: 'risk_disclosure', documentVersion: _documentVersion);
      if (!mounted) return;
      context.go(Routes.clientAgreement);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

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
                decoration: BoxDecoration(
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
                      loading: _submitting,
                      onPressed: _agreed && !_submitting ? _agree : null,
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
