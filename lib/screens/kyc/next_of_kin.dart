// KYC 7 — next of kin (step 5 of 5, final). Name / relationship / phone.
// Continue finalizes the draft: POST /kyc-submissions/draft/finalize
// (2026-08-20, phased-KYC directive — was POST /kyc-submissions, the
// all-at-once call, before this) — requires steps 2-4 (id document,
// liveness, utility bill) already done, computes the real vendorDecision
// from everything accumulated across the earlier steps, and leaves
// 'draft' for good. Then sets kycSubmitted, clears the held draft id
// (KycFormState.reset), and advances to the Submitted (pending review)
// screen. See lib/data/repositories/kyc_repository.dart.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
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
    setState(() => _busy = true);
    final repo = KycRepository(app.apiClient);
    try {
      await repo.finalizeDraft(
        nextOfKinName: _name.text,
        nextOfKinRelationship: _rel.text,
        nextOfKinPhone: _phone.text,
      );
      if (!mounted) return;
      app.kycForm.reset();
      app.setKycSubmitted(true);
      context.go(Routes.kycSubmitted);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, message: e.message);
    } catch (_) {
      // Widened from `on ApiException` only (2026-08-20) — any OTHER
      // exception type used to leave `_busy` stuck true forever (a
      // permanent loading spinner on the final submit button).
      if (!mounted) return;
      setState(() => _busy = false);
      _showErrorSheet(context, message: 'Something went wrong. Please try again.');
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
            KycTopBar(onBack: () => context.go(Routes.kycUtilityBill)),
            const KycStepProgress(total: 5, current: 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 8, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Next of kin',
                      body:
                          "Who should we contact about your account if we can't reach you? The CSCS requires this.",
                    ),
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
                // This app's flow has no separate review screen (spec 22) —
                // this button IS the final submit (calls finalizeDraft
                // directly), so it gets that screen's real button label
                // rather than a generic "Continue" on the last step.
                label: 'Submit for verification',
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
