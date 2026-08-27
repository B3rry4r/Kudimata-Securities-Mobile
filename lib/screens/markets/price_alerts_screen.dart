// Price alerts — rebuilt against `s49` ("Set a price alert") and `s50`
// ("My alerts"), `docs/design/redesign-2026-08/03 Home and Markets.dc.html`,
// per the redesign task's own ruling (ids from the task message, never a
// code comment — R-5). Supersedes the old s86-era build entirely: that file
// modelled a per-watchlist-row ±3%/±5%/±10% toggle editor entered from the
// (now-dropped, R-16) Watchlist screen. s49/s50 draw a different feature —
// a per-asset ABSOLUTE PRICE target, set from one asset's own page, plus a
// flat "My alerts" list of everything currently set. These are genuinely
// different features that happened to share a name; this rebuild follows
// the artboards' model, reconciled against what PriceAlertRepository (the
// real backend, `Kudimata-Securities-Backend/src/price-alerts/`) can
// actually store — see the two REAL BACKEND / GENUINE GAP notes below.
//
// R-16 ("My alerts" gets a permanent Account-menu row, since the watchlist
// screen — its other entry point — is dropped): confirmed live.
// account_screen.dart's menu already carries a 'My alerts' row wired to
// Routes.priceAlerts (`lib/screens/account/account_screen.dart`). The
// `+ watchlist` toggle on asset_detail_screen.dart still writes saved
// assets via WatchlistRepository, and THIS screen is a real reader of that
// data too now: "New alert" below opens a picker over the investor's
// watched assets (WatchlistRepository.items()) rather than requiring the
// investor already be on an asset's page — so saved-assets data keeps (at
// least) two readers (Home's rail, and this screen), not zero.
//
// REAL BACKEND (unchanged from the prior build): CreatePriceAlertRequest/
// UpdatePriceAlertRequest, CRUD routes GET/POST/PATCH/DELETE /price-alerts
// (price-alerts.controller.ts). PriceAlert carries `thresholdPct` (a
// direction-agnostic %-move-in-a-day trigger — |Quote.changePct| >=
// threshold, price-alerts.service.ts#isCrossed) OR `thresholdPriceKobo` (a
// "reached at least this price" trigger — `quote.priceKobo >=
// thresholdPriceKobo`, same method), exactly one per alert, immutable after
// create (delete + re-create to change the threshold; PATCH only ever
// flips `active`). See lib/data/repositories/price_alert_repository.dart.
//
// GENUINE GAP — direction (s49's "Rises above"/"Falls below" toggle).
// CreatePriceAlertRequest has no direction field, and #isCrossed's own
// comment is explicit: thresholdPriceKobo alerts always mean "reached AT
// LEAST this price," the more common price-target semantic. There is no
// server-side way to ask for "notify me when the price FALLS BELOW X" —
// building that toggle would silently create a "rises above" alert no
// matter which segment the investor tapped (or, worse, one that reads as
// already-satisfied the moment it's saved, since "falls below" is commonly
// set below today's price). Per the build brief ("do not build a UI for
// alerts the system cannot store"), SetPriceAlertScreen below drops the
// toggle and keeps only the one real mode — reached-at-least-this-price —
// surfaced as a single labelled field rather than a binary control with a
// dead half. Filed in BACKEND_GAPS.md: add a `direction` column +
// `isCrossed` branch before the toggle can ship.
//
// GENUINE GAP — s49's "Min ₦0.05 / Max ₦250.00" band. No asset field
// anywhere on this backend (Asset, Quote, or otherwise) carries a tick-size
// floor or a daily price-limit ceiling — confirmed against
// common/types/asset.types.ts. R-34: omitted rather than invented: the
// field this screen's price input still real and functional, just without
// a fabricated bounds row underneath it.
//
// GENUINE GAP — s50's triggered-alert card ("GTCO fell below ₦46.00...").
// Two independent blockers, not one: (1) PriceAlertsService#checkAndNotify
// — the code that would compare quotes against thresholds and fire a
// notification — is deliberately not wired to any scheduler (no
// @nestjs/schedule ScheduleModule registered anywhere in this backend; see
// that method's own header comment), so no alert has ever actually fired
// server-side; and (2) even once it does, `PriceAlert.lastTriggeredAt` is
// never serialised onto the wire shape (common/types/price-alert.types.ts
// has no such field), so the app has no way to tell a "waiting" alert from
// a "fired" one even after asking. Per R-34, the card is omitted rather
// than shown against data that can't exist — every alert in "My alerts"
// below renders as "Waiting" because none can honestly be anything else
// yet. Needs: the scheduler wired, and `lastTriggeredAt` added to
// `PriceAlert`/`PriceAlertWithQuote`'s wire shape.
//
// SHARED-CHANGE REQUEST (lib/router/routes.dart, lib/router/app_router.dart
// — off-limits to a screen agent, R-30/rule 5): SetPriceAlertScreen below
// (s49) is a real, working screen but has no go_router entry, so it isn't
// deep-linkable and test/shots_all.dart can't capture it by route. It's
// reached today only via this file's own "New alert" flow
// (Navigator.push, not go_router) and is exposed as a public, ticker-
// parametrised widget specifically so it can be wired from elsewhere once
// a route exists. Requested: `Routes.setPriceAlert(String ticker) =>
// '/asset/$ticker/alert'` + a matching GoRoute — after which (a)
// asset_detail_screen.dart (out of this file's scope) can add s49's other
// real entry point, a "Set a price alert" action on the asset page, via
// `context.push(Routes.setPriceAlert(asset.ticker))`, and (b) whatever
// screen owns the "Market closed" banner (market_hours.dart is a shared
// helper, not a screen — the actual banner lives in screens this pass
// doesn't own) can wire s49's other cited entry point the same way.
// Verified without a route in the interim via a throwaway rendering test
// (see this change's report), matching the precedent
// BACKEND_GAPS.md's Order Book entry already set.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/asset_repository.dart';
import 'package:kudimata_invest/data/repositories/price_alert_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

String _formatKobo(int minorUnits) {
  final negative = minorUnits < 0;
  final abs = negative ? -minorUnits : minorUnits;
  final major = abs ~/ 100;
  final minor = (abs % 100).toString().padLeft(2, '0');
  final majorStr = major.toString();
  final buf = StringBuffer();
  for (var i = 0; i < majorStr.length; i++) {
    final posFromEnd = majorStr.length - i;
    buf.write(majorStr[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return '${negative ? '−' : ''}$buf.$minor';
}

String _pctLabel(double pct) => pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);

// ─────────────────────────────────────────────────────────────────────────
// s50 · My alerts — routed at Routes.priceAlerts.
// ─────────────────────────────────────────────────────────────────────────

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  late final _client = AppScope.read(context).apiClient;
  late final _alertsRepo = PriceAlertRepository(_client);
  late final _watchlistRepo = WatchlistRepository(_client);
  late Future<(List<PriceAlertWithQuote>, List<Asset>)> _future = _load();

  Future<(List<PriceAlertWithQuote>, List<Asset>)> _load() async {
    // Future.wait, not two bare `await`s in sequence: under MockNetwork.error
    // (and any real simultaneous failure) the second future would otherwise
    // go unobserved the moment the first `await` throws, which flutter_test's
    // zone reports as an uncaught async error even though the screen itself
    // handles it fine via snapshot.hasError.
    final results = await Future.wait<Object>([_alertsRepo.list(), _watchlistRepo.items()]);
    return (results[0] as List<PriceAlertWithQuote>, results[1] as List<Asset>);
  }

  /// Optimistic delete, matching the app's standing revert-on-failure
  /// pattern (e.g. notifications_screen.dart's own mark-read) — mutates the
  /// already-resolved list in place rather than refetching, then puts the
  /// row back and surfaces the error if the DELETE fails.
  Future<void> _delete(String id, List<PriceAlertWithQuote> alerts) async {
    final index = alerts.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final removed = alerts[index];
    setState(() => alerts.removeAt(index));
    try {
      await _alertsRepo.remove(id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => alerts.insert(index, removed));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// "New alert" (s50's footer button). No ticker context exists here (this
  /// screen isn't opened from an asset page — R-16's whole point), so this
  /// picks one from the investor's saved assets — the same relationship
  /// this file's header describes. An investor with nothing saved yet is
  /// sent to Markets instead of an empty picker.
  Future<void> _openNewAlert(List<Asset> watchlist) async {
    if (watchlist.isEmpty) {
      context.push(Routes.markets);
      return;
    }
    final ticker = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KColor.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KRadii.sheet)),
      ),
      builder: (_) => _TickerPickerSheet(assets: watchlist),
    );
    if (ticker == null || !mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => SetPriceAlertScreen(ticker: ticker)),
    );
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'My alerts'),
      body: FutureBuilder<(List<PriceAlertWithQuote>, List<Asset>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(onPrimary: () => setState(() => _future = _load()));
          }
          final (alerts, watchlist) =
              snapshot.data ?? const (<PriceAlertWithQuote>[], <Asset>[]);
          // Empty condition: an investor who has never set a price alert —
          // the default state for most accounts today, since R-16 removed
          // the watchlist screen's row toggles that used to seed one.
          if (alerts.isEmpty) {
            return KEmptyView(
              icon: 'bell',
              title: 'No alerts yet',
              message:
                  "Set one from any asset's page, or start from something you already follow.",
              actionLabel: 'New alert',
              onAction: () => _openNewAlert(watchlist),
            );
          }
          return _MyAlertsBody(
            alerts: alerts,
            onDelete: (id) => _delete(id, alerts),
            onOpenAsset: (ticker) => context.push(Routes.assetDetail(ticker)),
            onNewAlert: () => _openNewAlert(watchlist),
          );
        },
      ),
    );
  }
}

class _MyAlertsBody extends StatelessWidget {
  const _MyAlertsBody({
    required this.alerts,
    required this.onDelete,
    required this.onOpenAsset,
    required this.onNewAlert,
  });

  final List<PriceAlertWithQuote> alerts;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onOpenAsset;
  final VoidCallback onNewAlert;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 18, bottom: 20),
            children: [
              // s50 draws a triggered-alert card above this — omitted, see
              // this file's header (no scheduler, no lastTriggeredAt on the
              // wire). Every real alert here is genuinely still waiting.
              Padding(padding: _gut, child: Text('Waiting', style: KType.cardTitle())),
              const SizedBox(height: 10),
              Padding(
                padding: _gut,
                child: Column(
                  children: [
                    for (final a in alerts) ...[
                      _AlertRow(
                        alert: a,
                        onDelete: () => onDelete(a.id),
                        onOpen: () => onOpenAsset(a.ticker),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: _gut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alerts are not orders', style: KType.cardTitle()),
                    const SizedBox(height: 7),
                    Text(
                      'Nothing is bought or sold on an alert. If you want the app '
                      'to act at a price, place a Name your price order instead.',
                      style: KType.body(color: KColor.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
          ),
          padding: EdgeInsets.fromLTRB(
            KSpace.gutter,
            14,
            KSpace.gutter,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: KButton(
            label: 'New alert',
            size: KButtonSize.lg,
            fullWidth: true,
            onPressed: onNewAlert,
          ),
        ),
      ],
    );
  }
}

/// One "Waiting" row: ticker-initials badge, what it's watching for, how
/// far the live quote is from it, and a delete control — s50's own layout
/// (a hairline card, not KAssetRow's price/change trailing slot, since the
/// trailing content here is a delete action, not a quote).
class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onDelete, required this.onOpen});

  final PriceAlertWithQuote alert;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  String get _initials {
    final letters = alert.ticker.replaceAll(RegExp('[^A-Za-z]'), '');
    return letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
  }

  (String title, String subtitle) _copy() {
    final now = _formatKobo(alert.priceKobo);
    if (alert.thresholdPriceKobo != null) {
      final target = alert.thresholdPriceKobo!;
      final away = alert.priceKobo == 0
          ? 0.0
          : ((target - alert.priceKobo).abs() / alert.priceKobo) * 100;
      return (
        '${alert.ticker} reaches ₦${_formatKobo(target)}',
        'Now ₦$now · ${away.toStringAsFixed(0)}% away',
      );
    }
    if (alert.thresholdPct != null) {
      final label = _pctLabel(alert.thresholdPct!);
      final today = alert.changePct >= 0
          ? '+${alert.changePct.toStringAsFixed(2)}'
          : alert.changePct.toStringAsFixed(2);
      return ('${alert.ticker} moves ±$label% in a day', 'Now ₦$now · $today% today');
    }
    return ('${alert.ticker} alert', 'Now ₦$now');
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _copy();
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KColor.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KColor.hairline, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: KColor.indicatorTint, shape: BoxShape.circle),
              child: Text(
                _initials,
                style: KType
                    .label(color: KColor.indicator)
                    .copyWith(fontSize: 12, letterSpacing: 0.24, height: 1.0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.cardTitle().copyWith(fontSize: 15, height: 20 / 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: KType.data(color: KColor.ink3).tnum),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: KIcon('close', size: 17, color: KColor.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

/// "New alert" picker over the investor's watched assets — see this file's
/// header re: the WatchlistRepository reader relationship. Screen-local,
/// not a shared component.
class _TickerPickerSheet extends StatelessWidget {
  const _TickerPickerSheet({required this.assets});
  final List<Asset> assets;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KSpace.gutter,
          20,
          KSpace.gutter,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert on which asset?', style: KType.cardTitle()),
            const SizedBox(height: 4),
            Text('From the names you follow.', style: KType.body(color: KColor.ink2)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: assets.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: KColor.hairline),
                itemBuilder: (context, i) => KAssetRow(
                  name: assets[i].name,
                  ticker: assets[i].ticker,
                  price: assets[i].price,
                  change: assets[i].change,
                  logoColor: assets[i].logoColor,
                  onTap: () => Navigator.of(context).pop(assets[i].ticker),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// s49 · Set a price alert — public (not routed via go_router yet; see this
// file's SHARED-CHANGE REQUEST above), constructed with the ticker to
// alert on.
// ─────────────────────────────────────────────────────────────────────────

class SetPriceAlertScreen extends StatefulWidget {
  const SetPriceAlertScreen({super.key, required this.ticker});
  final String ticker;

  @override
  State<SetPriceAlertScreen> createState() => _SetPriceAlertScreenState();
}

class _SetPriceAlertScreenState extends State<SetPriceAlertScreen> {
  late final _client = AppScope.read(context).apiClient;
  late final _assetRepo = AssetRepository(_client);
  late final _alertsRepo = PriceAlertRepository(_client);
  late Future<(Asset, PriceAlertWithQuote?)> _future = _load();
  final _priceController = TextEditingController();

  bool _hydrated = false;
  PriceAlertWithQuote? _existing;
  bool _saving = false;

  Future<(Asset, PriceAlertWithQuote?)> _load() async {
    // Future.wait — see PriceAlertsScreen._load's own comment on why not
    // two sequential `await`s.
    final results = await Future.wait<Object>(
      [_assetRepo.byTicker(widget.ticker), _alertsRepo.list()],
    );
    final asset = results[0] as Asset;
    final alerts = results[1] as List<PriceAlertWithQuote>;
    PriceAlertWithQuote? existing;
    for (final a in alerts) {
      if (a.ticker == widget.ticker && a.thresholdPriceKobo != null) {
        existing = a;
        break;
      }
    }
    return (asset, existing);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _hydrate(PriceAlertWithQuote? existing) {
    _existing = existing;
    if (existing?.thresholdPriceKobo != null) {
      _priceController.text = (existing!.thresholdPriceKobo! / 100).toStringAsFixed(2);
    }
  }

  double _parsePrice(String formatted) {
    final digits = formatted.replaceAll(RegExp('[^0-9.]'), '');
    return double.tryParse(digits) ?? 0;
  }

  Future<void> _save() async {
    final text = _priceController.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
      return;
    }
    final kobo = (value * 100).round();
    if (_existing != null && _existing!.thresholdPriceKobo == kobo) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _saving = true);
    try {
      if (_existing != null) await _alertsRepo.remove(_existing!.id);
      final created = await _alertsRepo.create(ticker: widget.ticker, thresholdPriceKobo: kobo);
      if (!mounted) return;
      setState(() {
        _existing = PriceAlertWithQuote(
          id: created.id,
          userId: created.userId,
          ticker: created.ticker,
          thresholdPct: created.thresholdPct,
          thresholdPriceKobo: created.thresholdPriceKobo,
          active: created.active,
          createdAt: created.createdAt,
          priceKobo: _existing?.priceKobo ?? kobo,
          changeAbsKobo: _existing?.changeAbsKobo ?? 0,
          changePct: _existing?.changePct ?? 0,
          asOf: _existing?.asOf,
        );
      });
      Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Price alert'),
      body: FutureBuilder<(Asset, PriceAlertWithQuote?)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(onPrimary: () => setState(() => _future = _load()));
          }
          final (asset, existing) = snapshot.data!;
          if (!_hydrated) {
            _hydrated = true;
            _hydrate(existing);
          }
          return _body(context, asset);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Asset asset) {
    final current = _parsePrice(asset.price);
    final target = double.tryParse(_priceController.text);
    String? derived;
    if (target != null && target > 0 && current > 0) {
      final diffPct = (target - current) / current * 100;
      final dir = diffPct >= 0 ? 'above' : 'below';
      derived = "That's ${_pctLabel(diffPct.abs())}% $dir today's price.";
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(KSpace.gutter, 22, KSpace.gutter, 16),
            children: [
              Text('Tell me when ${asset.ticker} hits a price', style: KType.title()),
              const SizedBox(height: 8),
              Text(
                'It trades at ${asset.price} today. We only send a message, '
                'nothing is bought.',
                style: KType.body(color: KColor.ink2),
              ),
              const SizedBox(height: 24),
              KInput(
                label: 'Alert me when it reaches',
                amount: true,
                prefix: '₦',
                suffix: 'per share',
                controller: _priceController,
                numeric: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                disabled: _saving,
                onChanged: (_) => setState(() {}),
              ),
              if (derived != null) ...[
                const SizedBox(height: 10),
                Text(derived, style: KType.body(color: KColor.ink2)),
              ],
              const SizedBox(height: 6),
              Text(
                'An alert just tells you. To buy automatically at a price, use '
                'Name your price on the buy screen instead.',
                style: KType.micro(color: KColor.ink3).copyWith(fontSize: 13, height: 19 / 13),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
          ),
          padding: EdgeInsets.fromLTRB(
            KSpace.gutter,
            16,
            KSpace.gutter,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KButton(
                label: 'Set alert',
                size: KButtonSize.lg,
                fullWidth: true,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.push(Routes.priceAlerts),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'See my alerts',
                    textAlign: TextAlign.center,
                    style: KType.body(color: KColor.indicator, w: KWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
