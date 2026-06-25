// Card + Badge. Ported from components/core/Card.jsx and Badge.jsx.
// Card: the default container — white, 1px hairline, NO shadow, radius 16.
// Badge: movement/status label — colour on numbers only; neutral grey otherwise.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.border = true,
    this.radius = KRadii.card,
    this.onTap,
    this.color = KColor.paper,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool border;
  final double radius;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: KColor.hairline, width: 1) : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

enum KBadgeTone { neutral, gain, loss, indicator }

class KBadge extends StatelessWidget {
  const KBadge({super.key, required this.label, this.tone = KBadgeTone.neutral, this.icon});

  final String label;
  final KBadgeTone tone;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final (Color color, Color? background) = switch (tone) {
      KBadgeTone.neutral => (KColor.ink2, null),
      KBadgeTone.gain => (KColor.gain, null),
      KBadgeTone.loss => (KColor.loss, null),
      KBadgeTone.indicator => (KColor.indicator, KColor.indicatorTint),
    };
    return Container(
      padding: tone == KBadgeTone.indicator
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 4)],
          Text(label, style: KType.label(color: color).copyWith(height: 1.0).tnum),
        ],
      ),
    );
  }
}
