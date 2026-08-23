// Stage 9 — Account shared bits. Local-only row/bubble helpers used across the
// Account hub and its 8 sub-screens. Mirrors the design's IconBubble + Row.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// 38px hairline circle holding a line icon (design `IconBubble`). Falls back to
/// a safe KIcon name when the requested glyph isn't in the fixed set.
class KIconBubble extends StatelessWidget {
  const KIconBubble(this.icon, {super.key, this.size = 38, this.iconSize = 19});
  final String icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final name = KIcon.has(icon) ? icon : 'card';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KColor.bg,
        shape: BoxShape.circle,
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: KIcon(name, size: iconSize, color: KColor.ink),
    );
  }
}

/// A control row used across the account cards: optional bubble icon · title +
/// sub · right control. `first` drops the top hairline (rows live in a padded
/// `KCard(padding: 4px 16px)`).
class KAccountRow extends StatelessWidget {
  const KAccountRow({
    super.key,
    this.icon,
    required this.title,
    this.sub,
    this.right,
    this.first = false,
    this.onTap,
    this.crossAlign = CrossAxisAlignment.center,
    this.titleColor,
    this.subUppercase = false,
  });

  final String? icon;
  final String title;
  final String? sub;
  final Widget? right;
  final bool first;
  final VoidCallback? onTap;
  final CrossAxisAlignment crossAlign;

  /// Overrides the title's ink colour — e.g. `KColor.loss` for a
  /// destructive row (screen 91's "Close my account and delete what you
  /// can"). Null keeps the existing default (ink).
  final Color? titleColor;

  /// Renders [sub] tracked-caps, matching the canvas's `text-micro` +
  /// `text-transform:uppercase` device-status caption (screen 50's "This
  /// device · now"). Default false keeps every other call site's sentence-
  /// style sub (Switch descriptions, "Verify your BVN...", etc.) unchanged —
  /// added rather than uppercasing [sub] unconditionally, since most callers
  /// need the opposite.
  final bool subUppercase;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? BorderSide.none
              : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        crossAxisAlignment: crossAlign,
        children: [
          if (icon != null) ...[
            KIconBubble(icon!),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: KType.cardTitle(color: titleColor, w: KWeight.medium)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(subUppercase ? sub!.upper : sub!,
                      style: KType.micro(color: KColor.ink3)
                          .copyWith(letterSpacing: 0.04 * 10)),
                ],
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: 10), right!],
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }
}

/// The right-hand chevron used on navigational rows. 16px per every `Icon
/// name="chevronRight"` x-import in the canvas (s45/s48/s49/s50/s51 all
/// agree) — corrected from a 20px guess during the 2026-08-23 exactness pass.
class KRowChevron extends StatelessWidget {
  const KRowChevron({super.key});
  @override
  Widget build(BuildContext context) =>
      KIcon('chevronRight', size: 16, color: KColor.ink3);
}

/// A padded grouping card (design uses `Card padding={0}` with `4px 16px`).
class KAccountCard extends StatelessWidget {
  const KAccountCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Pushed-screen scaffold: KDetailHeader + scrollable body with 20px gutters.
/// (Root tab supplies its own Scaffold without a bottom nav — the shell adds it.)
class KAccountSubScaffold extends StatelessWidget {
  const KAccountSubScaffold({
    super.key,
    required this.title,
    required this.child,
    this.headerTrailing,
    this.footer,
  });
  final String title;
  final Widget child;

  /// Passed straight through to [KDetailHeader.trailing] — e.g. the
  /// complaint-tracked screen's reference/status pill next to the title
  /// (screen 88). Added as a prop rather than a bespoke scaffold, per this
  /// app's "extend, don't fork a shared component" convention.
  final Widget? headerTrailing;

  /// Renders OUTSIDE the scrolling `child`, pinned to the bottom of the
  /// screen — several canvas screens using this scaffold put their final
  /// action button at `margin-top:auto` (e.g. Help & support's "File a
  /// complaint", screen 56) rather than as the last scrolled item. Added
  /// as a prop, per the same "extend, don't fork" convention as
  /// [headerTrailing], rather than a second scaffold widget.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: title, trailing: headerTrailing),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 20, KSpace.gutter, 32),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, 20),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
