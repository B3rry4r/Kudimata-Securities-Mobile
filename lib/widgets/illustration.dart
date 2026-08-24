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

/// A generated Adventurer-style character (CC BY 4.0) — see readme.md's
/// "Characters are generated, not drawn" note. `avatarKey` renders one of
/// the 8 named characters in assets/illustrations/avatars/ (one of
/// UserRepository.avatarKeys); `guide` always renders the pinned guide
/// character (the face of the comprehension layer and the AI mark)
/// regardless of `avatarKey`.
///
/// 2026-08-24, direct product instruction: this used to hash a `seed`
/// string (usually the investor's email) to auto-pick a character with no
/// real user choice at all. Avatars are now a real, user-chosen field
/// (PersonalInfo.avatarKey / UserProfile.avatarKey) — an investor who
/// hasn't picked one gets no avatar at all ("only their name text"), so
/// this widget requires a non-null `avatarKey` for its plain constructor;
/// callers with a possibly-null avatarKey branch on it themselves (see
/// account_screen.dart / home_screen.dart) rather than this widget silently
/// falling back to a generated one.
class KAvatar extends StatelessWidget {
  const KAvatar({super.key, required this.avatarKey, this.size = KIllo.avatarSm})
      : guide = false;

  const KAvatar.guide({super.key, this.size = KIllo.avatarSm})
      : avatarKey = 'guide',
        guide = true;

  final String avatarKey;
  final bool guide;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SvgPicture.asset(
        'assets/illustrations/avatars/$avatarKey.svg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
