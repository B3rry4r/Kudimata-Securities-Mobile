// Shared screen scaffolding ported from shared.jsx: the tracked eyebrow label,
// the editorial screen-head block, and the pushed-screen back-chevron header.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';

/// The editorial signature: small, uppercase, tracked label (.ks-eyebrow).
class KEyebrow extends StatelessWidget {
  const KEyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.upper, style: KType.label(color: color ?? KColor.ink3));
}

/// Screen title + optional body — the standard header block (ScreenHead).
class KScreenHead extends StatelessWidget {
  const KScreenHead({super.key, required this.title, this.body});
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: KType.title()),
        if (body != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(body!, style: KType.body(color: KColor.ink2)),
          ),
        ],
      ],
    );
  }
}

/// Back-chevron header for pushed (non-root) screens — NO tab bar. (DetailHeader)
///
/// Used as a Scaffold `appBar`. A custom PreferredSizeWidget does NOT get the
/// status-bar inset that Material's AppBar applies, so we add it ourselves: the
/// status-bar height is included in both [preferredSize] and the top padding, so
/// the bar always sits below the notch on every device.
class KDetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const KDetailHeader({super.key, required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;

  static const double _bar = 52;

  /// Status-bar height in logical px, read from the platform view (no context).
  static double get _statusBar {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.padding.top / view.devicePixelRatio;
  }

  @override
  Size get preferredSize => Size.fromHeight(_bar + _statusBar);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: BoxDecoration(
        color: KColor.bg,
        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: SizedBox(
        height: _bar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: KIcon('back', size: 22, color: KColor.ink)),
                ),
              ),
              const SizedBox(width: 4),
              Text(title, style: KType.section()),
            ],
          ),
        ),
      ),
    );
  }
}
