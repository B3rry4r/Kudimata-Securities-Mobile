// KYC 5 — verifying liveness (interstitial between step 3 and step 4 of 5).
// A centred spinner while the REAL liveness check runs server-side.
//
// REPURPOSED 2026-08-20 (phased-KYC directive): previously a pure UX-pacing
// timer with no backend call at all ("SEAM: the KYC provider's verification
// result replaces this timer" — this pass IS that replacement). Now calls
// POST /kyc-submissions/draft/liveness, which reads the selfie
// liveness.dart already uploaded+registered against the draft and actually
// runs the check. On success, advances to the utility-bill step (step 4);
// on failure, shows a retryable error state rather than silently
// continuing — this is a real verification call now, not a mocked delay.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

class CheckingScreen extends StatefulWidget {
  const CheckingScreen({super.key});

  @override
  State<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends State<CheckingScreen> {
  late final _repo = KycRepository(AppScope.read(context).apiClient);
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() => _error = null);
    try {
      await _repo.verifyDraftLiveness();
      if (!mounted) return;
      context.go(Routes.kycUtilityBill);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      // Widened from `on ApiException` only (2026-08-20) — any OTHER
      // exception type used to leave `_error` unset, which meant the
      // spinner + "Checking your selfie…" copy stayed up forever with no
      // way to retry, since this build() only shows the retry UI once
      // `_error` is non-null.
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
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
            KycTopBar(
              onBack: () => context.go(Routes.kycLiveness),
              stepLabel: 'Verification · 3 of 5',
            ),
            const KycStepProgress(total: 5, current: 3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _error != null
                      ? [
                          const KIllustration('error', role: KIlloRole.state),
                          const SizedBox(height: 22),
                          Text("Couldn't complete your face liveness check",
                              textAlign: TextAlign.center, style: KType.section()),
                          const SizedBox(height: 10),
                          Text(_error!, textAlign: TextAlign.center, style: KType.body(color: KColor.ink2)),
                          const SizedBox(height: 22),
                          KButton(label: 'Try again', onPressed: _verify),
                        ]
                      : [
                          const KIllustration('kyc-checking', role: KIlloRole.state),
                          const SizedBox(height: 22),
                          Text('Checking your face liveness…',
                              textAlign: TextAlign.center, style: KType.section()),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
