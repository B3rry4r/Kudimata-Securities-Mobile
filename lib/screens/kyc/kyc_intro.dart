// KYC — intro. Artboard s10/s10d (docs/design/redesign-2026-08/02
// Verification.dc.html) per RULINGS.md — a single scene, headline, body and
// one "Start" primary. The canvas's own step-by-step checklist lives on a
// SEPARATE artboard, s11 "Checklist hub" (the flow's spine — every later
// step returns to it), built as its own screen at
// kyc_checklist_screen.dart / Routes.kycChecklist (S-8, DECISIONS.md's
// SHARED-CHANGES.md).
//
// RESUME (2026-08-20, phased-KYC directive: "so users who goes out and
// comes back don't have to start all over"): checks GET /kyc-submissions/
// draft SOLELY to populate AppState.kycForm.draftId — every step screen
// past step 1 needs that set before it can upload anything (see
// AppState.kycDraftStep's own doc comment for the incident this fixed). It
// then hands off to the checklist hub rather than jumping straight to a
// specific step itself (X-5, SHARED-CHANGES.md, 2026-08-27): the hub already
// re-derives exactly which step is next from the same real draft/account
// data and is the one place that logic should live, now that it exists as
// its own re-enterable screen instead of computing it here too.
//
// 2026-08-29 (product-owner audit — "that let's start verifying your kyc
// should not be showing when user has begun"): this resume check used to
// run only on a "Start" TAP, which meant a resuming investor always saw the
// full "Let's verify your identity" hero first regardless. It now runs
// automatically on entry ([_checkResume]) — see that method's own doc
// comment. "Start" (renamed logic to [_start] below) still exists and still
// runs the identical check, for the genuine-first-timer case this screen's
// hero is now reserved for.
//
// 2026-08-29 (A-1 audit fix — "why is there a few more details screen? why
// is that still there"): this used to detour a fresh "Start" tap through
// onboarding/personal_details_screen.dart first, gated on a
// dob/address/city/state/phone completeness check. Removed entirely:
//   - Address/city/state duplicated utility_bill.dart's own s17 address
//     fields verbatim (same PATCH /users/me target) — a pure double-entry.
//   - Phone duplicated sign_up_screen.dart's own phone field (BR-3, added
//     after this screen's detour existed) — also a double-entry now.
//   - DOB has no other writer anywhere in the app. Rather than keep a
//     whole separate interrupting screen alive for one field, it now
//     folds into bvn_nin.dart's own "Is this you?" confirmation (step 1) —
//     the BVN/NIN registry resolves a DOB there for most investors (BR-4);
//     that screen only asks directly when the registry didn't resolve one
//     AND the account doesn't already have one on file.
// personal_details_screen.dart itself is kept (not deleted — reported as a
// removal candidate) since its own route is still walked by
// test/route_walk_test.dart and still reachable directly if deep-linked.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'kyc_checklist_screen.dart' show doneKycStepRoutes;

/// R-45 as amended (DECISIONS.md, 2026-08-29): the ONE place the "already
/// done before this session" snapshot is taken — kyc_intro.dart is the
/// single entry point onto an in-progress draft (AppState.
/// tradingEligibilityGap always routes here, never straight to a step
/// screen), so this is the one moment that can tell "old work from a
/// previous session" apart from "finished just now". Stored on
/// AppState.kycForm.lockedStepRoutes and read from there for the rest of
/// the session by kycBackTarget (_kyc_chrome.dart) and the checklist hub's
/// own tap-target rule (kyc_checklist_screen.dart) — never recomputed
/// after this.
Future<void> _lockAlreadyDoneSteps(AppState app) async {
  try {
    final done =
        await doneKycStepRoutes(app.apiClient, chnSkipped: app.kycForm.chnSkippedThisSession);
    app.kycForm.lockSteps(done);
  } catch (_) {
    // Best-effort, same reasoning as the resume fetch around this call —
    // if this one extra request fails, nothing gets locked (an investor
    // can still walk back into every step this session, same as before
    // R-45 existed) rather than blocking the resume itself on it.
  }
}

class KycIntroScreen extends StatefulWidget {
  const KycIntroScreen({super.key});

  @override
  State<KycIntroScreen> createState() => _KycIntroScreenState();
}

class _KycIntroScreenState extends State<KycIntroScreen> {
  bool _busy = false;

  // 2026-08-29 (product-owner audit — "that let's start verifying your kyc
  // should not be showing when user has begun and not completed... I click
  // continue and I still see that screen then the state screen again"):
  // AppState.tradingEligibilityGap ALWAYS routes an in-progress investor
  // here (app_state.dart's own comment explains why: every step screen past
  // step 1 needs AppState.kycForm.draftId, and this screen's resume fetch is
  // the one place that gets populated) — so this screen can't stop being
  // the entry point. What it CAN stop doing is painting "Let's verify your
  // identity" and waiting for a Start tap before running that fetch. True
  // while the SAME resume check `_start()` always ran on a tap is now
  // running automatically instead — see [_checkResume]. Only a genuine
  // first-timer (no draft yet) ever sees the hero below; a resuming
  // investor never sees this screen's content at all, just a brief loading
  // state before landing on the checklist hub.
  bool _checkingResume = true;

  @override
  void initState() {
    super.initState();
    _checkResume();
  }

  /// The exact same "does a draft already exist" check [_start] runs on a
  /// tap, run automatically on entry instead. A draft found here means an
  /// investor resuming mid-flow — redirect straight to the checklist hub
  /// (setting [AppState.kycForm]'s draftId first, same as [_start] always
  /// did) WITHOUT ever building the hero UI. No draft means a genuine
  /// first-timer: reveal the normal "Let's verify your identity" + Start
  /// screen, whose own [_start] handler re-runs this same fetch on tap (kept
  /// as its own re-check, not skipped, in case state changed between this
  /// screen loading and the tap — the exact defensiveness [_start]'s own
  /// doc comment already relies on).
  Future<void> _checkResume() async {
    final app = AppScope.read(context);
    try {
      final draft = await KycRepository(app.apiClient).getDraft();
      if (!mounted) return;
      if (draft != null && draft.id != null) {
        app.kycForm.setDraftId(draft.id!);
        await _lockAlreadyDoneSteps(app);
        if (!mounted) return;
        context.go(Routes.kycChecklist);
        return;
      }
    } catch (_) {
      // Best-effort, same reasoning as _start()'s own catch below — a
      // failed resume check just falls through to the normal first-timer
      // hero rather than stranding the investor on a loading state forever.
    }
    if (!mounted) return;
    setState(() => _checkingResume = false);
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      final draft = await KycRepository(app.apiClient).getDraft();
      if (!mounted) return;
      if (draft != null && draft.id != null) {
        app.kycForm.setDraftId(draft.id!);
        await _lockAlreadyDoneSteps(app);
        if (!mounted) return;
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
    // See [_checkingResume]'s own doc comment: a resuming investor is
    // redirected before this ever renders the hero below, so all this state
    // shows is a brief, silent loading view — never "Let's verify your
    // identity" for someone who already started.
    if (_checkingResume) {
      return Scaffold(backgroundColor: KColor.bg, body: const KLoadingView());
    }
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
                        // 2026-08-31 (owner: "scrap all those other useless
                        // illustrations on the kyc start screen... get
                        // illustrations from our Kudimata persona
                        // section"): the greyed-out/pinkish look was the old
                        // Semcore scene's own muted palette (KIllo.grey
                        // #7C6C86 + KIllo.tint #E9E0F2), not a rendering
                        // defect — this is now kudimata.app's own
                        // iri/kyc.svg persona illustration instead.
                        // tone: paper (not the state role's usual sun tint)
                        // because that art is dark ink + a purple gradient
                        // on a TRANSPARENT background — sunTint's dark-mode
                        // wash is nearly as dark as the screen itself and
                        // would make the ink vanish; see KIllo.platePaper's
                        // doc comment.
                        const KIllustration('kyc-intro', role: KIlloRole.state, tone: KIlloTone.paper),
                        const SizedBox(height: 28),
                        Text(
                          "Let's verify your identity",
                          style: KType.hero(color: KColor.ink)
                              .copyWith(fontSize: 32, height: 38 / 32, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'It keeps your money safe.',
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
