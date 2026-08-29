// Kudimata Invest — redesign 2026-08, wallet screens. Built against
// `docs/design/redesign-2026-08/05 Portfolio and Wallet.dc.html`:
// WalletScreen -> s35 (wallet home tab), TransactionDetailScreen -> s38
// ("Receipt"). Both artboard ids come from RULINGS.md, per
// SCREEN-AGENT-BRIEF.md R-5 — this file used to cite a since-deleted
// `mockup-raw/s40.html` / `screen-specs.md` (the OLD 97-screen canvas); those
// citations are gone now, not re-pointed, since the rebuild below reads the
// current artboard directly.
//
// NGX-only: no USD wallet / Convert flow in the UI. `TxnType.convert` has no
// dedicated case in `_TxnRow` below (removed — see that class) since
// DECISIONS.md flags it as unreachable: nothing in this backend can ever
// produce a convert-type Txn. The money-movement flows (Add money /
// Withdraw) live in wallet_flows.dart as bottom-sheet sequences — a separate
// file this pass does not touch.
//
// WalletScreen is wired per lib/data/api/README.md's FutureBuilder
// convention: WalletRepository.balance() (GET /wallet-balance) replaces the
// hardcoded '₦310,400.00' KBalancePanel literal, and
// TransactionRepository.list() (GET /transactions) replaces MockData.txns.
// Both are fetched together (started concurrently, awaited into one record)
// so the screen has a single loading/error state, matching the README's
// one-future-per-screen shape.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/realtime/realtime_client.dart';
import 'package:kudimata_invest/data/repositories/transaction_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';

import 'wallet_flows.dart';

// R-41 (docs/redesign/DECISIONS.md): also wired to `wallet:update`
// (RealtimeClient.walletUpdates) — the decoded WalletBalance is applied
// straight onto [_WalletScreenState._data]'s balance/pending fields via
// WalletRepository.walletUpdateFromJson, with NO network call on receipt.
// On reconnect after a drop, this refetches ONCE via the same [_load] this
// screen's own 8s poll already uses — the one legitimate fetch in this
// path.

// ─────────────────────────────────────────────────────────────────────────────
// 1 · WALLET HOME (root tab — shell provides the bottom nav).
// ─────────────────────────────────────────────────────────────────────────────

typedef _WalletData = ({
  String balance,
  String? pending,
  List<Txn> txns,
});

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late final _txnRepo = TransactionRepository(AppScope.read(context).apiClient);
  late final RealtimeClient _realtime = AppScope.read(context).realtimeClient;
  late Future<_WalletData> _future = _load();

  StreamSubscription<Map<String, dynamic>>? _walletSub;
  StreamSubscription<void>? _reconnectSub;

  /// The data actually rendered once the first silent poll succeeds — see
  /// home_screen.dart's identical field for the full writeup of why this
  /// exists (2026-08-20 fix: reassigning `_future` on every poll tick, this
  /// screen's own earlier approach, made FutureBuilder flash back to
  /// ConnectionState.waiting for one frame each time — "when I said poll,
  /// I didn't say poll and keep... flashing my screen").
  _WalletData? _data;

  // POLLING (2026-08-20, "poll the... wallets so we can see changes
  // instantly without refreshing since no realtime yet"). A test-fund tap,
  // a real Flutterwave webhook landing, or a market order filling can all
  // move the balance while this tab just sits open.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _silentRefresh());
    _walletSub = _realtime.walletUpdates.listen(_onWalletUpdate);
    _reconnectSub = _realtime.reconnected.listen((_) => _silentRefresh());
  }

  /// Applies a decoded `wallet:update` payload directly onto [_data]'s
  /// balance/pending fields — reuses [_load]'s existing txns list rather
  /// than re-fetching it, and reuses WalletRepository's own kobo->display
  /// formatting ([WalletRepository.walletUpdateFromJson]) rather than a
  /// second copy of it here. No network call. Dropped if nothing has
  /// loaded yet ([_data] null) — the in-flight initial [_future] covers
  /// that case moments later.
  void _onWalletUpdate(Map<String, dynamic> json) {
    final current = _data;
    if (current == null || !mounted) return;
    final snapshot = WalletRepository.walletUpdateFromJson(json);
    setState(() {
      _data = (balance: snapshot.available, pending: snapshot.pending, txns: current.txns);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _walletSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  Future<_WalletData> _load() async {
    // Record `.wait`, not fire-then-sequential-await — see home_screen.dart's
    // _load() for why (an early rejection would otherwise leave the other
    // future's eventual rejection unlistened-to: an "unhandled exception").
    final (balanceDetail, page) =
        await (_walletRepo.balanceDetail(), _txnRepo.list()).wait;
    return (
      balance: balanceDetail.available,
      pending: balanceDetail.pending,
      txns: page.data,
    );
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await _load();
      if (!mounted) return;
      setState(() => _data = data);
    } on Object {
      // A poll tick failing (flaky network blip) shouldn't blank out an
      // already-loaded screen — just try again next tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          // Pull-to-refresh updates `_data` too (not `_future`) — its own
          // spinner already shows above the content, so blanking the WHOLE
          // body back to KLoadingView underneath it as well would be a
          // second, jarring loading flash on top of the first.
          onRefresh: () async {
            try {
              final data = await _load();
              if (!mounted) return;
              setState(() => _data = data);
            } on Object {
              // A failed manual refresh just leaves the last-good numbers
              // showing — same treatment as a failed silent poll tick.
            }
          },
          child: FutureBuilder<_WalletData>(
            future: _future,
            builder: (context, snapshot) {
              // Prefer the freshest polled/refreshed data over the
              // FutureBuilder's own snapshot — see `_data`'s doc comment.
              final effective = _data ?? snapshot.data;
              if (effective == null) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const KLoadingView();
                }
                if (snapshot.hasError) {
                  return KErrorView(
                    onPrimary: () => setState(() => _future = _load()),
                  );
                }
              }
              final data = effective!;
              return _WalletBody(
                balance: data.balance,
                pending: data.pending,
                txns: data.txns,
              );
            },
          ),
        ),
      ),
    );
  }
}

// Same widget tree the mock version built — fed live balance/txns.
class _WalletBody extends StatelessWidget {
  const _WalletBody({
    required this.balance,
    required this.pending,
    required this.txns,
  });
  final String balance;

  /// "₦X held for a pending order" (loss-toned) — real data
  /// (backend pendingBalanceKobo), but 2026-08-24 direct feedback: "showing
  /// wallet funding activity for an account that hasn't been credited is
  /// just confusing... not everyone is going to understand ₦20,000 held for
  /// a pending order". No longer rendered on the panel itself — kept on
  /// [_WalletData] since order_status_screen.dart's own per-order detail is
  /// still the right, unambiguous place to show a hold tied to a specific
  /// order, rather than a summary line here with no order context at all.
  final String? pending;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 100),
      children: [
        // s35's header carries a trailing "doc" icon beside the title,
        // reaching the statements list ("doc icon → statements (Section
        // 6)") — same trailing-icon convention as Portfolio's `s33` header
        // (portfolio_screen.dart's `_StatementsButton`); kept as a
        // screen-local twin rather than importing across screen files.
        KScreenHead(
          title: 'Wallet',
          trailing: _StatementsButton(onTap: () => context.push(Routes.acctStatements)),
        ),
        const SizedBox(height: 16),

        // s35's money card is the light/paper treatment (icon + illustration
        // + trust line via KBalancePanel's `light: true` mode — the same
        // shape home_screen.dart already uses for its own money card), NOT
        // the filled-ink `KBalancePanel` this screen used before. Label is
        // s35's own "Cash available", and the action slot carries s35's
        // exact trust-line copy verbatim.
        KBalancePanel(
          label: 'Cash available',
          balance: balance,
          light: true,
          illustration: SvgPicture.asset('assets/illustrations/money-coins.svg', height: 64),
          action: Text(
            'Ready to invest now. Held with our custodian, never lent out.',
            style: KType.body(color: KColor.ink3).copyWith(fontSize: 14, height: 20 / 14),
          ),
        ),
        // s35 line 302: button row sits 20px below the money card.
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: KButton(
                label: 'Add money',
                iconLeft: 'plus',
                onPressed: () => showAddMoneyFlow(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KButton(
                label: 'Withdraw',
                variant: KButtonVariant.secondary,
                iconLeft: 'send',
                onPressed: () => showWithdrawFlow(context),
              ),
            ),
          ],
        ),
        // s35 line 306: the "Money in and out" row sits 22px below the
        // button row.
        const SizedBox(height: 22),

        // s35's section title is "Money in and out" (a card-title-weight
        // heading, not an uppercase eyebrow) with a trailing "All" link.
        // The link deliberately stays "Orders", not s35's literal "All":
        // TransactionRepository.list() already fetches every transaction
        // this API returns for the card below (no further pages exist to
        // reveal), so a link claiming to show "All" would in fact point at
        // the buy/sell-only Orders screen — STRICTLY LESS than what's
        // already on screen, an actively misleading destination rather than
        // just an inexact label. "Orders" is honest about what that
        // shortcut actually is.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Money in and out', style: KType.section()),
              GestureDetector(
                onTap: () => context.push(Routes.orderStatus),
                behavior: HitTestBehavior.opaque,
                child: Text('Orders',
                    style: KType.label(color: KColor.ink2, w: KWeight.semibold)),
              ),
            ],
          ),
        ),

        // Transactions list — tap a row → transaction detail.
        if (txns.isEmpty)
          KEmptyView.transactions(onAction: () => showAddMoneyFlow(context))
        else
          KCard(
            // s35 line 310: card padding is "0 24px" outer / "13px 0" per
            // row — modelled here as a symmetric 18/4 KCard inset, this
            // app's established convention for this exact row shape
            // (matches order_status_screen.dart's own list cards).
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < txns.length; i++)
                  _TxnRow(txn: txns[i], first: i == 0),
              ],
            ),
          ),
        // No further element after the transactions card — s35 ends here.
        // A previous pass added a generic withdrawal-destination disclaimer
        // sentence below the card; s35 draws no such line (checked directly
        // against the artboard markup), so it's removed rather than kept as
        // an uncited addition. The money card's own trust line above is s35's
        // real, designed reassurance copy for this screen.
      ],
    );
  }
}

// s35's trailing "doc" header icon, reaching the statements list — a
// screen-local twin of Portfolio's `_StatementsButton`
// (portfolio_screen.dart), same shape (40x40 track-tinted circle, "doc"
// glyph). Kept local rather than shared per SCREEN-AGENT-BRIEF.md rule 5.
class _StatementsButton extends StatelessWidget {
  const _StatementsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: KColor.track, shape: BoxShape.circle),
        child: KIcon('doc', size: 19, color: KColor.ink),
      ),
    );
  }
}

// One ledger row: icon medallion · title + date · signed tabular amount.
class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn, required this.first});
  final Txn txn;
  final bool first;

  // Map ledger type to a glyph from the fixed KIcon set (s35: fund-in row
  // uses "arrowDown", dividend uses "wallet" in a sun-tint circle, distinct
  // from a plain fund-in).
  //
  // `TxnType.convert` has no dedicated case — removed per DECISIONS.md's
  // dead-code list ("wallet_screens.dart's TxnType.convert"): this is an
  // NGX-only product with no Convert flow anywhere in the backend, so
  // nothing can ever construct a Txn with this type. The wildcard below
  // exists only to satisfy Dart's exhaustive-switch check over the shared
  // `TxnType` enum (lib/data/models.dart, off-limits to edit here); it is
  // not a designed row and is never expected to render.
  String get _icon => switch (txn.type) {
        TxnType.fund => 'arrowDown',
        TxnType.withdraw => 'arrowUp',
        TxnType.buy || TxnType.sell => 'markets',
        TxnType.dividend => 'wallet',
        _ => 'wallet',
      };

  // Colored icon circle per ledger type (indicator-tint / track / sun-tint).
  (Color, Color) get _iconColors => switch (txn.type) {
        TxnType.fund => (KColor.indicatorTint, KColor.indicator),
        TxnType.buy || TxnType.sell => (KColor.track, KColor.ink2),
        TxnType.withdraw => (KColor.sunTint, KColor.sunPress),
        TxnType.dividend => (KColor.sunTint, KColor.sunPress),
        _ => (KColor.sunTint, KColor.sunPress),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _iconColors;
    return GestureDetector(
      onTap: () => context.push(Routes.transactionDetail(txn.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        // s35 row: "13px 0" — 0 horizontal (the card above already carries
        // the 18px horizontal inset).
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            // s35: 40x40 rounded-square medallion (12px radius), icon 18 —
            // was a 34px circle with a 16px icon.
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: KIcon(_icon, size: 18, color: fg),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(txn.title, style: KType.cardTitle().copyWith(fontSize: 15, height: 20 / 15)),
                  const SizedBox(height: 1),
                  Text(txn.subtitle,
                      style: KType.data(color: KColor.ink3).copyWith(fontSize: 13, height: 18 / 13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(txn.amount,
                style: KType.cardTitle(
                  color: txn.incoming ? KColor.gain : KColor.ink,
                  w: KWeight.semibold,
                ).copyWith(fontSize: 15, height: 20 / 15).tnum),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2 · TRANSACTION DETAIL (pushed — KDetailHeader, no tab bar).
// ─────────────────────────────────────────────────────────────────────────────

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late final _repo = TransactionRepository(AppScope.read(context).apiClient);
  late Future<Txn> _future = _repo.byId(widget.id);

  // "Get receipt" is a one-shot action (GET /transactions/:id/receipt), not
  // the screen's own load — tracked separately so the load/retry state above
  // and the button's own busy state never fight each other.
  bool _receiptBusy = false;


  // "On its way"/"Completed"/"Failed" — mapped onto the shared workflow-state
  // vocabulary (KStatus), not a bespoke pill. s38 only draws the completed
  // ("Bought MTN Nigeria") case — a static green checkmark badge, no pill at
  // all — and no artboard variant covers pending/failed (checked: no
  // `s38b`/`s38p`/`s38c` id anywhere in the canvas or reverse-sweep.json's
  // state-variant list). Real transactions can land in any of the three
  // states, so this keeps the illustration+KStatusPill treatment below to
  // generalise across all of them, rather than hardcoding s38's one drawn
  // state and leaving pending/failed with nothing to render.
  (KStatus, String) _status(TxnStatus s) => switch (s) {
        TxnStatus.completed => (KStatus.approved, 'Completed'),
        TxnStatus.pending => (KStatus.review, 'On its way'),
        TxnStatus.failed => (KStatus.rejected, 'Failed'),
      };

  Future<void> _getReceipt() async {
    setState(() => _receiptBusy = true);
    try {
      // Backend note (transaction_repository.dart's receiptUrl() doc
      // comment): receipt generation is a known stub — a placeholder URL,
      // no real PDF, and NO email is ever sent from this endpoint. This
      // copy used to promise "check your email shortly" (2026-08-20,
      // reported: "transaction get receipt is not sending nothing to my
      // mail" — correct, nothing ever does), which was actively false
      // rather than just an unfinished feature. Says so honestly instead
      // until real receipt generation + delivery exists.
      await _repo.receiptUrl(widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipts are not available yet — check back soon.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } finally {
      if (mounted) setState(() => _receiptBusy = false);
    }
  }

  Widget get _notFoundScaffold => Scaffold(
        backgroundColor: KColor.bg,
        appBar: const KDetailHeader(title: 'Receipt'),
        body: Center(
          child: Text('Transaction not found', style: TextStyle(color: KColor.ink2)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Txn>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: KColor.bg,
            appBar: const KDetailHeader(title: 'Receipt'),
            body: const KLoadingView(),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          // A 404 (stale/deleted/inaccessible id — e.g. a deep link) is the
          // screen's own designed "not found" state, not a generic load
          // failure — see .pipeline/fragments/transaction-detail.json
          // uiStatesHandled[not-found].
          if (error is ApiException && error.statusCode == 404) {
            return _notFoundScaffold;
          }
          return Scaffold(
            backgroundColor: KColor.bg,
            appBar: const KDetailHeader(title: 'Receipt'),
            body: KErrorView(
              onPrimary: () => setState(() => _future = _repo.byId(widget.id)),
            ),
          );
        }

        final txn = snapshot.data;
        if (txn == null) return _notFoundScaffold;

        final (statusEnum, statusLabel) = _status(txn.status);
        // s38's hero amount is hardcoded `color:var(--ink)` — always plain
        // ink, not gain-toned for an incoming transaction. The trend cue
        // here is the StatusPill/sign, not the figure's colour.
        final amountColor = KColor.ink;

        // s38's own row set (Shares cost / Fees, all in / Date / Shares
        // settle / Reference) is written for one specific case — a
        // completed BUY. This model covers fund/withdraw/buy/sell/dividend
        // alike, so the row labels stay generic (Requested, not "Date";
        // Settlement, not "Shares settle") the way this screen already
        // generalised Fee/Settlement below — but the ORDER now matches s38:
        // Reference is the LAST row, not the first.
        //
        // R-34 (DECISIONS.md) applies to the Fee row: s38 draws "Fees, all
        // in ₦93.50", a real non-zero figure — but nothing in this backend's
        // Transaction model writes a per-transaction fee (confirmed: no
        // `fee`/`Fee` field anywhere in Txn or TransactionRepository). Per
        // R-34, the figure is omitted rather than invented — no hardcoded
        // ₦0.00 either, since that's still an assertion this screen has no
        // wire data for — and the row itself drops, since a "Fee" label
        // with nothing to put beside it isn't a real row. Filed in
        // BACKEND_GAPS.md (s38 — Wallet: Transaction receipt).
        //
        // Settlement only shown for withdraw/sell — the two types whose
        // proceeds actually route via Direct Cash Settlement; a `fund`
        // transaction is money coming IN by bank transfer, not a DCS
        // payout, so asserting DCS there would be wrong, not just imprecise.
        final rows = <(String, String)>[
          ('Requested', txn.date),
          if (txn.type == TxnType.withdraw || txn.type == TxnType.sell)
            ('Settlement', 'Direct Cash Settlement'),
          ('Reference', txn.id),
        ];

        return Scaffold(
          backgroundColor: KColor.bg,
          // s38's header carries a trailing "download" icon beside "Receipt"
          // — routed to the same real receipt action as the "Get receipt"
          // button below (GET /transactions/:id/receipt), not a second,
          // disconnected control.
          appBar: KDetailHeader(
            title: 'Receipt',
            trailing: GestureDetector(
              onTap: _receiptBusy ? null : _getReceipt,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: KColor.track, shape: BoxShape.circle),
                child: KIcon('download', size: 19, color: KColor.ink),
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 20, KSpace.gutter, 24),
              children: [
                // s38: illustration → hero amount → StatusPill → body
                // sentence, all centred, OUTSIDE any card.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // s38 itself draws a static green checkmark badge here
                    // (it only designs the completed state) — this keeps the
                    // warm-plated money-in-transit illustration instead,
                    // since it reads correctly across all three real
                    // statuses (completed/pending/failed) via the
                    // KStatusPill below, not just the one s38 draws. See
                    // `_status`'s doc comment.
                    const KIllustration('wallet-fund', role: KIlloRole.small, tone: KIlloTone.warm),
                    const SizedBox(height: 10),
                    Text(txn.amount, style: KType.hero(color: amountColor).tnum),
                    const SizedBox(height: 10),
                    KStatusPill(status: statusEnum, label: statusLabel),
                    if (txn.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      // Using the backend's own preformatted subtitle rather
                      // than reconstructing a specific delivery-time claim
                      // per type that this screen has no real way to verify
                      // for every transaction kind.
                      Text(txn.subtitle,
                          style: KType.body(color: KColor.ink2), textAlign: TextAlign.center),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                // Detail-rows card — separate from the amount/pill section
                // above, per s38.
                KCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        _DetailRow(
                            label: rows[i].$1, value: rows[i].$2, last: i == rows.length - 1),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // s38's co-branding callout ("Executed by Blue Marina
                // Securities Ltd, NGX dealing member, on behalf of Kudimata
                // Securities") — verified against the signed Client
                // Agreement (orders.service.ts:93,
                // statement-generator.service.ts:30), so kept verbatim
                // rather than treated as an unverified canvas claim.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: KColor.indicatorTint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('EXECUTED BY', style: KType.label(color: KColor.indicator)),
                      const SizedBox(height: 6),
                      Text(
                        'Blue Marina Securities Ltd, NGX dealing member, on behalf of Kudimata Securities.',
                        style: KType.body(color: KColor.ink2).copyWith(fontSize: 14, height: 20 / 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // GET /transactions/:id/receipt. Backend note: receipt
                // generation is still a stub (placeholder presigned URL, no
                // real PDF yet) — wired anyway so the plumbing is correct
                // end-to-end; see transaction_repository.dart's receiptUrl().
                // Labelled "Get receipt", not s38's literal "Email receipt":
                // receiptUrl()'s own doc comment confirms no email is ever
                // sent from this endpoint, and this exact false promise was
                // already reported and fixed once on this screen (see
                // _getReceipt's comment) — repeating it under a new label
                // would reintroduce the same bug. No icon (s38 draws none on
                // this button; the download glyph now lives on the header
                // instead, matching s38's own icon placement).
                KButton(
                  label: 'Get receipt',
                  variant: KButtonVariant.secondary,
                  loading: _receiptBusy,
                  onPressed: _receiptBusy ? null : _getReceipt,
                ),
                const SizedBox(height: 10),
                // s38's second button is "Done", filled primary, returning
                // to Wallet — this route is always reached via a push from
                // Wallet (see app_router.dart), so a plain pop genuinely
                // does return there.
                KButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, required this.last});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    // s38 detail rows: "13px 0" padding, text-data (14px) for both label
    // and value, value at regular weight.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: KType.data(color: KColor.ink2))),
          Text(value, style: KType.data(color: KColor.ink).tnum),
        ],
      ),
    );
  }
}
