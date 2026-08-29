// Bottom nav — edge-to-edge bar with a top hairline, per the redesign canvas
// (docs/design/redesign-2026-08/03 Home and Markets.dc.html, `#s22`/`#s22d`,
// the nav block right after the movers-dots row):
//
//   display:flex; justify-content:space-around; align-items:center;
//   padding:14px 8px 26px;
//   border-top:1px solid var(--hairline);
//   background:var(--paper)
//
// Per tab: column, 4px icon/label gap, 21px icon. Active tab: colour alone
// (`--indicator` on icon+label, bold label) — no filled pill behind it.
// Inactive: `--ink-3`, semibold label. Labels are sentence case ("Home", not
// "HOME").
//
// 2026-08-29 correction (owner: "EVEN THE NAVBAR IS WRONG" — a contrast
// complaint on the pill that turned out to be a symptom of a bigger
// divergence from the canvas): this widget used to render a floating rounded
// pill — `borderRadius: pill`, a shadow, an `indicatorTint`-filled active
// state, 20px icons, an all-caps 3px-gapped label — none of which the canvas
// draws. Checked `docs/redesign/DECISIONS.md` first: R-28 (2026-08-26) rules
// the four-tab SET (Home · Markets · Portfolio · Wallet) and Account moving
// to the header avatar; it says nothing about the container shape, the
// active-state treatment, or label casing, so the canvas wins on all of
// those, per this project's own "canvas wins" rule (CLAUDE.md). The hairline
// separator IS the fix for "blends into the screen" — `border-top:1px solid
// var(--hairline)` over `background:var(--paper)` is exactly what the canvas
// already specifies; no separate contrast treatment was invented here.
//
// [KShadow.nav] and [KColor.indicatorTint] are still used elsewhere (see
// widgets/feedback.dart and ~30 screen call sites) — not removed as tokens,
// just no longer read by this widget.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';

class KNavItem {
  const KNavItem({required this.id, required this.icon, required this.label});
  final String id;
  final String icon;
  final String label;
}

// R-28 (2026-08-26, ruled by product owner): four-tab bar, order Home ·
// Markets · Portfolio · Wallet, per redesign-2026-08 canvas artboard s22
// ("clean four-tab navbar"). The 'You' tab is gone — account is reached from
// the header avatar (see home_screen.dart) — and the old 'Assets' label
// consolidates with this same tab's 'Portfolio' screen title into one label,
// 'Portfolio'. `id`s stay as they were (internal routing keys, never shown).
//
// (Previously: { home: 'Home', portfolio: 'Assets', markets: 'Markets',
// wallet: 'Wallet', account: 'You' } — labels confirmed 2026-08-24 against
// the old 5-tab canvas's own `navItems` data.)
const List<KNavItem> kDefaultNavItems = [
  KNavItem(id: 'home', icon: 'home', label: 'Home'),
  KNavItem(id: 'markets', icon: 'markets', label: 'Markets'),
  KNavItem(id: 'portfolio', icon: 'portfolio', label: 'Portfolio'),
  KNavItem(id: 'wallet', icon: 'wallet', label: 'Wallet'),
];

class KBottomNav extends StatelessWidget {
  const KBottomNav({
    super.key,
    this.items = kDefaultNavItems,
    required this.active,
    required this.onChange,
  });

  final List<KNavItem> items;
  final String active;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The bottom inset is added INSIDE this container, not by a SafeArea
      // wrapped around it. That distinction is the whole fix: a SafeArea
      // outside pads the coloured surface away from the screen edge, so the
      // bar's `paper` background stopped short and the screen showed through
      // underneath — exactly where an Android gesture bar or a home indicator
      // sits, which reads as a transparent strip under the nav.
      //
      // s22 draws `padding:14px 8px 26px` on a static 390px artboard, where
      // that 26 is standing in for BOTH a comfortable bottom margin and a
      // real home-indicator inset — an artboard cannot tell those apart.
      // Split for a real device: 14 to match the top, plus whichever is
      // larger of the device's own inset or 12. No inset lands at 26, the
      // canvas's number; a notched device gets its real inset instead of
      // 26 plus the inset on top.
      padding: EdgeInsets.fromLTRB(
        8, 14, 8, 14 + math.max(12.0, MediaQuery.viewPaddingOf(context).bottom)),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border(top: BorderSide(color: KColor.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(it.id),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KIcon(
                      it.icon,
                      size: 21,
                      color: it.id == active ? KColor.indicator : KColor.ink3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      it.label,
                      style: KType.nav(
                        color: it.id == active ? KColor.indicator : KColor.ink3,
                        w: it.id == active ? KWeight.bold : KWeight.semibold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
