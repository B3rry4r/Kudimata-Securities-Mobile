// AssetRow, StatCard, BalancePanel. Ported from
// components/finance/{AssetRow,StatCard,BalancePanel}.jsx. Numbers tabular,
// never truncated; movement colour on the change number only.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'charts.dart';

/// Asset row — circular logo · name + ticker · right price + change% · optional
/// sparkline. Full text always; never truncated.
class KAssetRow extends StatelessWidget {
  const KAssetRow({
    super.key,
    required this.name,
    required this.ticker,
    this.logo,
    this.logoColor, // null → themed ink (resolved at build)
    this.price,
    this.change,
    this.trend,
    this.sparkline,
    this.onTap,
  });

  final String name;
  final String ticker;
  final Widget? logo; // a real mark; null → ticker initials on an ink circle
  final Color? logoColor;
  final String? price;
  final String? change;
  final KTrend? trend;
  final List<double>? sparkline;
  final VoidCallback? onTap;

  String get _initials {
    final letters = (ticker.isNotEmpty ? ticker : name).replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
  }

  KTrend get _dir =>
      trend ?? ((change != null && change!.trim().startsWith('-')) ? KTrend.loss : KTrend.gain);

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: logo != null ? KColor.bg : (logoColor ?? KColor.ink),
              shape: BoxShape.circle,
            ),
            child: logo ??
                Text(_initials,
                    style: KType.label(color: KColor.paper, w: KWeight.semibold)
                        .copyWith(fontSize: 12, letterSpacing: 0.24, height: 1.0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: KType.cardTitle().copyWith(height: 20 / 15)),
                const SizedBox(height: 2),
                Text(ticker,
                    style: KType.micro(color: KColor.ink3)
                        .copyWith(letterSpacing: 0.06 * 10, height: 15 / 10)),
              ],
            ),
          ),
          if (sparkline != null) ...[
            KSparkline(data: sparkline!, trend: _dir),
            const SizedBox(width: 4),
          ],
          if (price != null || change != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (price != null)
                  Text(price!, style: KType.cardTitle().copyWith(height: 20 / 15).tnum),
                if (change != null) ...[
                  const SizedBox(height: 2),
                  Text(change!,
                      style: KType.label(color: _dir == KTrend.loss ? KColor.loss : KColor.gain)
                          .copyWith(letterSpacing: 0, height: 16 / 11)
                          .tnum),
                ],
              ],
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }
}

enum KSubTone { neutral, gain, loss }

/// Stat card — solid hairline tile: line icon + tracked label + tabular value.
class KStatCard extends StatelessWidget {
  const KStatCard({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.subTone = KSubTone.neutral,
  });

  final Widget? icon;
  final String label;
  final String value;
  final String? sub;
  final KSubTone subTone;

  @override
  Widget build(BuildContext context) {
    final subColor = switch (subTone) {
      KSubTone.neutral => KColor.ink3,
      KSubTone.gain => KColor.gain,
      KSubTone.loss => KColor.loss,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: BorderRadius.circular(KRadii.card),
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(height: 14)],
          Text(label.upper, style: KType.label()),
          const SizedBox(height: 4),
          Text(value,
              style: KType.cardTitle(w: KWeight.semibold)
                  .copyWith(fontSize: 20, height: 24 / 20, letterSpacing: -0.20)
                  .tnum),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: KType.label(color: subColor).copyWith(letterSpacing: 0, height: 1.2).tnum),
          ],
        ],
      ),
    );
  }
}

/// Balance panel — the one rich surface per screen. Solid ink, white text.
class KBalancePanel extends StatelessWidget {
  const KBalancePanel({
    super.key,
    required this.label,
    required this.balance,
    this.change,
    this.changeTone = KTrend.gain,
    this.chart,
    this.action,
  });

  final String label;
  final String balance;
  final String? change;
  final KTrend changeTone;
  final Widget? chart;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final changeColor = changeTone == KTrend.loss ? KColor.lossOnInk : KColor.gainOnInk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KColor.feature,
        borderRadius: KRadii.featureR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.upper, style: KType.label(color: KColor.featureInk2)),
          const SizedBox(height: 12),
          Text(balance, style: KType.hero(color: KColor.featureInk).tnum),
          if (change != null) ...[
            const SizedBox(height: 8),
            Text(change!, style: KType.body(color: changeColor, w: KWeight.medium).tnum),
          ],
          if (chart != null) ...[const SizedBox(height: 20), chart!],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
