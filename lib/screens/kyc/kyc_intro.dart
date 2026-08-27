// KYC — intro. Artboard s10/s10d (docs/design/redesign-2026-08/02
// Verification.dc.html) per RULINGS.md — a single scene, headline, body and
// one "Start" primary. The canvas's own step-by-step checklist lives on a
// SEPARATE artboard, s11 "Checklist hub" (the flow's spine — every later
// step returns to it), built as its own screen at
// kyc_checklist_screen.dart / Routes.kycChecklist (S-8, DECISIONS.md's
// SHARED-CHANGES.md).
//
// RESUME (2026-08-20, phased-KYC directive: "so users who goes out and
// comes back don't have to start all over"): "Start" first checks
// GET /kyc-submissions/draft SOLELY to populate AppState.kycForm.draftId —
// every step screen past step 1 needs that set before it can upload
// anything (see AppState.kycDraftStep's own doc comment for the incident
// this fixed). It then hands off to the checklist hub rather than jumping
// straight to a specific step itself (X-5, SHARED-CHANGES.md, 2026-08-27):
// the hub already re-derives exactly which step is next from the same real
// draft/account data and is the one place that logic should live, now that
// it exists as its own re-enterable screen instead of computing it here
// too.
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
        context.go(Routes.kycChecklist);
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
