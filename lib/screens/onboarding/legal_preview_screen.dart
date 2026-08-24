// Read-only legal-document preview, pushed from sign_up_screen.dart's
// "By continuing..." links. Before this screen existed, that line named
// "Terms" and "Risk Disclosure" but neither was tappable — there was no way
// to actually read either document before creating an account, because
// every legal-documents route sat behind investor auth. This hits the
// unauthenticated mirror (GET /public/legal-documents/content/:kind — see
// LegalDocumentsRepository.getPublicContent) instead.
//
// Deliberately NOT the same widget as legal_acceptance_screen.dart: this is
// a passive preview (no checkbox, no accept button, no
// POST /compliance-acknowledgements) — there's no account yet for an
// acknowledgement to belong to. Real acceptance happens moments later, on
// the dedicated screens right after OTP verification.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'document_summary_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LegalDocument>(
      future: _future,
      builder: (context, snapshot) {
        // Loading/error states keep the plain Scaffold+KDetailHeader chrome
        // — only the success case hands off to DocumentSummaryScreen, which
        // has its own full-screen chrome (back button, KLanguageSwitch), so
        // it must not be nested inside a second Scaffold/app bar.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: KColor.bg,
            appBar: KDetailHeader(title: widget.title),
            body: const SafeArea(top: false, child: Padding(padding: EdgeInsets.all(20), child: KLoadingView())),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: KColor.bg,
            appBar: KDetailHeader(title: widget.title),
            body: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: KErrorView(
                  onPrimary: () => setState(() => _future = _repo.getPublicContent(widget.kind)),
                ),
              ),
            ),
          );
        }
        final doc = snapshot.data!;
        final original = StringBuffer(doc.sub)..write('\n\n');
        for (final s in doc.sections) {
          original
            ..write(s.heading)
            ..write('\n')
            ..write(s.body)
            ..write('\n\n');
        }
        return DocumentSummaryScreen(
          docTitle: widget.title,
          original: original.toString().trim(),
        );
      },
    );
  }
}

/// "Terms & disclosures" — one scrollable screen listing all 4 real legal
/// documents, reachable pre-signup (no account/token yet, same
/// GET /public/legal-documents/content/:kind LegalPreviewScreen already
/// uses). 2026-08-24, replacing sign_up_screen.dart's 4 separate inline
/// hyperlinks: direct feedback wanted "the old structure... all in one
/// screen where they scroll see all and click" instead of naming each
/// document individually in a sentence. Each row still opens the same
/// LegalPreviewScreen detail — only the entry point changed.
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

  Future<List<LegalDocument>> _load() =>
      Future.wait(_kAllLegalKinds.map(_repo.getPublicContent));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Terms & disclosures'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<List<LegalDocument>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const KLoadingView();
              }
              if (snapshot.hasError) {
                return KErrorView(onPrimary: () => setState(() => _future = _load()));
              }
              final docs = snapshot.data!;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Four documents, one agreement. Tap any row to read it in full.',
                      style: KType.body(color: KColor.ink2),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: KColor.paper,
                        border: Border.all(color: KColor.hairline),
                        borderRadius: KRadii.cardR,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < docs.length; i++)
                            _LegalBundleRow(
                              doc: docs[i],
                              showDivider: i != docs.length - 1,
                              onTap: () => context.push(Routes.legalPreview(docs[i].kind)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegalBundleRow extends StatelessWidget {
  const _LegalBundleRow({required this.doc, required this.showDivider, required this.onTap});
  final LegalDocument doc;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: KColor.hairline, width: 1))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                LegalPreviewScreen._titles[doc.kind] ?? doc.title,
                style: KType.cardTitle(),
              ),
            ),
            KIcon('chevronRight', size: 18, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}
