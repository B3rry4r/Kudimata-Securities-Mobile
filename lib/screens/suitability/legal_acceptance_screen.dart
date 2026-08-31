// Shared scaffold for the onboarding legal-acceptance screens. Each screen
// in this app's flow covers a GROUP of documents with ONE checkbox and ONE
// accept action (2026-08-20 consolidation — every one of the four legal
// documents used to be its own screen with its own tick, requiring 4
// separate taps total; user directive: "the terms of service and privacy
// policy... why should not be two ticks... users should read through all
// and click one agree checkbox that covers it all").
//
// R-8 (DECISIONS.md, 2026-08-26) supersedes the 2026-08-24 inline-text
// rendering this screen used to do: "Documents open in the phone's native
// viewer rather than being rendered in-app... risk disclosure is one of the
// four, presented at the start with the rest, not as its own gated screen."
// Per the screen-agent brief for this directory: "`legal_preview_screen.dart`
// already implements the file-viewer pattern; read it and match rather than
// inventing a second approach." So every document here is now a tap-to-open
// row (same shape as LegalBundlePreviewScreen's `_LegalDocRow`, mirrored
// locally rather than imported — it's a private, screen-local widget in
// that file, not something in lib/widgets/**) that hands the presigned file
// off to the phone's native viewer, instead of a scroll-gated wall of text.
//
// ACCEPTANCE-EVIDENCE CHANGE, reported per the brief's instruction to state
// this plainly: the old gate was "scrolled to the bottom of every document's
// full text". The new gate is "tapped to open every document at least
// once" — the app can confirm a document was launched into an external
// viewer, but (same limitation `legal_preview_screen.dart` already has) it
// cannot confirm the investor read it, or that the destination actually
// rendered rather than 404ing (BR-6: the four files were never uploaded to
// storage, so presigning succeeds and the external viewer opens to a broken
// page — nothing client-side can detect that in advance). This is a weaker
// acceptance signal than scroll-to-bottom-of-real-text and is intentionally
// not overstated as equivalent.
//
// RISK DISCLOSURE WAS AN EXCEPTION TO THAT PATTERN FROM 2026-08-29 TO
// 2026-08-31 (DECISIONS.md's R-8a superseded note, then its own 2026-08-31
// addendum): it was pulled out into its own scroll-gated screen on
// 2026-08-27, folded back into this list on 2026-08-29 ("...leave the
// scroll thing please") but STILL special-cased to push an in-app,
// hand-authored view of its `sections` text instead of the real file. Owner,
// 2026-08-31, verbatim: "the risk disclosure should be a PDF too not a
// screen" — `legal/risk-disclosure-v1.pdf` is a real, already-uploaded file
// (registry.json's LegalDocument, same as the other three), so there is no
// reason left for it to be the one document rendered from hand-authored
// `sections` in a bespoke widget rather than opened as what it actually is.
// It is now opened by the exact same `_open` path as the other three below
// — download-url + the phone's native viewer — with no special case. See
// DECISIONS.md's R-8a 2026-08-31 addendum for what that trades away (a
// literal scroll-to-the-end signal, which no app can observe once the
// document is handed to an external viewer) and what still gates
// acceptance instead (the same "confirmed launch of a real, present file"
// signal every other document here already relies on).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Kinds the investor has tapped open at least once — the acceptance-
  /// evidence gate under R-8 (see file header). A kind with no file
  /// attached yet can't be opened at all, so it's excluded from this
  /// requirement rather than permanently blocking acceptance of the other,
  /// available documents — see [_unavailable]. Uniform across all four
  /// documents since 2026-08-31 (DECISIONS.md R-8a's addendum) — risk
  /// disclosure no longer carries its own rule.
  final Set<String> _opened = {};
  String? _openingKind;

  Future<List<LegalDocument>> _load() async {
    // Independent GETs, fetched concurrently rather than sequentially so a
    // slow document doesn't delay the rest.
    return Future.wait(widget.kinds.map(_legalRepo.getContent));
  }

  /// True when [d] has no real file behind it yet.
  bool _unavailable(LegalDocument d) => d.fileObjectKey.isEmpty;

  bool _allOpened(List<LegalDocument> docs) => docs.every(
        (d) => _unavailable(d) || _opened.contains(d.kind),
      );

  /// Opens [doc] in the phone's native viewer — the one mechanism every
  /// document here uses since 2026-08-31 (risk disclosure included; see
  /// file header). `_opened` is set once [launchUrl] itself reports
  /// success, exactly the same evidence the other three documents have
  /// always relied on — see this class's own R-8 doc comment on what that
  /// signal is (and is not).
  Future<void> _open(LegalDocument doc) async {
    if (_unavailable(doc)) {
      _snack("${_kDocTitle[doc.kind] ?? doc.title} hasn't been uploaded yet.");
      return;
    }
    setState(() => _openingKind = doc.kind);
    try {
      final url = await _legalRepo.downloadUrl(doc.id);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (ok) {
        setState(() => _opened.add(doc.kind));
      } else if (mounted) {
        _snack("Couldn't open ${_kDocTitle[doc.kind] ?? doc.title}. Try again.");
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _openingKind = null);
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
      // Sequential, not parallel — if an earlier acknowledgement fails, the
      // later ones must not fire.
      for (final kind in widget.kinds) {
        await _complianceRepo.acknowledge(kind: kind);
      }
      if (!mounted) return;
      // Keeps AppState.riskDisclosureAccepted in sync when this bundle
      // covers risk_disclosure (R-8, then R-8a-superseded 2026-08-29: it's
      // one of the documents here now, not its own screen) — without this,
      // app_state.dart's tradingEligibilityGap would still re-route a
      // freshly-onboarded investor to Routes.termsOfService post-KYC
      // despite having already accepted it on this screen, since that flag
      // is otherwise only ever set here.
      //
      // setSignedIn(true) rides along with it (moved from the old standalone
      // risk-disclaimer screen's own accept action, per R-8a's own "two
      // things that must not be lost in the rewiring" note — DECISIONS.md):
      // the onboarding chain's sign-in completion has to fire exactly at
      // the point risk disclosure is accepted, wherever that step lands.
      if (widget.kinds.contains('risk_disclosure')) {
        final app = AppScope.read(context);
        app.setRiskDisclosureAccepted(true);
        if (!app.signedIn) app.setSignedIn(true);
      }
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
                        // Checkbox + accept button only render once EVERY
                        // document has actually loaded — agreeing to
                        // something you never saw isn't a real acceptance.
                        final allOpened = _allOpened(docs);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final doc in docs) ...[
                              _LegalDocRow(
                                title: _kDocTitle[doc.kind] ?? doc.title,
                                sub: doc.fileObjectKey.isEmpty
                                    ? 'Not available yet'
                                    : doc.sub,
                                opened: _opened.contains(doc.kind),
                                busy: _openingKind == doc.kind,
                                onTap: _openingKind != null ? null : () => _open(doc),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 8),
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
                              opacity: allOpened ? 1 : 0.45,
                              child: IgnorePointer(
                                ignoring: !allOpened,
                                child: KCheckbox(
                                  checked: _agreed,
                                  onChanged: (v) => setState(() => _agreed = v),
                                  label: widget.checkboxLabel,
                                  description: widget.checkboxDescription,
                                ),
                              ),
                            ),
                            if (!allOpened) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Open every document above to continue.',
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

/// One document row — icon, title, version/date, and a trailing glyph that
/// is a small spinner while its file is being fetched, a check once opened,
/// or a plain download icon otherwise. Screen-local; mirrors
/// `legal_preview_screen.dart`'s `_LegalDocRow` (private to that file, so
/// duplicated here rather than imported — never a shared-widget fork, since
/// neither copy lives in lib/widgets/**).
class _LegalDocRow extends StatelessWidget {
  const _LegalDocRow({
    required this.title,
    required this.sub,
    required this.opened,
    required this.busy,
    required this.onTap,
  });
  final String title;
  final String sub;
  final bool opened;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(color: opened ? KColor.indicator : KColor.hairline),
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
              child: Center(child: KIcon('doc', size: 16, color: KColor.indicator)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.cardTitle()),
                  Text(sub, style: KType.micro(color: KColor.ink3)),
                ],
              ),
            ),
            SizedBox(
              width: 16,
              height: 16,
              child: busy
                  ? CircularProgressIndicator(strokeWidth: 2, color: KColor.ink3)
                  : KIcon(opened ? 'check' : 'download', size: 16,
                      color: opened ? KColor.indicator : KColor.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
