// Kudimata Invest — the AI "comprehension layer" (2026-08-22 "Soft Landing"
// redesign; see the 2026-08-22 product audit's section 6.7 and
// docs/redesign/screen-specs.md screens 06, 14, 15, 27, 29, 34, 38, 45, 53,
// 54, 57). Ported from components/comprehension/*.jsx. Every one of these
// renders GENERATED content, and the audit is explicit that the user must
// always be able to tell that at a glance — KAIMark is the recurring visual
// signature that does that.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';
import 'illustration.dart';
import 'k_icon.dart';

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

/// The 4-point spark glyph — Icon.jsx's inline path, always grape (or
/// whatever `color` is asked for) since it's a signature, not a themed icon.
String _sparkSvg(Color color) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12">'
    '<path d="M6 0.6 7.1 4.1 10.6 5.2 7.1 6.3 6 9.8 4.9 6.3 1.4 5.2 4.9 4.1Z" fill="${_hex(color)}"/>'
    '</svg>';

/// A hand-dashed underline (Flutter has no CSS `border-bottom-style: dashed`
/// equivalent) — used by [KGlossaryTerm] and the inline [KExplainTrigger].
class _DashedUnderline extends StatelessWidget {
  const _DashedUnderline({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedLinePainter(KColor.indicatorSoft),
      child: Padding(padding: const EdgeInsets.only(bottom: 2), child: child),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 3.0, gap = 2.0;
    final y = size.height - 0.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dashWidth, size.width), y), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

/// The signature on anything Kudimata generated for you — components/comprehension/AIMark.jsx.
/// A grape dot with the spark glyph (or a [guide] avatar in its place) plus an
/// uppercase micro label. Appears on every comprehension-layer surface so
/// generated content is never mistaken for static product copy.
class KAIMark extends StatelessWidget {
  const KAIMark({
    super.key,
    this.label = 'Written for you',
    this.size = 20,
    this.guide,
    this.showLabel = true,
  });

  final String label;
  final double size;
  final Widget? guide;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final mark = guide != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(size / 2),
            child: SizedBox(width: size, height: size, child: guide),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: KColor.indicator, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: SvgPicture.string(_sparkSvg(KColor.featureInk), width: size * 0.62, height: size * 0.62),
          );
    if (!showLabel) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 7),
      Text(label.upper, style: KType.micro(color: KColor.indicator)),
    ]);
  }
}

/// The comprehension layer's own surface — components/comprehension/ExplainPanel.jsx.
/// Warmer, roomier and more conversational than a card; the one part of the
/// product meant to feel like a knowledgeable friend rather than a form.
class KExplainPanel extends StatelessWidget {
  const KExplainPanel({
    super.key,
    this.title,
    required this.body,
    this.register = 'Explaining',
    this.illustration,
    this.actions,
  });

  final String? title;
  final String body;
  final String register;
  final Widget? illustration;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.featureR),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const KAvatar.guide(size: KIllo.avatarSm),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kudimata Invest',
                    style: KType.cardTitle(color: KColor.indicatorPress).copyWith(fontSize: 13, height: 1.2)),
                Text(register.upper, style: KType.micro()),
              ],
            ),
          ]),
          if (illustration != null) ...[const SizedBox(height: 16), illustration!],
          const SizedBox(height: 16),
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontFamily: KType.fontDisplay,
                fontWeight: KWeight.bold,
                fontSize: 20,
                height: 26 / 20,
                letterSpacing: -0.02 * 20,
                color: KColor.indicatorPress,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(body, style: KType.body()),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions!),
          ],
        ],
      ),
    );
  }
}

enum KExplainTriggerVariant { pill, inline, icon }

/// The persistent, obviously-tappable "Explain this" affordance —
/// components/comprehension/ExplainTrigger.jsx. The audit's own wording:
/// next to any product, term or filing, never a buried help-article link.
class KExplainTrigger extends StatelessWidget {
  const KExplainTrigger({
    super.key,
    this.label = 'Explain this',
    this.variant = KExplainTriggerVariant.pill,
    this.onTap,
  });

  final String label;
  final KExplainTriggerVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spark = SvgPicture.string(_sparkSvg(KColor.indicator), width: 13, height: 13);
    switch (variant) {
      case KExplainTriggerVariant.inline:
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            spark,
            const SizedBox(width: 6),
            _DashedUnderline(
              child: Text(label, style: KType.cardTitle(color: KColor.indicator).copyWith(fontSize: 13)),
            ),
          ]),
        );
      case KExplainTriggerVariant.icon:
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.pillR),
            child: spark,
          ),
        );
      case KExplainTriggerVariant.pill:
        return GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.pillR),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              spark,
              const SizedBox(width: 6),
              Text(label, style: KType.cardTitle(color: KColor.indicator).copyWith(fontSize: 13)),
            ]),
          ),
        );
    }
  }
}

enum KGeneratingState { thinking, writing, done }

/// The states while Kudimata writes — components/comprehension/GeneratingText.jsx.
/// A spinner tells a first-time investor nothing about whether the app is
/// stuck or working: thinking shimmers, writing reveals character-by-character
/// with a caret, done is plain text. Honours reduced-motion.
class KGeneratingText extends StatefulWidget {
  const KGeneratingText({
    super.key,
    required this.text,
    this.state = KGeneratingState.writing,
    this.lines = 3,
    this.speedMs = 18,
    this.onDone,
  });

  final String text;
  final KGeneratingState state;
  final int lines;
  final int speedMs;
  final VoidCallback? onDone;

  @override
  State<KGeneratingText> createState() => _KGeneratingTextState();
}

class _KGeneratingTextState extends State<KGeneratingText> with SingleTickerProviderStateMixin {
  String _shown = '';
  Timer? _timer;
  bool _reducedMotion = false;
  bool _started = false;
  late final AnimationController _shimmerCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (!_started) {
      _started = true;
      _start();
    }
  }

  @override
  void didUpdateWidget(covariant KGeneratingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.state != widget.state) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (widget.state != KGeneratingState.writing) {
      setState(() => _shown = widget.state == KGeneratingState.done ? widget.text : '');
      return;
    }
    if (_reducedMotion) {
      setState(() => _shown = widget.text);
      widget.onDone?.call();
      return;
    }
    var i = 0;
    setState(() => _shown = '');
    _timer = Timer.periodic(Duration(milliseconds: widget.speedMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      i++;
      setState(() => _shown = widget.text.substring(0, i.clamp(0, widget.text.length)));
      if (i >= widget.text.length) {
        t.cancel();
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == KGeneratingState.thinking) {
      // Simplified from the web version's moving gradient sweep to a pulsing
      // opacity skeleton — reads as "shimmering, not static" without needing
      // a per-line shader/gradient-transform setup.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.lines; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (context, _) {
                  final opacity = 0.35 + 0.5 * (0.5 + 0.5 * math.sin(_shimmerCtrl.value * 2 * math.pi));
                  return Opacity(
                    opacity: opacity,
                    child: FractionallySizedBox(
                      widthFactor: i == widget.lines - 1 ? 0.62 : 1.0,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }
    final caretVisible = widget.state == KGeneratingState.writing && _shown.length < widget.text.length;
    return RichText(
      text: TextSpan(style: KType.body(), children: [
        TextSpan(text: _shown),
        if (caretVisible) WidgetSpan(alignment: PlaceholderAlignment.middle, child: _Caret()),
      ]),
    );
  }
}

class _Caret extends StatefulWidget {
  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c.drive(TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 45),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 5),
      ])),
      child: Container(width: 2, height: 14, margin: const EdgeInsets.only(left: 2), color: KColor.indicator),
    );
  }
}

/// A term a first-time investor may not know, marked in place —
/// components/comprehension/GlossaryTerm.jsx. Dashed grape underline,
/// tappable (never hover-only, per the audit).
class KGlossaryTerm extends StatelessWidget {
  const KGlossaryTerm({super.key, required this.text, this.onTap, this.style});

  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _DashedUnderline(
        child: Text(text, style: (style ?? KType.body()).copyWith(color: KColor.indicator)),
      ),
    );
  }
}

/// Plain English above the raw filing, always one tap from the original —
/// components/comprehension/DocumentSummary.jsx. The audit is explicit this
/// order is the feature, not a detail, and deserves a first-class screen.
class KDocumentSummary extends StatefulWidget {
  const KDocumentSummary({
    super.key,
    this.kind = 'Corporate filing',
    this.title,
    required this.summary,
    this.points = const [],
    this.original,
    this.footer,
  });

  final String kind;
  final String? title;
  final String summary;
  final List<String> points;
  final String? original;
  final Widget? footer;

  @override
  State<KDocumentSummary> createState() => _KDocumentSummaryState();
}

class _KDocumentSummaryState extends State<KDocumentSummary> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: KColor.indicatorTint, borderRadius: KRadii.featureR),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const KAIMark(label: 'In plain English'),
                Text(widget.kind.upper, style: KType.micro()),
              ]),
              if (widget.title != null) ...[
                const SizedBox(height: 12),
                Text(widget.title!, style: KType.section(color: KColor.indicatorPress)),
              ],
              const SizedBox(height: 8),
              Text(widget.summary, style: KType.body()),
              if (widget.points.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final p in widget.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 8, right: 10),
                        decoration: BoxDecoration(color: KColor.indicatorSoft, shape: BoxShape.circle),
                      ),
                      Expanded(child: Text(p, style: KType.body().copyWith(fontSize: 14))),
                    ]),
                  ),
              ],
              if (widget.footer != null) ...[const SizedBox(height: 16), widget.footer!],
            ],
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _showOriginal = !_showOriginal),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline),
              borderRadius: KRadii.cardR,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_showOriginal ? 'Hide the original document' : 'Read the original document',
                  style: KType.cardTitle()),
              Text((_showOriginal ? 'Close' : 'NGX filing').upper, style: KType.micro()),
            ]),
          ),
        ),
        if (_showOriginal && widget.original != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline),
              borderRadius: KRadii.cardR,
            ),
            child: Text(widget.original!, style: KType.data(color: KColor.ink2)),
          ),
        ],
      ],
    );
  }
}

/// Generated answers cost real money to produce, so the balance is always
/// visible before the tap — components/comprehension/CreditMeter.jsx. There
/// is no unlimited plan in this product; `total` is always a real number.
class KCreditMeter extends StatelessWidget {
  const KCreditMeter({
    super.key,
    this.used = 0,
    this.total = 10,
    this.kind = 'trial',
    this.unit = 'explanations',
    this.renews,
    this.action,
    this.compact = false,
  });

  final int used;
  final int total;

  /// 'trial' | 'plan' | anything else (generic "Explanations" label).
  final String kind;
  final String unit;
  final String? renews;
  final Widget? action;
  final bool compact;

  int get _left => (total - used).clamp(0, total);
  bool get _out => _left == 0;
  bool get _low => !_out && _left <= math.max(1, (total * 0.2).round());
  Color get _barColor => _out ? KColor.loss : (_low ? KColor.warm : KColor.indicator);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: _out ? KColor.warmTint : KColor.indicatorTint,
          borderRadius: KRadii.pillR,
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const KAIMark(showLabel: false, size: 14),
          const SizedBox(width: 7),
          Text(_out ? 'None left' : '$_left left',
              style: KType.micro(color: _out ? KColor.warmPress : KColor.indicator)),
        ]),
      );
    }

    final pct = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline),
        borderRadius: KRadii.cardR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            KAIMark(label: kind == 'trial' ? 'Free trial' : (kind == 'plan' ? 'Your plan' : 'Explanations')),
            Text('$_left of $total left',
                style: KType.data(color: _out ? KColor.loss : KColor.ink, w: KWeight.semibold).tnum),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: KColor.track,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (1 - pct).clamp(0.0, 1.0),
                child: Container(color: _barColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_out)
            Text(
              'You have used every ${unit.replaceFirst(RegExp(r's$'), '')} in this ${kind == 'trial' ? 'trial' : 'cycle'}.',
              style: KType.data(color: KColor.ink3),
            )
          else if (renews != null)
            Text('Renews $renews.', style: KType.data(color: KColor.ink3))
          else if (kind == 'trial')
            Text('Free while you are getting started.', style: KType.data(color: KColor.ink3)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Shown INSTEAD of a generated answer when the balance is empty —
/// components/comprehension/CreditGate.jsx. Must never read as an error: warm
/// plate, plain arithmetic, one action, and always names what stays free.
class KCreditGate extends StatelessWidget {
  const KCreditGate({
    super.key,
    this.title = 'You have used your free explanations',
    this.message,
    this.price,
    this.freeAlternative,
    this.primary,
    this.secondary,
  });

  final String title;
  final String? message;
  final String? price;
  final String? freeAlternative;
  final Widget? primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: KColor.warmTint, borderRadius: KRadii.featureR),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // plate="none" in the source JSX — bare scene, no additional tint
          // plate (this container's own warmTint background is the plate).
          SvgPicture.asset('assets/illustrations/wallet-fund.svg', height: KIllo.small, fit: BoxFit.contain),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: KType.section()),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: KType.body()),
          ],
          if (price != null) ...[
            const SizedBox(height: 16),
            Text(price!, style: KType.cardTitle(color: KColor.warmPress).tnum),
          ],
          if (primary != null || secondary != null) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [?primary, ?secondary]),
          ],
          if (freeAlternative != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x12000000)))),
              child: Text(freeAlternative!, textAlign: TextAlign.center, style: KType.data(color: KColor.ink3)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A plan, with its credit count stated on the face of it —
/// components/comprehension/PlanCard.jsx. No unlimited tier exists in this
/// product; `credits` is required and always shown.
class KPlanCard extends StatelessWidget {
  const KPlanCard({
    super.key,
    required this.name,
    required this.price,
    this.period = 'per month',
    required this.credits,
    this.unit = 'explanations a month',
    this.features = const [],
    this.featured = false,
    this.note,
    this.action,
  });

  final String name;
  final String price;
  final String period;
  final String credits;
  final String unit;
  final List<String> features;
  final bool featured;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ink = featured ? KColor.featureInk : KColor.ink;
    final ink2 = featured ? KColor.featureInk2 : KColor.ink2;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: featured ? KColor.feature : KColor.paper,
        border: Border.all(color: featured ? KColor.feature : KColor.hairline),
        borderRadius: KRadii.featureR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: KType.cardTitle(color: featured ? KColor.sun : KColor.indicator)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(
              price,
              style: TextStyle(
                      fontFamily: KType.fontDisplay,
                      fontWeight: KWeight.black,
                      fontSize: 30,
                      letterSpacing: -0.75,
                      color: ink)
                  .tnum,
            ),
            const SizedBox(width: 7),
            Text(period, style: KType.data(color: featured ? KColor.featureInk2 : KColor.ink3)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: featured ? const Color(0x1AFFFFFF) : KColor.indicatorTint,
              borderRadius: KRadii.chipR,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  credits,
                  style: TextStyle(
                          fontFamily: KType.fontDisplay,
                          fontWeight: KWeight.black,
                          fontSize: 20,
                          color: featured ? KColor.featureInk : KColor.indicatorPress)
                      .tnum,
                ),
                const SizedBox(width: 7),
                Flexible(child: Text(unit, style: KType.data(color: ink2))),
              ],
            ),
          ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('•',
                      style: TextStyle(
                          color: featured ? KColor.sun : KColor.gain, fontWeight: KWeight.bold, fontSize: 14)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(f, style: KType.body(color: ink2).copyWith(fontSize: 14))),
                ]),
              ),
          ],
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!,
                style: KType.data(color: featured ? KColor.featureInk2 : KColor.ink3).copyWith(fontSize: 13)),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class KLanguageSwitchOption {
  const KLanguageSwitchOption(this.id, this.label);
  final String id;
  final String label;
}

/// English / Pidgin — components/comprehension/LanguageSwitch.jsx. The audit
/// is specific: persistent and low-friction, never buried in settings. A
/// distinct pill-track visual, not the app's boxier [KSegmentedControl].
class KLanguageSwitch extends StatelessWidget {
  const KLanguageSwitch({super.key, this.value = 'en', this.options, this.onChanged});

  final String value;
  final List<KLanguageSwitchOption>? options;
  final ValueChanged<String>? onChanged;

  static const _default = [
    KLanguageSwitchOption('en', 'English'),
    KLanguageSwitchOption('pcm', 'Pidgin'),
  ];

  @override
  Widget build(BuildContext context) {
    final opts = options ?? _default;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: KColor.track, borderRadius: KRadii.pillR),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < opts.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          _LanguageOption(option: opts[i], selected: opts[i].id == value, onTap: () => onChanged?.call(opts[i].id)),
        ],
      ]),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.option, required this.selected, this.onTap});
  final KLanguageSwitchOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KMotion.fast,
        curve: KMotion.easeSoft,
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? KColor.paper : null,
          borderRadius: KRadii.pillR,
          boxShadow: selected ? KShadow.card : null,
        ),
        child: Text(option.label,
            style: KType.cardTitle(color: selected ? KColor.ink : KColor.ink2).copyWith(fontSize: 13)),
      ),
    );
  }
}

enum KNudgeTone { warm, sun, grape }

/// Gentle encouragement, never a compliance notice —
/// components/comprehension/NudgeCard.jsx. Warm-toned and dismissible; must
/// never be red and must never look like an error.
class KNudgeCard extends StatelessWidget {
  const KNudgeCard({
    super.key,
    this.title,
    required this.body,
    this.tone = KNudgeTone.warm,
    this.avatar,
    this.onDismiss,
    this.action,
  });

  final String? title;
  final String body;
  final KNudgeTone tone;

  /// null → the pinned guide character (KAvatar.guide).
  final Widget? avatar;
  final VoidCallback? onDismiss;
  final Widget? action;

  Color get _tint => switch (tone) {
        KNudgeTone.warm => KColor.warmTint,
        KNudgeTone.sun => KColor.sunTint,
        KNudgeTone.grape => KColor.indicatorTint,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _tint, borderRadius: KRadii.cardR),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: KIllo.avatarSm,
          height: KIllo.avatarSm,
          child: avatar ?? const KAvatar.guide(size: KIllo.avatarSm),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) Text(title!, style: KType.cardTitle()),
              Padding(
                padding: EdgeInsets.only(top: title != null ? 3 : 0),
                child: Text(body, style: KType.body().copyWith(fontSize: 14)),
              ),
              if (action != null) Padding(padding: const EdgeInsets.only(top: 12), child: action!),
            ],
          ),
        ),
        if (onDismiss != null)
          GestureDetector(
            onTap: onDismiss,
            child: Padding(padding: const EdgeInsets.all(4), child: KIcon('close', size: 16, color: KColor.ink3)),
          ),
      ]),
    );
  }
}

/// "Your assistant telling you something" — components/comprehension/DigestCard.jsx.
/// Visually distinct from a holding/transaction row so generated content is
/// never mistaken for static product copy.
class KDigestCard extends StatelessWidget {
  const KDigestCard({super.key, this.eyebrow = 'Written for you', this.title, required this.body, this.footer});

  final String eyebrow;
  final String? title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline),
        borderRadius: KRadii.cardR,
        boxShadow: KShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          KAIMark(label: eyebrow, size: 20),
          const SizedBox(height: 12),
          if (title != null) ...[
            Text(title!, style: KType.section()),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 8),
          Text(body, style: KType.body()),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}
