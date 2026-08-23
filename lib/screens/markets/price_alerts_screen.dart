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
// REAL BACKEND GAP (flagged honestly, not silently invented or faked):
// WatchlistRepository's WatchlistItem resource (GET/POST/DELETE
// /watchlist-items) has no per-asset alert-threshold field, and
// NotificationPreferencesRepository's NotificationPreference resource
// (dispatcher ruling C-5/UA-19) is exactly THREE email-only booleans
// (ordersEmail/priceAlertsEmail/accountEmail) with no per-asset granularity
// at all. There is no "set a % or price target for ticker X, notify me when
// it's crossed" backend capability anywhere in registry.json. Wiring this
// for real would need a new resource, e.g.
//   PriceAlert { id, userId, ticker, thresholdPct?: number,
//                thresholdPriceKobo?: number, active: boolean }
// with CRUD endpoints (GET/POST/PATCH/DELETE /price-alerts) plus a
// monitoring job comparing live quotes against each active alert.
//
// So: this screen reads the investor's REAL watchlist (names/tickers are
// real, live data), but every alert preset/custom-price/switch is LOCAL
// STATE ONLY — never persisted, reset the next time this screen opens.
// "Save alerts" says so honestly via SnackBar rather than silently
// pretending to succeed, the same "not available yet" pattern
// withdraw_mandate_screen.dart's confirm button uses for its own real,
// known, unbuilt backend capability. It deliberately does NOT navigate away
// on save (same as that screen and plans_screen.dart's "preview" CTAs) so
// the investor actually sees the disclaimer; the header back-chevron
// already covers "back where you came from" for dismissal.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/watchlist_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);
const _presets = ['±3%', '±5%', '±10%'];

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  late final _repo = WatchlistRepository(AppScope.read(context).apiClient);
  late Future<List<Asset>> _future = _repo.items();

  // Local-only state (see file header — no backend field exists for any of
  // this). The first watchlist item becomes the "featured" editable card
  // (mirrors s86.html's MTNN example card); everything else gets a simple
  // on/off row. Nothing here is ever sent to the server.
  String? _featuredPreset;
  final _customPriceController = TextEditingController();
  final Map<String, bool> _otherAlertsOn = {};

  @override
  void dispose() {
    _customPriceController.dispose();
    super.dispose();
  }

  void _saveAlerts() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Price alerts aren't saved yet — this previews what's coming.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Price alerts'),
      body: FutureBuilder<List<Asset>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: () => setState(() => _future = _repo.items()),
            );
          }
          final items = snapshot.data ?? const <Asset>[];
          if (items.isEmpty) {
            return const KEmptyView.watchlist();
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
                              onTap: () => setState(
                                () => _featuredPreset = _featuredPreset == p ? null : p,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      KInput(
                        label: 'Or tell me when it reaches',
                        prefix: '₦',
                        controller: _customPriceController,
                        numeric: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              description: (_otherAlertsOn[others[i].ticker] ?? false)
                                  ? '±5% in a day'
                                  : 'No alert set',
                              checked: _otherAlertsOn[others[i].ticker] ?? false,
                              onChanged: (v) =>
                                  setState(() => _otherAlertsOn[others[i].ticker] = v),
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
            onPressed: _saveAlerts,
          ),
        ),
      ],
    );
  }
}
