// Toast + StatusView + StatusPill. Ported from
// components/feedback/{Toast,StatusView}.jsx and components/data/StatusPill.jsx.
// Colour is carried by a small mark only — the card/medallion stays white.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'buttons.dart';
import 'illustration.dart';
import 'k_icon.dart';

/// Workflow status vocabulary (2026-08-22 "Soft Landing" — components/data/
/// StatusPill.jsx's STATUS map). Inherits the movement logic: resolved-good
/// reads gain, resolved-bad reads loss, waiting stays neutral ink, and the
/// one state needing a human decision carries the purple indicator.
enum KStatus { pending, review, approved, rejected, expired, flagged }

/// Tinted pill + dot — the dashboard/order/KYC workflow-state vocabulary.
class KStatusPill extends StatelessWidget {
  const KStatusPill({super.key, required this.status, this.label, this.dot = true, this.small = false});

  final KStatus status;
  final String? label;
  final bool dot;
  final bool small;

  (String, Color, Color) get _spec => switch (status) {
        KStatus.pending => ('Pending', KColor.ink2, KColor.statusPendingTint),
        KStatus.review => ('Under review', KColor.indicator, KColor.statusReviewTint),
        KStatus.approved => ('Approved', KColor.gain, KColor.statusApprovedTint),
        KStatus.rejected => ('Rejected', KColor.loss, KColor.statusRejectedTint),
        KStatus.expired => ('Expired', KColor.ink2, KColor.track),
        KStatus.flagged => ('Flagged', KColor.loss, KColor.statusRejectedTint),
      };

  @override
  Widget build(BuildContext context) {
    final (defaultLabel, color, tint) = _spec;
    final fontSize = small ? 10.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 4),
      decoration: BoxDecoration(color: tint, borderRadius: KRadii.pillR),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text((label ?? defaultLabel).upper,
              style: KType.label(color: color).copyWith(fontSize: fontSize, height: 1.3)),
        ],
      ),
    );
  }
}

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
/// Illustration-led (2026-08-22 "Soft Landing" — the audit's own finding was
/// that the old icon-in-a-ring medallion "is exactly where the app felt like
/// a form"). [illustrationName] should name the scene that actually fits the
/// screen (e.g. 'kyc-not-approved', 'offline', 'empty-wallet') — the per-tone
/// default here is a generic fallback for call sites not yet updated with a
/// specific scene.
class KStatusView extends StatelessWidget {
  const KStatusView({
    super.key,
    this.tone = KStatusTone.success,
    this.illustrationName,
    this.title,
    this.message,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.extra,
  });

  final KStatusTone tone;
  final String? illustrationName;
  final String? title;
  final String? message;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  /// Optional content rendered between [message] and the button(s) — e.g. a
  /// small data-summary card (screens 89 "Dormant account" / 92 "Locked
  /// out" both show a two-row card here). Nullable/additive so every
  /// existing call site (KYC outcomes, order status, wallet flows, ...) is
  /// unaffected.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final (defaultName, plateTone) = switch (tone) {
      KStatusTone.success => ('kyc-approved', KIlloTone.sun),
      KStatusTone.error => ('error', KIlloTone.indicator),
      KStatusTone.pending => ('loading', KIlloTone.indicator),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: KIllustration(
            illustrationName ?? defaultName,
            role: KIlloRole.state,
            tone: plateTone,
          ),
        ),
        const SizedBox(height: 22),
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
        if (extra != null) ...[
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: extra!),
        ],
        if (primary != null || secondary != null) ...[
          const SizedBox(height: 24),
          if (primary != null) KButton(label: primary!, onPressed: onPrimary),
          if (primary != null && secondary != null) const SizedBox(height: 10),
          if (secondary != null)
            KButton(label: secondary!, onPressed: onSecondary, variant: KButtonVariant.secondary),
        ],
      ],
    );
  }
}
