// Account → Legal — artboard `s03c` ("Terms and Disclosures",
// "01 Getting In.dc.html"), cross-referenced from Account per its own
// footer note ("Also reachable from Account → Terms.") and per s51's own
// "Terms and disclosures" row. RULINGS.md: `redesign-to-artboard`.
//
// R-8 (DECISIONS.md, 2026-08-26): s03c draws 8 documents; only 4 are real
// (terms_of_service, privacy_policy, risk_disclosure, client_agreement —
// GET /legal-documents already returns exactly these 4, see
// legal_documents_repository.dart). The other 4 the canvas draws (Fees and
// Charges, Best Execution Policy, Conflicts of Interest Policy, Complaints
// Procedure, Custody and Client Assets) do not exist and are not created.
//
// NATIVE FILE VIEWER (R-8, supersedes the prior in-app viewer below this
// note's own history): documents open in the phone's native file viewer via
// a presigned download URL, matching lib/screens/onboarding/
// legal_preview_screen.dart's pattern exactly (that file is the R-8
// reference implementation — read it before touching this one). Previously
// this screen pushed an in-app read-only viewer of GET /legal-documents'
// `sections` content instead — R-8 supersedes that for this flow;
// `document_summary_screen.dart` was deleted for the same reason. Every
// document's `fileObjectKey` today is a placeholder never actually uploaded
// to storage (BR-6, a known live defect on the owner's desk) — presigning
// still succeeds, so the phone's viewer can still 404 after a successful
// `downloadUrl` call. Nothing client-side can tell that apart in advance, so
// a failure to open surfaces as an honest snackbar rather than a silent or
// blank result — never a dropped-into-nothing viewer.
//
// The 4 reference screens below the document list (Partner disclosures,
// Referral terms, Data notice, Account closure terms — legal_reference_
// screens.dart) are a DIFFERENT, real set of documents with no artboard of
// their own anywhere in the current canvas (RULINGS.md: `restyle-only`,
// "keep and restyle"). They stay, unchanged by this pass — legal_reference_
// screens.dart is another agent's file.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
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
  String? _openingId;

  /// Fetches the presigned download URL for [doc] and opens it in the
  /// phone's native file viewer — matches legal_preview_screen.dart's
  /// `_openLegalDocument` exactly (that helper is file-private to onboarding
  /// and can't be imported; screen-local duplication is this codebase's own
  /// established pattern for a one-off of a few lines, see e.g.
  /// complaint_screen.dart's `_TappableField`). `doc.fileObjectKey` empty
  /// means no file has been uploaded for this document at all (a real
  /// backend state); a non-empty key can still 404 once opened (BR-6, see
  /// file header) — nothing client-side can tell those apart in advance, so
  /// both surface as an honest snackbar rather than a silent failure.
  Future<void> _open(LegalDocument doc) async {
    if (doc.fileObjectKey.isEmpty) {
      _snack("${doc.title} hasn't been uploaded yet.");
      return;
    }
    setState(() => _openingId = doc.id);
    try {
      final url = await _repo.downloadUrl(doc.id);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack("Couldn't open ${doc.title}. Try again.");
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
    if (mounted) setState(() => _openingId = null);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          // Two visibly distinct groups, per s03c's own document-card
          // treatment (icon + download glyph, opens the real file) vs. the
          // 4 reference screens below (legal_reference_screens.dart —
          // a different, undesigned feature; see file header), which stay
          // chevron rows since they navigate to another in-app screen
          // rather than opening an external file. The download-vs-chevron
          // glyph difference carries the distinction, so no extra heading
          // text is needed.
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${docs.length} document${docs.length == 1 ? '' : 's'}. '
                  'Tap one to open the file.',
                  style: KType.body(color: KColor.ink2),
                ),
                const SizedBox(height: 14),
                for (final doc in docs) ...[
                  _LegalDocRow(
                    title: doc.title,
                    sub: doc.sub,
                    busy: _openingId == doc.id,
                    onTap: _openingId != null ? null : () => _open(doc),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 14),
                KAccountCard(
                  children: [
                    KAccountRow(
                      icon: 'card',
                      title: 'Partner disclosures',
                      right: const KRowChevron(),
                      first: true,
                      onTap: () => context.push(Routes.acctLegalPartnerDisclosures),
                    ),
                    KAccountRow(
                      icon: 'send',
                      title: 'Referral terms',
                      right: const KRowChevron(),
                      onTap: () => context.push(Routes.acctLegalReferralTerms),
                    ),
                    KAccountRow(
                      icon: 'shieldCheck',
                      title: 'Data notice · NDPA',
                      right: const KRowChevron(),
                      onTap: () => context.push(Routes.acctLegalDataNotice),
                    ),
                    KAccountRow(
                      icon: 'close',
                      title: 'Account closure terms',
                      right: const KRowChevron(),
                      onTap: () => context.push(Routes.acctLegalClosureTerms),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One of s03c's document cards — icon bubble + title/sub + a trailing
/// download glyph that becomes a small spinner while its file is being
/// fetched. Screen-local; mirrors legal_preview_screen.dart's own
/// `_LegalDocRow` exactly (same reasoning as `_open` above for why this is
/// duplicated rather than shared).
class _LegalDocRow extends StatelessWidget {
  const _LegalDocRow({
    required this.title,
    required this.sub,
    required this.busy,
    required this.onTap,
  });
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
