// Statutory Risk Disclaimer (Rule 76 compliance) fallback screen.
//
// R-8 (DECISIONS.md, 2026-08-26) demotes this from a dedicated scroll-gated
// acceptance screen to "one of the four [documents], presented at the start
// with the rest, not as its own gated screen." Risk disclosure now lives in
// the main onboarding bundle (terms_and_privacy_screen.dart, via
// legal_acceptance_screen.dart) alongside Terms of Service, Privacy Policy
// and Client Agreement, opened in the phone's native file viewer instead of
// rendered inline.
//
// This screen still exists and is still routed to (Routes.riskDisclaimer,
// wired in app_router.dart and app_state.dart's tradingEligibilityGap) for
// ONE fallback case: a returning investor whose account has
// suitabilityComplete=true but no recorded risk_disclosure acknowledgement
// (e.g. onboarded before risk_disclosure joined the main bundle). For that
// investor there is no other place in the app that still asks. Removing the
// route/gate that reaches it is a router and app_state.dart change — see
// this pass's report (SHARED-CHANGE REQUEST) rather than a local edit here,
// per Rule 5/6 of the screen-agent brief.
//
// ═══ ACCEPTANCE-EVIDENCE CHANGE — reported, not softened ═══
// Until 2026-08-27 this screen required scrolling to the bottom of the
// FULL disclosure text (Risk of Capital Loss / Digital Platform
// Infrastructure Risks / No Investment Advice / Regulatory Jurisdiction)
// before "Accept & Proceed" enabled — real evidence the investor's screen
// had displayed every word of the statutory notice. Matching R-8's native-
// viewer pattern (and legal_acceptance_screen.dart, converted the same way)
// replaces that with "tapped to open the document once" — the app can
// confirm the file was handed off to an external viewer, nothing more. It
// cannot confirm the investor read it, scrolled it, or even that the
// destination rendered rather than 404ing (BR-6: the file was never
// actually uploaded to storage, so presigning succeeds and the external
// viewer opens to a broken page with no client-side way to detect that in
// advance). If compliance ever needs proof an investor actually read this
// document, neither this screen's new mechanism nor the bundle's does that
// — flagged exactly as R-8 itself flags it, restated here concretely.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Route `extra`. Kept for router-contract compatibility with existing
/// callers (suitability_result_screen.dart) — R-2 (no profiling anywhere)
/// means [profile] is never rendered by this screen; it is not read here at
/// all any more, only carried so the route signature doesn't have to change
/// in lockstep with a router file this directory can't edit.
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

  bool _opened = false;
  bool _opening = false;
  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  Future<void> _openDocument(LegalDocument doc) async {
    if (doc.fileObjectKey.isEmpty) {
      _snack("This document hasn't been uploaded yet.");
      return;
    }
    setState(() => _opening = true);
    try {
      final url = await _legalRepo.downloadUrl(doc.id);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (ok) {
        setState(() => _opened = true);
      } else if (mounted) {
        _snack("Couldn't open the Risk Disclosure. Try again.");
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                    // file has been attached to it yet — a real backend
                    // state, distinct from BR-6 (a file attached but never
                    // actually uploaded, which this screen cannot detect).
                    if (doc.fileObjectKey.isEmpty) {
                      return const KEmptyView(
                        icon: 'card',
                        title: 'No file available yet',
                        message:
                            "The Risk Disclosure hasn't been uploaded yet. Please try again shortly.",
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const KScreenHead(
                          title: 'Important regulatory & risk notice',
                          body:
                              'Please open and read this disclosure before activating your account.',
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _opening ? null : () => _openDocument(doc),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                            decoration: BoxDecoration(
                              color: KColor.paper,
                              border: Border.all(
                                color: _opened ? KColor.indicator : KColor.hairline,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: KColor.indicatorTint,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Center(
                                    child: KIcon('doc', size: 16, color: KColor.indicator),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Risk Disclosure', style: KType.cardTitle()),
                                      Text(doc.sub, style: KType.micro(color: KColor.ink3)),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: _opening
                                      ? CircularProgressIndicator(
                                          strokeWidth: 2, color: KColor.ink3)
                                      : KIcon(
                                          _opened ? 'check' : 'download',
                                          size: 16,
                                          color: _opened ? KColor.indicator : KColor.ink3,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: KType.body(color: KColor.loss)),
                        ],
                        const SizedBox(height: 20),
                        Opacity(
                          opacity: _opened ? 1 : 0.45,
                          child: IgnorePointer(
                            ignoring: !_opened,
                            child: KCheckbox(
                              checked: _agreed,
                              onChanged: (v) => setState(() => _agreed = v),
                              label:
                                  'I confirm that I have read, understood, and voluntarily accept the Risk Disclaimer and the Privacy Terms in alignment with the Nigeria Data Protection Act (NDPA).',
                            ),
                          ),
                        ),
                        if (!_opened) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Open the document above to continue.',
                            style: KType.micro(color: KColor.ink3),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: KButton(
                label: 'Accept & Proceed',
                loading: _submitting,
                onPressed: _opened && _agreed && !_submitting ? _accept : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
