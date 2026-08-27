// AssetRow, StatCard, BalancePanel. Ported from
// components/finance/{AssetRow,StatCard,BalancePanel}.jsx. Numbers tabular,
// never truncated; movement colour on the change number only.
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import 'charts.dart';
import 'k_icon.dart';

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
    this.initialsSource,
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

  /// Overrides what the fallback-initials badge reads letters from, when
  /// [ticker] itself isn't the instrument symbol (e.g. the Portfolio screen,
  /// mockup-raw/s38.html, passes a composed "120 shares · avg ₦241.10"
  /// string as `ticker` for display — that string has no symbol letters to
  /// extract). Null keeps the original ticker-then-name fallback.
  final String? initialsSource;

  String get _initials {
    final source = initialsSource ?? (ticker.isNotEmpty ? ticker : name);
    final letters = source.replaceAll(RegExp(r'[^A-Za-z]'), '');
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
              color: logo != null ? KColor.bg : (logoColor ?? KColor.indicatorTint),
              shape: BoxShape.circle,
            ),
            child: logo ??
                Text(_initials,
                    style: KType.label(color: logoColor != null ? KColor.featureInk : KColor.indicator, w: KWeight.semibold)
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
///
/// 2026-08-27 (Home rebuild, R-32): given an optional prop rather than a
/// fork per DECISIONS.md's screen-agent rule 5 — s22/s23/s34/s35's "money
/// card" ('03 Home and Markets.dc.html' lines 56-67, also '05 Portfolio and
/// Wallet.dc.html' lines 52-67/292-...) is the SAME concept (a headline
/// balance) on a genuinely different surface: paper + hairline instead of
/// solid ink, a decorative indicator-tint blob, an optional top-right
/// illustration, and the balance's minor (cents) part styled smaller/muted.
/// [light] switches to that surface; [illustration] and the balance-split
/// styling only apply when it's set.
class KBalancePanel extends StatelessWidget {
  const KBalancePanel({
    super.key,
    required this.label,
    required this.balance,
    this.change,
    this.changeTone = KTrend.gain,
    this.chart,
    this.action,
    this.light = false,
    this.illustration,
  });

  final String label;
  final String balance;
  final String? change;
  final KTrend changeTone;
  final Widget? chart;
  final Widget? action;
  final bool light;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    if (light) return _buildLight(context);
    final changeColor = changeTone == KTrend.loss ? KColor.lossOnInk : KColor.gainOnInk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KColor.feature,
        borderRadius: KRadii.featureR,
        boxShadow: KShadow.indicator,
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

  /// Splits "₦457,580.34" into a bold main span + a smaller, muted decimal
  /// span — canvas's own two-<span> treatment (money-coins card, all three
  /// screens it appears on).
  List<TextSpan> _balanceSpans() {
    final dot = balance.lastIndexOf('.');
    if (dot == -1) return [TextSpan(text: balance)];
    return [
      TextSpan(text: balance.substring(0, dot)),
      TextSpan(
        text: balance.substring(dot),
        style: TextStyle(fontSize: 23, color: KColor.ink3, fontWeight: KWeight.regular),
      ),
    ];
  }

  Widget _buildLight(BuildContext context) {
    final changeColor = changeTone == KTrend.loss ? KColor.loss : KColor.gain;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: KColor.paper,
        borderRadius: KRadii.featureR,
        border: Border.all(color: KColor.hairline, width: 1),
        boxShadow: KShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(color: KColor.indicatorTint, shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label.upper, style: KType.label(color: KColor.ink3)),
                          const SizedBox(width: 8),
                          KIcon('eye', size: 15, color: KColor.ink3),
                        ],
                      ),
                    ),
                    ?illustration,
                  ],
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: KType.hero(color: KColor.ink).copyWith(fontSize: 42, height: 46 / 42).tnum,
                    children: _balanceSpans(),
                  ),
                ),
                if (change != null) ...[
                  const SizedBox(height: 8),
                  Text(change!, style: KType.body(color: changeColor, w: KWeight.medium).tnum),
                ],
                if (chart != null) ...[const SizedBox(height: 20), chart!],
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum KRiskTier { low, medium, high }

/// The redesigned asset/product card (2026-08-22, new — components/finance/
/// ProductCard.jsx). The audit's finding was that more text rows on the old
/// card wasn't the fix: risk/fees/liquidity/minimum sit in a 2x2 grid under
/// the price, and "Explain this" is part of the card, not a help link.
class KProductCard extends StatelessWidget {
  const KProductCard({
    super.key,
    required this.name,
    this.market,
    this.price,
    this.change,
    this.risk = KRiskTier.medium,
    this.fee,
    this.liquidity,
    this.minimum,
    this.spot,
    this.onExplain,
    this.action,
    this.onTapStat,
  });

  final String name;
  final String? market;
  final String? price;
  final String? change;
  final KRiskTier risk;
  final String? fee;
  final String? liquidity;
  final String? minimum;
  final Widget? spot;
  final VoidCallback? onExplain;
  final Widget? action;

  /// Makes the Risk/Fees/Liquidity/Minimum labels tappable glossary terms
  /// when provided (2026-08-24, direct product instruction — "liquidity
  /// this t+3 this and that... all bigterms explain them properly").
  /// Called with the cell's own label ('Risk'/'Fees'/'Liquidity'/
  /// 'Minimum'). Kept as a callback rather than this widget calling
  /// showGlossaryExplainSheet directly — lib/widgets/ stays presentational,
  /// never importing a screen/repository (see lib/data/api/README.md's
  /// layering convention).
  final ValueChanged<String>? onTapStat;

  bool get _up => change == null || !(change!.trim().startsWith('-') || change!.trim().startsWith('−'));

  Color get _riskColor => switch (risk) {
        KRiskTier.low => KColor.gain,
        KRiskTier.medium => KColor.sunPress,
        KRiskTier.high => KColor.loss,
      };

  String get _riskLabel => switch (risk) {
        KRiskTier.low => 'Low',
        KRiskTier.medium => 'Medium',
        KRiskTier.high => 'High',
      };

  Widget _cell(String label, String? value, {Color? color}) {
    final labelText = Text(label.upper, style: KType.micro(color: KColor.ink3));
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          onTapStat == null
              ? labelText
              : GestureDetector(
                  onTap: () => onTapStat!(label),
                  behavior: HitTestBehavior.opaque,
                  child: labelText,
                ),
          const SizedBox(height: 4),
          Text(value ?? '—',
              style: KType.data(color: color ?? KColor.ink, w: KWeight.semibold).tnum),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: KRadii.cardR,
        boxShadow: KShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (spot != null) ...[spot!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: KType.cardTitle()),
                    if (market != null) ...[
                      const SizedBox(height: 2),
                      Text(market!, style: KType.data(color: KColor.ink3)),
                    ],
                  ],
                ),
              ),
              if (price != null || change != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (price != null) Text(price!, style: KType.cardTitle().tnum),
                    if (change != null) ...[
                      const SizedBox(height: 2),
                      Text(change!,
                          style: KType.data(color: _up ? KColor.gain : KColor.loss).tnum),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cell('Risk', _riskLabel, color: _riskColor),
              const SizedBox(width: 14),
              _cell('Fees', fee),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cell('Liquidity', liquidity),
              const SizedBox(width: 14),
              _cell('Minimum', minimum),
            ],
          ),
          if (onExplain != null || action != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (onExplain != null)
                  GestureDetector(
                    onTap: onExplain,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KColor.indicatorTint,
                        borderRadius: KRadii.pillR,
                      ),
                      child: Text('Explain this',
                          style: KType.cardTitle(color: KColor.indicator).copyWith(fontSize: 13)),
                    ),
                  ),
                if (onExplain != null && action != null) const SizedBox(width: 10),
                ?action,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
