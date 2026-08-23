// MilestoneSheet + OnboardingSlide (2026-08-22 "Soft Landing" — genuinely
// new, components/mobile/{MilestoneSheet,OnboardingSlide}.jsx).
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'illustration.dart';

/// A once-per-user celebration moment: first trade filled, first dividend,
/// KYC approved (screens 25, 37). Sun plate, never gain-green — a milestone
/// is not a price movement.
class KMilestoneSheet extends StatelessWidget {
  const KMilestoneSheet({
    super.key,
    required this.illustrationName,
    this.eyebrow,
    required this.title,
    this.message,
    this.primary,
    this.secondary,
  });

  final String illustrationName;
  final String? eyebrow;
  final String title;
  final String? message;
  final Widget? primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: KColor.sunTint, borderRadius: KRadii.sheetR),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          KIllustration(illustrationName, role: KIlloRole.state, tone: KIlloTone.sun),
          const SizedBox(height: 12),
          if (eyebrow != null) ...[
            Text(eyebrow!.upper, style: KType.label(color: KColor.sunPress)),
            const SizedBox(height: 6),
          ],
          Text(title, textAlign: TextAlign.center, style: KType.title()),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: KType.body(color: KColor.ink2)),
          ],
          if (primary != null || secondary != null) ...[
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
              ?primary,
              ?secondary,
            ]),
          ],
        ],
      ),
    );
  }
}

/// One slide of the pre-account welcome slider (screen 02) — scene above,
/// copy below, dot progress under that.
class KOnboardingSlide extends StatelessWidget {
  const KOnboardingSlide({
    super.key,
    required this.illustrationName,
    required this.title,
    required this.message,
    required this.index,
    required this.count,
    this.action,
  });

  final String illustrationName;
  final String title;
  final String message;
  final int index;
  final int count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.sheetR),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          KIllustration(illustrationName, role: KIlloRole.hero),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: KType.title(color: KColor.indicatorPress)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: KType.body(color: KColor.ink2)),
          if (action != null) ...[const SizedBox(height: 18), action!],
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                AnimatedContainer(
                  duration: KMotion.base,
                  curve: KMotion.easeSoft,
                  height: 7,
                  width: i == index ? 20 : 7,
                  decoration: BoxDecoration(
                    color: i == index ? KColor.indicator : KColor.ramp4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
