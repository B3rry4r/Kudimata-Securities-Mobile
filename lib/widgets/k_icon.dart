// Kudimata line-icon set — one family, 1.5px stroke, no fills. Paths ported 1:1
// from components/icons/Icon.jsx (24×24 viewBox, rendered at 20px; stroke 1.75 ≈
// 1.5px visual). Plus the custom `fingerprint` glyph from shared.jsx. Rendered
// through flutter_svg so the geometry is exactly the design's, not a font's.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/tokens.dart';

/// Inner SVG markup for each named icon (the path/line/circle children).
const Map<String, String> _kIconPaths = {
  'home': '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
      '<path d="M9 22V12h6v10"/>',
  // custom pie-chart mark used for the Portfolio tab
  'portfolio': '<path d="M21.21 15.89A10 10 0 1 1 8 2.83"/>'
      '<path d="M22 12A10 10 0 0 0 12 2v10z"/>',
  'markets': '<polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/>'
      '<polyline points="16 7 22 7 22 13"/>',
  'wallet': '<path d="M21 12V7H5a2 2 0 0 1 0-4h14v4"/>'
      '<path d="M3 5v14a2 2 0 0 0 2 2h16v-5"/>'
      '<path d="M18 12a2 2 0 0 0 0 4h4v-4Z"/>',
  'profile': '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/>'
      '<circle cx="12" cy="7" r="4"/>',
  'search': '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  'filter': '<line x1="4" x2="4" y1="21" y2="14"/><line x1="4" x2="4" y1="10" y2="3"/>'
      '<line x1="12" x2="12" y1="21" y2="12"/><line x1="12" x2="12" y1="8" y2="3"/>'
      '<line x1="20" x2="20" y1="21" y2="16"/><line x1="20" x2="20" y1="12" y2="3"/>'
      '<line x1="2" x2="6" y1="14" y2="14"/><line x1="10" x2="14" y1="8" y2="8"/>'
      '<line x1="18" x2="22" y1="16" y2="16"/>',
  'bell': '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/>'
      '<path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  'back': '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
  'chevronRight': '<path d="m9 18 6-6-6-6"/>',
  'plus': '<path d="M5 12h14"/><path d="M12 5v14"/>',
  'close': '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  'arrowUp': '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
  'arrowDown': '<path d="M12 5v14"/><path d="m19 12-7 7-7-7"/>',
  'arrowUpRight': '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
  'arrowDownLeft': '<path d="M17 7 7 17"/><path d="M17 17H7V7"/>',
  'check': '<path d="M20 6 9 17l-5-5"/>',
  'eye': '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
  'card': '<rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/>',
  'transfer': '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/>'
      '<path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
  'send': '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
  // custom — drawn in the same Lucide idiom (shared.jsx Fingerprint)
  'fingerprint': '<path d="M2 12C2 6.5 6.5 2 12 2a10 10 0 0 1 8 4"/>'
      '<path d="M5 19.5C5.5 18 6 16 6 14a6 6 0 0 1 .34-2"/>'
      '<path d="M17.29 21.02c.12-.6.43-2.3.5-3.02"/>'
      '<path d="M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4"/>'
      '<path d="M8.65 22c.21-.66.45-1.32.57-2"/>'
      '<path d="M14 13.12c0 2.38 0 6.38-1 8.88"/>'
      '<path d="M2 16h.01"/>'
      '<path d="M21.8 16c.2-2 .131-5.354 0-6"/>'
      '<path d="M9 6.8a6 6 0 0 1 9 5.2v2"/>',
};

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

/// A monochrome line icon. `name` must exist in [_kIconPaths].
class KIcon extends StatelessWidget {
  const KIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.stroke = 1.75,
    this.color, // null → themed ink (resolved at build)
  });

  final String name;
  final double size;
  final double stroke;
  final Color? color;

  static bool has(String name) => _kIconPaths.containsKey(name);

  @override
  Widget build(BuildContext context) {
    final inner = _kIconPaths[name] ?? '';
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
        'viewBox="0 0 24 24" fill="none" stroke="${_hex(color ?? KColor.ink)}" '
        'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">'
        '$inner</svg>';
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(svg, width: size, height: size),
    );
  }
}
