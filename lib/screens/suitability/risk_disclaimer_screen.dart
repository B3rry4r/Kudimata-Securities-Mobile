// Statutory Risk Disclosure (Rule 76 compliance) — in-app scroll-gated
// CONTENT VIEWER, pushed from legal_acceptance_screen.dart's document list
// when the investor taps the "Risk Disclosure" row, never its own route.
//
// HISTORY, because this file used to be a full onboarding screen and the
// trail matters: R-8a (DECISIONS.md, 2026-08-27) pulled risk disclosure OUT
// of the legal-documents bundle and into its own scroll-gated screen,
// running right after suitability and ahead of the other three documents,
// to resolve a three-way conflict between R-1a (suitability before the
// legal documents), R-8 (risk disclosure bundled with the other three,
// phone viewer) and the firm's real SEC-facing compliance intake ("the
// disclaimer must appear immediately after suitability", scroll-gated
// in-app). That gave risk disclosure its own route (Routes.riskDisclaimer),
// its own "Accept & Proceed" button that called
// POST /compliance-acknowledgements directly, and its own `setSignedIn
// (true)` call.
//
// SUPERSEDED 2026-08-29 — product owner, verbatim: "risk disclosure should
// be part of the legal docs screen not a standalone before them they
// should be in on user opens and then can click on the checkmark leave the
// scroll thing please". DECISIONS.md's R-8a entry carries a superseded note
// recording this reversal. What changed: risk disclosure is back in the
// legal-documents list (terms_and_privacy_screen.dart's `kinds`), opened
// and checked off exactly like the other three documents — one open, then
// the shared checkbox unlocks once every document has been opened, and one
// shared "Accept and continue" button POSTs every kind, risk_disclosure
// included (legal_acceptance_screen.dart's `_accept()` already handled a
// risk_disclosure kind before this change, for the account-reference case;
// nothing new needed there beyond adding `setSignedIn(true)` alongside its
// existing `setRiskDisclosureAccepted(true)` call — see that file).
//
// What did NOT change, per the product owner's own "leave the scroll thing
// please": the scroll-to-bottom gate is the only mechanism that produces
// real evidence the investor was actually shown the statutory text — with
// BR-6 live (files never uploaded, presigning succeeds, the phone viewer
// 404s) the other three documents' tap-to-open-externally pattern would
// record "opened" for a document nobody could read, and that is NOT
// acceptable for this one. So [RiskDisclosureScrollScreen] below is what
// legal_acceptance_screen.dart pushes (`Navigator.push`, not a route — this
// is an on-demand document viewer, not a flow step) when the risk_disclosure
// row is tapped, in place of the phone-viewer hand-off it uses for the
// other three. It carries the exact same scroll-to-bottom detection this
// file always had; it just no longer owns the accept/POST/navigate/sign-in
// logic, which moved to legal_acceptance_screen.dart's shared accept
// button. It pops `true` only once the investor has scrolled to the end
// and tapped through — legal_acceptance_screen.dart marks the row
// 'opened' (unlocking its own checkbox once every row is) on that `true`,
// never on a bare dismiss.
//
// The disclosure TEXT ITSELF (Risk of Capital Loss / Digital Platform
// Infrastructure Risks / No Investment Advice / Regulatory Jurisdiction
// sections) is deliberately NOT authored here — direct product
// instruction: "leave risk disclaimer content for legal team, they would
// do it". This screen renders whatever LegalDocument content already
// exists for kind='risk_disclosure' (already fetched by
// legal_acceptance_screen.dart's own GET /legal-documents/content/
// risk_disclosure, passed in rather than re-fetched) verbatim; only the
// STRUCTURE around it (scroll gating, the button label) is this screen's
// own.
//
// R-2 (still in force): the investor's computed risk profile is never
// displayed here — this screen doesn't even carry one any more
// (RiskDisclaimerArgs, which existed only for this reason, is gone with
// the standalone route).
import 'package:flutter/material.dart';

import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Pushed (not routed) from legal_acceptance_screen.dart when its
/// 'risk_disclosure' row is tapped. [document] is already-fetched content
/// (that screen's own FutureBuilder already has it) — no second network
/// round-trip. Pops `true` once scrolled to the bottom and acknowledged,
/// `null`/`false` on a bare back-out.
class RiskDisclosureScrollScreen extends StatefulWidget {
  const RiskDisclosureScrollScreen({super.key, required this.document});
  final LegalDocument document;

  @override
  State<RiskDisclosureScrollScreen> createState() => _RiskDisclosureScrollScreenState();
}

class _RiskDisclosureScrollScreenState extends State<RiskDisclosureScrollScreen> {
  final _scrollController = ScrollController();
  bool _scrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // A short document (or a tall device) may never produce a scrollable
    // overflow at all — nothing to scroll TO, so the gate must not stay
    // permanently unmet. Deferred a frame so the ScrollController has a
    // laid-out position to check.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAlreadyAtBottom());
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

  @override
  Widget build(BuildContext context) {
    final sections = widget.document.sections;
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Risk Disclosure'),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // Empty condition: the document record exists but no
              // sections have been published for it yet — a real backend
              // state, distinct from a network/server error (which
              // legal_acceptance_screen.dart's own FutureBuilder already
              // surfaces before this screen is ever reachable).
              child: sections.isEmpty
                  ? const KEmptyView(
                      icon: 'card',
                      title: 'No content available yet',
                      message:
                          "The Risk Disclosure hasn't been published yet. Please try again shortly.",
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KScreenHead(
                            title: 'Important regulatory & risk notice',
                            body:
                                'Please read this disclosure carefully before continuing.',
                          ),
                          const SizedBox(height: 20),
                          for (final section in sections) ...[
                            Text(section.heading, style: KType.cardTitle()),
                            const SizedBox(height: 6),
                            Text(section.body, style: KType.body(color: KColor.ink2)),
                            const SizedBox(height: 18),
                          ],
                          if (!_scrolledToBottom) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Scroll to the end to continue.',
                              style: KType.micro(color: KColor.ink3),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: KButton(
                label: "I've read this",
                onPressed: _scrolledToBottom
                    ? () => Navigator.of(context).pop(true)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
