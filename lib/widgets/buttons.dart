// Button + IconButton. Ported 1:1 from components/core/Button.jsx and
// IconButton.jsx. Primary = the one purple moment per view; 0.98 press scale.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';
import 'spinner.dart';

enum KButtonVariant { primary, secondary, ghost }

enum KButtonSize { lg, md, sm }

class KButton extends StatefulWidget {
  const KButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = KButtonVariant.primary,
    this.size = KButtonSize.lg,
    this.fullWidth = true,
    this.loading = false,
    this.iconLeft,
    this.iconRight,
  });

  final String label;
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  final bool fullWidth;
  final bool loading;
  final String? iconLeft;
  final String? iconRight;

  bool get _disabled => onPressed == null;

  @override
  State<KButton> createState() => _KButtonState();
}

class _KButtonState extends State<KButton> {
  bool _pressed = false;

  double get _height => switch (widget.size) {
        KButtonSize.lg => 50,
        KButtonSize.md => 44,
        KButtonSize.sm => 36,
      };
  double get _pad => switch (widget.size) {
        KButtonSize.lg => 20,
        KButtonSize.md => 18,
        KButtonSize.sm => 14,
      };
  double get _fontSize => switch (widget.size) {
        KButtonSize.lg => 15,
        KButtonSize.md => 14,
        KButtonSize.sm => 13,
      };

  @override
  Widget build(BuildContext context) {
    final blocked = widget._disabled || widget.loading;
    final disabled = widget._disabled;

    late Color bg;
    late Color fg;
    Color border = const Color(0x00000000);
    switch (widget.variant) {
      case KButtonVariant.primary:
        bg = disabled
            ? KColor.ink3
            : (_pressed && !widget.loading ? KColor.indicatorPress : KColor.indicator);
        fg = KColor.paper;
        break;
      case KButtonVariant.secondary:
        bg = KColor.paper;
        fg = disabled ? KColor.ink3 : KColor.ink;
        border = KColor.hairline;
        break;
      case KButtonVariant.ghost:
        bg = _pressed && !blocked ? KColor.bg : const Color(0x00000000);
        fg = disabled ? KColor.ink3 : KColor.ink;
        break;
    }

    final iconSize = 18.0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.iconLeft != null) ...[
          KIcon(widget.iconLeft!, size: iconSize, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: KType.cardTitle(color: fg, w: KWeight.semibold).copyWith(
            fontSize: _fontSize,
            letterSpacing: -0.01 * _fontSize,
            height: 1.0,
          ),
        ),
        if (widget.iconRight != null) ...[
          const SizedBox(width: 8),
          KIcon(widget.iconRight!, size: iconSize, color: fg),
        ],
      ],
    );

    return GestureDetector(
      onTapDown: blocked ? null : (_) => setState(() => _pressed = true),
      onTapUp: blocked ? null : (_) => setState(() => _pressed = false),
      onTapCancel: blocked ? null : () => setState(() => _pressed = false),
      onTap: blocked ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed && !blocked ? 0.98 : 1.0,
        duration: KMotion.fast,
        curve: KMotion.easeSoft,
        child: AnimatedContainer(
          duration: KMotion.fast,
          curve: KMotion.easeSoft,
          width: widget.fullWidth ? double.infinity : null,
          height: _height,
          padding: EdgeInsets.symmetric(horizontal: _pad),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: KRadii.buttonR,
            border: Border.all(
              color: widget.variant == KButtonVariant.secondary ? border : const Color(0x00000000),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: widget.loading ? 0 : 1, child: content),
              if (widget.loading)
                KSpinner(size: widget.size == KButtonSize.sm ? 16 : 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

enum KIconButtonVariant { solid, float }

/// Circular icon button — solid white + hairline; `float` adds a soft shadow.
class KIconButton extends StatefulWidget {
  const KIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.variant = KIconButtonVariant.solid,
    this.semanticLabel,
  });

  final String icon;
  final VoidCallback? onPressed;
  final double size;
  final KIconButtonVariant variant;
  final String? semanticLabel;

  @override
  State<KIconButton> createState() => _KIconButtonState();
}

class _KIconButtonState extends State<KIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: KMotion.fast,
          curve: KMotion.easeSoft,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KColor.paper,
              shape: BoxShape.circle,
              border: Border.all(color: KColor.hairline, width: 1),
              boxShadow: widget.variant == KIconButtonVariant.float ? KShadow.float : null,
            ),
            child: KIcon(widget.icon, size: 20, color: KColor.ink),
          ),
        ),
      ),
    );
  }
}
