// Text field, search pill, segmented control, pill chip, file upload.
// Ported from components/core/{Input,SearchPill,SegmentedControl,PillChip,FileUpload}.jsx.
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';

/// Text input — tracked uppercase label, hairline field that goes ink on focus,
/// helper/error line. Optional leading icon, prefix (₦), suffix, numeric mode.
class KInput extends StatefulWidget {
  const KInput({
    super.key,
    this.label,
    this.controller,
    this.value,
    this.onChanged,
    this.placeholder,
    this.icon,
    this.prefix,
    this.suffix,
    this.helper,
    this.error,
    this.disabled = false,
    this.numeric = false,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.amount = false,
    this.amountSize = 26,
  });

  final String? label;
  final TextEditingController? controller;
  final String? value;
  final ValueChanged<String>? onChanged;
  final String? placeholder;
  final String? icon;
  final String? prefix;
  final String? suffix;
  final String? helper;
  final String? error;
  final bool disabled;
  final bool numeric;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;

  /// Editorial large-amount mode: bumps the input figure (and ₦/$ prefix) to a
  /// 26px semibold tabular numeral, matching the design's amount-entry sheets
  /// (Buy/Sell/Add money/Withdraw at 26, Convert at 22 via [amountSize]).
  final bool amount;

  /// The figure size when [amount] is true.
  final double amountSize;

  @override
  State<KInput> createState() => _KInputState();
}

class _KInputState extends State<KInput> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final borderColor = widget.error != null
        ? KColor.loss
        : focused
            ? KColor.ink
            : KColor.hairline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!.upper,
              style: KType.label(color: widget.disabled ? KColor.ink3 : KColor.ink2)),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: KMotion.fast,
          curve: KMotion.easeSoft,
          height: widget.amount ? 64 : 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.disabled ? KColor.bg : KColor.paper,
            borderRadius: BorderRadius.circular(KRadii.input),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                KIcon(widget.icon!, size: 18, color: focused ? KColor.ink : KColor.ink3),
                const SizedBox(width: 10),
              ],
              if (widget.prefix != null) ...[
                Text(widget.prefix!,
                    style: (widget.amount
                            ? KType.body(color: KColor.ink2, w: KWeight.semibold).copyWith(
                                fontSize: widget.amountSize,
                                height: 1.0,
                                letterSpacing: -0.5,
                              )
                            : KType.body(color: KColor.ink2, w: KWeight.medium))
                        .tnum),
                SizedBox(width: widget.amount ? 8 : 10),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: !widget.disabled,
                  onChanged: widget.onChanged,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType ??
                      (widget.numeric ? TextInputType.number : TextInputType.text),
                  cursorColor: KColor.indicator,
                  cursorWidth: 1.5,
                  style: KType
                      .body(
                        color: widget.disabled ? KColor.ink3 : KColor.ink,
                        w: widget.amount
                            ? KWeight.semibold
                            : widget.numeric
                                ? KWeight.medium
                                : KWeight.regular,
                      )
                      .copyWith(
                        fontSize: widget.amount ? widget.amountSize : null,
                        height: widget.amount ? 1.0 : null,
                        letterSpacing: widget.amount
                            ? -0.5
                            : widget.numeric
                                ? -0.14
                                : null,
                        fontFeatures: (widget.numeric || widget.amount)
                            ? const [FontFeature.tabularFigures()]
                            : null,
                      ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: KType.body(color: KColor.ink3),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 10),
                Text(widget.suffix!, style: KType.body(color: KColor.ink3, w: KWeight.medium)),
              ],
              if (widget.trailing != null) ...[const SizedBox(width: 10), widget.trailing!],
            ],
          ),
        ),
        if (widget.error != null || widget.helper != null) ...[
          const SizedBox(height: 7),
          Text(
            widget.error ?? widget.helper!,
            style: KType.micro(color: widget.error != null ? KColor.loss : KColor.ink3)
                .copyWith(letterSpacing: 0.02 * 10),
          ),
        ],
      ],
    );
  }
}

/// Search pill — solid, hairline, leading search icon, optional trailing filter.
class KSearchPill extends StatelessWidget {
  const KSearchPill({
    super.key,
    this.placeholder = 'Search',
    this.controller,
    this.onChanged,
    this.onFilter,
    this.showFilter = false,
    this.readOnly = false,
    this.onTap,
  });

  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;
  final bool showFilter;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: BorderRadius.circular(KRadii.pill),
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: Row(
        children: [
          const KIcon('search', size: 18, color: KColor.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              readOnly: readOnly,
              onTap: onTap,
              cursorColor: KColor.indicator,
              style: KType.body(color: KColor.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: KType.body(color: KColor.ink3),
              ),
            ),
          ),
          if (showFilter)
            GestureDetector(
              onTap: onFilter,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: KIcon('filter', size: 18, color: KColor.ink2),
              ),
            ),
        ],
      ),
    );
  }
}

class KSegmentOption {
  const KSegmentOption({required this.value, required this.label, this.icon});
  final String value;
  final String label;
  final String? icon;
}

/// Segmented control — recessed track, white active segment that reads as a
/// lifted card. Not purple — purple is reserved for the primary action.
class KSegmentedControl extends StatelessWidget {
  const KSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<KSegmentOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KColor.track,
        borderRadius: BorderRadius.circular(KRadii.input),
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: Row(
        children: [
          for (final opt in options)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: opt == options.first ? 0 : 4),
                child: GestureDetector(
                  onTap: () => onChanged(opt.value),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: KMotion.fast,
                    curve: KMotion.easeSoft,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: opt.value == value ? KColor.paper : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: opt.value == value ? KColor.hairline : const Color(0x00000000),
                        width: 1,
                      ),
                      boxShadow: opt.value == value ? KShadow.float : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opt.icon != null) ...[
                          KIcon(opt.icon!, size: 16, color: opt.value == value ? KColor.ink : KColor.ink3),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          opt.label,
                          style: KType.body(
                            color: opt.value == value ? KColor.ink : KColor.ink3,
                            w: opt.value == value ? KWeight.semibold : KWeight.medium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill chip — categories & filters. Selected = purple fill + white text.
class KPillChip extends StatelessWidget {
  const KPillChip({super.key, required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KMotion.fast,
        curve: KMotion.easeSoft,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? KColor.indicator : KColor.paper,
          borderRadius: BorderRadius.circular(KRadii.pill),
          border: Border.all(color: selected ? KColor.indicator : KColor.hairline, width: 1),
        ),
        child: Text(
          label,
          style: KType.label(color: selected ? KColor.paper : KColor.ink2)
              .copyWith(letterSpacing: 0.01 * 11, height: 1.0),
        ),
      ),
    );
  }
}

/// A picked file (mock — the real picker plugs in later).
class KFileInfo {
  const KFileInfo({required this.name, this.size});
  final String name;
  final int? size;

  String get sizeLabel {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).round()} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// File upload — dashed dropzone; collapses to a file row once chosen.
/// On mobile, tapping the zone invokes [onPick] (a real picker plugs in later).
class KFileUpload extends StatelessWidget {
  const KFileUpload({
    super.key,
    this.label,
    this.hint = 'PDF, PNG or JPG · up to 10 MB',
    this.prompt = 'Tap to upload, or take a photo',
    this.helper,
    this.error,
    this.disabled = false,
    this.file,
    this.onPick,
    this.onRemove,
  });

  final String? label;
  final String hint;
  final String prompt;
  final String? helper;
  final String? error;
  final bool disabled;
  final KFileInfo? file;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final borderColor = error != null ? KColor.loss : KColor.hairline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!.upper, style: KType.label(color: disabled ? KColor.ink3 : KColor.ink2)),
          const SizedBox(height: 8),
        ],
        if (file == null)
          GestureDetector(
            onTap: disabled ? null : onPick,
            child: DottedBorder(
              color: borderColor,
              radius: KRadii.card,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KColor.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: KColor.hairline, width: 1),
                      ),
                      child: KIcon('arrowUp', size: 20, color: disabled ? KColor.ink3 : KColor.ink),
                    ),
                    const SizedBox(height: 8),
                    Text(prompt,
                        style: KType.body(
                            color: disabled ? KColor.ink3 : KColor.ink, w: KWeight.medium)),
                    const SizedBox(height: 4),
                    Text(hint, style: KType.micro(color: KColor.ink3)),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KColor.paper,
              borderRadius: BorderRadius.circular(KRadii.input),
              border: Border.all(color: error != null ? KColor.loss : KColor.hairline, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KColor.ink,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const KIcon('check', size: 18, color: KColor.paper),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KType.cardTitle()),
                      const SizedBox(height: 2),
                      Text(file!.sizeLabel,
                          style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0.04 * 10)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: KIcon('close', size: 18, color: KColor.ink3),
                  ),
                ),
              ],
            ),
          ),
        if (error != null || helper != null) ...[
          const SizedBox(height: 7),
          Text(error ?? helper!,
              style: KType.micro(color: error != null ? KColor.loss : KColor.ink3)),
        ],
      ],
    );
  }
}

/// A 1.5px dashed rounded border (the dropzone edge). Kept here as it's only
/// used by KFileUpload.
class DottedBorder extends StatelessWidget {
  const DottedBorder({super.key, required this.child, required this.color, this.radius = 16});
  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color, radius),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color || old.radius != radius;
}
