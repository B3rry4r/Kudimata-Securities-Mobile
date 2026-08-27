// KYC — intro. Artboard s10/s10d (docs/design/redesign-2026-08/02
// Verification.dc.html) per RULINGS.md — a single scene, headline, body and
// one "Start" primary. The canvas's own step-by-step checklist lives on a
// SEPARATE artboard, s11 "Checklist hub" (the flow's spine — every later
// step returns to it) — s11 has no app route yet; see this screen agent's
// report for whether it should be absorbed here or built as its own screen.
// Until it exists, "Start" goes straight into the collection steps, same as
// before.
//
// RESUME (2026-08-20, phased-KYC directive: "so users who goes out and
// comes back don't have to start all over"): "Start" first checks
// GET /kyc-submissions/draft. A draft in progress routes straight to
// whichever step it's at (see _routeForStep) instead of always restarting
// at step 1 — the same check home_screen.dart's "Complete your KYC — N/5
// done" prompt already makes via AppState.kycDraftStep, but re-checked
// live here rather than trusting a value that may be stale by the time the
// investor actually taps Start.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class KycIntroScreen extends StatefulWidget {
  const KycIntroScreen({super.key});

  @override
  State<KycIntroScreen> createState() => _KycIntroScreenState();
}

class _KycIntroScreenState extends State<KycIntroScreen> {
  bool _busy = false;

  /// Which route a given backend currentStep (2-5, per
  /// KycRepository.getDraft's doc comment — a draft always exists past step
  /// 1) resumes into. The backend only tracks 5 milestones
  /// (KYC_TOTAL_STEPS, kyc-submissions.service.ts) — CHN/bank-DCS/
  /// declarations/next-of-kin/review are mobile-only screens layered
  /// between those milestones, so several backend steps fan out to more
  /// than one mobile route:
  ///   backend 2 (no id document yet)   -> mobile step 2 (CHN), the first
  ///                                        untracked screen after step 1;
  ///                                        its own Continue/Skip always
  ///                                        lands on step 3 (ID upload)
  ///   backend 3 (liveness not done)    -> mobile step 4 (selfie capture)
  ///   backend 4 (no utility bill)      -> mobile step 5 (utility bill)
  ///   backend 5 (ready to finalize)    -> mobile step 6 (Bank & DCS), the
  ///                                        first of the three untracked
  ///                                        steps (bank/DCS, declarations,
  ///                                        next of kin) still left; each
  ///                                        is safe to redo/re-answer.
  /// Step 1 has no entry here since a draft's currentStep is never reported
  /// as 1.
  static const _stepRoutes = {
    2: Routes.kycChn,
    3: Routes.kycLiveness,
    4: Routes.kycUtilityBill,
    5: Routes.kycBankDcs,
  };

  /// "A few more details" (DOB/address/city/state/phone) — 2026-08-24,
  /// direct product feedback: "a few more details should be part of the
  /// KYC and not a separate step after login". Moved from a mandatory
  /// post-login onboarding gate (every fresh signup used to detour through
  /// personal_details_screen.dart before ever reaching Home) to a
  /// prerequisite checked HERE, the moment an investor actually starts
  /// verification — Home itself no longer waits on it, matching every
  /// other not-yet-KYC'd investor's browse-only state. Same completeness
  /// check confirm_passcode_screen.dart used to run before this move (now
  /// removed there — see that file's header).
  Future<bool> _personalDetailsComplete(AppState app) async {
    try {
      final info = await UserRepository(app.apiClient).personalInfo();
      return info.dob != '—' &&
          info.residentialAddress != '—' &&
          info.city != '—' &&
          info.state != '—' &&
          info.phone.isNotEmpty;
    } on ApiException {
      // Best-effort — a failed check falls through to asking again rather
      // than blocking verification entirely on a network hiccup.
      return false;
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      // Never send an ALREADY-APPROVED investor to "a few more details" —
      // reported: "why has a user who has approved KYC still showing same
      // thing with the a few more details?". An approved account with
      // genuinely missing dob/residentialAddress/phone is a real, historical
      // data gap (most likely from before this prerequisite existed, or an
      // account provisioned some other way) — that's a data-repair
      // question, not something re-entering this flow should ever demand
      // from someone the NGX has already approved.
      if (!app.kycApproved && !await _personalDetailsComplete(app)) {
        if (!mounted) return;
        context.go(Routes.onboardingPersonal);
        return;
      }
      final draft = await KycRepository(app.apiClient).getDraft();
      if (!mounted) return;
      if (draft != null && draft.id != null) {
        app.kycForm.setDraftId(draft.id!);
        context.go(_stepRoutes[draft.currentStep] ?? Routes.kycBvn);
        return;
      }
      context.go(Routes.kycBvn);
    } catch (_) {
      // Best-effort — if the resume check itself fails for ANY reason
      // (network, an unexpected response shape, not just ApiException —
      // widened 2026-08-20 after this got reported stuck on the loading
      // spinner forever despite the underlying request succeeding: a
      // narrower `on ApiException` catch let some other exception type
      // propagate uncaught, which meant `_busy` never got reset since the
      // `finally` below didn't exist yet either), fall through to a normal
      // fresh start rather than stranding the investor on this screen. Step
      // 1 re-checks/re-creates a draft regardless.
      if (!mounted) return;
      context.go(Routes.kycBvn);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, KSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // s10's only header chrome is a single close affordance (no
              // back chevron, no step strip — this is entered once, before
              // step 1 exists). Wired to Home, the same exit the old
              // "Look around first" ghost button gave — s10 doesn't draw a
              // second button, so that affordance moved into this icon.
              // Align (not a bare child of this CrossAxisAlignment.stretch
              // Column) keeps the fixed 40x40 circle from being stretched
              // into a smeared oval — Container.tighten intersects a fixed
              // width against the Column's tight full-width constraint and
              // loses.
              Align(
                alignment: Alignment.centerLeft,
                child: KIconButton(
                  icon: 'close',
                  semanticLabel: 'Not now',
                  onPressed: _busy ? null : () => context.go(Routes.home),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KIllustration('kyc-intro', role: KIlloRole.state, tone: KIlloTone.sun),
                        const SizedBox(height: 28),
                        Text(
                          "Let's verify your identity",
                          style: KType.hero(color: KColor.ink)
                              .copyWith(fontSize: 32, height: 38 / 32, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'It keeps your money safe. Takes about 5 minutes.',
                          style: KType.body(color: KColor.ink2).copyWith(fontSize: 17, height: 26 / 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              KButton(
                label: 'Start',
                loading: _busy,
                onPressed: _busy ? null : _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
