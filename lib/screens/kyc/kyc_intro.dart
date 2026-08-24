// KYC 1 — intro. What we'll verify (identity / document / selfie) and a single
// purple "Start" primary that enters the linear flow. Mirrors KycIntro.
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

class _KycRow {
  const _KycRow(this.eyebrow, this.line, this.icon);
  final String eyebrow;
  final String line;
  final String icon; // KIcon name
}

class KycIntroScreen extends StatefulWidget {
  const KycIntroScreen({super.key});

  @override
  State<KycIntroScreen> createState() => _KycIntroScreenState();
}

class _KycIntroScreenState extends State<KycIntroScreen> {
  // 2026-08-24 re-sequencing: the design mockup's own checklist (screen 13)
  // lists all 8 real steps — CHN, bank/DCS, and the two declarations are now
  // genuinely built (chn_screen.dart, bank_dcs_screen.dart,
  // declarations_screen.dart) and wired into the flow between id-upload and
  // next-of-kin, so this list now matches the mockup verbatim instead of the
  // narrower 5-item list a prior pass deliberately trimmed it to.
  static const _rows = [
    _KycRow('IDENTITY', 'Your BVN and NIN — checked with NIBSS.', 'profile'),
    _KycRow('CHN', 'Your CSCS number, if you already have one.', 'card'),
    _KycRow('DOCUMENT', 'A government ID — NIN, international passport, licence or voter\'s card.', 'card'),
    // Face liveness check — fingerprint/profile motif (no camera icon in
    // the set). Eyebrow renamed from 'SELFIE' 2026-08-20 ("please don't
    // use selfie wording for face liveness check").
    _KycRow('FACE LIVENESS', 'A quick liveness check to match your face.', 'fingerprint'),
    _KycRow('ADDRESS', 'A utility bill dated in the last three months.', 'card'),
    _KycRow('BANK & DCS', 'The account your dividends and sale proceeds settle to.', 'wallet'),
    _KycRow('DECLARATIONS', 'Two short SEC-required questions.', 'profile'),
    _KycRow('NEXT OF KIN', 'Who to contact if we can\'t reach you.', 'profile'),
  ];

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
          padding: const EdgeInsets.fromLTRB(
              KSpace.gutter, 24, KSpace.gutter, KSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const KIllustration('kyc-intro', role: KIlloRole.small),
                      const SizedBox(height: 20),
                      const KScreenHead(
                        title: 'Verify to start investing',
                        body:
                            'This is required before your CSCS account can open. Eight steps, about six minutes.',
                      ),
                      const SizedBox(height: 28),
                      KCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < _rows.length; i++)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: i == 0
                                        ? BorderSide.none
                                        : BorderSide(color: KColor.hairline, width: 1),
                                  ),
                                ),
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: KColor.indicatorTint,
                                        shape: BoxShape.circle,
                                      ),
                                      child: KIcon(_rows[i].icon, size: 20, color: KColor.indicator),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          KEyebrow(_rows[i].eyebrow),
                                          const SizedBox(height: 4),
                                          Text(_rows[i].line, style: KType.body(color: KColor.ink)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Then we provision your trading account — that part is on us, and takes up to one business day.',
                        style: KType.body(color: KColor.ink3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              KButton(
                label: 'Start verification',
                iconRight: 'arrowUpRight',
                loading: _busy,
                onPressed: _busy ? null : _start,
              ),
              const SizedBox(height: 10),
              KButton(
                label: 'Look around first',
                variant: KButtonVariant.ghost,
                onPressed: _busy ? null : () => context.go(Routes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
