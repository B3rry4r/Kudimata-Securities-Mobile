// Shared scaffold for the onboarding legal-acceptance screens. Each screen
// in this app's flow covers a GROUP of documents with ONE checkbox and ONE
// accept action (2026-08-20 consolidation — every one of the four legal
// documents used to be its own screen with its own tick, requiring 4
// separate taps total; user directive: "the terms of service and privacy
// policy... why should not be two ticks... users should read through all
// and click one agree checkbox that covers it all").
//
// Widened from a fixed two-document pairing to an arbitrary-length `kinds`
// list the same day (further user directive: "the privacy policy, terms
// of service and risk disclosure... stack them in one screen so user just
// scrolls down and accept one time not moving between screens" — Client
// Agreement wasn't named that time, so it briefly stood alone on its own
// screen, then joined the rest on a follow-up directive the same day:
// "move client agreement to the beginning, let users accept it all in the
// terms and disclosures"). All four documents now go through this ONE
// widget, in ONE screen (terms_and_privacy_screen.dart) — there is no
// longer a second legal-acceptance screen anywhere in onboarding.
//
// Fetches every document (GET /legal-documents/content/:kind, called once
// per kind, all concurrently via `.wait`) and renders them in one
// scrollable view with a divider between each — content is still
// backend-driven, not hardcoded, same as before. Tapping the primary button
// posts one acknowledgement per kind IN ORDER (POST
// /compliance-acknowledgements — there is no combined-kind endpoint, and
// none is needed); if any one of them fails, the ones after it never fire
// (never record "agreed to X" without also recording "agreed to" everything
// the investor was shown before it).
import 'package:flutter/material.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/data/repositories/compliance_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/screens/onboarding/document_summary_screen.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:go_router/go_router.dart';

/// Static placeholder summaries (2026-08-22 "Soft Landing", screen 06) — no
/// backend endpoint generates a real per-document plain-English summary yet
/// (see docs/redesign/PLAN.md). The risk_disclosure copy is the design
/// system's own example; the rest are reasonable placeholders in the same
/// voice, clearly not real generated content until that backend exists.
const Map<String, String> _kPlainEnglishSummary = {
  'risk_disclosure':
      'Trading shares can lose you money, and Kudimata cannot promise any return. You are the one deciding what to buy.',
  'terms_of_service':
      "This is the agreement between you and Kudimata Securities Ltd for using the app — what we do, what you're responsible for, and how either of us can end it.",
  'privacy_policy':
      'What information we collect about you, why we collect it, and who we share it with — mainly your regulators and the people who help us verify your identity.',
  'client_agreement':
      'The formal terms of your relationship with Kudimata as your broker — how your orders are handled, how your money and shares are held, and what happens if something goes wrong.',
};

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({
    super.key,
    required this.kinds,
    required this.screenTitle,
    this.screenBody,
    required this.checkboxLabel,
    this.checkboxDescription,
    required this.buttonLabel,
    required this.onAccepted,
  }) : assert(kinds.length > 0, 'LegalAcceptanceScreen needs at least one document kind');

  /// One or more of 'terms_of_service' | 'privacy_policy' | 'risk_disclosure'
  /// | 'client_agreement', in the order they should be read/acknowledged.
  final List<String> kinds;
  final String screenTitle;
  final String? screenBody;
  final String checkboxLabel;
  final String? checkboxDescription;
  final String buttonLabel;

  /// Runs after EVERY kind's acknowledgement is successfully persisted, in
  /// `kinds` order — the specific screen's own next-step navigation (and,
  /// for the last one in onboarding, completing it).
  final Future<void> Function(BuildContext context) onAccepted;

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  late final _legalRepo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late final _complianceRepo = ComplianceRepository(AppScope.read(context).apiClient);
  late Future<List<LegalDocument>> _future = _load();

  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  Future<List<LegalDocument>> _load() async {
    // Independent GETs, fetched concurrently rather than sequentially so a
    // slow document doesn't delay the rest.
    return Future.wait(widget.kinds.map(_legalRepo.getContent));
  }

  Future<void> _accept() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Sequential, not parallel — if an earlier acknowledgement fails, the
      // later ones must not fire.
      for (final kind in widget.kinds) {
        await _complianceRepo.acknowledge(kind: kind);
      }
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
              KScreenHead(title: widget.screenTitle, body: widget.screenBody),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<LegalDocument>>(
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
                    final docs = snapshot.data!;
                    // Checkbox + accept button only render once EVERY
                    // document has actually loaded — agreeing to something
                    // you never saw isn't a real acceptance.
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
                                  for (var i = 0; i < docs.length; i++) ...[
                                    if (i != 0) ...[
                                      const SizedBox(height: 28),
                                      Container(height: 1, color: KColor.hairline),
                                      const SizedBox(height: 28),
                                    ],
                                    ..._buildDocument(docs[i]),
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
                              // 2026-08-22 "Soft Landing" — screen-specs.md
                              // screen 05: grape-toned (not warm) NudgeCard
                              // for the "you can lose money" risk warning.
                              const KNudgeCard(
                                tone: KNudgeTone.grape,
                                body:
                                    "Share prices fall as well as rise. Only invest money you won't need for the next few years.",
                              ),
                              const SizedBox(height: 14),
                              if (_error != null) ...[
                                Text(_error!, style: KType.body(color: KColor.loss)),
                                const SizedBox(height: 12),
                              ],
                              KCheckbox(
                                checked: _agreed,
                                onChanged: (v) => setState(() => _agreed = v),
                                label: widget.checkboxLabel,
                                description: widget.checkboxDescription,
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
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KEyebrow(doc.title),
                const SizedBox(height: 4),
                Text(doc.sub, style: KType.micro(color: KColor.ink3).tnum),
              ],
            ),
          ),
          KExplainTrigger(
            label: 'Plain English',
            variant: KExplainTriggerVariant.inline,
            onTap: () => context.push(
              Routes.documentSummary,
              extra: DocumentSummaryArgs(
                docTitle: doc.title,
                summary: _kPlainEnglishSummary[doc.kind] ??
                    'A generated plain-English summary of this document.',
                original: doc.sections.map((s) => '${s.heading}\n${s.body}').join('\n\n'),
              ),
            ),
          ),
        ],
      ),
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
