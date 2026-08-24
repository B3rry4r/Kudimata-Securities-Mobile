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
// per kind, all concurrently via `.wait`) and renders a canvas-s05 row-list
// — name + real "vN · Read" badge, tap opens that one document's
// plain-English preview (Routes.documentSummary) — NOT the full text of
// every document inline on this screen (2026-08-24 fix: it used to render
// every section of every document inline here, a structurally different,
// much heavier screen than the canvas's checklist-then-link pattern).
// Tapping the primary button posts one acknowledgement per kind IN ORDER (POST
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
import 'package:kudimata_invest/screens/onboarding/onboarding_scaffold.dart' show KOnboardTopBar;

/// Display titles per kind — canvas s05's document-list row labels.
const Map<String, String> _kDocTitle = {
  'terms_of_service': 'Terms of Service',
  'privacy_policy': 'Privacy Policy',
  'risk_disclosure': 'Risk Disclosure',
  'client_agreement': 'Client Agreement',
};

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({
    super.key,
    required this.kinds,
    required this.screenTitle,
    this.screenBody,
    this.stepLabel,
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

  /// Canvas s05's "Step 2 of 4" mid-flow indicator (KOnboardTopBar, the same
  /// convention otp_screen.dart/create_passcode_screen.dart/
  /// biometric_screen.dart already use) — null renders no top bar at all,
  /// for a future non-onboarding caller of this same widget.
  final String? stepLabel;
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

  /// Scroll-to-bottom gate. The checkbox says "I have read and agree", and
  /// it used to be live on first paint — an investor could accept three
  /// executed agreements without seeing a word of them.
  ///
  /// Now that every document renders inline (2026-08-24), scroll-to-bottom
  /// is the right gate and the same one the statutory Risk Disclaimer uses
  /// (risk_disclaimer_screen.dart), which is what the firm's SEC intake doc
  /// actually specifies. The previous open-each-document gate existed only
  /// because the documents were behind links; with the text on the page,
  /// reaching the end of it is the stronger and more honest signal.
  final ScrollController _scroll = ScrollController();
  bool _reachedEnd = false;

  void _onScroll() {
    if (_reachedEnd || !_scroll.hasClients) return;
    // 24pt of slack: exact-equality never fires reliably across devices,
    // and a hairline of remaining scroll shouldn't trap someone who has
    // plainly reached the end.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 24) {
      setState(() => _reachedEnd = true);
    }
  }

  /// Content shorter than the viewport can never scroll, so nothing would
  /// ever satisfy the gate. Checked after each layout instead.
  void _checkAlreadyAtEnd() {
    if (_reachedEnd || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent <= 0) {
      setState(() => _reachedEnd = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.stepLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: KOnboardTopBar(stepLabel: widget.stepLabel),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KScreenHead(title: widget.screenTitle, body: widget.screenBody),
                    const SizedBox(height: 18),
                    FutureBuilder<List<LegalDocument>>(
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
                        // Runs after this frame lays out: if all three
                        // documents happen to fit without scrolling, the
                        // gate would otherwise never open.
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _checkAlreadyAtEnd());
                        // Checkbox + accept button only render once EVERY
                        // document has actually loaded — agreeing to
                        // something you never saw isn't a real acceptance.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 2026-08-24, direct instruction: "instead of
                            // doing it like that lay the 3 out please...
                            // not to click and open, lay them out the way
                            // it was before and they scroll down to be able
                            // to click". Every document's full text renders
                            // INLINE here, in order, so accepting is one
                            // continuous read rather than three round trips
                            // into a detail screen — which also matches the
                            // original directive behind this screen ("stack
                            // them in one screen so user just scrolls down
                            // and accept one time not moving between
                            // screens"). The tap-to-open row list this
                            // replaces additionally hit a real bug: it
                            // pushed /document-summary, which the router
                            // bounced to login because this step runs
                            // before sign-in completes.
                            for (var i = 0; i < docs.length; i++) ...[
                              if (i != 0) const SizedBox(height: 14),
                              _InlineDocument(doc: docs[i]),
                            ],
                            const SizedBox(height: 18),
                            // 2026-08-24: canvas's own literal copy here was
                            // a blunt "You can lose money" warning with no
                            // context — direct feedback: "a better glossary
                            // than you can loose money... that is wrong
                            // UX". Reframed in the app's own explain-first
                            // voice (same as ExplainTrigger/GlossaryTerm
                            // elsewhere) — still states the real risk (a
                            // genuine regulatory disclosure, not removable),
                            // just explains WHY prices move instead of
                            // stopping at the warning.
                            const KNudgeCard(
                              tone: KNudgeTone.grape,
                              title: 'Why share prices move',
                              body:
                                  "A share's price follows how the company is doing and what other investors think it's worth — it can rise or fall on any given day. That's true of every stock here, which is why we show you the risk label and explain each one before you buy.",
                            ),
                            const SizedBox(height: 18),
                            if (_error != null) ...[
                              Text(_error!, style: KType.body(color: KColor.loss)),
                              const SizedBox(height: 12),
                            ],
                            Opacity(
                              opacity: _reachedEnd ? 1 : 0.45,
                              child: IgnorePointer(
                                ignoring: !_reachedEnd,
                                child: KCheckbox(
                                  checked: _agreed,
                                  onChanged: (v) => setState(() => _agreed = v),
                                  label: widget.checkboxLabel,
                                  description: widget.checkboxDescription,
                                ),
                              ),
                            ),
                            if (!_reachedEnd) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Scroll to the end of the documents to continue.',
                                style: KType.data(color: KColor.ink3),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: KButton(
                label: widget.buttonLabel,
                loading: _submitting,
                onPressed: _agreed && !_submitting ? _accept : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// One legal document rendered in full, inline — title, version, then every
/// section as a heading + body. Same plain KCard treatment
/// legal_screen.dart's own viewer and legal_reference_screens.dart use, so a
/// document reads identically wherever it appears (2026-08-24).
class _InlineDocument extends StatelessWidget {
  const _InlineDocument({required this.doc});
  final LegalDocument doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline),
        borderRadius: KRadii.cardR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_kDocTitle[doc.kind] ?? doc.title, style: KType.cardTitle()),
          const SizedBox(height: 4),
          Text('v${doc.versionLabel}'.upper, style: KType.micro(color: KColor.ink3)),
          for (final s in doc.sections) ...[
            const SizedBox(height: 14),
            Text(s.heading, style: KType.cardTitle(w: KWeight.semibold)),
            const SizedBox(height: 5),
            Text(s.body, style: KType.body(color: KColor.ink2)),
          ],
        ],
      ),
    );
  }
}
