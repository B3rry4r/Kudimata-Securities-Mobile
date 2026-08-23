// Price alerts (screen 86, "Soft Landing" cluster — canvas grew 66 -> 97
// screens). Ported from s86.html: a per-asset alert-threshold editor for the
// investor's watchlist, not the channel toggle already on the Notifications
// settings screen (that's the "email on/off" switch; this is "how big a
// move, on which name").
//
// Entry points per s86.html's footer note ("From 46 Watchlist or 48
// Notification settings ... Save -> back where you came from"):
//   - Watchlist screen (lib/screens/markets/watchlist_screen.dart) — wired
//     here, as the "Manage price alerts" action on its existing "Price
//     alerts" NudgeCard.
//   - Notification settings (lib/screens/account/notifications_settings_screen.dart)
//     — NOT wired by this agent; that file isn't in this cluster's owned-file
//     list (another agent owns the account/notifications cluster). Flagged
//     in this change's report for whoever wires routes centrally.
//
// REAL BACKEND, wired (2026-08-23): Kudimata-Securities-Backend shipped a
// real PriceAlert resource — CreatePriceAlertRequest/UpdatePriceAlertRequest
// and CRUD routes GET/POST/PATCH/DELETE /price-alerts
// (src/price-alerts/price-alerts.controller.ts) — closing the gap this
// header used to document. See lib/data/repositories/price_alert_repository.dart
// for the wire shapes.
//
// The design UI implies "one alert config per watched asset" (a featured
// editable card for the first watchlist item, on/off rows for the rest),
// but the backend models a PriceAlert as an independently
// created/updated/deleted row, not a field on WatchlistItem — there is no
// bulk "save all alerts" endpoint. This screen reconciles that by fetching
// BOTH the watchlist (WatchlistRepository) and the investor's alerts
// (PriceAlertRepository.list()), matching them by ticker, and committing
// each row's change as its own real API call as it happens:
//   - A toggle switching ON with no existing alert for that ticker ->
//     PriceAlertRepository.create() with a default ±5% threshold (the
//     default the old mock-state UI already implied via its "±5% in a day"
//     row copy).
//   - A toggle switching OFF -> PriceAlertRepository.setActive(id, false),
//     NOT remove(). Chosen over delete so the investor's threshold choice
//     (default or otherwise) survives a re-enable — flipping back on just
//     PATCHes {active: true} on the same row instead of losing the prior
//     config and silently recreating it at the ±5% default. remove() is
//     still exercised elsewhere below (changing an existing alert's
//     threshold), so both repository methods are genuinely used, not one
//     left dead.
//   - The featured card's preset chips / custom-price field write to (or
//     clear) the alert for that one ticker, looked up in the fetched list
//     first so this never creates a duplicate PriceAlert row for the same
//     ticker. Because PriceAlertsService only lets `active` be patched post-
//     create (ticker/thresholds are immutable — delete + re-create is the
//     documented way to change them), changing the featured ticker's
//     threshold removes its old alert row (if any) and creates a new one.
//   - "Save alerts": every row/preset change above is already its own live
//     API call the moment it happens (standard REST CRUD, no bulk-save
//     endpoint exists), so this button is no longer "save everything at
//     once." It now does exactly one more thing — commit the custom-price
//     field, which (unlike the preset chips or the on/off switches) is free
//     text and shouldn't fire a request per keystroke — and then pops back,
//     matching s86.html's own footer note ("Save -> back where you came
//     from"). If the custom-price field is empty, there's nothing left to
//     commit, so it's a plain "done editing" pop.
//
// Notification-copy note: this screen's own copy ("An alert tells you a
// price moved...") never claims live delivery is happening today, so it's
// left as-is. The CRUD here is now real — an alert really is saved/active
// server-side — but PriceAlertsService#checkAndNotify (the code that would
// actually compare quotes against thresholds and fire a notification) is
// deliberately not wired to any scheduler yet (no @nestjs/schedule
// ScheduleModule registered anywhere in the backend) — see that method's own
// header comment. That's a "saved but not yet delivering" gap, not a lie
// this screen tells: the investor's alert is genuinely persisted and will
// fire once a scheduler exists, it just won't page anyone today. Separately,
// watchlist_screen.dart's own NudgeCard ("We'll notify you if a name on this
// list moves more than 5% in a day...") makes a stronger, screen-owned
// promise that's outside this file's edit scope (that screen belongs to
// concurrent work per its own header) — flagged in this change's report
// rather than silently rewritten.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/price_alert_repository.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);
const _presets = ['±3%', '±5%', '±10%'];
const _defaultRowThresholdPct = 5.0;

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  late final _watchlistRepo = WatchlistRepository(AppScope.read(context).apiClient);
  late final _alertsRepo = PriceAlertRepository(AppScope.read(context).apiClient);
  late Future<(List<Asset>, List<PriceAlertWithQuote>)> _future = _load();

  // Hydrated once per successful [_load] (see _body's hydration guard) into
  // a mutable map keyed by ticker, then updated in place after every
  // create/setActive/remove call below so the UI reflects each change
  // immediately without a full refetch — same optimistic-update shape
  // watchlist_screen.dart's own _removeTicker already uses, just scoped to
  // this screen's own alert map instead of AppState.
  bool _hydrated = false;
  Map<String, PriceAlert> _alertByTicker = {};
  String? _featuredPreset;
  final _customPriceController = TextEditingController();
  bool _savingFeatured = false;
  bool _savingCustomPrice = false;
  final Set<String> _busyTickers = {};

  Future<(List<Asset>, List<PriceAlertWithQuote>)> _load() async {
    final watchlistFuture = _watchlistRepo.items();
    final alertsFuture = _alertsRepo.list();
    return (await watchlistFuture, await alertsFuture);
  }

  @override
  void dispose() {
    _customPriceController.dispose();
    super.dispose();
  }

  double _presetPct(String preset) =>
      double.parse(preset.replaceAll(RegExp('[^0-9.]'), ''));

  String? _presetForPct(double pct) => switch (pct) {
        3.0 => '±3%',
        5.0 => '±5%',
        10.0 => '±10%',
        _ => null,
      };

  String _pctLabel(double pct) => pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);

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

  void _hydrate(List<PriceAlertWithQuote> alerts, String featuredTicker) {
    _alertByTicker = {for (final a in alerts) a.ticker: a};
    final existing = _alertByTicker[featuredTicker];
    if (existing?.thresholdPct != null) {
      _featuredPreset = _presetForPct(existing!.thresholdPct!);
    } else if (existing?.thresholdPriceKobo != null) {
      _customPriceController.text =
          (existing!.thresholdPriceKobo! / 100).toStringAsFixed(2);
    }
  }

  void _showError(ApiException e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }

  /// Toggle rows (everything but the featured card): ON with no alert ->
  /// create at the default threshold; ON with an existing (inactive) alert
  /// -> reactivate it, keeping whatever threshold it already had; OFF ->
  /// deactivate rather than delete (see file header for why).
  Future<void> _toggleRow(String ticker, bool wantOn) async {
    setState(() => _busyTickers.add(ticker));
    try {
      final existing = _alertByTicker[ticker];
      if (wantOn) {
        final updated = existing == null
            ? await _alertsRepo.create(ticker: ticker, thresholdPct: _defaultRowThresholdPct)
            : await _alertsRepo.setActive(existing.id, true);
        if (!mounted) return;
        setState(() => _alertByTicker[ticker] = updated);
      } else if (existing != null) {
        final updated = await _alertsRepo.setActive(existing.id, false);
        if (!mounted) return;
        setState(() => _alertByTicker[ticker] = updated);
      }
    } on ApiException catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyTickers.remove(ticker));
    }
  }

  /// Featured card preset chip tap. Tapping the already-selected preset
  /// clears the alert entirely (mirrors the old local-only toggle-off
  /// behaviour). Any other tap replaces the featured ticker's alert with
  /// the new threshold — thresholds are immutable post-create, so an
  /// existing row is deleted before the replacement is created.
  Future<void> _onPresetTap(String ticker, String preset) async {
    final turningOff = _featuredPreset == preset;
    setState(() => _savingFeatured = true);
    try {
      final existing = _alertByTicker[ticker];
      if (turningOff) {
        if (existing != null) await _alertsRepo.remove(existing.id);
        if (!mounted) return;
        setState(() {
          _alertByTicker.remove(ticker);
          _featuredPreset = null;
        });
        return;
      }
      if (existing != null) await _alertsRepo.remove(existing.id);
      final created =
          await _alertsRepo.create(ticker: ticker, thresholdPct: _presetPct(preset));
      if (!mounted) return;
      setState(() {
        _alertByTicker[ticker] = created;
        _featuredPreset = preset;
        _customPriceController.clear();
      });
    } on ApiException catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _savingFeatured = false);
    }
  }

  /// "Save alerts": every switch/chip above already committed itself the
  /// moment it changed. The one thing still only local is the free-text
  /// custom-price field (a per-keystroke API call would be wrong there), so
  /// this commits that — if non-empty and different from what's already
  /// saved — then pops back, matching s86.html's "Save -> back where you
  /// came from". An empty field just pops: there's nothing left to save.
  Future<void> _saveAlerts(String ticker) async {
    final text = _customPriceController.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    final value = double.tryParse(text);
    if (value == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid price.')));
      return;
    }
    final kobo = (value * 100).round();
    final existing = _alertByTicker[ticker];
    if (existing != null && existing.thresholdPriceKobo == kobo) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _savingCustomPrice = true);
    try {
      if (existing != null) await _alertsRepo.remove(existing.id);
      final created =
          await _alertsRepo.create(ticker: ticker, thresholdPriceKobo: kobo);
      if (!mounted) return;
      setState(() {
        _alertByTicker[ticker] = created;
        _featuredPreset = null;
      });
      Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _savingCustomPrice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Price alerts'),
      body: FutureBuilder<(List<Asset>, List<PriceAlertWithQuote>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: () => setState(() {
                _hydrated = false;
                _future = _load();
              }),
            );
          }
          final (items, alerts) = snapshot.data ?? const (<Asset>[], <PriceAlertWithQuote>[]);
          if (items.isEmpty) {
            return const KEmptyView.watchlist();
          }
          // Hydrate the mutable alert map exactly once per successful load
          // (a fresh retry resets [_hydrated] above) — every later rebuild
          // reuses the already-mutated [_alertByTicker] instead of
          // clobbering optimistic updates with the original snapshot.
          if (!_hydrated) {
            _hydrated = true;
            _hydrate(alerts, items.first.ticker);
          }
          return _body(context, items);
        },
      ),
    );
  }

  Widget _body(BuildContext context, List<Asset> items) {
    final featured = items.first;
    final others = items.skip(1).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            children: [
              Padding(
                padding: _gut,
                child: Text(
                  'Only for names you follow, and only when something actually moves.',
                  style: KType.data(color: KColor.ink2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: _gut,
                child: KCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${featured.name} · ${featured.ticker}',
                          style: KType.cardTitle()),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _presets)
                            KPillChip(
                              label: p,
                              selected: _featuredPreset == p,
                              onTap: _savingFeatured
                                  ? null
                                  : () => _onPresetTap(featured.ticker, p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      KInput(
                        label: 'Or tell me when it reaches',
                        prefix: '₦',
                        controller: _customPriceController,
                        numeric: true,
                        disabled: _savingFeatured || _savingCustomPrice,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          // Free text only clears the preset selection
                          // locally (the two are mutually exclusive) — it
                          // does not call the API per keystroke; "Save
                          // alerts" below commits it.
                          if (_featuredPreset != null) {
                            setState(() => _featuredPreset = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: _gut,
                  child: KCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < others.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: i == others.length - 1
                                    ? BorderSide.none
                                    : BorderSide(color: KColor.hairline, width: 1),
                              ),
                            ),
                            child: KSwitch(
                              label: others[i].name,
                              description: _rowDescription(others[i].ticker),
                              checked: _alertByTicker[others[i].ticker]?.active ?? false,
                              disabled: _busyTickers.contains(others[i].ticker),
                              onChanged: (v) => _toggleRow(others[i].ticker, v),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: _gut,
                child: KNudgeCard(
                  tone: KNudgeTone.sun,
                  title: "We won't nudge you to trade",
                  body:
                      'An alert tells you a price moved. It is never a recommendation, and there is no daily digest of what other people are buying.',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            KSpace.gutter,
            12,
            KSpace.gutter,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: KButton(
            label: 'Save alerts',
            size: KButtonSize.lg,
            loading: _savingCustomPrice,
            onPressed: _savingCustomPrice ? null : () => _saveAlerts(featured.ticker),
          ),
        ),
      ],
    );
  }

  String _rowDescription(String ticker) {
    final alert = _alertByTicker[ticker];
    if (alert == null || !alert.active) return 'No alert set';
    if (alert.thresholdPct != null) {
      return '±${_pctLabel(alert.thresholdPct!)}% in a day';
    }
    if (alert.thresholdPriceKobo != null) {
      return 'Alert at ₦${_formatKobo(alert.thresholdPriceKobo!)}';
    }
    return 'No alert set';
  }
}
