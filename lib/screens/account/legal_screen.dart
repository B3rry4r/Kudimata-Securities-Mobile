// Stage 9 — Legal (pushed). Document rows (version + date). Mirrors `Legal` in
// settings-screens.jsx. No fixed income — these are the trading/risk/privacy docs only.
//
// Wired to the LegalDocument resource per lib/data/api/README.md's
// FutureBuilder convention: GET /legal-documents replaces the old hardcoded
// `_docs` list, and tapping a row fetches a presigned download URL (GET
// /legal-documents/:id/download-url) and launches it externally — there is
// no in-app document viewer to build one for.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
import 'account_widgets.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final _repo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late Future<List<LegalDocument>> _future = _repo.list();

  Future<void> _open(LegalDocument doc) async {
    try {
      final url = await _repo.downloadUrl(doc.id);
      if (url.isEmpty) return;
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No in-app surface to report this on (a chevron row, not a form) —
      // matches this screen's original no-op-on-failure seam; the download
      // is a best-effort external hand-off.
    }
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
