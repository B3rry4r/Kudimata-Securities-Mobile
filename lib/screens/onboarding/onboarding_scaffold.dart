// Local onboarding scaffolding — passcode dots, numeric keypad, OTP cells, the
// Lucide-idiom fingerprint glyph, and the slim mid-flow top bar. Ported 1:1 from
// the design's shared.jsx (these live here, not in lib/widgets, since they are
// onboarding-only). Monochrome; purple only where the spec calls for it.
import 'package:flutter/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Fingerprint glyph in the Lucide idiom (1.5px, no fill). KIcon has 'fingerprint'
/// but the design draws it directly; we reuse KIcon for consistency.
class KFingerprint extends StatelessWidget {
  const KFingerprint({super.key, this.size = 20, this.stroke = 1.6, this.color});
  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      KIcon('fingerprint', size: size, stroke: stroke, color: color ?? KColor.ink);
}

/// Slim top bar with a back affordance, for mid-flow screens. Height 44, no
/// rule. [stepLabel] (e.g. "Step 3 of 4") renders centered — screen-specs.md
/// calls for this on every Flow A mid-flow screen (04, 05, 07, 08, 12); a
/// prior pass reskinned colors/fonts here but never actually added the step
/// label itself, so it was silently missing everywhere in onboarding even
/// though the equivalent KYC chrome (_kyc_chrome.dart) already has one.
class KOnboardTopBar extends StatelessWidget {
  const KOnboardTopBar({super.key, this.onBack, this.stepLabel, this.showBackIcon = true});
  final VoidCallback? onBack;
  final String? stepLabel;

  /// False renders just the (left-aligned) step label with no back arrow —
  /// canvas #s09 ("Unlock faster") shows only a plain "Step 4 of 4" label,
  /// no IconButton, unlike every other mid-flow screen (04/05/07/08/12)
  /// which all pair a back arrow with their step label. Defaults true so
  /// every existing call site (which all want the arrow) is unaffected.
  final bool showBackIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (showBackIcon)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
          if (stepLabel != null)
            Padding(
              // Canvas #s09's bare label sits at the row's own left inset
              // (padding:14px 20px 0, not centered like the arrow+label
              // screens) — only apply that inset when there's no back icon
              // to already provide left padding.
              padding: EdgeInsets.only(left: showBackIcon ? 0 : 20),
              child: showBackIcon
                  ? Center(child: Text(stepLabel!.upper, style: KType.label(color: KColor.ink3)))
                  : Text(stepLabel!.upper, style: KType.label(color: KColor.ink3)),
            ),
        ],
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
    // Ported 1:1 from the canvas mockup's #s07 block: CSS grid, 3 columns,
    // 14px gap both axes, 64px-tall cells. Only the DIGIT keys sit on a
    // paper/hairline/r-input rounded-square tile — delete and the
    // biometric-slot key are bare icons with no visible box, exactly as
    // authored (`<span style="height:64px;...border-radius:var(--r-input);
    // cursor:pointer">` with no background/border for delete).
    Widget cell(Widget? child, {VoidCallback? onTap, String? semantic, bool boxed = false}) {
      return Expanded(
        child: Semantics(
          button: onTap != null,
          label: semantic,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 64,
              child: Center(
                child: child == null
                    ? const SizedBox.shrink()
                    : (boxed
                        ? Container(
                            width: double.infinity,
                            height: 64,
                            decoration: BoxDecoration(
                              color: KColor.paper,
                              border: Border.all(color: KColor.hairline),
                              borderRadius: BorderRadius.circular(KRadii.input),
                            ),
                            alignment: Alignment.center,
                            child: child,
                          )
                        : child),
              ),
            ),
          ),
        ),
      );
    }

    Widget digit(String d) => cell(
          Text(
            d,
            style: KType.title(color: KColor.ink).copyWith(
              fontSize: 24,
              fontWeight: KWeight.bold,
              letterSpacing: 0,
            ).tnum,
          ),
          onTap: () => onKey(d),
          semantic: d,
          boxed: true,
        );

    Widget row(List<Widget> kids) => Row(
          children: [
            for (var i = 0; i < kids.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              kids[i],
            ],
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit('1'), digit('2'), digit('3')]),
        const SizedBox(height: 14),
        row([digit('4'), digit('5'), digit('6')]),
        const SizedBox(height: 14),
        row([digit('7'), digit('8'), digit('9')]),
        const SizedBox(height: 14),
        row([
          leftAction != null
              ? cell(leftAction, onTap: onLeftAction, semantic: 'Use biometrics')
              : cell(null),
          digit('0'),
          cell(
            KIcon('back', size: 22, color: KColor.ink2), // delete (backspace) affordance
            onTap: () => onKey('del'),
            semantic: 'Delete',
          ),
        ]),
      ],
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
                ? [BoxShadow(color: KColor.indicatorTint, spreadRadius: 4, blurRadius: 0)]
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
///
/// The design distributes content with flex spacers (Spacer) against an 812px
/// canvas. Real phones are shorter, so a plain Column would overflow once the
/// fixed content (heads + keypad/OTP/buttons) exceeds the viewport. We wrap the
/// column in a LayoutBuilder + scroll view + IntrinsicHeight: on tall phones the
/// Spacers expand exactly as designed; on short phones the body scrolls instead
/// of throwing a RenderFlex overflow.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(KSpace.gutter, paddingTop, KSpace.gutter, KSpace.s20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: maxH.isFinite ? maxH - paddingTop - KSpace.s20 : 0,
            ),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
            ),
          ),
        );
      },
    );
  }
}
