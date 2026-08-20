// Stage 9 — Legal (pushed). Document rows (version + date). Mirrors `Legal` in
// settings-screens.jsx. No fixed income — these are the trading/risk/privacy docs only.
//
// Wired to the LegalDocument resource per lib/data/api/README.md's
// FutureBuilder convention: GET /legal-documents replaces the old hardcoded
// `_docs` list.
//
// IN-APP VIEWER (2026-08-20, user directive: "why can't the legal side of
// the app be the same process instead of links?") — previously tapping a
// row fetched a presigned S3 download URL (GET /legal-documents/:id/
// download-url) and launched it externally. That URL pointed at a
// fileObjectKey that was never actually uploaded to S3 (a known,
// pre-existing gap — every doc's fileObjectKey is a placeholder), so this
// always 404'd (S3 NoSuchKey) in practice. GET /legal-documents already
// returns each document's full `sections` content (same DTO the four
// onboarding acceptance screens' GET /legal-documents/content/:kind uses —
// see legal_documents_repository.dart's LegalDocument), so this screen now
// pushes an in-app read-only viewer instead of ever touching S3 at all —
// one process for legal content everywhere in the app, not two.
import 'package:flutter/material.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final _repo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late Future<List<LegalDocument>> _future = _repo.list();

  void _open(LegalDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _LegalDocumentViewerScreen(doc: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Legal',
      child: FutureBuilder<List<LegalDocument>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: () => setState(() => _future = _repo.list()),
            );
          }
          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const KEmptyView(
              icon: 'card',
              title: 'No documents yet',
              message: 'Legal documents will show here once published.',
            );
          }
          return _LegalList(docs: docs, onTap: _open);
        },
      ),
    );
  }
}

class _LegalList extends StatelessWidget {
  const _LegalList({required this.docs, required this.onTap});

  final List<LegalDocument> docs;
  final void Function(LegalDocument doc) onTap;

  @override
  Widget build(BuildContext context) {
    return KAccountCard(
      children: [
        for (var i = 0; i < docs.length; i++)
          KAccountRow(
            icon: 'card',
            title: docs[i].title,
            sub: docs[i].sub,
            right: const KRowChevron(),
            first: i == 0,
            onTap: () => onTap(docs[i]),
          ),
      ],
    );
  }
}

/// Read-only in-app viewer for a single LegalDocument's sections — no
/// checkbox/accept affordance (unlike LegalAcceptanceScreen, which this
/// mirrors the rendering of), since this is a settings-side reference view
/// of a document already accepted (or not yet reached) during onboarding,
/// not an acceptance flow. Uses the SAME `sections` content GET
/// /legal-documents already returned in this screen's list() call — no
/// second network request.
class _LegalDocumentViewerScreen extends StatelessWidget {
  const _LegalDocumentViewerScreen({required this.doc});
  final LegalDocument doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: doc.title),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 20, KSpace.gutter, 32),
          child: doc.sections.isEmpty
              ? const KEmptyView(
                  icon: 'card',
                  title: 'No content yet',
                  message: "This document's content hasn't been published yet.",
                )
              : SingleChildScrollView(
                  child: KCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.sub, style: KType.micro(color: KColor.ink3).tnum),
                          const SizedBox(height: 18),
                          for (var i = 0; i < doc.sections.length; i++) ...[
                            if (i != 0) const SizedBox(height: 22),
                            KEyebrow(doc.sections[i].heading),
                            const SizedBox(height: 8),
                            Text(doc.sections[i].body, style: KType.body(color: KColor.ink2)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
