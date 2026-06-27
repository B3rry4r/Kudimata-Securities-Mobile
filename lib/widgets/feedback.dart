// Toast + StatusView. Ported from components/feedback/{Toast,StatusView}.jsx.
// Colour is carried by a small mark only — the card/medallion stays white.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';

enum KToastTone { success, error, info }

class KToast extends StatelessWidget {
  const KToast({
    super.key,
    this.tone = KToastTone.info,
    this.title,
    this.message,
    this.action,
    this.onAction,
    this.onClose,
  });

  final KToastTone tone;
  final String? title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final (String icon, Color color) = switch (tone) {
      KToastTone.success => ('check', KColor.gain),
      KToastTone.error => ('close', KColor.loss),
      KToastTone.info => ('bell', KColor.ink),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: BorderRadius.circular(KRadii.card),
        border: Border.all(color: KColor.hairline, width: 1),
        boxShadow: KShadow.nav,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone == KToastTone.info ? KColor.bg : const Color(0x00000000),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: KIcon(icon, size: 15, stroke: 2.2, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(title!, style: KType.cardTitle(w: KWeight.semibold).copyWith(height: 20 / 15)),
                if (message != null) ...[
                  if (title != null) const SizedBox(height: 2),
                  Text(message!, style: KType.body(color: KColor.ink2).copyWith(height: 20 / 14)),
                ],
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Text(action!.upper,
                    style: KType.label(color: KColor.ink, w: KWeight.semibold)
                        .copyWith(letterSpacing: 0.06 * 11)),
              ),
            )
          else if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.only(top: 1, left: 2, right: 2),
                child: KIcon('close', size: 16, color: KColor.ink3),
              ),
            ),
        ],
      ),
    );
  }
}

enum KStatusTone { success, error, pending }

/// StatusView — the big centred result for an outcome screen or sheet.
class KStatusView extends StatelessWidget {
  const KStatusView({
    super.key,
    this.tone = KStatusTone.success,
    this.title,
    this.message,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final KStatusTone tone;
  final String? title;
  final String? message;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final (String icon, Color color, Color ring) = switch (tone) {
      KStatusTone.success => ('check', KColor.gain, const Color(0x29209A5B)),
      KStatusTone.error => ('close', KColor.loss, const Color(0x29C8443D)),
      KStatusTone.pending => ('transfer', KColor.ink, KColor.hairline),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 22),
          decoration: BoxDecoration(
            color: KColor.paper,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [BoxShadow(color: ring, blurRadius: 0, spreadRadius: 8)],
          ),
          child: KIcon(icon, size: 32, stroke: 2.4, color: color),
        ),
        if (title != null)
          Text(title!, textAlign: TextAlign.center, style: KType.title()),
        if (message != null) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(message!,
                textAlign: TextAlign.center, style: KType.body(color: KColor.ink2)),
          ),
        ],
        if (primary != null || secondary != null) ...[
          const SizedBox(height: 28),
          if (primary != null)
            _StatusButton(label: primary!, onTap: onPrimary, primary: true),
          if (primary != null && secondary != null) const SizedBox(height: 10),
          if (secondary != null)
            _StatusButton(label: secondary!, onTap: onSecondary, primary: false),
        ],
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.label, required this.onTap, required this.primary});
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? KColor.indicator : KColor.paper,
          borderRadius: KRadii.buttonR,
          border: primary ? null : Border.all(color: KColor.hairline, width: 1),
        ),
        child: Text(label,
            style: KType.cardTitle(
              color: primary ? KColor.paper : KColor.ink,
              w: KWeight.semibold,
            ).copyWith(letterSpacing: -0.15, height: 1.0)),
      ),
    );
  }
}
