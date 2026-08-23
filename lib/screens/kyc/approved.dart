// KYC 8 — approved (success). A centred success StatusView. Sets kycApproved and
// the primary "Start investing" hands off to the suitability questionnaire.
// Mirrors Approved.
//
// WIRING NOTE (kyc-approved pass): per .pipeline/fragments/kyc-approved.json
// this screen used to call AppScope.read(context).setKycApproved(true)
// unconditionally on mount — reaching the route WAS "approved", regardless
// of any real KYC outcome. By design, the only route into this screen is
// kyc-submitted (see router/app_router.dart), which is meant to have
// already confirmed a real `approved` status via `GET /kyc-submissions/me`
// before navigating here. But checked read-only at wiring time,
// lib/screens/kyc/submitted.dart was STILL the unwired stub described in
// .pipeline/fragments/kyc-submitted.json: an unconditional 2600ms Timer
// that calls `context.go(Routes.kycApproved)` with no status check at all
// (SEAM comment: "replace with the KYC provider's approval callback").
// There is no ordering guarantee between that screen's wiring pass and this
// one, so the precondition this screen is supposed to be able to trust
// could not be confirmed as enforced. Per this pass's brief, that doubt is
// exactly the trigger to add a defensive re-check here rather than assume:
// this screen now calls `GET /kyc-submissions/me` itself via the shared
// `KycRepository.me()` (also used by kyc-submitted's own re-check — see
// lib/data/repositories/kyc_repository.dart, extended additively) and only
// flips `AppState.kycApproved` / shows the success view when the fetched
// `status` is genuinely `"approved"`. Any other status (or a failed
// request) shows an inline non-celebratory state instead — see
// _buildForStatus / the FutureBuilder error branch below. If a later pass
// confirms kyc-submitted enforces the precondition itself, this re-check
// becomes redundant but harmless (one extra always-fast GET on an
// already-authenticated, already-approved user) rather than wrong.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class ApprovedScreen extends StatefulWidget {
  const ApprovedScreen({super.key});

  @override
  State<ApprovedScreen> createState() => _ApprovedScreenState();
}

class _ApprovedScreenState extends State<ApprovedScreen> {
  late final _repo = KycRepository(AppScope.read(context).apiClient);
  late Future<KycSubmissionStatus> _statusFuture = _checkStatus();

  /// Confirms the real status via GET /kyc-submissions/me. Only flips the
  /// gate flag — the thing that used to happen unconditionally on mount —
  /// once that confirmation genuinely says "approved".
  Future<KycSubmissionStatus> _checkStatus() async {
    final result = await _repo.me();
    if (result.isApproved && mounted) {
      AppScope.read(context).setKycApproved(true);
    }
    return result;
  }

  void _retry() {
    setState(() => _statusFuture = _checkStatus());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          child: Center(
            child: FutureBuilder<KycSubmissionStatus>(
              future: _statusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const KStatusView(
                    tone: KStatusTone.pending,
                    title: 'Confirming your verification…',
                    message: 'Just a moment while we check your KYC status.',
                  );
                }
                if (snapshot.hasError) {
                  final message = snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Something went wrong. Please try again.';
                  return KStatusView(
                    tone: KStatusTone.error,
                    title: "Couldn't confirm your verification",
                    message: message,
                    primary: 'Try again',
                    onPrimary: _retry,
                    secondary: 'Back to home',
                    onSecondary: () => context.go(Routes.home),
                  );
                }
                return _buildForStatus(snapshot.data!.status);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForStatus(String status) {
    if (status == 'approved') {
      // Goes straight to Home, not the suitability questionnaire
      // (2026-08-20 fix — the questionnaire is no longer part of the
      // mandatory post-KYC flow at all: "make the assessment optional or
      // hide it for now — the one that comes after KYC". Removing it from
      // tradingEligibilityGap alone wasn't enough — this screen's single
      // button was still the only way forward, and it went straight to
      // the questionnaire regardless). The questionnaire screen itself is
      // unchanged and still reachable for anyone who wants to complete it
      // voluntarily.
      // KMilestoneSheet, not KStatusView — a once-per-investor celebration
      // moment (2026-08-22 "Soft Landing", screen 25), sun-tinted rather
      // than the routine pending/error status views below. Same
      // "Start investing" -> Home behaviour as before (2026-08-20 fix: the
      // questionnaire is no longer mandatory post-KYC — do not point this
      // at Routes.questionnaire again).
      return KMilestoneSheet(
        illustrationName: 'kyc-approved',
        eyebrow: 'Verification complete',
        title: "You're verified",
        message: 'Your money is ready to invest.',
        // fullWidth: false — KMilestoneSheet lays this out in a Wrap, which
        // gives children unbounded width; a fullWidth (the KButton default)
        // button asks for infinite width there and renders as a visible
        // overflow glitch (found live via test/shots.dart).
        primary: KButton(
          label: 'Start investing',
          fullWidth: false,
          onPressed: () => context.go(Routes.home),
        ),
      );
    }
    if (status == 'pending' || status == 'review') {
      return KStatusView(
        tone: KStatusTone.pending,
        title: "We're still reviewing your details",
        message:
            "This usually takes a few minutes. We'll notify you when you're verified.",
        secondary: 'Back to home',
        onSecondary: () => context.go(Routes.home),
      );
    }
    if (status == 'rejected' || status == 'flagged' || status == 'expired') {
      // Genuinely terminal non-approved outcome — defer to the dedicated
      // outcome screen, which re-fetches to decide the specific UI
      // (resubmit / contact support / manual review / restart) rather than
      // duplicating that logic here. Scheduled post-frame since this is
      // reached from inside a FutureBuilder's build, not an event handler.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.kycOutcome);
      });
      return const KStatusView(
        tone: KStatusTone.pending,
        title: 'One moment…',
      );
    }
    // Anything unexpected — show a non-celebratory status rather than the
    // success view.
    return KStatusView(
      tone: KStatusTone.error,
      title: "We couldn't verify you",
      message: 'Please contact support or try submitting your details again.',
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }
}
