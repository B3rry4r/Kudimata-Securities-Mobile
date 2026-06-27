// Bottom nav — one white pill holding every item; the active item gets a purple
// fill circle that SLIDES between slots. Ported from navigation/BottomNav.jsx.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';

class KNavItem {
  const KNavItem({required this.id, required this.icon, required this.label});
  final String id;
  final String icon;
  final String label;
}

const List<KNavItem> kDefaultNavItems = [
  KNavItem(id: 'home', icon: 'home', label: 'Home'),
  KNavItem(id: 'portfolio', icon: 'portfolio', label: 'Portfolio'),
  KNavItem(id: 'markets', icon: 'markets', label: 'Markets'),
  KNavItem(id: 'wallet', icon: 'wallet', label: 'Wallet'),
  KNavItem(id: 'profile', icon: 'profile', label: 'Account'),
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

  static const double _pad = 6;
  static const double _knob = 48;
  static const double _content = 56; // slot/icon row height

  @override
  Widget build(BuildContext context) {
    var idx = items.indexWhere((it) => it.id == active);
    if (idx < 0) idx = 0;

    // Fills the available width like a real navbar: the items spread evenly and
    // the purple knob slides to the centre of the active slot.
    return LayoutBuilder(
      builder: (context, c) {
        final innerW = c.maxWidth - _pad * 2 - 2; // minus padding + 1px border each side
        final slotW = innerW / items.length;
        final knobLeft = idx * slotW + (slotW - _knob) / 2;

        return Container(
          width: c.maxWidth,
          padding: const EdgeInsets.all(_pad),
          decoration: BoxDecoration(
            color: KColor.paper,
            borderRadius: BorderRadius.circular(KRadii.pill),
            border: Border.all(color: KColor.hairline, width: 1),
            boxShadow: KShadow.nav,
          ),
          child: SizedBox(
            height: _content,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedPositioned(
                  duration: KMotion.base,
                  curve: KMotion.easeSoft,
                  left: knobLeft,
                  top: (_content - _knob) / 2,
                  width: _knob,
                  height: _knob,
                  child: Container(
                    decoration: BoxDecoration(
                      color: KColor.indicator,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x57670099), offset: Offset(0, 8), blurRadius: 18),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final it in items)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onChange(it.id),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: _content,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: KMotion.base,
                                child: KIcon(
                                  it.icon,
                                  key: ValueKey('${it.id}-${it.id == active}'),
                                  size: 22,
                                  stroke: it.id == active ? 1.9 : 1.6,
                                  color: it.id == active ? KColor.paper : KColor.ink3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
