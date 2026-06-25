// Shared screen scaffolding ported from shared.jsx: the tracked eyebrow label,
// the editorial screen-head block, and the pushed-screen back-chevron header.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';

/// The editorial signature: small, uppercase, tracked label (.ks-eyebrow).
class KEyebrow extends StatelessWidget {
  const KEyebrow(this.text, {super.key, this.color = KColor.ink3});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text.upper, style: KType.label(color: color));
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
class KDetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const KDetailHeader({super.key, required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Center(child: KIcon('back', size: 22, color: KColor.ink)),
            ),
          ),
          const SizedBox(width: 4),
          Text(title, style: KType.section()),
        ],
      ),
    );
  }
}
