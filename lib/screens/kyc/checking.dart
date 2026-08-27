// KYC — verifying liveness (interstitial right after step 4 of 7, before step
// 5; renumbered 8->7 2026-08-27 per X-2/bvn_nin.dart's derivation).
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
              stepLabel: 'Verification · 4 of 7',
            ),
            const KycStepProgress(total: 7, current: 4),
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
                          // s16's own title/body, verbatim.
                          Text('Checking your selfie',
                              textAlign: TextAlign.center, style: KType.section()),
                          const SizedBox(height: 10),
                          Text('Done on the spot. If it fails, you just retake it.',
                              textAlign: TextAlign.center, style: KType.body(color: KColor.ink2)),
                          // 2026-08-24 fix: this file's own header comment
                          // has always claimed "a centred spinner while the
                          // REAL liveness check runs server-side" — it was
                          // never actually in the widget tree, just the
                          // static illustration above. A static image gives
                          // no sense that anything is actively happening —
                          // direct feedback: "checking your face liveness
                          // has to also show a loader".
                          const SizedBox(height: 18),
                          const KSpinner(size: 28),
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
