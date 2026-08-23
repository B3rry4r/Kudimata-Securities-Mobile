// Shared KYC chrome: slim back top bar + the segmented step-progress indicator.
// KYC is a linear gated flow — NO tab bar; each step has a back chevron and a
// "STEP n OF 5" progress strip (mirrors StepProgress in kyc-screens.jsx).
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Slim 44px top bar with a single back affordance. The `onBack ?? maybePop`
/// fallback below only works for a PUSHED route — every KYC screen advances
/// with `context.go(...)`, which doesn't add a Navigator entry to pop, so
/// `maybePop()` silently no-ops. Every KYC screen using this bar MUST pass an
/// explicit `onBack: () => context.go(Routes.kycX)` pointing at the previous
/// step (found live 2026-08-19: every back chevron in the KYC flow was dead).
class KycTopBar extends StatelessWidget {
  const KycTopBar({super.key, this.onBack, this.stepLabel});
  final VoidCallback? onBack;

  /// e.g. "Verification · 1 of 5" — sits beside the back button, same row.
  /// Ported 1:1 from the canvas mockup's #s14-#s21 blocks: the step label is
  /// part of the header row (`padding:14px 20px 10px`), not a caption under
  /// the progress bar — was previously rendered as "STEP N OF total" below
  /// the bar instead (wrong position AND wrong copy pattern).
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
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
                child: Center(child: KIcon('back', size: 22, color: KColor.ink)),
              ),
            ),
            if (stepLabel != null)
              Expanded(
                child: Text(
                  stepLabel!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0.4),
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
  const KycStepProgress({super.key, this.total = 4, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
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
                  color: i < current ? KColor.indicator : KColor.track,
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
