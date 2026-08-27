// Corporate actions — local shared bits for this cluster's 4 screens.
// Mirrors lib/screens/account/account_widgets.dart's pattern of small,
// screen-local helpers rather than growing the shared lib/widgets/ library
// for one-cluster shapes (readme.md's "never fork a shared component" rule
// is about K* components; a local private row/scaffold widget used only
// inside one feature folder is the established escape hatch — see
// account_widgets.dart's own KAccountRow/KIconBubble/KAccountCard).
//
// R-5 correction (2026-08-27, docs/redesign/DECISIONS.md): this file used
// to cite "#s82" for the fact-row shape — that id is stale (from an earlier,
// now-superseded pass; the current, authoritative artboard for this
// cluster is `06 Account and Support.dc.html#s55`, "55 · Corporate
// actions" — the hub only. The three detail screens (rights issue, AGM,
// dividends) have no artboard of their own — R-24 (DECISIONS.md): kept and
// restyled onto the new tokens, behaviour unchanged.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Pushed-screen scaffold for this cluster: KDetailHeader + scrollable body
/// with the standard 20px gutter. Same shape as
/// account_widgets.dart's KAccountSubScaffold, kept local since corporate
/// actions isn't an Account sub-flow.
class KCorpActionScaffold extends StatelessWidget {
  const KCorpActionScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: title),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 12, KSpace.gutter, 24),
          child: child,
        ),
      ),
    );
  }
}

/// One label/value row inside a hairline card — "Your entitlement · 80
/// shares · 1 for 5" etc. [emphasis] renders the value in cardTitle weight
/// for the one standout row ("Cost to take it all").
class KFactRow extends StatelessWidget {
  const KFactRow({
    super.key,
    required this.label,
    required this.value,
    this.first = false,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool first;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KType.data(color: KColor.ink2))),
          Text(
            value,
            style: (emphasis ? KType.cardTitle() : KType.data(color: KColor.ink)).tnum,
          ),
        ],
      ),
    );
  }
}

/// The circular icon/initials bubble s55 draws on every row — the green
/// "ZB" ticker-initials mark on the spotlighted rights-issue card, and the
/// smaller icon-in-a-tint bubbles on the "Recent" list. One widget, two
/// content modes ([icon] xor [initials]), so both places share one shape.
class KCorpAvatarBadge extends StatelessWidget {
  const KCorpAvatarBadge({
    super.key,
    this.icon,
    this.initials,
    required this.background,
    required this.foreground,
    this.size = 40,
  }) : assert((icon == null) != (initials == null), 'pass exactly one of icon/initials');

  final String? icon;
  final String? initials;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: icon != null
          ? KIcon(icon!, size: size * 0.45, color: foreground)
          : Text(
              initials!,
              style: KType.cardTitle(color: foreground).copyWith(fontSize: 12, height: 1.0),
            ),
    );
  }
}

/// A tappable history/waiting row — badge + title + subtitle + trailing
/// (chevron by default). Backs both s55's "Recent" list and the compact
/// "Also waiting" rows for a second/third pending item the artboard's own
/// single spotlighted card doesn't draw (see corporate_actions_screen.dart's
/// report for why more than one can be pending at once).
class KCorpActivityRow extends StatelessWidget {
  const KCorpActivityRow({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget badge;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(color: KColor.hairline, width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.cardTitle().copyWith(fontSize: 15)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: KType.data(color: KColor.ink3).copyWith(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? KIcon('chevronRight', size: 17, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}
