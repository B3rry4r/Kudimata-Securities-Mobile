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
//   - rejected AND flagged: as of R-50 (DECISIONS.md, 2026-08-31, "every
//     failed KYC can be retried, and the app says what went wrong") these
//     two share one build path — `_buildFailure` below. Both offer "Try
//     again" (clears KycFormState and restarts at kyc-bvn — a fresh
//     attempt must not carry over the failed attempt's stale fields, see
//     KycFormState.reset) while `attemptCount < maxAttempts` AND no reason
//     is marked non-retryable; otherwise "Contact support", never a button
//     that will just fail again. `maxAttempts` rose from 3 to 5 under
//     R-50 — a backend value this screen only ever reads, never hardcodes.
//     R-50 SUPERSEDES R-48 (which offered a retry only for a liveness-only
//     failure) and the older rule this header used to describe (flagged
//     always dead-ended at "Back to home", never offering a retry — the
//     defect the owner hit on 2026-08-31).
//   - The one exception, carried over from R-50 verbatim: a sanctions/AML
//     match is never explained specifically — see [KycFailureReason]'s own
//     doc comment for why that's a legal requirement (tipping-off), not an
//     omission. That reason arrives with `retryable: false`, which is
//     exactly what removes the retry control here.
//   - expired: a genuine restart (`_restartKyc`) — expiry isn't a decision
//     against the investor, just a stale submission, so no attempt-count
//     check applies here. This is now the ONLY path that still wipes the
//     form and returns to step 1.
//
// 2026-09-01 — "Try again" stopped meaning "start over". It calls
// `POST /kyc-submissions/retry` (KycRepository.retry) on the SAME
// submission, which keeps every check that passed, keeps the ID document
// and the utility bill, deletes only a stale liveness selfie, and re-runs
// anything a provider never answered without involving the investor. This
// screen then lands them on the step that actually failed
// (`failedKycStepRoutes`, kyc_checklist_screen.dart) rather than on step 1.
// It also now handles a `pending` submission the server is willing to
// retry — the provider-outage case, which used to sit on kyc-submitted's
// "we're reviewing your details" with no control anywhere; see
// `_buildProviderUnavailable`.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'kyc_checklist_screen.dart' show failedKycStepRoutes;

class KycOutcomeScreen extends StatefulWidget {
  const KycOutcomeScreen({super.key});

  @override
  State<KycOutcomeScreen> createState() => _KycOutcomeScreenState();
}

class _KycOutcomeScreenState extends State<KycOutcomeScreen> {
  late final _repo = KycRepository(AppScope.read(context).apiClient);
  late Future<KycSubmissionStatus> _statusFuture = _repo.me();

  /// True while POST /kyc-submissions/retry is in flight — the button
  /// shows a spinner instead of firing twice.
  bool _retrying = false;

  /// Set when the retry call itself was refused or failed (409/422/network),
  /// shown under the outcome copy rather than replacing it. Null otherwise.
  String? _retryError;

  void _retry() {
    setState(() => _statusFuture = _repo.me());
  }

  /// Clears the shared in-progress form so kyc-bvn starts clean, then
  /// restarts the KYC collection flow. Used ONLY for a genuinely fresh
  /// start (an expired submission) — a failed one goes through
  /// [_retryFailedChecks], which keeps everything that passed.
  void _restartKyc() {
    AppScope.read(context).kycForm.reset();
    context.go(Routes.kycBvn);
  }

  /// Defect B's fix (2026-09-01). Asks the backend to retry THIS submission
  /// — which reuses the same row, keeps every check that passed, keeps the
  /// ID document and the utility bill, deletes only a stale liveness
  /// selfie, and re-runs anything a provider never answered without
  /// involving the investor — then lands them on the step that actually
  /// failed, carrying forward everything that did not.
  ///
  /// The failed steps are read from the status BEFORE the call, because
  /// the retry itself is what clears those `false` signals back to null.
  Future<void> _retryFailedChecks(KycSubmissionStatus before) async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryError = null;
    });

    final steps = failedKycStepRoutes(before);
    final app = AppScope.read(context);
    try {
      final retried = await _repo.retry();
      if (!mounted) return;

      // Keep the draft: this is the SAME submission row, and the next
      // document upload has to register against it. See KycFormState.reset.
      final form = app.kycForm;
      form.reset(keepDraft: true);
      final id = retried.id;
      if (id != null) form.setDraftId(id);
      // Re-seed next of kin from the server's own copy, so re-finalizing
      // never asks the investor to retype what they already gave us (and
      // works even in a session that never collected it).
      final nok = retried.nextOfKin;
      if (nok != null) {
        form.setNextOfKin(
          name: nok.name,
          relationship: nok.relationship,
          phone: nok.phone,
          email: nok.email,
        );
      }

      if (retried.status != 'draft') {
        // Nothing was handed back — the retry resolved server-side (the
        // provider answered this time, or is still down). kyc-submitted
        // re-checks and routes on the REAL outcome, including back here.
        context.go(Routes.kycSubmitted);
        return;
      }
      if (steps.isNotEmpty) {
        context.go(steps.first);
        return;
      }
      // Reopened with nothing specific to redo — the checklist hub derives
      // the right next step from the draft's real state.
      context.go(Routes.kycChecklist);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _retryError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _retryError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        // R-50 (2026-08-31) lengthened this screen's message text — real
        // per-reason copy plus an attempts-remaining sentence can run
        // longer than the fixed message this screen shipped with, and a
        // bare Center+Padding has no give: on a short viewport the extra
        // text overflows instead of scrolling. Scrollable-but-still-
        // centered when content fits — same pattern as liveness.dart's
        // SizedBox/ConstrainedBox (KOnboardBody uses it too), found the
        // same way: a real-viewport widget test overflowed, not a visual
        // guess.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: maxH.isFinite ? maxH : 0),
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
            );
          },
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
      return _buildFailure(result, isFlagged: false);
    }
    // 2026-09-01, defect A's app half. A submission left open because a
    // verification provider never ANSWERED a check is not a decision
    // against the investor and must not be dressed as one: nothing they
    // submitted is wrong, and the server will re-run the lookup itself
    // from what they already gave us. Recognised from the backend's own
    // `canRetry` (see KycSubmissionStatus.isAwaitingUnansweredCheck), not
    // from a rule this screen invents.
    if (result.isAwaitingUnansweredCheck) {
      return _buildProviderUnavailable(result);
    }
    switch (result.status) {
      case 'rejected':
        return _buildFailure(result, isFlagged: false);
      case 'flagged':
        return _buildFailure(result, isFlagged: true);
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

  /// The known-bad shape `flagDetail`/`flagReason` has shipped in — a raw
  /// internal per-signal dump, e.g. "nin=true, bvn=true, liveness=false,
  /// name=true", never written for an investor to read (BR-10,
  /// BACKEND_GAPS.md). R-50: this screen must not parse that string into
  /// structured data — this check does NOT do that; it only recognises the
  /// shape well enough to refuse to show it verbatim, same as any other
  /// "this isn't real copy" guard.
  bool _looksLikeDebugDump(String s) =>
      RegExp(r'^([a-zA-Z]+\s*=\s*(true|false)\s*,?\s*)+$').hasMatch(s);

  /// Resolves what to tell the investor, preferring [KycFailureReason] —
  /// the structured shape this screen is BUILT AGAINST per R-50/BR-10 (see
  /// that class's own doc comment) — over the per-check booleans and free
  /// text this app already had. `result.failureReasons` is null for every
  /// real response today (the backend hasn't shipped it), so this always
  /// falls through to the second block below in practice; the moment it
  /// does ship, this screen picks it up with no further change here.
  List<KycFailureReason> _resolveFailureReasons(KycSubmissionStatus result) {
    final structured = result.failureReasons;
    if (structured != null) return structured;

    // Fallback — today's real data. Every reason derived this way is
    // `retryable: true`: the current wire shape has no field at all that
    // could mark a case as a sanctions/AML decision (that distinction only
    // exists once `failureReasons` ships), so nothing here can honestly
    // claim otherwise.
    final fromSignals = <KycFailureReason>[
      for (final entry in {
        'nin': (result.verificationSignals?.nin, 'Your NIN could not be verified'),
        'bvn': (result.verificationSignals?.bvn, 'Your BVN could not be verified'),
        'name': (result.verificationSignals?.name, "Your name didn't match your registered ID"),
        'dob': (result.verificationSignals?.dob, "Your date of birth didn't match your registered ID"),
        'liveness': (result.verificationSignals?.liveness, "Your face liveness check didn't pass"),
      }.entries)
        if (entry.value.$1 == false)
          KycFailureReason(code: entry.key, message: entry.value.$2, retryable: true),
    ];
    if (fromSignals.isNotEmpty) return fromSignals;

    final detail = result.flagDetail?.trim();
    if (detail != null && detail.isNotEmpty && !_looksLikeDebugDump(detail)) {
      return [KycFailureReason(code: '', message: detail, retryable: true)];
    }
    final reason = result.flagReason?.trim();
    if (reason != null && reason.isNotEmpty && !_looksLikeDebugDump(reason)) {
      return [KycFailureReason(code: '', message: reason, retryable: true)];
    }
    return const [];
  }

  /// R-50 (DECISIONS.md, 2026-08-31): 'rejected' and 'flagged' share this
  /// one build path now — "every failed or rejected outcome offers a
  /// retry... until the attempts are spent." `isFlagged` only changes the
  /// title/illustration copy, never the retry/attempts mechanics — both
  /// statuses now mean the identical thing to the investor: something
  /// failed, here is what, and here is whether trying again can fix it.
  Widget _buildFailure(KycSubmissionStatus result, {required bool isFlagged}) {
    final reasons = _resolveFailureReasons(result);
    // A single non-retryable reason (a sanctions/AML decision — see
    // KycFailureReason's own doc comment) makes the WHOLE case a decision,
    // never mixed with a "try again" control it would be false to offer.
    final decisionOnly = reasons.any((r) => !r.retryable);
    final attemptsLeft = (result.maxAttempts - result.attemptCount).clamp(0, result.maxAttempts);
    final canRetry = !decisionOnly && result.canResubmit;

    final reasonText = reasons.isNotEmpty
        ? reasons.map((r) => r.message).join(' ')
        : (isFlagged
            ? 'One of our team needs to take a closer look at your submission.'
            : "We weren't able to verify your details.");

    final String message;
    if (canRetry) {
      final triesWord = attemptsLeft == 1 ? 'try' : 'tries';
      message = '$reasonText You can try again — $attemptsLeft $triesWord left.';
    } else if (decisionOnly) {
      // Rendered verbatim, on purpose — see KycFailureReason's doc comment
      // on why this app never enriches or second-guesses this message.
      message = reasonText;
    } else {
      // Retryable in kind, but the attempts are spent — R-50: "the screen
      // says so honestly and routes to support, rather than offering a
      // button that will refuse." A human now has the full history, same
      // as a from-the-start sanctions decision, but this is not one —
      // said plainly so the two don't read the same to the investor.
      message = "$reasonText You've used all ${result.maxAttempts} attempts — "
          "one of our team will take it from here.";
    }

    return KStatusView(
      tone: canRetry ? KStatusTone.error : (decisionOnly ? KStatusTone.error : KStatusTone.pending),
      illustrationName: 'kyc-not-approved',
      // A refused/failed retry call is shown here rather than swallowed —
      // the server's own 409/422 message is the honest reason the button
      // did not do what it said (see _retryFailedChecks).
      extra: _retryError == null
          ? null
          : Text(_retryError!, textAlign: TextAlign.center, style: KType.body(color: KColor.loss)),
      title: isFlagged && !canRetry && !decisionOnly
          ? 'Your account needs manual review'
          : "We couldn't verify you",
      message: message,
      primary: canRetry ? (_retrying ? 'Trying again…' : 'Try again') : 'Contact support',
      // 2026-09-01: was _restartKyc — a full wipe back to step 1 whatever
      // failed. Now retries THIS submission and lands on the step that
      // actually failed; see _retryFailedChecks.
      onPrimary: canRetry
          ? () => _retryFailedChecks(result)
          : () => context.go(Routes.acctHelp),
      secondary: 'Back to home',
      onSecondary: () => context.go(Routes.home),
    );
  }

  /// A submission still open only because a verification provider never
  /// answered — no failed check, nothing for the investor to fix. The real
  /// 2026-09-01 incident: LumiID was unreachable for the NIN lookup (it
  /// even auto-refunded the fee), so that one signal stayed unresolved, the
  /// submission parked on 'pending', and the investor was told a reviewer
  /// would look — while no reviewer had a button either.
  ///
  /// The copy says what is true and what the button does: it re-runs the
  /// check server-side from the BVN/NIN already on file. Nothing to
  /// re-enter, nothing to re-upload.
  Widget _buildProviderUnavailable(KycSubmissionStatus result) {
    return KStatusView(
      tone: KStatusTone.pending,
      illustrationName: 'kyc-checking',
      title: "We couldn't finish checking your ID",
      message: _retryError ??
          "Our ID checking service didn't respond, so one of your checks "
              "never completed. Nothing is wrong with your details — tap "
              "Try again and we'll re-run it. You won't need to re-enter "
              'anything.',
      primary: _retrying ? 'Trying again…' : 'Try again',
      onPrimary: () => _retryFailedChecks(result),
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
