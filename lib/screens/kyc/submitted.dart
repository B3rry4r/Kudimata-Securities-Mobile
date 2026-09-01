// KYC 8 — submitted (pending review). A centred pending StatusView.
//
// The real KYC submission (POST /kyc-submissions/draft/finalize) already
// happened on the PRECEDING next-of-kin screen — see
// lib/screens/kyc/next_of_kin.dart and lib/data/repositories/
// kyc_repository.dart. That screen's response isn't stashed anywhere this
// screen can read, so this screen re-fetches via GET /kyc-submissions/me
// and routes on the REAL outcome: the verification provider's synchronous
// NIN/BVN checks may have already decided it, or it may still be pending
// further review.
//
// POLLING (2026-08-20 fix — reported: staff/investor testing during a
// provider outage found this screen just sits on "we're reviewing your
// details" forever once the FIRST check comes back pending/review, never
// checking again on its own; the investor had to manually leave and
// re-enter the flow to get a fresh check). Now polls every
// _pollInterval while pending/review, instead of checking exactly once.
// Capped at _maxPollDuration of real wall-clock time — after that this
// stops actively polling and just leaves the pending view up (a real
// decision can take longer than that; the investor will see it next time
// they open the app, via Home's "Your KYC is under review" prompt, or a
// notification once staff decides it — this screen doesn't need to poll
// forever in the background to eventually reflect that).
//
// KycSubmission.status (registry.json) is one of draft|pending|review|
// approved|rejected|flagged|expired ('draft' is never reachable here — this
// screen is only entered after finalize() has already moved the submission
// out of it). pending/review stay on this screen's existing "we're
// reviewing your details" pending view — that copy is accurate for those
// two. rejected/flagged/expired are genuinely terminal non-approved
// outcomes and route to Routes.kycOutcome (see
// lib/screens/kyc/outcome_not_approved.dart), which re-fetches the status
// itself to decide the specific outcome UI (resubmit / contact support /
// manual review / restart).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class SubmittedScreen extends StatefulWidget {
  const SubmittedScreen({super.key});

  @override
  State<SubmittedScreen> createState() => _SubmittedScreenState();
}

class _SubmittedScreenState extends State<SubmittedScreen> {
  late final _repo = KycRepository(AppScope.read(context).apiClient);
  Timer? _timer;

  /// First check fires fast (the provider's synchronous nin/bvn checks may
  /// already have decided it); every check after that spaces out — no
  /// point hammering the API once it's genuinely gone to manual review.
  static const _firstCheckDelay = Duration(milliseconds: 1400);
  static const _pollInterval = Duration(seconds: 8);

  /// Stop actively polling after this much real wall-clock time and just
  /// leave the pending view up — a real decision can take longer than
  /// this, and there's no need to poll forever in the background for it;
  /// the investor will see the outcome next time they open the app (Home's
  /// prompt re-checks, or a notification once staff decides it).
  static const _maxPollDuration = Duration(minutes: 10);
  DateTime? _pollingStartedAt;

  /// Non-null only when the status re-check itself failed (network/API
  /// error) — distinct from a successful check that came back non-approved,
  /// which just leaves the pending view showing.
  String? _errorMessage;

  /// The last successful status fetch — canvas screen 23 ("Checking your
  /// details") shows a real per-check list (BVN matched / ID read / address
  /// & bank under review / declaration review), not just one blob message.
  /// This app's real signal set is bvn/nin/name/dob/liveness
  /// (KycVerificationSignals) — a different shape than the canvas's
  /// illustrative example labels, so the checklist below uses THESE real
  /// signal names rather than forcing an exact but fictional label match
  /// (2026-08-24 fix — was previously not rendered as a checklist at all).
  KycSubmissionStatus? _lastResult;

  /// True only once a real check has actually CONFIRMED the submission is
  /// still pending/review — see build()'s doc comment for why this exists
  /// (2026-08-20 fix: "why is 'we're reviewing your kyc' the first thing
  /// that shows before it proceeds to show verified... being reviewed
  /// stay as being reviewed"). Before the first check completes, this
  /// screen no longer guesses "still pending" by default.
  bool _confirmedPending = false;

  @override
  void initState() {
    super.initState();
    _pollingStartedAt = DateTime.now();
    _timer = Timer(_firstCheckDelay, _checkStatus);
  }

  Future<void> _checkStatus() async {
    try {
      final result = await _repo.me();
      if (!mounted) return;
      if (result.isApproved) {
        context.go(Routes.kycApproved);
        return;
      }
      if (result.status == 'rejected' ||
          result.status == 'flagged' ||
          result.status == 'expired' ||
          result.isRejectedWithRoomToRetry ||
          // 2026-09-01, defect A's app half: a 'pending' submission the
          // SERVER is willing to retry — one left open because a
          // verification provider never answered a check. This screen's
          // "we're reviewing your details" was false for that case (no
          // reviewer was routed to it, and this app never asked the server
          // to re-run anything), and its poll would never have changed it:
          // nothing on the backend re-runs an unanswered check on its own,
          // and there is no NIN webhook. kyc-outcome owns every state that
          // has an action attached, including this one — see its
          // _buildProviderUnavailable.
          result.isAwaitingUnansweredCheck) {
        context.go(Routes.kycOutcome);
        return;
      }
      // pending | review — ONLY NOW is it real: a check actually ran and
      // confirmed it. Schedule another check, unless the poll cap is
      // reached.
      setState(() {
        _confirmedPending = true;
        _lastResult = result;
      });
      final startedAt = _pollingStartedAt;
      if (startedAt != null && DateTime.now().difference(startedAt) < _maxPollDuration) {
        _timer = Timer(_pollInterval, _checkStatus);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      // Widened from `on ApiException` only (2026-08-20) — any OTHER
      // exception type used to leave `_errorMessage` unset (so the pending
      // spinner stayed up) AND no follow-up poll scheduled, stranding the
      // investor on this screen forever.
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    }
  }

  /// Manual "Try again" (error state) restarts the poll-duration clock too
  /// — a fresh attempt shouldn't inherit an already-expired cap.
  void _retryFromError() {
    setState(() => _errorMessage = null);
    _pollingStartedAt = DateTime.now();
    _timer = Timer(_firstCheckDelay, _checkStatus);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        // Scrollable-but-still-centred, the same pattern
        // outcome_not_approved.dart and liveness.dart already use. The
        // pending view carries the five-row verification checklist card
        // (added 2026-08-24) on top of an illustration, title, message and
        // button — more than a bare Center+Padding has room for on a short
        // viewport, where it overflowed rather than scrolled. Found by a
        // real-viewport widget test (kyc_targeted_retry_test.dart's pending
        // cases), not by eye.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: maxH.isFinite ? maxH : 0),
                child: Center(
                  child: _errorMessage != null
                      ? KStatusView(
                          tone: KStatusTone.error,
                          title: "Couldn't check your status",
                          message: _errorMessage,
                          primary: 'Try again',
                          onPrimary: _retryFromError,
                          secondary: 'Back to home',
                          onSecondary: () => context.go(Routes.home),
                        )
                      // A neutral "checking" state until a real check has
                      // actually confirmed the submission is still
                      // pending/review (2026-08-20 fix — reported: "why is
                      // 'we're reviewing your kyc' the first thing that shows
                      // before it proceeds to show verified"). Previously this
                      // was the unconditional default render — shown for the
                      // entire ~1.4s before the very first status check even
                      // fired, so even an instant auto-approval always flashed
                      // "under review" first. `_confirmedPending` only flips
                      // true once a check genuinely comes back pending/review —
                      // never assumed.
                      : !_confirmedPending
                      ? const KStatusView(
                          tone: KStatusTone.pending,
                          title: 'Checking your status…',
                          message: 'Just a moment while we confirm your KYC status.',
                        )
                      : KStatusView(
                          tone: KStatusTone.pending,
                          illustrationName: 'kyc-checking',
                          // s20's own title, verbatim. Body is NOT s20's "Usually
                          // 1–2 business days. We'll notify you." — that's an
                          // unverified SLA plus a notification promise this
                          // codebase has no mechanism to back (no push, no
                          // email hook; the real signal set is the synchronous
                          // provider check this screen polls for below), so it
                          // gets the same treatment as the redesign's other
                          // unverified-claim removals (e.g. the "24-hour
                          // security hold" line) rather than being transcribed.
                          //
                          // "you can close the app" is also dropped outright —
                          // it isn't just unbacked, it's wrong on its own terms:
                          // AppState's trading gate (app_state.dart,
                          // tradingEligibilityGap) only blocks placing trades
                          // while KYC is pending; router/app_router.dart's
                          // _gateRedirect free-roams every other screen for any
                          // signed-in user regardless of kycApproved. The
                          // investor can carry on using the app right now — the
                          // "Add money while you wait" button below is exactly
                          // that — so telling them to leave both overpromises
                          // (a notification) and underdescribes (an app they
                          // could keep using) in the same sentence.
                          title: "You're done. We're reviewing",
                          message:
                              "We're checking your details now. You don't need to wait here — you can keep using the app, including adding money to your wallet, while we finish.",
                          // Canvas screen 23's own checklist card, between the
                          // message and the button — real per-check signals,
                          // not the canvas's illustrative example labels (see
                          // _lastResult's doc comment for why the label set
                          // differs).
                          extra: _lastResult?.verificationSignals != null
                              ? _VerificationChecklist(signals: _lastResult!.verificationSignals!)
                              : null,
                          // s20's own single CTA, verbatim — the same route
                          // approved.dart's own "Add money" primary uses.
                          primary: 'Add money while you wait',
                          onPrimary: () => context.go(Routes.wallet),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Canvas screen 23's checklist card — a row per real verification signal,
/// check icon (true), spinner (still running / null), or a plain dash
/// (false — a real fail; rare to see while still pending/review, but not
/// impossible if one check failed while others are still in flight).
class _VerificationChecklist extends StatelessWidget {
  const _VerificationChecklist({required this.signals});
  final KycVerificationSignals signals;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, bool?)>[
      ('BVN matched', signals.bvn),
      ('NIN matched', signals.nin),
      ('Name matched', signals.name),
      ('Date of birth matched', signals.dob),
      ('Face liveness matched', signals.liveness),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0 ? BorderSide.none : BorderSide(color: KColor.hairline, width: 1),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: switch (rows[i].$2) {
                      true => KIcon('check', size: 16, color: KColor.gain),
                      false => KIcon('close', size: 16, color: KColor.ink3),
                      null => KSpinner(size: 16),
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(rows[i].$1, style: KType.body(color: KColor.ink2)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
