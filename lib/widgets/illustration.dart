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

/// Which tinted plate the illustration sits on. `paper` is the one
/// theme-invariant option — see KIllo.platePaper's doc comment — for
/// persona-style art (dark ink on a transparent background) that would
/// otherwise vanish against `indicator`/`warm`/`sun`'s dark-mode washes.
enum KIlloTone { indicator, warm, sun, paper }

/// A scene from assets/illustrations/ on its plate. `name` is the file's
/// basename without extension, e.g. `KIllustration('empty-wallet')`.
class KIllustration extends StatelessWidget {
  const KIllustration(
    this.name, {
    super.key,
    this.role = KIlloRole.state,
    this.tone = KIlloTone.indicator,
    this.padding,
    this.plate = true,
  });

  final String name;
  final KIlloRole role;
  final KIlloTone tone;
  final double? padding;

  /// Whether to draw the tinted plate behind the illustration. Defaults to
  /// `true` — every existing call site wants the plate and is unaffected.
  /// `false` renders the SVG bare, no background/padding: artboard `s21`
  /// (light "Approved") draws the illustration bare while `s21d` (dark)
  /// plates it — see SHARED-CHANGES.md S-4.
  final bool plate;

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
        KIlloTone.paper => KIllo.platePaper,
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
    final svg = SvgPicture.asset(
      'assets/illustrations/$name.svg',
      height: _height,
      fit: BoxFit.contain,
    );
    if (!plate) {
      return Center(widthFactor: 1, heightFactor: 1, child: svg);
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding ?? KIllo.platePad),
      decoration: BoxDecoration(color: _plate, borderRadius: KRadii.illoR),
      child: Center(widthFactor: 1, heightFactor: 1, child: svg),
    );
  }
}

/// `avatarKey` renders one of the 6 named characters in
/// assets/illustrations/avatars/ (one of UserRepository.avatarKeys);
/// `guide` always renders the pinned guide character (the face of the
/// comprehension layer and the AI mark) regardless of `avatarKey`.
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
///
/// 2026-08-31: the 8 generated (DiceBear "Adventurer") glyphs this used to
/// draw — near-duplicate outlines differing mostly by background tint —
/// are replaced by Kudimata's own 6 persona illustrations (same source as
/// kudimata.app's kudi-persona picker; see UserRepository.avatarKeys' own
/// updated doc comment for why the count changed 8 → 6). That art is drawn
/// with dark ink and gradient fills on a TRANSPARENT background — it needs
/// a light plate under it or it reads as nothing on the app's dark ground,
/// same problem the website solves with its own literal-white
/// `.avatarPlate` (components/kudi-persona/kudiPersona.module.css). `guide`
/// is unaffected: it is still the original self-contained circular mark
/// (its own background baked into the SVG, no plate needed) — the `guide`
/// flag is what tells this widget which of the two rendering rules to use,
/// rather than forking a second avatar widget for it.
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
    final svg = SvgPicture.asset(
      'assets/illustrations/avatars/$avatarKey.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    if (guide) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: svg,
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KIllo.platePaper,
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: svg,
    );
  }
}
