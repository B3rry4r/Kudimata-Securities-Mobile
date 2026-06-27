// Spinner — a thin rotating ring. Defaults to brand purple; pass a colour
// (e.g. white) inside an ink/purple button. Ported from feedback/Spinner.jsx.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

class KSpinner extends StatefulWidget {
  const KSpinner({
    super.key,
    this.size = 18,
    this.stroke = 2,
    this.color, // null → brand purple (resolved at build)
    this.trackOpacity = 0.18,
  });

  final double size;
  final double stroke;
  final Color? color;
  final double trackOpacity;

  @override
  State<KSpinner> createState() => _KSpinnerState();
}

class _KSpinnerState extends State<KSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _c,
        child: CustomPaint(
          painter: _SpinnerPainter(widget.color ?? KColor.indicator, widget.stroke, widget.trackOpacity),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color, this.stroke, this.trackOpacity);
  final Color color;
  final double stroke;
  final double trackOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: trackOpacity);
    canvas.drawCircle(center, r, track);

    // a 90° arc cap, matching the JS "M12 3 a9 9 0 0 1 9 9" quarter sweep
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -1.5708, 1.5708, false, arc);
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.color != color || old.stroke != stroke || old.trackOpacity != trackOpacity;
}
