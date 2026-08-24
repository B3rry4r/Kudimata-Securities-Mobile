// Kudimata Invest — the illustration system (2026-08-22 "Soft Landing"
// redesign; see readme.md's "ILLUSTRATION" section). 35 Semcore (MIT) scenes
// in assets/illustrations/, each drawn on a tinted plate — never bare paper,
// one illustration per view, never inside data or behind a figure.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/tokens.dart';

/// Which role this illustration plays on the screen — resolves its drawn
/// height. Never derived from the source SVG's own viewBox (mixed intrinsic
/// sizes per tokens/illustration.css's own comment).
enum KIlloRole { hero, state, small, banner }

/// Which tinted plate the illustration sits on.
enum KIlloTone { indicator, warm, sun }

/// A scene from assets/illustrations/ on its plate. `name` is the file's
/// basename without extension, e.g. `KIllustration('empty-wallet')`.
class KIllustration extends StatelessWidget {
  const KIllustration(
    this.name, {
    super.key,
    this.role = KIlloRole.state,
    this.tone = KIlloTone.indicator,
    this.padding,
  });

  final String name;
  final KIlloRole role;
  final KIlloTone tone;
  final double? padding;

  double get _height => switch (role) {
        KIlloRole.hero => KIllo.hero,
        KIlloRole.state => KIllo.state,
        KIlloRole.small => KIllo.small,
        KIlloRole.banner => KIllo.banner,
      };

  Color get _plate => switch (tone) {
        KIlloTone.indicator => KIllo.platePurple,
        KIlloTone.warm => KIllo.plateWarm,
        KIlloTone.sun => KIllo.plateSun,
      };

  @override
  Widget build(BuildContext context) {
    // 2026-08-24 fix: `alignment: Alignment.center` on a Container with an
    // explicit `width: double.infinity` but no explicit height — under an
    // UNBOUNDED height constraint (e.g. inside a SingleChildScrollView,
    // as the welcome slider's KOnboardingSlideContent has), Container's
    // "has alignment, tries to be as big as possible" sizing rule made
    // this plate balloon far past its intended ~200-256px height, pushing
    // the title/body text below the scrollable fold entirely. `Center`
    // as the child (instead of `alignment` on the Container itself)
    // shrink-wraps to the SvgPicture's real size in a loose/unbounded
    // context, while still centering it when the incoming constraint IS
    // bounded/tight — same fix as KPillChip's identical bug.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding ?? KIllo.platePad),
      decoration: BoxDecoration(color: _plate, borderRadius: KRadii.illoR),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: SvgPicture.asset(
          'assets/illustrations/$name.svg',
          height: _height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// A generated Adventurer-style character (CC BY 4.0), seeded per user id —
/// see readme.md's "Characters are generated, not drawn" note. `seed` picks
/// a stable avatar from the pre-generated set in
/// assets/illustrations/avatars/ by hashing to one of the named characters;
/// `guide` always renders the pinned guide character (the face of the
/// comprehension layer and the AI mark) regardless of seed.
class KAvatar extends StatelessWidget {
  const KAvatar({super.key, required this.seed, this.size = KIllo.avatarSm})
      : guide = false;

  const KAvatar.guide({super.key, this.size = KIllo.avatarSm})
      : seed = '',
        guide = true;

  final String seed;
  final bool guide;
  final double size;

  static const _named = [
    'adebayo',
    'bisi',
    'chiamaka',
    'emeka',
    'folake',
    'kudi',
    'ngozi',
    'tunde',
  ];

  String get _file {
    if (guide) return 'guide';
    if (seed.isEmpty) return 'kudi';
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return _named[hash % _named.length];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SvgPicture.asset(
        'assets/illustrations/avatars/$_file.svg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
