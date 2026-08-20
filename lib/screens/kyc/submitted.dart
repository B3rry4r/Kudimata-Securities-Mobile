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
          result.status == 'expired') {
        context.go(Routes.kycOutcome);
        return;
      }
      // pending | review — stay on this pending view (accurate copy for
      // both) and schedule another check, unless the poll cap is reached.
      final startedAt = _pollingStartedAt;
      if (startedAt != null && DateTime.now().difference(startedAt) < _maxPollDuration) {
        _timer = Timer(_pollInterval, _checkStatus);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
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
                : KStatusView(
                    tone: KStatusTone.pending,
                    title: "We're reviewing your details",
                    message:
                        "This usually takes a few minutes. We'll notify you when you're verified.",
                    secondary: 'Back to home',
                    onSecondary: () => context.go(Routes.home),
                  ),
          ),
        ),
      ),
    );
  }
}
