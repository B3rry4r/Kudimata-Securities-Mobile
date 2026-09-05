// Text field, search pill, segmented control, pill chip, file upload.
// Ported from components/core/{Input,SearchPill,SegmentedControl,PillChip,FileUpload}.jsx.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import '../theme/tokens.dart';
import 'k_icon.dart';

/// Shared field-label row: the tracked uppercase label used across every
/// input-shaped control, with an optional trailing red asterisk for fields
/// that actually block submission when left empty. Built once here so
/// [KInput], [KFileUpload], and the per-screen picker/"tappable select"
/// field widgets (state, bank, document-type, phone country, etc.) render
/// the same marker instead of each reimplementing it — see the owner's
/// "compulsory fields get a red asterisk" instruction (2026-08-31).
///
/// The asterisk is a visual-only signal, so [required] also folds into this
/// widget's semantics label ("Field, required") rather than leaving screen
/// readers with no way to know.
class KFieldLabel extends StatelessWidget {
  const KFieldLabel(this.text, {super.key, this.required = false, this.color});

  final String text;
  final bool required;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = KType.label(color: color);
    return Semantics(
      label: required ? '$text, required' : text,
      excludeSemantics: true,
      child: RichText(
        text: TextSpan(
          text: text.upper,
          style: style,
          children: required
              ? [TextSpan(text: ' *', style: style.copyWith(color: KColor.loss))]
              : null,
        ),
      ),
    );
  }
}

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
    this.multiline = false,
    this.minLines = 3,
    this.required = false,
    this.maxLength,
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

  /// Marks the field as one that actually blocks submission when empty —
  /// renders a red asterisk beside the label. Set this only for fields
  /// confirmed in the screen's own validity/button-enable logic, not from
  /// the label text alone.
  final bool required;

  /// Editorial large-amount mode: bumps the input figure (and ₦/$ prefix) to a
  /// 26px semibold tabular numeral, matching the design's amount-entry sheets
  /// (Buy/Sell/Add money/Withdraw at 26, Convert at 22 via [amountSize]).
  final bool amount;

  /// The figure size when [amount] is true.
  final double amountSize;

  /// Grows into a multi-line free-text field instead of the fixed 50px
  /// single-line row — for the rare "describe what happened" style field
  /// (e.g. the complaint form's "What happened?"), not a new component,
  /// just KInput's existing frame with wrapping enabled.
  final bool multiline;

  /// Minimum visible lines when [multiline] is true.
  final int minLines;

  /// Hard character cap, enforced while typing — a prop on the one input,
  /// not a second input (2026-09-05, added for the KYC occupation field's
  /// wire bound). Null means uncapped, which is every existing caller.
  ///
  /// Deliberately NOT TextField.maxLength: that draws Material's own "12/100"
  /// counter below the field, which is not in this design system. This just
  /// stops the field accepting more, the same way otp_screen.dart's own raw
  /// TextField already does with LengthLimitingTextInputFormatter.
  final int? maxLength;

  @override
  State<KInput> createState() => _KInputState();
}

class _KInputState extends State<KInput> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

  // Password/passcode fields (widget.obscure) start hidden, same as before —
  // this just tracks whether the reveal toggle below has since flipped that.
  late bool _obscured = widget.obscure;

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
          KFieldLabel(widget.label!,
              required: widget.required,
              color: widget.disabled ? KColor.ink3 : KColor.ink2),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: KMotion.fast,
          curve: KMotion.easeSoft,
          height: widget.amount ? 64 : (widget.multiline ? null : 50),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: widget.multiline ? 14 : 0,
          ),
          decoration: BoxDecoration(
            color: widget.disabled ? KColor.bg : KColor.paper,
            borderRadius: BorderRadius.circular(KRadii.input),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            crossAxisAlignment:
                widget.multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
                  inputFormatters: widget.maxLength == null
                      ? null
                      : [LengthLimitingTextInputFormatter(widget.maxLength!)],
                  obscureText: _obscured,
                  maxLines: widget.multiline ? null : 1,
                  minLines: widget.multiline ? widget.minLines : null,
                  textInputAction:
                      widget.multiline ? TextInputAction.newline : TextInputAction.done,
                  keyboardType: widget.keyboardType ??
                      (widget.multiline
                          ? TextInputType.multiline
                          : widget.numeric
                              ? TextInputType.number
                              : TextInputType.text),
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
              if (widget.obscure) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _obscured = !_obscured),
                  child: KIcon(_obscured ? 'eye' : 'eyeOff', size: 18, color: KColor.ink3),
                ),
              ] else if (widget.trailing != null) ...[
                const SizedBox(width: 10),
                widget.trailing!,
              ],
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
          KIcon('search', size: 18, color: KColor.ink3),
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
              child: Padding(
                padding: const EdgeInsets.all(2),
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
    this.compact = false,
  });

  final List<KSegmentOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  /// Small, content-hugging track (e.g. screen 35's Buy/Sell sheet title
  /// row: a "Naira / Shares" toggle sitting beside the title, not stretched
  /// across the sheet). Segments size to their label instead of sharing
  /// equal `Expanded` widths, and the track sits at 40px instead of the
  /// default 46px. Added as a prop rather than a second widget so every
  /// call site keeps the same selected-segment look and behaviour.
  final bool compact;

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
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (final opt in options)
            // Expanded must be a DIRECT child of this Row — nesting it
            // inside the Padding (as this used to) throws "Incorrect use of
            // ParentDataWidget" (Expanded's ParentData applied to Padding's
            // RenderObject instead of a Flex slot). Padding now wraps the
            // segment and Expanded wraps the Padding, not the reverse.
            compact
                ? Padding(
                    padding: EdgeInsets.only(left: opt == options.first ? 0 : 4),
                    child: _segment(opt),
                  )
                : Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: opt == options.first ? 0 : 4),
                      child: _segment(opt),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _segment(KSegmentOption opt) {
    final tile = GestureDetector(
      onTap: () => onChanged(opt.value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: KMotion.fast,
        curve: KMotion.easeSoft,
        height: 38,
        padding: compact ? const EdgeInsets.symmetric(horizontal: 14) : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: opt.value == value ? KColor.paper : const Color(0x00000000),
          // Radius 10, not 7 (2026-08-24): the track outside this is
          // KRadii.input (14) with 4px padding, so the inner curve it has
          // to sit inside is 14 - 4 = 10. At 7 the pill's corners bulged
          // past the track's rounder corners and read as a doubled,
          // mis-clipped edge — most visible on the selected segment, where
          // the pill also carries a border and shadow.
          borderRadius: BorderRadius.circular(KRadii.input - 4),
          border: Border.all(
            color: opt.value == value ? KColor.hairline : const Color(0x00000000),
            width: 1,
          ),
          // knob, not float (2026-08-24): float is offset(0,8)/blur 24 —
          // a shadow sized for a whole card lifting off the page. On a 38px
          // pill inside a track with 4px padding it spills far outside the
          // track's rounded bounds and reads as a smudged, clipped
          // rendering fault. knob (offset(0,2)/blur 6) is the token meant
          // for exactly this: a small element floating just above its own
          // track.
          boxShadow: opt.value == value ? KShadow.knob : null,
        ),
        child: _segmentContent(opt),
      ),
    );
    return tile;
  }

  Widget _segmentContent(KSegmentOption opt) {
    return Row(
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
    // 2026-08-24 fix: every Wrap of these across the app ("pills are
    // vertical") — `Wrap` gives each child a BOUNDED maxWidth (the wrap's
    // own full width), not an unbounded one. A `Container` with `alignment`
    // set but no explicit width, given bounded constraints, tries to be "as
    // big as possible" before centering its child — so this pill stretched
    // to the wrap's full width every time, one per row, instead of hugging
    // its own text. Fixed by centering via `Center(widthFactor: 1,
    // heightFactor: 1, ...)` instead of `Container.alignment` — that shrinks
    // the centering box to its child's own size rather than expanding to
    // fill.
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KMotion.fast,
        curve: KMotion.easeSoft,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? KColor.indicator : KColor.paper,
          borderRadius: BorderRadius.circular(KRadii.pill),
          border: Border.all(color: selected ? KColor.indicator : KColor.hairline, width: 1),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            label,
            style: KType.label(color: selected ? KColor.featureInk : KColor.ink2)
                .copyWith(letterSpacing: 0.01 * 11, height: 1.0),
          ),
        ),
      ),
    );
  }
}

/// A picked file, as returned by the platform file picker (`file_picker`).
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
/// On mobile, tapping the zone invokes [onPick], which callers wire to the
/// platform file picker (`file_picker`).
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
    this.required = false,
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

  /// See [KInput.required] — renders a red asterisk beside the label.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final borderColor = error != null ? KColor.loss : KColor.hairline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          KFieldLabel(label!, required: required, color: disabled ? KColor.ink3 : KColor.ink2),
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
                    color: KColor.feature,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: KIcon('check', size: 18, color: KColor.featureInk),
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
                  child: Padding(
                    padding: const EdgeInsets.all(4),
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
