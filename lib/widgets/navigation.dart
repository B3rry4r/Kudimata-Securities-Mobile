// Bottom nav — one paper pill holding every item; the active item gets an
// indicator-tinted background behind its stacked icon+label (2026-08-22
// "Soft Landing" — components/mobile/BottomNav.jsx: no sliding knob, a
// static per-item tint instead).
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

  static const double _pad = 8;
  static const double _content = 52; // slot height

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: BorderRadius.circular(KRadii.pill),
        boxShadow: KShadow.nav,
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(it.id),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: KMotion.fast,
                  curve: KMotion.easeSoft,
                  height: _content,
                  decoration: BoxDecoration(
                    color: it.id == active ? KColor.indicatorTint : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(KRadii.pill),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KIcon(
                        it.icon,
                        size: 20,
                        color: it.id == active ? KColor.indicator : KColor.ink3,
                      ),
                      const SizedBox(height: 3),
                      Text(it.label.upper,
                          style: KType.micro(
                              color: it.id == active ? KColor.indicator : KColor.ink3)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
