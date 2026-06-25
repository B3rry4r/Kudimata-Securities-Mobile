// Sparkline, LineChart, AllocationDonut. Charts are the one place colour is
// expected. Ported from components/finance/{Sparkline,LineChart,AllocationDonut}.jsx.
// LineChart + donut use fl_chart; the tiny sparkline is a CustomPainter.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum KTrend { gain, loss }

/// Tiny inline sparkline — single 1.5px stroke, subtle fade fill.
class KSparkline extends StatelessWidget {
  const KSparkline({
    super.key,
    required this.data,
    this.width = 64,
    this.height = 28,
    this.trend = KTrend.gain,
    this.strokeWidth = 1.5,
  });

  final List<double> data;
  final double width;
  final double height;
  final KTrend trend;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(
          data.isNotEmpty ? data : const [0, 0],
          trend == KTrend.loss ? KColor.loss : KColor.gain,
          strokeWidth,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data, this.color, this.strokeWidth);
  final List<double> data;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final span = (max - min) == 0 ? 1 : (max - min);
    final stepX = size.width / (data.length - 1 == 0 ? 1 : data.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < data.length; i++)
        Offset(i * stepX, size.height - (data[i] - min) / span * (size.height - 2) - 1),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.data != data || old.color != color;
}

/// Line chart — single 1.75px stroke, subtle fill, time-range pills below.
class KLineChart extends StatefulWidget {
  const KLineChart({
    super.key,
    required this.data,
    this.ranges = const ['1D', '1W', '1M', '1Y', 'ALL'],
    this.range,
    this.onRangeChange,
    this.trend = KTrend.gain,
    this.height = 160,
    this.onDark = false,
  });

  final List<double> data;
  final List<String> ranges;
  final String? range;
  final ValueChanged<String>? onRangeChange;
  final KTrend trend;
  final double height;
  final bool onDark;

  @override
  State<KLineChart> createState() => _KLineChartState();
}

class _KLineChartState extends State<KLineChart> {
  late String _active = widget.range ?? widget.ranges.first;

  @override
  Widget build(BuildContext context) {
    final active = widget.range ?? _active;
    final color = widget.onDark
        ? const Color(0xFFB98AE6)
        : (widget.trend == KTrend.loss ? KColor.loss : KColor.gain);
    final data = widget.data.isNotEmpty ? widget.data : const [0.0, 0.0];
    final spots = [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i])];

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              minX: 0,
              maxX: (data.length - 1).toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: color,
                  barWidth: 1.75,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: widget.onDark ? 0.32 : 0.14),
                        color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final r in widget.ranges)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: r == widget.ranges.first ? 0 : 6),
                  child: _RangePill(
                    label: r,
                    active: r == active,
                    onDark: widget.onDark,
                    onTap: () {
                      setState(() => _active = r);
                      widget.onRangeChange?.call(r);
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({required this.label, required this.active, required this.onDark, required this.onTap});
  final String label;
  final bool active;
  final bool onDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = active
        ? (onDark ? const Color(0x29FFFFFF) : KColor.ink)
        : const Color(0x00000000);
    final Color fg = active
        ? KColor.paper
        : (onDark ? const Color(0x99FFFFFF) : KColor.ink3);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KRadii.pill)),
        child: Text(label,
            style: KType.label(color: fg).copyWith(letterSpacing: 0.04 * 11, height: 1.0).tnum),
      ),
    );
  }
}

class KDonutSegment {
  const KDonutSegment({required this.value, this.label, this.color});
  final double value;
  final String? label;
  final Color? color;
}

/// Allocation donut — brand purple ramp (indicator → tints).
class KAllocationDonut extends StatelessWidget {
  const KAllocationDonut({
    super.key,
    required this.segments,
    this.size = 140,
    this.thickness = 18,
    this.centerLabel,
    this.centerValue,
  });

  final List<KDonutSegment> segments;
  final double size;
  final double thickness;
  final String? centerLabel;
  final String? centerValue;

  static const ramp = [
    Color(0xFF670099),
    Color(0xFF8C39B8),
    Color(0xFFB07FD4),
    Color(0xFFD2B3E6),
    Color(0xFFECDDF5),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = [
      for (var i = 0; i < segments.length; i++)
        PieChartSectionData(
          value: segments[i].value,
          color: segments[i].color ?? ramp[i % ramp.length],
          radius: thickness,
          showTitle: false,
        ),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 0,
              centerSpaceRadius: size / 2 - thickness,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
          if (centerValue != null || centerLabel != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerValue != null)
                  Text(centerValue!,
                      style: KType.cardTitle(w: KWeight.semibold).copyWith(fontSize: 18).tnum),
                if (centerLabel != null)
                  Text(centerLabel!, style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0)),
              ],
            ),
        ],
      ),
    );
  }
}
