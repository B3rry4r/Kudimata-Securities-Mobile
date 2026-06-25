// Local onboarding scaffolding — passcode dots, numeric keypad, OTP cells, the
// Lucide-idiom fingerprint glyph, and the slim mid-flow top bar. Ported 1:1 from
// the design's shared.jsx (these live here, not in lib/widgets, since they are
// onboarding-only). Monochrome; purple only where the spec calls for it.
import 'package:flutter/widgets.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

/// Fingerprint glyph in the Lucide idiom (1.5px, no fill). KIcon has 'fingerprint'
/// but the design draws it directly; we reuse KIcon for consistency.
class KFingerprint extends StatelessWidget {
  const KFingerprint({super.key, this.size = 20, this.stroke = 1.6, this.color = KColor.ink});
  final double size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      KIcon('fingerprint', size: size, stroke: stroke, color: color);
}

/// Slim top bar with a back affordance, for mid-flow screens. Height 44, no rule.
class KOnboardTopBar extends StatelessWidget {
  const KOnboardTopBar({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
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

/// 6-dot passcode indicator. Filled dots ink (or loss when [error]); empty are
/// hairline rings.
class KPasscodeDots extends StatelessWidget {
  const KPasscodeDots({super.key, this.count = 6, this.filled = 0, this.error = false});
  final int count;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i < filled;
        return Container(
          width: 13,
          height: 13,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? (error ? KColor.loss : KColor.ink) : const Color(0x00000000),
            border: on ? null : Border.all(color: KColor.hairline, width: 1.5),
          ),
        );
      }),
    );
  }
}

/// Numeric keypad. Optional bottom-left action node (biometric on login).
class KKeypad extends StatelessWidget {
  const KKeypad({super.key, required this.onKey, this.leftAction, this.onLeftAction});
  final ValueChanged<String> onKey; // digit '0'..'9' or 'del'
  final Widget? leftAction;
  final VoidCallback? onLeftAction;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, {VoidCallback? onTap, String? semantic}) {
      return Semantics(
        button: onTap != null,
        label: semantic,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(height: 60, child: Center(child: child)),
        ),
      );
    }

    Widget digit(String d) => key(
          Text(
            d,
            style: KType.title(color: KColor.ink).copyWith(
              fontSize: 26,
              fontWeight: KWeight.medium,
              letterSpacing: 0,
            ).tnum,
          ),
          onTap: () => onKey(d),
        );

    final cells = <Widget>[
      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9']) digit(d),
      // bottom-left: biometric action or empty
      leftAction != null
          ? key(leftAction!, onTap: onLeftAction, semantic: 'Use biometrics')
          : const SizedBox.shrink(),
      digit('0'),
      key(
        const KIcon('back', size: 28, color: KColor.ink2), // delete uses a back-style glyph
        onTap: () => onKey('del'),
        semantic: 'Delete',
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 8,
      childAspectRatio: (300 / 3) / 60,
      children: cells,
    );
  }
}

/// OTP: a row of 6 single-digit cells; the focused one carries a purple ring.
class KOtpCells extends StatelessWidget {
  const KOtpCells({super.key, required this.digits, required this.focusIndex});
  final List<String> digits;
  final int focusIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(digits.length, (i) {
        final d = digits[i];
        final focused = i == focusIndex;
        return Container(
          width: 48,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KColor.paper,
            borderRadius: BorderRadius.circular(KRadii.input),
            border: Border.all(
              color: focused ? KColor.ink : KColor.hairline,
              width: focused ? 1.5 : 1,
            ),
            boxShadow: focused
                ? [const BoxShadow(color: KColor.indicatorTint, spreadRadius: 4, blurRadius: 0)]
                : null,
          ),
          child: d.isNotEmpty
              ? Text(
                  d,
                  style: KType.section(color: KColor.ink)
                      .copyWith(fontSize: 24, fontWeight: KWeight.semibold)
                      .tnum,
                )
              : (focused
                  ? Container(width: 1.5, height: 26, color: KColor.indicator)
                  : null),
        );
      }),
    );
  }
}

/// Generic onboarding screen body: padded gutter column. Mirrors shared.jsx Body.
class KOnboardBody extends StatelessWidget {
  const KOnboardBody({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.paddingTop = 8,
  });
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(KSpace.gutter, paddingTop, KSpace.gutter, KSpace.s20),
      child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
    );
  }
}
