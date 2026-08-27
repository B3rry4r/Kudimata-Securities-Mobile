// Statutory Risk Disclaimer (Rule 76 compliance) — its OWN scroll-gated,
// in-app screen. R-8a (DECISIONS.md, 2026-08-27) is the current ruling: it
// resolves a three-way conflict between R-1a (suitability before the legal
// documents), R-8 (risk disclosure bundled with the other three, phone
// viewer) and the firm's real SEC-facing compliance intake ("My
// observations on KSL papers.docx", "the disclaimer must appear
// immediately after suitability", scroll-gated in-app).
//
// Resolution: this screen runs right after suitability_result_screen.dart,
// BEFORE the other three legal documents (terms of service, privacy
// policy, client agreement — still opened in the phone's native viewer via
// terms_and_privacy_screen.dart/legal_acceptance_screen.dart). It keeps
// in-app rendering + a scroll-to-bottom gate because that's the only
// mechanism that produces real evidence the investor was shown the text —
// with BR-6 live (files never actually uploaded, presigning succeeds, the
// viewer 404s) the phone-viewer pattern would record acceptance for a
// document nobody could read.
//
// The disclosure TEXT ITSELF (Risk of Capital Loss / Digital Platform
// Infrastructure Risks / No Investment Advice / Regulatory Jurisdiction
// sections) is deliberately NOT authored here — direct product
// instruction: "leave risk disclaimer content for legal team, they would
// do it". This screen renders whatever LegalDocument content already
// exists for kind='risk_disclosure' (GET /legal-documents/content/
// risk_disclosure) verbatim; only the STRUCTURE around it (scroll gating,
// the button label, the NDPA-naming checkbox) is this screen's own.
//
// R-2 (still in force, restated by R-8a): the investor's computed risk
// profile is never displayed on this screen. RiskDisclaimerArgs.profile is
// kept only so the route contract (suitability_result_screen.dart's caller,
// AppState.tradingEligibilityGap's fallback caller) doesn't change; it is
// never read by the body below.
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

/// Route `extra`. Carried for router-contract compatibility with existing
/// callers (suitability_result_screen.dart pushes this with the just-
/// computed profile) — R-2 means [profile] is never rendered by this
/// screen. AppState.tradingEligibilityGap's fallback prompt (home_screen.dart)
/// pushes this route with no `extra` at all, for a returning investor
/// re-gated here directly with no freshly-computed profile in hand; this
/// screen doesn't need one either way.
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
  late Future<LegalDocument> _future = _legalRepo.getContent('risk_disclosure');

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
      // it computed the profile; harmless if already true.
      app.setSuitabilityComplete(true);
      // R-8a moved this screen to run right after suitability, ahead of
      // the other three legal documents / passcode / biometric / KYC — it
      // is no longer the last gated onboarding step, but sign-in
      // completion still fires exactly here (the point the disclaimer
      // itself was accepted at), same as it always has.
      if (!app.signedIn) app.setSignedIn(true);
      context.go(Routes.termsOfService);
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
                      onPrimary: () => setState(
                        () => _future = _legalRepo.getContent('risk_disclosure'),
                      ),
                    );
                  }
                  final doc = snapshot.data!;
                  // Empty condition: the document record exists but no
                  // sections have been published for it yet — a real
                  // backend state, distinct from a network/server error.
                  if (doc.sections.isEmpty) {
                    return const KEmptyView(
                      icon: 'card',
                      title: 'No content available yet',
                      message:
                          "The Risk Disclosure hasn't been published yet. Please try again shortly.",
                    );
                  }
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
