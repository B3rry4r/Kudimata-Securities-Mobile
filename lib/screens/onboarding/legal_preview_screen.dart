// Artboard `s03c` (+ dark `s03cd`) in `01 Getting In.dc.html` — "Terms and
// Disclosures", opened from the agree checkbox on the signup screen.
// Read-only legal-document preview, pushed from sign_up_screen.dart's
// "By continuing..." link. Before this screen existed, that line named
// "Terms" and "Risk Disclosure" but neither was tappable — there was no way
// to actually read either document before creating an account, because
// every legal-documents route sat behind investor auth. This hits the
// unauthenticated mirror (GET /public/legal-documents/content/:kind — see
// LegalDocumentsRepository.getPublicContent) instead.
//
// R-8 (DECISIONS.md, 2026-08-26): exactly 4 documents, not the canvas's 8 —
// the other 4 ("Fees and Charges", "Best Execution Policy", "Conflicts of
// Interest Policy", "Complaints Procedure", "Custody and Client Assets")
// don't exist and are never created. Risk disclosure is one of the real 4,
// shown here with the rest rather than as its own gated screen. And rows
// open the real file in the phone's native viewer — this screen used to
// hand off to an in-app parsed renderer (document_summary_screen.dart),
// which R-8 supersedes for this flow. That screen was never wired in
// anywhere else either and was dropped entirely (D-4, SHARED-CHANGES.md
// 2026-08-27 removals pass).
//
// Deliberately NOT the same widget as legal_acceptance_screen.dart: this is
// a passive preview (no checkbox, no accept button that actually records
// anything, no POST /compliance-acknowledgements) — there's no account yet
// for an acknowledgement to belong to. Real acceptance happens moments
// later, on the dedicated screens right after OTP verification. The bundle
// screen's own "I agree to all of these" button (drawn by `s03c`) only
// returns to that checkbox screen — it does not itself accept anything.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';

/// Fetches the presigned download URL for [doc] and opens it in the phone's
/// native file viewer (R-8). `doc.fileObjectKey` is real backend content, not
/// a UI field — see this screen's SHARED-CHANGE / BACKEND_GAPS note: every
/// legal document's fileObjectKey today is a placeholder never actually
/// uploaded to S3, so a successful `downloadUrl` call can still hand the OS
/// a link that 404s once opened. Nothing client-side can distinguish that
/// case in advance, so failures surface as an honest snackbar rather than a
/// silent no-op.
Future<void> _openLegalDocument(
  BuildContext context,
  LegalDocumentsRepository repo,
  LegalDocument doc,
) async {
  try {
    final url = await repo.downloadUrl(doc.id);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _snack(context, "Couldn't open ${doc.title}. Try again.");
    }
  } on ApiException catch (e) {
    if (context.mounted) _snack(context, e.message);
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class LegalPreviewScreen extends StatefulWidget {
  const LegalPreviewScreen({super.key, required this.kind});

  /// 'terms_of_service' | 'privacy_policy' | 'risk_disclosure' |
  /// 'client_agreement'.
  final String kind;

  static const _titles = {
    'terms_of_service': 'Terms of Service',
    'privacy_policy': 'Privacy Policy',
    'risk_disclosure': 'Risk Disclosure',
    'client_agreement': 'Client Agreement',
  };

  String get title => _titles[kind] ?? 'Legal document';

  @override
  State<LegalPreviewScreen> createState() => _LegalPreviewScreenState();
}

class _LegalPreviewScreenState extends State<LegalPreviewScreen> {
  // Same single shared ApiClient every other repository-backed screen uses
  // (see api_client.dart's header) — reachable here even pre-signup, since
  // /auth/signup itself already goes through this same instance.
  late final _repo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late Future<LegalDocument> _future = _repo.getPublicContent(widget.kind);
  bool _opening = false;

  Future<void> _open(LegalDocument doc) async {
    setState(() => _opening = true);
    await _openLegalDocument(context, _repo, doc);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: widget.title),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<LegalDocument>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const KLoadingView();
              }
              if (snapshot.hasError) {
                return KErrorView(
                  onPrimary: () => setState(() => _future = _repo.getPublicContent(widget.kind)),
                );
              }
              final doc = snapshot.data!;
              // Empty condition: the document record exists but no file has
              // been attached to it yet (fileObjectKey unset) — a real,
              // if not currently fixture-triggered, backend state.
              if (doc.fileObjectKey.isEmpty) {
                return const KEmptyView(
                  icon: 'card',
                  title: 'No file available yet',
                  message: "This document hasn't been uploaded yet.",
                );
              }
              return _LegalDocRow(
                title: widget.title,
                sub: doc.sub,
                busy: _opening,
                onTap: _opening ? null : () => _open(doc),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Terms and Disclosures" — one scrollable screen listing all 4 real legal
/// documents, reachable pre-signup (no account/token yet, same
/// GET /public/legal-documents/content/:kind LegalPreviewScreen already
/// uses). 2026-08-24, replacing sign_up_screen.dart's 4 separate inline
/// hyperlinks: direct feedback wanted "the old structure... all in one
/// screen where they scroll see all and click" instead of naming each
/// document individually in a sentence. Each row opens the real file in the
/// phone's native viewer (R-8) rather than pushing another screen.
const List<String> _kAllLegalKinds = [
  'terms_of_service',
  'privacy_policy',
  'risk_disclosure',
  'client_agreement',
];

class LegalBundlePreviewScreen extends StatefulWidget {
  const LegalBundlePreviewScreen({super.key});

  @override
  State<LegalBundlePreviewScreen> createState() => _LegalBundlePreviewScreenState();
}

class _LegalBundlePreviewScreenState extends State<LegalBundlePreviewScreen> {
  late final _repo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late Future<List<LegalDocument>> _future = _load();
  String? _openingId;

  Future<List<LegalDocument>> _load() =>
      Future.wait(_kAllLegalKinds.map(_repo.getPublicContent));

  Future<void> _open(LegalDocument doc) async {
    if (doc.fileObjectKey.isEmpty) {
      _snack(context, "${LegalPreviewScreen._titles[doc.kind] ?? doc.title} hasn't been uploaded yet.");
      return;
    }
    setState(() => _openingId = doc.id);
    await _openLegalDocument(context, _repo, doc);
    if (mounted) setState(() => _openingId = null);
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// The most recent of the 4 real documents' own `publishedAt` — a real,
  /// derived figure (not the canvas's fixed "4 August 2026" caption, which
  /// has no single backing field once there are 4 independently-versioned
  /// documents). Null, and the line is omitted, if none carry a date yet.
  String? _lastUpdated(List<LegalDocument> docs) {
    final dates = docs.map((d) => d.publishedAt).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    return '${latest.day} ${_months[latest.month - 1]} ${latest.year}';
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
              padding: const EdgeInsets.fromLTRB(12, 6, 20, 0),
              child: KIconButton(
                icon: 'back',
                semanticLabel: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(KSpace.gutter, 8, KSpace.gutter, KSpace.gutter),
                child: FutureBuilder<List<LegalDocument>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: KLoadingView(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: KErrorView(onPrimary: () => setState(() => _future = _load())),
                      );
                    }
                    final docs = snapshot.data!;
                    final lastUpdated = _lastUpdated(docs);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KScreenHead(
                          title: 'Terms and Disclosures',
                          body: 'Four documents. Tap one to open the file.',
                        ),
                        const SizedBox(height: 18),
                        Column(
                          children: [
                            for (final doc in docs) ...[
                              _LegalDocRow(
                                title: LegalPreviewScreen._titles[doc.kind] ?? doc.title,
                                sub: doc.sub,
                                busy: _openingId == doc.id,
                                onTap: _openingId != null ? null : () => _open(doc),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.only(top: 20),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                lastUpdated == null
                                    ? 'We email you when any of these change.'
                                    : 'Last updated $lastUpdated. We email you when any of these change.',
                                textAlign: TextAlign.center,
                                style: KType.micro(color: KColor.ink3),
                              ),
                              const SizedBox(height: 14),
                              KButton(
                                label: 'I agree to all of these',
                                onPressed: () => Navigator.of(context).maybePop(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One document row — icon, title, version/date, and a trailing download
/// glyph that becomes a small spinner while its file is being fetched.
/// Screen-local; shared by both screens above (never forked, never reused
/// outside this file).
class _LegalDocRow extends StatelessWidget {
  const _LegalDocRow({required this.title, required this.sub, required this.busy, required this.onTap});
  final String title;
  final String sub;
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
          border: Border.all(color: KColor.hairline),
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
                  : KIcon('download', size: 16, color: KColor.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
