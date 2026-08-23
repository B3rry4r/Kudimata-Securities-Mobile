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

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'document_summary_screen.dart';

class LegalPreviewScreen extends StatefulWidget {
  const LegalPreviewScreen({super.key, required this.kind});

  /// 'terms_of_service' | 'privacy_policy' | 'risk_disclosure'.
  final String kind;

  static const _titles = {
    'terms_of_service': 'Terms of Service',
    'privacy_policy': 'Privacy Policy',
    'risk_disclosure': 'Risk Disclosure',
  };

  // Plain-English summaries (2026-08-22 "Soft Landing" redesign, screen 06):
  // static per-document copy, not generated — see docs/redesign/PLAN.md and
  // document_summary_screen.dart's header comment for why. `original` (the
  // full document) still comes from the real GET /public/legal-documents
  // fetch below — only the summary/points on top of it are static.
  static const _summaries = {
    'terms_of_service':
        'This is the agreement between you and Kudimata Securities Ltd for using the app — what we do, what you\'re responsible for, and how either side can end it.',
    'privacy_policy':
        'What information we collect about you, why we collect it, and who we share it with (mainly regulators and the partners that make trading and payments work).',
    'risk_disclosure':
        'Trading shares can lose you money, and Kudimata cannot promise any return. You are the one deciding what to buy.',
  };

  static const _points = {
    'terms_of_service': [
      'You must be 18+ and provide accurate KYC information to use the app.',
      'Kudimata can suspend an account that breaks these terms or looks fraudulent.',
      'Fees for trades and transfers are disclosed before you confirm an order.',
    ],
    'privacy_policy': [
      'We share what NIBSS/NIMC require to verify your identity (BVN, NIN).',
      'We never sell your personal data to advertisers.',
      'You can request a copy or deletion of your data through support.',
    ],
    'risk_disclosure': [
      'Share prices fall as well as rise — you can lose some or all of what you invest.',
      'Past performance of a stock is not a promise of future performance.',
      'Only invest money you won\'t need for the next few years.',
    ],
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
          summary: LegalPreviewScreen._summaries[widget.kind] ??
              'A plain-English summary isn\'t available for this document yet — read the original below.',
          points: LegalPreviewScreen._points[widget.kind] ?? const [],
          original: original.toString().trim(),
        );
      },
    );
  }
}
