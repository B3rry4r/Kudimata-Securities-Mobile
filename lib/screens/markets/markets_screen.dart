// Markets tab root — title, read-only SearchPill (pushes Search), category
// PillChips (All / NGX / US / ETFs), trending + the filtered list. Ported from
// app-screens.jsx `Markets`, extended with all four categories. Root tab: Scaffold
// body WITHOUT bottom nav (the shell owns it).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

/// Category filter — value drives the list; null = All.
class _Cat {
  const _Cat(this.label, this.cls);
  final String label;
  final AssetClass? cls;
}

const _cats = [
  _Cat('All', null),
  _Cat('NGX', AssetClass.ngx),
  _Cat('US', AssetClass.us),
  _Cat('ETFs', AssetClass.etf),
];

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  String _cat = 'All';

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  List<Asset> get _list {
    final cls = _cats.firstWhere((c) => c.label == _cat).cls;
    if (cls == null) return MockData.allAssets;
    return MockData.allAssets.where((a) => a.assetClass == cls).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
          padding: const EdgeInsets.only(top: 14, bottom: 100),
          children: [
            Padding(
              padding: _gut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Markets', style: KType.title()),
                  const SizedBox(height: 16),
                  KSearchPill(
                    placeholder: 'Search stocks, ETFs',
                    showFilter: true,
                    readOnly: true,
                    onTap: () => context.push(Routes.search),
                    onFilter: () => context.push(Routes.search),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // category chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
                children: [
                  for (final c in _cats)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: KPillChip(
                        label: c.label,
                        selected: _cat == c.label,
                        onTap: () => setState(() => _cat = c.label),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // trending (only on the All tab)
            if (_cat == 'All') ...[
              Padding(
                padding: _gut,
                child: Row(
                  children: [
                    const KEyebrow('Trending'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push(Routes.assetList),
                      behavior: HitTestBehavior.opaque,
                      child: Text('See all'.upper,
                          style: KType.micro(color: KColor.ink2, w: KWeight.semibold)
                              .copyWith(letterSpacing: 0.06 * 10)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(padding: _gut, child: _card(MockData.trending, spark: false)),
              const SizedBox(height: 28),
            ],

            // the filtered list
            Padding(
              padding: _gut,
              child: KEyebrow(_cat == 'All' ? 'All assets' : _cat),
            ),
            const SizedBox(height: 12),
            Padding(padding: _gut, child: _card(_list, spark: true)),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Asset> assets, {required bool spark}) {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < assets.length; i++)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0
                      ? BorderSide.none
                      : const BorderSide(color: KColor.hairline, width: 1),
                ),
              ),
              child: KAssetRow(
                name: assets[i].name,
                ticker: assets[i].ticker,
                price: assets[i].price,
                change: assets[i].change,
                trend: _k(assets[i].trend),
                logoColor: assets[i].logoColor ?? KColor.ink,
                sparkline: spark ? assets[i].sparkline : null,
                onTap: () => context.push(Routes.assetDetail(assets[i].ticker)),
              ),
            ),
        ],
      ),
    );
  }
}
