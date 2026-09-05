// Shared KYC chrome: slim back top bar + the segmented step-progress
// indicator, and — as of 2026-09-04 — the ONE definition of how many steps
// the KYC flow has.
//
// KYC is a linear gated flow: no tab bar, a back chevron and a step-progress
// strip on every screen.
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// THE KYC STEP COUNT. One constant, one definition, every surface.
///
/// This project has shipped a WRONG step figure three separate times, each
/// time because the number was spelled out again somewhere new — a private
/// constant in bvn_nin.dart, a `total: 7` literal on eight screens, a stale
/// `total = 4` default on [KycStepProgress] that nothing happened to be
/// using, and the backend's own unrelated KYC_TOTAL_STEPS = 5 (its phased
/// gating counter, which has never described this flow). Every one of those
/// is now derived from here or deleted.
///
/// The eight steps, in checklist order (kyc_checklist_screen.dart's
/// `_loadChecklistSteps` builds exactly this many items, and
/// test/kyc_step_count_single_truth_test.dart asserts it):
///   1 BVN & NIN        2 CHN (optional)     3 Documents (ID + utility bill)
///   4 Selfie           5 Bank & DCS         6 Source of funds
///   7 Declarations     8 Next of kin
///
/// Step 6 was added 2026-09-04 for the Nigerian SEC's No Objection condition
/// 2 (a dedicated Source of Funds field in the onboarding questionnaire).
const int kKycTotalSteps = 8;

/// The step label [KycTopBar.stepLabel] takes — "Verification · 5 of 8".
/// Built from [kKycTotalSteps] so a screen can state WHICH step it is without
/// also restating how many there are.
String kycStepLabel(int step, {bool optional = false}) =>
    'Verification · $step of $kKycTotalSteps${optional ? ' · optional' : ''}';

/// R-45 as amended (DECISIONS.md, 2026-08-29 — owner's correction to the
/// original ruling: "they can go back but on restart they shouldn't be able
/// to do so... on the flow they can go back"): the real back target for a
/// KYC step, given [currentRoute]. A step that was already complete BEFORE
/// this session's flow was entered — i.e. finished in a previous session,
/// found again on resume after a restart — is "locked"
/// (AppState.kycForm.lockedStepRoutes, snapshotted once by kyc_intro.dart's
/// resume check) and goes to the checklist hub instead of its normal
/// predecessor, so an investor can't walk back into old, already-accepted
/// work. A step finished DURING this session is not in that set, so it
/// keeps using [Routes.gatedBackTarget]'s ordinary linear-predecessor chain
/// — pressing back right after finishing a step, to fix a mistake just
/// made, must keep working exactly as it does today.
///
/// Called by BOTH every KYC step screen's own on-screen back arrow (each
/// `onBack: () => context.go(kycBackTarget(context, Routes.kycX))`) AND
/// app_router.dart's hardware-back handler (`_handleGatedBack`) — the ONE
/// place this decision is made, so the two can never disagree, the same
/// guarantee [Routes.gatedBackTarget]'s own header comment already makes
/// for every other gated route.
String kycBackTarget(BuildContext context, String currentRoute) {
  final locked = AppScope.read(context).kycForm.lockedStepRoutes.contains(currentRoute);
  if (locked) return Routes.kycChecklist;
  return Routes.gatedBackTarget[currentRoute] ?? Routes.kycChecklist;
}

/// Slim 44px top bar with a single back affordance. The `onBack ?? maybePop`
/// fallback below only works for a PUSHED route — every KYC screen advances
/// with `context.go(...)`, which doesn't add a Navigator entry to pop, so
/// `maybePop()` silently no-ops. Every KYC screen using this bar MUST pass an
/// explicit `onBack: () => context.go(Routes.kycX)` pointing at the previous
/// step (found live 2026-08-19: every back chevron in the KYC flow was dead).
class KycTopBar extends StatelessWidget {
  const KycTopBar({super.key, this.onBack, this.stepLabel, this.onFeature = false});
  final VoidCallback? onBack;

  /// e.g. "Verification · 1 of 8" — sits beside the back button, same row.
  /// Build it with [kycStepLabel]; never spell the total again by hand.
  /// Ported 1:1 from the canvas mockup's #s14-#s21 blocks: the step label is
  /// part of the header row (`padding:14px 20px 10px`), not a caption under
  /// the progress bar — was previously rendered as "STEP N OF total" below
  /// the bar instead (wrong position AND wrong copy pattern).
  final String? stepLabel;

  /// True on a full-bleed `KColor.feature` (grape) screen — s15 "Selfie
  /// check" is the one KYC screen the canvas puts on that panel instead of
  /// `--bg`. The plain [KColor.ink]/[KColor.ink3] icon+label this bar
  /// otherwise uses would be near-invisible on grape, so this swaps to
  /// featureInk/featureInk2 instead of forking a second top-bar widget.
  final bool onFeature;

  @override
  Widget build(BuildContext context) {
    final iconColor = onFeature ? KColor.featureInk : KColor.ink;
    final labelColor = onFeature ? KColor.featureInk2 : KColor.ink3;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: KIcon('back', size: 22, color: iconColor)),
              ),
            ),
            if (stepLabel != null)
              Expanded(
                child: Text(
                  stepLabel!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: KType.micro(color: labelColor).copyWith(letterSpacing: 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Segmented step-progress strip — indicator (grape) for done/current, track
/// ahead. Ported 1:1 from the canvas mockup's #s14-#s21 blocks: 5px-tall
/// segments with a 3px radius (a subtle rounded bar, not a full pill) and no
/// caption underneath — the step label lives in [KycTopBar] instead.
class KycStepProgress extends StatelessWidget {
  /// [total] defaults to [kKycTotalSteps] and no caller should ever pass it.
  /// It used to default to a stale `4` that nothing was using — a wrong step
  /// count sitting in the shared widget waiting for someone to rely on it.
  const KycStepProgress({super.key, this.total = kKycTotalSteps, required this.current, this.onFeature = false});
  final int total;
  final int current;

  /// See [KycTopBar.onFeature] — [KColor.indicator] IS the light-theme
  /// `--feature` grape, so a done/current segment in its usual colour would
  /// be invisible on that same panel (s15). Swaps to featureInk/a translucent
  /// featureInk instead.
  final bool onFeature;

  @override
  Widget build(BuildContext context) {
    final doneColor = onFeature ? KColor.featureInk : KColor.indicator;
    final trackColor = onFeature ? KColor.featureInk.withValues(alpha: 0.25) : KColor.track;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 4, KSpace.gutter, 16),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: KMotion.base,
                curve: KMotion.easeSoft,
                height: 5,
                decoration: BoxDecoration(
                  color: i < current ? doneColor : trackColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
