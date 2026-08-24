// Statutory Risk Disclaimer (Rule 76 compliance) — NEW screen, 2026-08-24.
// Sourced from the firm's real SEC-facing compliance intake ("My
// observations on KSL papers.docx"): must appear immediately after the
// suitability questionnaire, show the investor's own just-computed risk
// category, require scrolling to the bottom of the disclosure text before
// "Accept & Proceed" enables, and record a real acknowledgement.
//
// The disclosure TEXT ITSELF (Risk of Capital Loss / Digital Platform
// Infrastructure Risks / No Investment Advice / Regulatory Jurisdiction
// sections) is deliberately NOT rewritten here — direct product
// instruction: "leave risk disclaimer content for legal team, they would
// do it". This screen renders whatever LegalDocument content already
// exists for kind='risk_disclosure' (GET /legal-documents/content/
// risk_disclosure) verbatim; only the STRUCTURE around it (scroll gating,
// the dynamic risk-category callout, the button label, the NDPA-naming
// checkbox) is this pass's responsibility.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/compliance_repository.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/onboarding/onboarding_scaffold.dart'
    show KOnboardTopBar;
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Route `extra` — the profile just computed by suitability_result_screen.dart,
/// carried forward so this screen's dynamic callout doesn't need a second
/// GET /suitability-result/me round-trip for that entry path. Optional:
/// AppState.tradingEligibilityGap's own prompt (home_screen.dart) pushes
/// this route with no `extra` at all when a RETURNING investor is re-gated
/// here directly (suitability already complete from a past session, just
/// never accepted this disclaimer) — that path fetches the real profile
/// itself instead.
class RiskDisclaimerArgs {
  const RiskDisclaimerArgs({required this.profile});
  final String profile;
}

class RiskDisclaimerScreen extends StatefulWidget {
  const RiskDisclaimerScreen({super.key, this.profile});
  final String? profile;

  @override
  State<RiskDisclaimerScreen> createState() => _RiskDisclaimerScreenState();
}

class _RiskDisclaimerScreenState extends State<RiskDisclaimerScreen> {
  late final _legalRepo = LegalDocumentsRepository(
    AppScope.read(context).apiClient,
  );
  late final _complianceRepo = ComplianceRepository(
    AppScope.read(context).apiClient,
  );
  late Future<LegalDocument> _future = _load();

  /// Only the document now — the investor's computed profile was displayed
  /// here until 2026-08-24 (see the removed callout below) and is no longer
  /// read by this screen. `widget.profile` and RiskDisclaimerArgs are kept
  /// so the caller and route contract are unchanged if it is restored.
  Future<LegalDocument> _load() => _legalRepo.getContent('risk_disclosure');

  final _scrollController = ScrollController();
  bool _scrolledToBottom = false;
  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrolledToBottom) return;
    final position = _scrollController.position;
    // 24px tolerance — a real device's last frame of momentum scrolling
    // rarely lands on the exact maxScrollExtent pixel.
    if (position.pixels >= position.maxScrollExtent - 24) {
      setState(() => _scrolledToBottom = true);
    }
  }

  /// Runs once the document has laid out — a short document (or a tall
  /// device) may never produce a scrollable overflow at all, in which case
  /// there's nothing to scroll TO and the gate must not stay permanently
  /// unmet.
  void _checkAlreadyAtBottom() {
    if (_scrolledToBottom || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 0) {
      setState(() => _scrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _complianceRepo.acknowledge(kind: 'risk_disclosure');
      if (!mounted) return;
      final app = AppScope.read(context);
      app.setRiskDisclosureAccepted(true);
      // Idempotent — suitability_result_screen.dart already set this when
      // it computed the profile this screen is displaying; harmless if
      // already true (e.g. a returning investor re-gated after this
      // screen shipped, who reaches here with suitabilityComplete already
      // set from a much earlier session).
      app.setSuitabilityComplete(true);
      if (!app.signedIn) app.setSignedIn(true);
      context.go(Routes.home);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: KOnboardTopBar(
                stepLabel: 'Risk disclosure',
                showBackIcon: false,
              ),
            ),
            Expanded(
              child: FutureBuilder<LegalDocument>(
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
                  final doc = snapshot.data!;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _checkAlreadyAtBottom(),
                  );
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const KScreenHead(
                          title: 'Important regulatory & risk notice',
                          body:
                              'Please read this disclosure carefully before activating your account.',
                        ),
                        const SizedBox(height: 16),
                        // 2026-08-24, direct instruction: "There is still an
                        // investor profile on the risk legal doc view on kyc
                        // please remove that container". The removed block
                        // was the SEC intake document's own dynamic
                        // "Suitability Acknowledgement" field — "you have
                        // been categorized as a [Conservative / Moderate /
                        // Aggressive] investor. Investing in assets outside
                        // of your designated risk profile can lead to severe
                        // financial distress."
                        //
                        // FLAGGED, NOT SILENTLY DROPPED: that field is the
                        // one element the compliance doc explicitly requires
                        // ON THIS SCREEN. The profile is still computed and
                        // persisted (SuitabilityResult), so restoring the
                        // callout is re-adding this block — but as it stands
                        // the app no longer shows the investor their
                        // categorisation anywhere, which compliance should
                        // sign off before go-live.
                        const SizedBox(height: 20),
                        for (final section in doc.sections) ...[
                          Text(section.heading, style: KType.cardTitle()),
                          const SizedBox(height: 6),
                          Text(
                            section.body,
                            style: KType.body(color: KColor.ink2),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (_error != null) ...[
                          Text(_error!, style: KType.body(color: KColor.loss)),
                          const SizedBox(height: 12),
                        ],
                        KCheckbox(
                          checked: _agreed,
                          disabled: !_scrolledToBottom,
                          onChanged: (v) => setState(() => _agreed = v),
                          label:
                              'I confirm that I have read, understood, and voluntarily accept the Risk Disclaimer and the Privacy Terms in alignment with the Nigeria Data Protection Act (NDPA).',
                        ),
                        if (!_scrolledToBottom) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Scroll to the end to continue.',
                            style: KType.micro(color: KColor.ink3),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: KButton(
                label: 'Accept & Proceed',
                loading: _submitting,
                onPressed: _scrolledToBottom && _agreed && !_submitting
                    ? _accept
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
