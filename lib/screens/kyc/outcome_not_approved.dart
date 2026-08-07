// KYC — non-approved terminal outcome (rejected / flagged / expired). A
// centred StatusView, exactly like kyc-submitted's pending view and
// kyc-approved's success view, but for the three genuinely-terminal
// non-approved statuses KycSubmission.status (registry.json) allows:
// rejected | flagged | expired. pending/review are NOT routed here — those
// stay on kyc-submitted/kyc-approved's existing "we're reviewing" view,
// which is accurate copy for them.
//
// Reached from kyc-submitted (initial post-submit check) and kyc-approved
// (its defensive re-check — see that file's header) via
// `context.go(Routes.kycOutcome)`. This screen re-fetches the status itself
// via the same `KycRepository.me()` both callers already use, rather than
// trusting data passed through GoRouter `extra` — mirrors kyc-approved's
// own "don't assume the precondition was enforced upstream" defensive
// re-check, and means this screen also works if ever reached directly.
//
// Per registry.json's KycSubmission resource:
//   - rejected: `flagReason`/`flagDetail` explain why (support-authored,
//     shown verbatim when present). `attemptCount`/`maxAttempts` gate
//     whether resubmission is still allowed — if attempts remain, "Resubmit
//     documents" clears the in-memory KycFormState (a fresh attempt must
//     not carry over the rejected attempt's stale fields — see
//     KycFormState.reset) and restarts the 5-screen KYC collection flow at
//     kyc-personal. If attempts are exhausted, "Contact support" instead —
//     no resubmit option.
//   - flagged: needs a human reviewer, not a resubmission, so there is
//     never a resubmit action here. The investor is still signed in and the
//     app's gate redirect (`_gateRedirect` in app_router.dart) only checks
//     `signedIn`, not `kycApproved` — limited app features remain reachable
//     — so the action is "Back to home", same as pending/review.
//   - expired: same restart action as rejected-with-attempts-remaining
//     (expiry isn't a decision against the investor, just a stale
//     submission), so no attempt-count check applies here.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/kyc_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class KycOutcomeScreen extends StatefulWidget {
  const KycOutcomeScreen({super.key});

  @override
  State<KycOutcomeScreen> createState() => _KycOutcomeScreenState();
}

class _KycOutcomeScreenState extends State<KycOutcomeScreen> {
  late final _repo = KycRepository(AppScope.read(context).apiClient);
  late Future<KycSubmissionStatus> _statusFuture = _repo.me();

  void _retry() {
    setState(() => _statusFuture = _repo.me());
  }

  /// Clears the shared in-progress form so kyc-personal starts clean, then
  /// restarts the 5-screen KYC collection flow.
  void _restartKyc() {
    AppScope.read(context).kycForm.reset();
    context.go(Routes.kycPersonal);
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
                    title: 'Checking your status…',
                    message: 'Just a moment while we check your KYC status.',
                  );
                }
                if (snapshot.hasError) {
                  final message = snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Something went wrong. Please try again.';
                  return KStatusView(
                    tone: KStatusTone.error,
                    title: "Couldn't check your status",
                    message: message,
                    primary: 'Try again',
                    onPrimary: _retry,
                    secondary: 'Back to home',
                    onSecondary: () => context.go(Routes.home),
                  );
                }
                return _buildForStatus(snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForStatus(KycSubmissionStatus result) {
    switch (result.status) {
      case 'rejected':
        return _buildRejected(result);
      case 'flagged':
        return _buildFlagged();
      case 'expired':
        return _buildExpired();
      default:
        // Defensive fallback only — kyc-submitted/kyc-approved route here
        // exclusively for rejected/flagged/expired, but avoid a dead end if
        // the status has since changed (e.g. re-decided) underneath us.
        return KStatusView(
          tone: KStatusTone.error,
          title: "We couldn't verify you",
          message: 'Please contact support or try again.',
          secondary: 'Back to home',
          onSecondary: () => context.go(Routes.home),
        );
    }
  }

  Widget _buildRejected(KycSubmissionStatus result) {
    final message = result.flagDetail?.trim().isNotEmpty == true
        ? result.flagDetail!
        : (result.flagReason?.trim().isNotEmpty == true
            ? result.flagReason!
            : "We weren't able to verify your details.");
    final canResubmit = result.canResubmit;
    return KStatusView(
      tone: KStatusTone.error,
      title: "We couldn't verify you",
      message: message,
      primary: canResubmit ? 'Resubmit documents' : 'Contact support',
      onPrimary: canResubmit ? _restartKyc : () => context.go(Routes.acctHelp),
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }

  Widget _buildFlagged() {
    return KStatusView(
      tone: KStatusTone.pending,
      title: 'Your account needs manual review',
      message:
          "One of our team needs to take a closer look at your submission. We'll notify you once it's resolved.",
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }

  Widget _buildExpired() {
    return KStatusView(
      tone: KStatusTone.error,
      title: 'Your submission expired',
      message: "It's been a while since you started — please start your verification again.",
      primary: 'Start again',
      onPrimary: _restartKyc,
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }
}
