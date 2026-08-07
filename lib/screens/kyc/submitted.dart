// KYC 8 — submitted (pending review). A centred pending StatusView.
//
// The real KYC submission (POST /kyc-submissions) already happened on the
// PRECEDING next-of-kin screen — see lib/screens/kyc/next_of_kin.dart and
// lib/data/repositories/kyc_repository.dart. That screen's response only
// surfaces the new submission's `id` (needed immediately, to attach
// documents); it does not stash `status`/`vendorDecision` anywhere this
// screen can read. So after a short fixed UX-pacing beat (NOT the bug —
// see below), this screen re-fetches the submission via
// GET /kyc-submissions/me and routes on the REAL outcome: LumiID's
// synchronous NIN/BVN checks may have already decided it, or it may still
// be pending further review.
//
// FIXED: previously this screen unconditionally advanced to Approved via a
// fixed Timer regardless of outcome (mocking the provider always approving).
// Now it only advances to Routes.kycApproved when status is genuinely
// 'approved'.
//
// KycSubmission.status (registry.json) is one of
// pending|review|approved|rejected|flagged|expired. pending/review stay on
// this screen's existing "we're reviewing your details" pending view — that
// copy is accurate for those two. rejected/flagged/expired are genuinely
// terminal non-approved outcomes and route to Routes.kycOutcome (see
// lib/screens/kyc/outcome_not_approved.dart), which re-fetches the status
// itself to decide the specific outcome UI (resubmit / contact support /
// manual review / restart).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/api/api_exception.dart';
import 'package:kudimata_securities/data/repositories/kyc_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

class SubmittedScreen extends StatefulWidget {
  const SubmittedScreen({super.key});

  @override
  State<SubmittedScreen> createState() => _SubmittedScreenState();
}

class _SubmittedScreenState extends State<SubmittedScreen> {
  late final _repo = KycRepository(AppScope.read(context).apiClient);
  Timer? _timer;

  /// Non-null only when the status re-check itself failed (network/API
  /// error) — distinct from a successful check that came back non-approved,
  /// which just leaves the pending view showing.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  /// Fixed short delay purely for UX pacing — a deliberate "we're
  /// processing" beat, not the bug this pass fixes. The routing decision in
  /// [_checkStatus] is what changed: it now depends on the real fetched
  /// status instead of firing unconditionally.
  void _scheduleCheck() {
    _timer = Timer(const Duration(milliseconds: 1400), _checkStatus);
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
      // pending | review — no route change: stay on this pending view,
      // whose copy is accurate for those two statuses.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
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
                    onPrimary: () {
                      setState(() => _errorMessage = null);
                      _scheduleCheck();
                    },
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
