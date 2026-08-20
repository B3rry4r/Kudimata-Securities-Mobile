// Shared scaffold for the two onboarding legal-acceptance screens: terms of
// service + privacy policy (account creation), and risk disclosure + client
// agreement (post-suitability). Each screen in this app's flow now covers
// a PAIR of documents with ONE checkbox and ONE accept action — previously
// each of the four documents was its own screen with its own tick,
// requiring 4 separate taps total (2026-08-20, user directive: "the terms
// of service and privacy policy... why should not be two ticks... users
// should read through all and click one agree checkbox that covers it
// all" — same complaint, same fix, for risk disclosure + client
// agreement).
//
// Fetches BOTH documents (GET /legal-documents/content/:kind, called once
// per kind) and renders them in one scrollable view with a divider between
// them — content is still backend-driven, not hardcoded, same as before.
// Tapping the primary button posts BOTH acknowledgements in sequence
// (POST /compliance-acknowledgements — one call per kind; there is no
// combined-kind endpoint, and none is needed) and then runs whatever the
// specific pairing needs to happen next.
//
// The two concrete screens (terms_and_privacy_screen.dart,
// risk_and_agreement_screen.dart) are thin wrappers supplying the two
// kinds/copy/navigation — kept separate from this shared widget since each
// pairing's post-accept behavior genuinely differs (terms+privacy just
// continues to passcode creation; risk+agreement also completes
// suitability and signs the investor in).
import 'package:flutter/material.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/data/repositories/compliance_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';

class DualLegalAcceptanceScreen extends StatefulWidget {
  const DualLegalAcceptanceScreen({
    super.key,
    required this.firstKind,
    required this.secondKind,
    required this.screenTitle,
    required this.checkboxLabel,
    required this.buttonLabel,
    required this.onAccepted,
  });

  /// 'terms_of_service' | 'privacy_policy' | 'risk_disclosure' | 'client_agreement'.
  final String firstKind;
  final String secondKind;
  final String screenTitle;
  final String checkboxLabel;
  final String buttonLabel;

  /// Runs after BOTH acknowledgements are successfully persisted (in order:
  /// firstKind, then secondKind) — the specific pairing's own next-step
  /// navigation (and, for the last pairing in onboarding, completing it).
  final Future<void> Function(BuildContext context) onAccepted;

  @override
  State<DualLegalAcceptanceScreen> createState() => _DualLegalAcceptanceScreenState();
}

class _DualLegalAcceptanceScreenState extends State<DualLegalAcceptanceScreen> {
  late final _legalRepo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late final _complianceRepo = ComplianceRepository(AppScope.read(context).apiClient);
  late Future<(LegalDocument, LegalDocument)> _future = _load();

  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  Future<(LegalDocument, LegalDocument)> _load() async {
    // Both documents are independent GETs — fetched concurrently (`.wait`,
    // matching this app's usual two-future-one-screen convention) rather
    // than sequentially, so a slow first document doesn't delay the second.
    final (first, second) = await (
      _legalRepo.getContent(widget.firstKind),
      _legalRepo.getContent(widget.secondKind),
    ).wait;
    return (first, second);
  }

  Future<void> _accept() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Sequential, not parallel — if the first acknowledgement fails, the
      // second must not fire (never record "agreed to the client
      // agreement" without also recording "agreed to risk disclosure").
      await _complianceRepo.acknowledge(kind: widget.firstKind);
      await _complianceRepo.acknowledge(kind: widget.secondKind);
      if (!mounted) return;
      await widget.onAccepted(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
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
              KScreenHead(title: widget.screenTitle),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<(LegalDocument, LegalDocument)>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const KLoadingView();
                    }
                    if (snapshot.hasError) {
                      return KErrorView(
                        onPrimary: () => setState(() => _future = _load()),
                      );
                    }
                    final (first, second) = snapshot.data!;
                    // Checkbox + accept button only render once BOTH
                    // documents have actually loaded — agreeing to
                    // something you never saw isn't a real acceptance.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: KCard(
                            padding: EdgeInsets.zero,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ..._buildDocument(first),
                                  const SizedBox(height: 28),
                                  Container(height: 1, color: KColor.hairline),
                                  const SizedBox(height: 28),
                                  ..._buildDocument(second),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_error != null) ...[
                                Text(_error!, style: KType.body(color: KColor.loss)),
                                const SizedBox(height: 12),
                              ],
                              KCheckbox(
                                checked: _agreed,
                                onChanged: (v) => setState(() => _agreed = v),
                                label: widget.checkboxLabel,
                              ),
                              const SizedBox(height: 14),
                              KButton(
                                label: widget.buttonLabel,
                                loading: _submitting,
                                onPressed: _agreed && !_submitting ? _accept : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDocument(LegalDocument doc) {
    return [
      KEyebrow(doc.title),
      const SizedBox(height: 4),
      Text(doc.sub, style: KType.micro(color: KColor.ink3).tnum),
      const SizedBox(height: 14),
      for (var i = 0; i < doc.sections.length; i++) ...[
        if (i != 0) const SizedBox(height: 22),
        KEyebrow(doc.sections[i].heading),
        const SizedBox(height: 8),
        Text(doc.sections[i].body, style: KType.body(color: KColor.ink2)),
      ],
    ];
  }
}
