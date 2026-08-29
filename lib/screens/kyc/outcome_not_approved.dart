// KYC — non-approved terminal outcome (rejected / flagged / expired). A
// centred StatusView, exactly like kyc-submitted's pending view and
// kyc-approved's success view, but for the three genuinely-terminal
// non-approved statuses KycSubmission.status (registry.json) allows:
// rejected | flagged | expired. pending/review are NOT routed here — those
// stay on kyc-submitted/kyc-approved's existing "we're reviewing" view,
// which is accurate copy for them.
//
// NO ARTBOARD — R-10 (docs/redesign/DECISIONS.md): "Rejected / flagged /
// expired outcomes keep their existing behaviour ... but the screen is
// authored fresh against the redesign's patterns rather than waiting for an
// artboard. The layout is ours; that is recorded here so nobody later
// mistakes it for designer intent." This layout is therefore an original
// composition, not a transcription of a canvas artboard. It matches the
// *pattern* of the redesign's other KYC outcome screens instead — same bare
// `KColor.bg` scaffold, same centred `KStatusView` (illustration plate,
// title, message, stacked buttons), same button styles — as drawn by
// `s20`/`s20d` "Under review" and `s21`/`s21d` "Verified" in
// `docs/design/redesign-2026-08/02 Verification.dc.html`, and as built in
// this app by `submitted.dart` (s20) and `approved.dart` (s21). No new
// visual idiom is introduced here.
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
//     KycFormState.reset) and restarts the KYC collection flow at kyc-bvn.
//     If attempts are exhausted, "Contact support" instead —
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
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

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

  /// Clears the shared in-progress form so kyc-bvn starts clean, then
  /// restarts the KYC collection flow.
  void _restartKyc() {
    AppScope.read(context).kycForm.reset();
    context.go(Routes.kycBvn);
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
    // Checked before the switch — a staff reject with resubmission room
    // left sends status back to 'pending' (not a terminal value), per the
    // backend's own contract, so it can't be a normal switch case on
    // `status` alone. See isRejectedWithRoomToRetry's doc comment. Fixes:
    // "it was rejected but app still told me under review".
    if (result.isRejectedWithRoomToRetry) {
      return _buildRejected(result);
    }
    switch (result.status) {
      case 'rejected':
        return _buildRejected(result);
      case 'flagged':
        return _buildFlagged(result);
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

  /// Plain-language reasons, derived from the real per-check signals
  /// (2026-08-20 fix — reported: "on the dashboard and on the app WE CAN'T
  /// TELL WHAT WAS WRONG... not manual review, if rejected they should see
  /// the reason"). Only lists checks that actually FAILED (false) — a null
  /// signal means that check never ran, not a problem. Empty when there's
  /// no per-check breakdown to draw from (an older submission from before
  /// this fix, or a decision made for some other reason).
  List<String> _failedChecks(KycSubmissionStatus result) {
    final s = result.verificationSignals;
    if (s == null) return const [];
    return [
      if (s.nin == false) 'Your NIN could not be verified',
      if (s.bvn == false) 'Your BVN could not be verified',
      if (s.name == false) "Your name didn't match your registered ID",
      if (s.dob == false) "Your date of birth didn't match your registered ID",
      if (s.liveness == false) "Your face liveness check didn't pass",
    ];
  }

  Widget _buildRejected(KycSubmissionStatus result) {
    final reasons = _failedChecks(result);
    final message = reasons.isNotEmpty
        ? '${reasons.join('. ')}.'
        : (result.flagDetail?.trim().isNotEmpty == true
            ? result.flagDetail!
            : (result.flagReason?.trim().isNotEmpty == true
                ? result.flagReason!
                : "We weren't able to verify your details."));
    final canResubmit = result.canResubmit;
    return KStatusView(
      tone: KStatusTone.error,
      illustrationName: 'kyc-not-approved',
      title: "We couldn't verify you",
      message: message,
      primary: canResubmit ? 'Resubmit documents' : 'Contact support',
      onPrimary: canResubmit ? _restartKyc : () => context.go(Routes.acctHelp),
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }

  Widget _buildFlagged(KycSubmissionStatus result) {
    // "we'll notify you" dropped for the same reason as submitted.dart's
    // s20 pending copy: no push/email mechanism backs it. This class is
    // still signed in and the router's gate only checks signedIn, not
    // kycApproved (see this file's header comment), so — same as
    // pending/review — they can keep using the app; the copy says that
    // instead of a promise nothing delivers on.
    final reasons = _failedChecks(result);
    final message = reasons.isNotEmpty
        ? "${reasons.join('. ')}. One of our team is taking a closer look — you can keep using the app while that happens."
        : "One of our team needs to take a closer look at your submission. You can keep using the app while that happens.";
    return KStatusView(
      tone: KStatusTone.pending,
      illustrationName: 'kyc-not-approved',
      title: 'Your account needs manual review',
      message: message,
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }

  Widget _buildExpired() {
    return KStatusView(
      tone: KStatusTone.error,
      illustrationName: 'timeout',
      title: 'Your submission expired',
      message: "It's been a while since you started — please start your verification again.",
      primary: 'Start again',
      onPrimary: _restartKyc,
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }
}
