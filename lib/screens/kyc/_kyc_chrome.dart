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
  const KycTopBar({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(child: KIcon('back', size: 22, color: KColor.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented step-progress strip — indicator (grape) for done/current, track
/// ahead, plus a tracked "STEP n OF total" caption. 2026-08-22 "Soft
/// Landing": docs/redesign/screen-specs.md's Flow B header note — "filled
/// segments = --indicator, unfilled = --track".
class KycStepProgress extends StatelessWidget {
  const KycStepProgress({super.key, this.total = 4, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 4, KSpace.gutter, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: KMotion.base,
                    curve: KMotion.easeSoft,
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < current ? KColor.indicator : KColor.track,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text('STEP $current OF $total',
              style: KType.micro(color: KColor.ink3).tnum),
        ],
      ),
    );
  }
}
