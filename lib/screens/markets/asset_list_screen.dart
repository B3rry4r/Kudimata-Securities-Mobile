// Asset list (pushed) — a category list of KAssetRow with a sort toggle.
// Ported from app-screens.jsx `AssetList`. Pushed screen: own Scaffold +
// KDetailHeader. Optional [assetClass] narrows the universe; null = all NGX.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({super.key, this.assetClass});

  /// Which class to list. Null defaults to the NGX universe (design default).
  final AssetClass? assetClass;

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> {
  bool _byChange = false; // false = Price, true = Change

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  String get _title => switch (widget.assetClass) {
        AssetClass.us => 'US stocks',
        AssetClass.etf => 'ETFs',
        _ => 'Nigerian stocks',
      };

  List<Asset> get _items {
    final cls = widget.assetClass ?? AssetClass.ngx;
    return MockData.allAssets.where((a) => a.assetClass == cls).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: _title),
      body: ListView(
        padding: const EdgeInsets.only(top: 14, bottom: 24),
        children: [
          // sort toggle row
          Padding(
            padding: _gut,
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _byChange = !_byChange),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: KColor.paper,
                    borderRadius: BorderRadius.circular(KRadii.pill),
                    border: Border.all(color: KColor.hairline, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KIcon('filter', size: 15, color: KColor.ink2),
                      const SizedBox(width: 6),
                      Text((_byChange ? 'Change' : 'Price').upper,
                          style: KType.label(color: KColor.ink2)
                              .copyWith(letterSpacing: 0.04 * 11, height: 1.0)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: _gut,
            child: KCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: i == 0
                              ? BorderSide.none
                              : const BorderSide(color: KColor.hairline, width: 1),
                        ),
                      ),
                      child: KAssetRow(
                        name: items[i].name,
                        ticker: items[i].ticker,
                        price: items[i].price,
                        change: items[i].change,
                        trend: _k(items[i].trend),
                        logoColor: items[i].logoColor ?? KColor.ink,
                        sparkline: items[i].sparkline,
                        onTap: () => context.push(Routes.assetDetail(items[i].ticker)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
