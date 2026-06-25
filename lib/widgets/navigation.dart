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

  static const double _slot = 56;
  static const double _pad = 6;
  static const double _knob = 46;

  @override
  Widget build(BuildContext context) {
    var idx = items.indexWhere((it) => it.id == active);
    if (idx < 0) idx = 0;
    final width = _pad * 2 + items.length * _slot;
    const height = _pad * 2 + _slot;
    final knobLeft = _pad + idx * _slot + (_slot - _knob) / 2;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: BorderRadius.circular(KRadii.pill),
        border: Border.all(color: KColor.hairline, width: 1),
        boxShadow: KShadow.nav,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: KMotion.base,
            curve: KMotion.easeSoft,
            left: knobLeft - _pad,
            top: (height - _pad * 2 - _knob) / 2,
            width: _knob,
            height: _knob,
            child: Container(
              decoration: const BoxDecoration(
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
                GestureDetector(
                  onTap: () => onChange(it.id),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: _slot,
                    height: _slot,
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
            ],
          ),
        ],
      ),
    );
  }
}
