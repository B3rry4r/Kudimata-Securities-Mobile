// Brand mark + wordmark lockup. Ported from shared.jsx (Mark / Wordmark). The
// mark keeps its native 2070×2385 aspect ratio; white variant for ink surfaces.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/tokens.dart';

const _markPurple = 'assets/brand/kudimata-mark.svg';
const _markWhite = 'assets/brand/kudimata-mark-white.svg';

/// Just the K mark. `size` is the width; height keeps the mark's viewBox ratio.
class KMark extends StatelessWidget {
  const KMark({super.key, this.size = 30, this.white = false});
  final double size;
  final bool white;

  @override
  Widget build(BuildContext context) {
    // Aspect ratio from the mark's viewBox (2070.02 × 2384.77 — the shield mark).
    return SvgPicture.asset(
      white ? _markWhite : _markPurple,
      width: size,
      height: size * 2384.77 / 2070.02,
    );
  }
}

/// Mark + "Kudimata Securities" wordmark.
class KWordmark extends StatelessWidget {
  const KWordmark({
    super.key,
    this.size = 30,
    this.center = false,
    this.white = false,
  });
  final double size;
  final bool center;
  final bool white;

  @override
  Widget build(BuildContext context) {
    final ink = white ? KColor.featureInk : KColor.ink;
    final sub = white ? KColor.featureInk2 : KColor.ink2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        KMark(size: size, white: white),
        const SizedBox(width: 10),
        // Flexible + ellipsis so the wordmark degrades gracefully under large
        // accessibility text scales / very narrow widths instead of throwing a
        // horizontal RenderFlex overflow.
        Flexible(
          child: Text.rich(
            TextSpan(
              style: KType.section(color: ink).copyWith(
                fontSize: 17,
                fontWeight: KWeight.semibold,
                letterSpacing: -0.17,
                height: 1.0,
              ),
              children: [
                const TextSpan(text: 'Kudimata '),
                TextSpan(
                  text: 'Securities',
                  style: TextStyle(fontWeight: KWeight.regular, color: sub),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
