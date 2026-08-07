// KYC 7 — next of kin (post-check; no step strip). Name / relationship / phone.
// Mirrors NextOfKin. Continue submits the application: POST /kyc-submissions
// with the fields accumulated across all 5 KYC screens (KycFormState), then
// registers any documents uploaded earlier (id_upload.dart / liveness.dart)
// against the new submission id, then sets kycSubmitted and advances to the
// Submitted (pending review) screen. See lib/data/api/README.md,
// lib/data/repositories/kyc_repository.dart (submission) and
// lib/data/repositories/kyc_document_repository.dart (document
// registration).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/kyc_document_repository.dart';
import 'package:kudimata_securities/data/repositories/kyc_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import '_kyc_chrome.dart';

class NextOfKinScreen extends StatefulWidget {
  const NextOfKinScreen({super.key});

  @override
  State<NextOfKinScreen> createState() => _NextOfKinScreenState();
}

class _NextOfKinScreenState extends State<NextOfKinScreen> {
  final _name = TextEditingController();
  final _rel = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = AppScope.read(context);
    final kycForm = app.kycForm;
    kycForm.setNextOfKinName(_name.text);
    kycForm.setNextOfKinRelationship(_rel.text);
    kycForm.setNextOfKinPhone(_phone.text);

    setState(() => _busy = true);
    final repo = KycRepository(app.apiClient);
    final docRepo = KycDocumentRepository(app.apiClient);
    try {
      final submissionId = await repo.submit(kycForm.toSubmissionBody());
      // Documents uploaded on kyc-id / kyc-liveness could only stash
      // objectKey+documentKind in KycFormState (no kycSubmissionId existed
      // yet). Register every accumulated document against the submission
      // that now exists, completing that handoff.
      for (final doc in kycForm.documents) {
        await docRepo.registerDocument(
          kycSubmissionId: submissionId,
          objectKey: doc.objectKey,
          documentName: _documentName(doc.documentKind),
          documentKind: doc.documentKind,
        );
      }
      if (!mounted) return;
      app.setKycSubmitted(true);
      context.go(Routes.kycSubmitted);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, message: e.message);
    }
  }

  /// registry.json's KycDocument has no separate "display name" collected
  /// anywhere upstream — only objectKey + documentKind survive to this
  /// screen (KycFormState.documents) — so this derives a human-readable
  /// `documentName` from the enum kind for the POST /kyc-documents body.
  String _documentName(String kind) => switch (kind) {
        'nin' => 'NIN',
        'passport' => 'Passport',
        'drivers_licence' => "Driver's licence",
        'proof_of_address' => 'Proof of address',
        'liveness_selfie' => 'Liveness selfie',
        _ => kind,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KycTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 8, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Next of kin'),
                    const SizedBox(height: 20),
                    KCard(
                      child: Column(
                        children: [
                          KInput(
                              label: 'Full name',
                              placeholder: 'Amara Okafor',
                              controller: _name),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Relationship',
                              placeholder: 'Sister',
                              controller: _rel),
                          const SizedBox(height: 16),
                          KInput(
                              label: 'Phone number',
                              prefix: '+234',
                              placeholder: '801 234 5678',
                              keyboardType: TextInputType.phone,
                              controller: _phone),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(
                label: 'Continue',
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the POST /kyc-submissions (or a document registration) call
/// fails with an [ApiException] — [message] is that exception's
/// human-readable summary (safe to show directly, per
/// lib/data/api/api_exception.dart). The form's entered values stay intact
/// so the user can retry without re-typing anything.
void _showErrorSheet(BuildContext context, {required String message}) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: 'Submission failed',
        message: message,
        primary: 'Try again',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}
