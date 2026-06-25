// Bottom sheet — opaque white (never frosted), drag handle, radius 24 top, soft
// shadow + scrim. Ported from overlays/BottomSheet.jsx. Use [showKSheet] to
// present buy/sell, confirmations, filters over the current tab.
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// The sheet body: drag handle + optional title + content + optional footer.
class KSheet extends StatelessWidget {
  const KSheet({super.key, this.title, required this.child, this.footer});
  final String? title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets.bottom; // keyboard height when raised
    // Bound the sheet to 90% of the screen so a tall body (Buy/Sell amount,
    // Add money / Withdraw / Convert) scrolls instead of overflowing on phones
    // shorter than the 812px design canvas. The drag handle + title stay pinned;
    // the body scrolls; the footer CTA stays pinned above the keyboard.
    final maxHeight = media.size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: KColor.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(KRadii.sheet)),
          boxShadow: KShadow.sheet,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 18),
                decoration: BoxDecoration(
                  color: KColor.hairline,
                  borderRadius: BorderRadius.circular(KRadii.pill),
                ),
              ),
            ),
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(title!, style: KType.section()),
              ),
              const SizedBox(height: 16),
            ],
            // Scrollable body — keeps the focused field reachable above the
            // keyboard; viewInsets padding is applied inside the scroll area.
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + (footer == null ? viewInsets : 0)),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + viewInsets),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Present an opaque bottom sheet styled to the design system.
Future<T?> showKSheet<T>(
  BuildContext context, {
  String? title,
  required Widget child,
  Widget? footer,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x520F0F12), // rgba(15,15,18,0.32)
    elevation: 0,
    builder: (ctx) => KSheet(title: title, footer: footer, child: child),
  );
}
