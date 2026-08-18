// Shared scaffold for the four onboarding legal-acceptance screens: terms
// of service, privacy policy, risk disclosure, client agreement. Fetches
// the CURRENT document for a given `kind` from the backend
// (GET /legal-documents/content/:kind) and renders its sections — content
// is no longer hardcoded per screen, so an update to any of these four
// documents never requires a mobile release. Tapping the primary button
// posts the acknowledgement (POST /compliance-acknowledgements {kind}; the
// backend resolves and stamps the current version/document id itself) and
// then runs whatever the specific screen needs to happen next.
//
// The four concrete screens (risk_disclosure_screen.dart,
// client_agreement_screen.dart, privacy_policy_screen.dart,
// terms_of_service_screen.dart) are thin wrappers supplying kind/copy/
// navigation — kept separate from this shared widget because each one's
// post-accept behavior genuinely differs (three are a plain "go to the next
// step"; the last, client agreement, also completes suitability and signs
// the investor in) — folding that into a callback parameter here is the
// actual shared shape, not an excuse to merge four screens that don't
// otherwise differ. Not one continuous chain: terms of service -> privacy
// policy run right after OTP verification (account-creation consent);
// risk disclosure -> client agreement run right after the suitability
// result (investment-specific documents) — see terms_of_service_screen.dart.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/data/repositories/compliance_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({
    super.key,
    required this.kind,
    required this.screenTitle,
    required this.checkboxLabel,
    required this.buttonLabel,
    required this.onAccepted,
  });

  /// 'terms_of_service' | 'privacy_policy' | 'risk_disclosure' | 'client_agreement'.
  final String kind;
  final String screenTitle;
  final String checkboxLabel;
  final String buttonLabel;

  /// Runs after the acknowledgement is successfully persisted — the
  /// specific screen's own next-step navigation (and, for the last screen
  /// in the chain, completing onboarding).
  final Future<void> Function(BuildContext context) onAccepted;

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  late final _legalRepo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late final _complianceRepo = ComplianceRepository(AppScope.read(context).apiClient);
  late Future<LegalDocument> _future = _legalRepo.getContent(widget.kind);

  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _complianceRepo.acknowledge(kind: widget.kind);
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
                child: FutureBuilder<LegalDocument>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const KLoadingView();
                    }
                    if (snapshot.hasError) {
                      return KErrorView(
                        onPrimary: () =>
                            setState(() => _future = _legalRepo.getContent(widget.kind)),
                      );
                    }
                    final doc = snapshot.data!;
                    // Checkbox + accept button only render once the content
                    // has actually loaded — agreeing to something you never
                    // saw isn't a real acceptance.
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
                                  for (var i = 0; i < doc.sections.length; i++) ...[
                                    if (i != 0) const SizedBox(height: 22),
                                    KEyebrow(doc.sections[i].heading),
                                    const SizedBox(height: 8),
                                    Text(doc.sections[i].body,
                                        style: KType.body(color: KColor.ink2)),
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
                              const SizedBox(height: 12),
                              Center(
                                child: Text(doc.sub,
                                    style: KType.micro(color: KColor.ink3).tnum),
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
}
