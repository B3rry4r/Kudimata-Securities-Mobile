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

