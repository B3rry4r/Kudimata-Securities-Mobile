// KYC — approved (success). Artboard s21 (+ s21d), "02 Verification.dc.html".
// A centred success StatusView. Sets kycApproved and offers "Add money" /
// "Browse the market first" — s21's own two CTAs.
//
// R-1a (docs/redesign/DECISIONS.md): the suitability questionnaire moved
// EARLIER in onboarding — after OTP, before the legal documents — and no
// longer attaches to this screen. The previous "Start investing → hands off
// to the questionnaire" wiring (and the 2026-08-24 "make it mandatory"
// restore that put it there) is removed per that ruling; this screen no
// longer references Routes.questionnaire at all.
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
      // s21: no enclosing tinted card — the illustration, title, message and
      // two full-width buttons sit directly on `--bg`. KMilestoneSheet (the
      // old canvas screen 25's sun-tinted "celebration sheet") no longer
      // matches that structure, so this uses KStatusView like every other
      // KYC outcome view (submitted.dart's s20, this screen's own pending/
      // error branches below) — tone: success gives the same sun-tone plate
      // via KIllustration.
      //
      // s21 (light) draws the illustration bare and the "Browse the market
      // first" ghost CTA borderless; s21d (dark) plates the illustration and
      // outlines the ghost CTA — see SHARED-CHANGES.md S-4/S-5.
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return KStatusView(
        tone: KStatusTone.success,
        illustrationName: 'kyc-approved',
        illustrationPlate: isDark,
        title: "You're verified",
        message: "Your NGX account is live. Buy your first share from ₦5,000.",
        primary: 'Add money',
        onPrimary: () => context.go(Routes.wallet),
        secondary: 'Browse the market first',
        onSecondary: () => context.go(Routes.markets),
        secondaryVariant: KButtonVariant.ghost,
        secondaryGhostBorder: isDark,
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
