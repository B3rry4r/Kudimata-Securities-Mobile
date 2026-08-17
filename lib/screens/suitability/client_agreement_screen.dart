// Suitability — client agreement. Scrollable terms, a KCheckbox, a primary
// "Accept and continue" button, and a version footer. Accepting posts a
// ComplianceAcknowledgement (kind: 'client_agreement') to the broker
// compliance API, then — only once that succeeds — completes suitability
// and signs the user in, then routes to the home tab. This is the final
// gated onboarding step, so those AppState flags must never flip on a
// failed acknowledgement.
// Ported from risk-screens.jsx (ClientAgreement).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/compliance_repository.dart';

/// One numbered, eyebrow-led clause.
class _Clause {
  const _Clause(this.eyebrow, this.body);
  final String eyebrow;
  final String body;
}

class ClientAgreementScreen extends StatefulWidget {
  const ClientAgreementScreen({super.key});

  @override
  State<ClientAgreementScreen> createState() => _ClientAgreementScreenState();
}

class _ClientAgreementScreenState extends State<ClientAgreementScreen> {
  bool _agreed = false;
  bool _submitting = false;

  late final _repo = ComplianceRepository(AppScope.read(context).apiClient);

  /// Matches the "Version 1.0 · 25 June 2026" footer below — the
  /// documentVersion sent with the acknowledgement.
  static const _documentVersion = '1.0';

  static const List<_Clause> _clauses = [
    _Clause('1 · About this agreement',
        'This agreement sets out the terms between you and Kudimata '
            'Invest. By accepting, you enter into a binding contract.'),
    _Clause('2 · Your account',
        'Your account is personal to you. You may not let anyone else use it. '
            'You must give us accurate information and keep it up to date.'),
    _Clause('3 · Orders and settlement',
        'We pass your orders to our execution partners. Orders are subject to '
            'market hours and available liquidity, and may be partly filled.'),
    _Clause('4 · Fees and charges',
        'Applicable fees are disclosed before you confirm an order. We will '
            'tell you in advance if our fees change.'),
    _Clause('5 · Closing your account',
        'You can close your account at any time once open positions are '
            'settled. We may close an account where required by law or '
            'regulation.'),
  ];

  Future<void> _accept() async {
    setState(() => _submitting = true);
    try {
      await _repo.acknowledge(
        kind: 'client_agreement',
        documentVersion: _documentVersion,
      );
      if (!mounted) return;
      final app = AppScope.read(context);
      app.setSuitabilityComplete(true);
      app.setSignedIn(true);
      context.go(Routes.home);
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
              const KScreenHead(title: 'Client agreement'),
              const SizedBox(height: 16),
              Expanded(
                child: KCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < _clauses.length; i++) ...[
                          if (i != 0) const SizedBox(height: 22),
                          KEyebrow(_clauses[i].eyebrow),
                          const SizedBox(height: 8),
                          Text(_clauses[i].body, style: KType.body(color: KColor.ink2)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KCheckbox(
                      checked: _agreed,
                      onChanged: (v) => setState(() => _agreed = v),
                      label: 'I agree to the Client Agreement',
                    ),
                    const SizedBox(height: 14),
                    KButton(
                      label: 'Accept and continue',
                      loading: _submitting,
                      onPressed: _agreed && !_submitting ? _accept : null,
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text('Version 1.0 · 25 June 2026',
                          style: KType.micro(color: KColor.ink3).tnum),
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
