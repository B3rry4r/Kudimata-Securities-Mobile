// Checkbox, Radio, Switch. Ported from components/forms/{Checkbox,Radio,Switch}.jsx.
// Purple owns the "on" state across all three.
import 'package:flutter/widgets.dart';
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
              child: checked ? KIcon('check', size: 14, stroke: 2.6, color: KColor.paper) : null,
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
              color: KColor.paper,
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
