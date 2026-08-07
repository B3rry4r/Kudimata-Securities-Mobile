// Asset list (pushed) — a category list of KAssetRow with a sort toggle.
// Ported from app-screens.jsx `AssetList`. Pushed screen: own Scaffold +
// KDetailHeader. Optional [assetClass] narrows the universe; null = all NGX.
//
// Wired to GET /assets?assetClass= via AssetRepository.byClass (see
// lib/data/api/README.md for the FutureBuilder convention this follows).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/data/repositories/asset_repository.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/screens/shared/state_views.dart';
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

  late final _repo = AssetRepository(AppScope.read(context).apiClient);
  late Future<List<Asset>> _future = _repo.byClass(_class);

  AssetClass get _class => widget.assetClass ?? AssetClass.ngx;

  String get _title => switch (widget.assetClass) {
        AssetClass.us => 'US stocks',
        AssetClass.etf => 'ETFs',
        _ => 'Nigerian stocks',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: _title),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _repo.byClass(_class));
          await _future;
        },
        child: FutureBuilder<List<Asset>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                onPrimary: () => setState(() => _future = _repo.byClass(_class)),
              );
            }
            final items = snapshot.data!;
            return _AssetListBody(
              items: items,
              byChange: _byChange,
              onToggleSort: () => setState(() => _byChange = !_byChange),
            );
          },
        ),
      ),
    );
  }
}

class _AssetListBody extends StatelessWidget {
  const _AssetListBody({
    required this.items,
    required this.byChange,
    required this.onToggleSort,
  });

  final List<Asset> items;
  final bool byChange;
  final VoidCallback onToggleSort;

  KTrend _k(Trend t) => t == Trend.gain ? KTrend.gain : KTrend.loss;

  /// Parses the leading numeric magnitude out of a formatted price/change
  /// string (e.g. "₦268.40" → 268.40, "+1.94%" → 1.94, "−0.62%" → -0.62),
  /// stripping currency symbols, commas, and the "%" sign, and normalizing
  /// the unicode minus (U+2212) these strings use to an ASCII one so
  /// `double.tryParse` can read it.
  double _sortValue(Asset a) {
    final raw = byChange ? a.change : a.price;
    final cleaned = raw.replaceAll('−', '-').replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // Client-side sort over the already-fetched list — highest price/change
    // first — driven purely by the toggle's current label (Price/Change), no
    // extra API call.
    final sorted = List<Asset>.of(items)
      ..sort((a, b) => _sortValue(b).compareTo(_sortValue(a)));
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        // sort toggle row
        Padding(
          padding: _gut,
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onToggleSort,
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
                    KIcon('filter', size: 15, color: KColor.ink2),
                    const SizedBox(width: 6),
                    Text((byChange ? 'Change' : 'Price').upper,
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
                for (var i = 0; i < sorted.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: i == 0
                            ? BorderSide.none
                            : BorderSide(color: KColor.hairline, width: 1),
                      ),
                    ),
                    child: KAssetRow(
                      name: sorted[i].name,
                      ticker: sorted[i].ticker,
                      price: sorted[i].price,
                      change: sorted[i].change,
                      trend: _k(sorted[i].trend),
                      logoColor: sorted[i].logoColor ?? KColor.ink,
                      sparkline: sorted[i].sparkline,
                      onTap: () => context.push(Routes.assetDetail(sorted[i].ticker)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
