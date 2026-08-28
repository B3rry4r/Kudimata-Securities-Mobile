// Deterministic sparkline generator. Not fixture/mock data — this produces
// the little inline trend line shown next to an asset's price from nothing
// but its trend direction, the same way for every render, so the app never
// needs a real tick-by-tick series just to draw a decorative shape.
import 'dart:math' as math;

/// Deterministic sparkline series — up trends rise, down trends fall, with a
/// little wobble. Ported verbatim from the design's app-data.jsx `spark(up, n
/// = 16)`.
List<double> spark(bool up, [int n = 16]) {
  final out = <double>[];
  for (var i = 0; i < n; i++) {
    out.add(
      math.sin(i * 0.7) * 2.4 + i * (up ? 0.55 : -0.55) + (i % 3) * 0.6,
    );
  }
  return out;
}
