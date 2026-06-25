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
    return Container(
      decoration: const BoxDecoration(
        color: KColor.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KRadii.sheet)),
        boxShadow: KShadow.sheet,
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 2, bottom: 18),
              decoration: BoxDecoration(
                color: KColor.hairline,
                borderRadius: BorderRadius.circular(KRadii.pill),
              ),
            ),
          ),
          if (title != null) ...[
            Text(title!, style: KType.section()),
            const SizedBox(height: 16),
          ],
          child,
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
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
