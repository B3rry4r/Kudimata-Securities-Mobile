// Checkbox, Radio, Switch. Ported from components/forms/{Checkbox,Radio,Switch}.jsx.
// Purple owns the "on" state across all three.
import 'package:flutter/widgets.dart';
import '../k_links.dart' show openExternalLink;
import '../theme/tokens.dart';
import 'k_icon.dart';

class _LabelBlock extends StatelessWidget {
  const _LabelBlock({this.label, this.description});
  final String? label;
  final String? description;

  @override
  Widget build(BuildContext context) {
    if (label == null && description == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(label!, style: KType.body(color: KColor.ink, w: KWeight.medium).copyWith(height: 20 / 14)),
        if (description != null) ...[
          if (label != null) const SizedBox(height: 2),
          Text(description!, style: KType.label(color: KColor.ink3).copyWith(letterSpacing: 0, height: 16 / 11)),
        ],
      ],
    );
  }
}

class KCheckbox extends StatelessWidget {
  const KCheckbox({
    super.key,
    required this.checked,
    this.onChanged,
    this.label,
    this.description,
    this.disabled = false,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged?.call(!checked),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: description != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: EdgeInsets.only(top: description != null ? 1 : 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? KColor.indicator : KColor.paper,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: checked ? KColor.indicator : KColor.hairline, width: 1.5),
              ),
              child: checked ? KIcon('check', size: 14, stroke: 2.6, color: KColor.featureInk) : null,
            ),
            if (label != null || description != null) ...[
              const SizedBox(width: 12),
              Flexible(child: _LabelBlock(label: label, description: description)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A [KCheckbox] whose label carries exactly one tappable link out to an
/// external document — "I acknowledge that I have read and agree to
/// **Kudimata Securities Agreements**" (sign-up's
/// account-creation checkbox) / "I have read the **Risk Disclosure**"
/// (trade confirmation's risk checkbox). Built once here (R-51, DECISIONS.md,
/// 2026-08-31) rather than forked per screen — both callers needed the exact
/// same "checkbox + a link inside the label" shape, and this repo's forks
/// gate covers exactly that kind of duplication.
///
/// [prefixText] and [linkText] are deliberately two SEPARATE `Text` widgets
/// laid out in a [Wrap] rather than one `Text.rich` — not a styling choice,
/// a hit-testing one: [linkText] carries its own [GestureDetector] that
/// opens [url] and must never also toggle [checked], and two independent
/// widgets give each its own unambiguous tap target instead of relying on
/// where an inline span happens to land inside a merged run of text.
/// Tapping the checkbox glyph or [prefixText] toggles [checked]; tapping
/// [linkText] opens [url] via [openExternalLink] (k_links.dart) and does
/// not toggle.
class KLinkedCheckbox extends StatelessWidget {
  const KLinkedCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    required this.prefixText,
    required this.linkText,
    required this.url,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final String prefixText;
  final String linkText;
  final String url;

  @override
  Widget build(BuildContext context) {
    final labelStyle = KType.body(color: KColor.ink, w: KWeight.medium).copyWith(height: 20 / 14);
    final linkStyle = labelStyle.copyWith(
      color: KColor.indicator,
      decoration: TextDecoration.underline,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onChanged(!checked),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: checked ? KColor.indicator : KColor.paper,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: checked ? KColor.indicator : KColor.hairline, width: 1.5),
            ),
            child: checked ? KIcon('check', size: 14, stroke: 2.6, color: KColor.featureInk) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => onChanged(!checked),
                  behavior: HitTestBehavior.opaque,
                  child: Text(prefixText, style: labelStyle),
                ),
                GestureDetector(
                  onTap: () => openExternalLink(url),
                  behavior: HitTestBehavior.opaque,
                  child: Text(linkText, style: linkStyle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class KRadio extends StatelessWidget {
  const KRadio({
    super.key,
    required this.checked,
    this.onChanged,
    this.label,
    this.description,
    this.disabled = false,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged?.call(true),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: description != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: EdgeInsets.only(top: description != null ? 1 : 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KColor.paper,
                shape: BoxShape.circle,
                border: Border.all(color: checked ? KColor.indicator : KColor.hairline, width: 1.5),
              ),
              child: AnimatedScale(
                scale: checked ? 1 : 0,
                duration: KMotion.fast,
                curve: KMotion.easeSoft,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(color: KColor.indicator, shape: BoxShape.circle),
                ),
              ),
            ),
            if (label != null || description != null) ...[
              const SizedBox(width: 12),
              Flexible(child: _LabelBlock(label: label, description: description)),
            ],
          ],
        ),
      ),
    );
  }
}

class KSwitch extends StatelessWidget {
  const KSwitch({
    super.key,
    required this.checked,
    this.onChanged,
    this.label,
    this.description,
    this.disabled = false,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final knob = AnimatedContainer(
      duration: KMotion.base,
      curve: KMotion.easeSoft,
      width: 46,
      height: 28,
      decoration: BoxDecoration(
        color: checked ? KColor.indicator : KColor.hairline,
        borderRadius: BorderRadius.circular(KRadii.pill),
      ),
      child: AnimatedAlign(
        duration: KMotion.base,
        curve: KMotion.easeSoft,
        alignment: checked ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: KColor.featureInk, // white knob on the track (both themes)
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x380F0F12), offset: Offset(0, 2), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged?.call(!checked),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: description != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (label != null || description != null)
              Expanded(child: _LabelBlock(label: label, description: description)),
            if (label != null || description != null) const SizedBox(width: 14),
            knob,
          ],
        ),
      ),
    );
  }
}
