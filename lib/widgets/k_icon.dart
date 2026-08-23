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
  'eyeOff': '<path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/>'
      '<path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/>'
      '<path d="M6.61 6.61A13.526 13.526 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/>'
      '<line x1="2" x2="22" y1="2" y2="22"/>',
  'card': '<rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/>',
  'transfer': '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/>'
      '<path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
  'send': '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
  // Lucide 'camera' — the liveness capture shutter button (BUG-02: was
  // 'fingerprint', a biometric/Touch-ID affordance, not a photo-capture one).
  'camera': '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/>'
      '<circle cx="12" cy="13" r="3"/>',
  // Lucide 'refresh-cw' — liveness.dart's shutter doubles as a "retry camera
  // init" affordance when the camera couldn't be reached (BUG-02).
  'refresh': '<path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>'
      '<path d="M3 3v5h5"/>'
      '<path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/>'
      '<path d="M16 16h5v5"/>',
  // Lucide 'upload' — liveness.dart's web variant (file-picker selfie
  // upload, no live camera preview on web) uses this in place of 'camera'.
  'upload': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>'
      '<polyline points="17 8 12 3 7 8"/><line x1="12" x2="12" y1="3" y2="15"/>',
  // Lucide 'download' — 'upload' mirrored (mockup-raw/s43.html's "Download
  // receipt" icon-left="download"). Was missing from this set entirely, so
  // the receipt button on transaction-detail (screen 43) silently rendered
  // a blank icon slot — same failure mode as the 'settings' gap noted above.
  'download': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>'
      '<polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
  // Lucide 'shield-check' — security alert notifications (new sign-in,
  // password changed, bank account added; 2026-08-20, "notifications for
  // almost every important thing... this is a darn fintech app!").
  'shieldCheck': '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>'
      '<path d="m9 12 2 2 4-4"/>',
  // Lucide 'shield' (no checkmark) — the complaint-tracking timeline's
  // not-yet-reached "escalate to the SEC" step (screen 88); distinct from
  // 'shieldCheck', which always implies something already verified.
  'shield': '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>',
  // Lucide 'triangle-alert' — 2026-08-22 "Soft Landing", used for the
  // "no wrong answers but read the fine print" style callouts (e.g.
  // suitability_result_screen.dart's "no foreign stocks yet" note).
  'alert': '<path d="m21.73 18-8-14a2 2 0 0 0-3.46 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/>'
      '<path d="M12 9v4"/><path d="M12 17h.01"/>',
  // Lucide 'clock' — Home's "Orders" quick action (spec screen 29), and the
  // market-hours-closed states (spec screens 60-63).
  'clock': '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  // Lucide 'mail' — email-labeled KInput fields across onboarding (sign-up,
  // log-in, reset-password), per the canvas's icon="mail" on every one of
  // them. Added during the screens 1-12 exactness audit: this icon was
  // referenced by the canvas but had never actually been added to this map,
  // so every "Email" field silently fell back to the 'profile' glyph.
  'mail': '<rect width="20" height="16" x="2" y="4" rx="2"/>'
      '<path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>',
  // Lucide 'lock' — password-labeled KInput fields (log-in, reset-password),
  // per the canvas's icon="lock" on every one of them. Same gap as 'mail'
  // above.
  'lock': '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>'
      '<path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  // Lucide 'settings' (gear) — dashboard-only glyph per
  // docs/design/design-system/readme.md's ICONOGRAPHY section ("added in
  // the same idiom... flagged substitution"). Was entirely missing before
  // this audit, so the notifications screen's header settings button (spec
  // screen 47, icon="settings") silently rendered nothing usable.
  'settings': '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/>'
      '<circle cx="12" cy="12" r="3"/>',
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
