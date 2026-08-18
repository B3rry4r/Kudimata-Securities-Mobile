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

class LegalPreviewScreen extends StatefulWidget {
  const LegalPreviewScreen({super.key, required this.kind});

  /// 'terms_of_service' | 'privacy_policy' | 'risk_disclosure'.
  final String kind;

  static const _titles = {
    'terms_of_service': 'Terms of Service',
    'privacy_policy': 'Privacy Policy',
    'risk_disclosure': 'Risk Disclosure',
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
                  onPrimary: () =>
                      setState(() => _future = _repo.getPublicContent(widget.kind)),
                );
              }
              final doc = snapshot.data!;
              return KCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
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
              );
            },
          ),
        ),
      ),
    );
  }
}
