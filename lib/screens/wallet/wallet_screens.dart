// Kudimata Invest — Stage 8: Wallet screens. Mirrors wallet-screens.jsx:
// WalletScreen (root tab — naira BalancePanel, action row, recent
// transactions) and TransactionDetailScreen (pushed; KStatusView-style summary +
// detail rows). NGX-only: no USD wallet / Convert flow in the UI (HIDE phase —
// TxnType.convert stays as dead code below). The money-movement flows
// (Add money / Withdraw) live in wallet_flows.dart as bottom-sheet sequences.
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
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/transaction_repository.dart';
import 'package:kudimata_invest/data/repositories/wallet_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';

import 'wallet_flows.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1 · WALLET HOME (root tab — shell provides the bottom nav).
// ─────────────────────────────────────────────────────────────────────────────

typedef _WalletData = ({String balance, List<Txn> txns, bool devFundEnabled});

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final _walletRepo = WalletRepository(AppScope.read(context).apiClient);
  late final _txnRepo = TransactionRepository(AppScope.read(context).apiClient);
  late Future<_WalletData> _future = _load();

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
  bool _devFundBusy = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<_WalletData> _load() async {
    // Record `.wait`, not fire-then-sequential-await — see home_screen.dart's
    // _load() for why (an early rejection would otherwise leave the other
    // future's eventual rejection unlistened-to: an "unhandled exception").
    final (balance, page, devFundEnabled) =
        await (_walletRepo.balance(), _txnRepo.list(), _walletRepo.devFundEnabled()).wait;
    return (balance: balance, txns: page.data, devFundEnabled: devFundEnabled);
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

  Future<void> _devFund() async {
    setState(() => _devFundBusy = true);
    try {
      // ₦10,000 — a fixed, convenient amount for exercising the market-buy
      // wallet-balance gate (see the backend's applyWalletSideEffect); not
      // user-entered, since this is a one-tap test convenience, not a real
      // funding flow.
      await _walletRepo.devFund(amountKobo: 1_000_000);
      if (!mounted) return;
      final data = await _load();
      if (!mounted) return;
      setState(() => _data = data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added ₦10,000 (test funding)')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _devFundBusy = false);
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
                txns: data.txns,
                showDevFund: data.devFundEnabled,
                devFundBusy: _devFundBusy,
                onDevFund: _devFund,
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
    required this.txns,
    required this.showDevFund,
    required this.devFundBusy,
    required this.onDevFund,
  });
  final String balance;
  final List<Txn> txns;

  /// True only when the backend reports Flutterwave is on a sandbox key
  /// (GET /transactions/dev-fund/enabled) — never shown against a live key,
  /// however this build got configured.
  final bool showDevFund;
  final bool devFundBusy;
  final VoidCallback onDevFund;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 100),
      children: [
        const KScreenHead(title: 'Wallet'),
        const SizedBox(height: 16),

        // Naira wallet — the one rich ink surface on this screen.
        KBalancePanel(label: 'Available to invest', balance: balance),
        const SizedBox(height: 12),

        // Action row — Add money / Withdraw (sheet flows).
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: 'arrowDownLeft',
                label: 'Add money',
                onTap: () => showAddMoneyFlow(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: 'arrowUp',
                label: 'Withdraw',
                onTap: () => showWithdrawFlow(context),
              ),
            ),
          ],
        ),

        // Sandbox-only convenience (2026-08-20) — an instant ₦10,000 test
        // credit, no real Flutterwave checkout, for exercising the
        // wallet-balance gate on a market buy. Only ever rendered when the
        // backend itself confirms Flutterwave is on a sandbox key.
        if (showDevFund) ...[
          const SizedBox(height: 10),
          KButton(
            label: 'Add ₦10,000 (test funding)',
            variant: KButtonVariant.ghost,
            loading: devFundBusy,
            onPressed: devFundBusy ? null : onDevFund,
          ),
        ],
        const SizedBox(height: 28),

        // Recent header — eyebrow + Orders shortcut.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const KEyebrow('Recent'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < txns.length; i++)
                  _TxnRow(txn: txns[i], first: i == 0),
              ],
            ),
          ),
      ],
    );
  }
}

// 1/2-width action tile — line icon over a label.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KIcon(icon, size: 22),
            const SizedBox(height: 8),
            Text(label,
                style: KType.label(color: KColor.ink).copyWith(letterSpacing: 0, height: 1.0)),
          ],
        ),
      ),
    );
  }
}

// One ledger row: icon medallion · title + date · signed tabular amount.
class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn, required this.first});
  final Txn txn;
  final bool first;

  // Map ledger type to a glyph from the fixed KIcon set.
  String get _icon => switch (txn.type) {
        TxnType.fund => 'arrowDownLeft',
        TxnType.withdraw => 'arrowUp',
        TxnType.buy => 'markets',
        TxnType.sell => 'markets',
        TxnType.convert => 'transfer',
      };

  // Colored icon circle per ledger type (2026-08-22 "Soft Landing" —
  // screen-specs.md #40: "Icon (arrowDown, markets, wallet — each in a
  // colored circle: indicator-tint, track, sun-tint respectively)").
  (Color, Color) get _iconColors => switch (txn.type) {
        TxnType.fund => (KColor.indicatorTint, KColor.indicator),
        TxnType.buy || TxnType.sell => (KColor.track, KColor.ink),
        TxnType.withdraw || TxnType.convert => (KColor.sunTint, KColor.sunPress),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _iconColors;
    return GestureDetector(
      onTap: () => context.push(Routes.transactionDetail(txn.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: KIcon(_icon, size: 18, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(txn.title, style: KType.cardTitle().copyWith(height: 20 / 15)),
                  const SizedBox(height: 2),
                  Text(txn.subtitle,
                      style: KType.micro(color: KColor.ink3)
                          .copyWith(letterSpacing: 0.04 * 10, height: 15 / 10)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(txn.amount,
                style: KType.cardTitle(
                  color: txn.incoming ? KColor.gain : KColor.ink,
                  w: KWeight.semibold,
                ).copyWith(height: 20 / 15).tnum),
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

  // Human label for the ledger type (sentence case).
  String _typeLabel(Txn t) => switch (t.type) {
        TxnType.fund => 'Add money',
        TxnType.withdraw => 'Withdrawal',
        TxnType.buy => 'Buy',
        TxnType.sell => 'Sell',
        TxnType.convert => 'Conversion',
      };

  // "On its way"/"Completed"/"Failed" per screen-specs.md #43 — mapped onto
  // the shared workflow-state vocabulary (KStatus), not a bespoke pill.
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _receiptBusy = false);
    }
  }

  Widget get _notFoundScaffold => Scaffold(
        backgroundColor: KColor.bg,
        appBar: const KDetailHeader(title: 'Transaction'),
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
            appBar: const KDetailHeader(title: 'Transaction'),
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
            appBar: const KDetailHeader(title: 'Transaction'),
            body: KErrorView(
              onPrimary: () => setState(() => _future = _repo.byId(widget.id)),
            ),
          );
        }

        final txn = snapshot.data;
        if (txn == null) return _notFoundScaffold;

        final (statusEnum, statusLabel) = _status(txn.status);
        final amountColor = txn.incoming ? KColor.gain : KColor.ink;

        final rows = <(String, String)>[
          ('Type',
              '${_typeLabel(txn)} · ${txn.title.replaceFirst(RegExp(r'^(Buy|Sell)\s+'), '')}'),
          ('Reference', txn.id),
          ('Date & time', txn.date),
          ('Status', statusLabel),
        ];

        return Scaffold(
          backgroundColor: KColor.bg,
          appBar: const KDetailHeader(title: 'Transaction'),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 20, KSpace.gutter, 24),
              children: [
                // Money-in-transit illustration, warm-plated per
                // screen-specs.md #43's colour note — distinct from the
                // grape/sun plates used elsewhere, for neutral/in-progress
                // money-movement states.
                const KIllustration('wallet-fund', role: KIlloRole.small, tone: KIlloTone.warm),
                const SizedBox(height: 20),
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status pill + hero amount, centred over a hairline.
                      Container(
                        padding: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
                        ),
                        child: Column(
                          children: [
                            KStatusPill(status: statusEnum, label: statusLabel),
                            const SizedBox(height: 16),
                            Text(txn.amount,
                                style: KType.hero(color: amountColor).tnum),
                          ],
                        ),
                      ),
                      // Detail rows.
                      for (var i = 0; i < rows.length; i++)
                        _DetailRow(
                            label: rows[i].$1, value: rows[i].$2, last: i == rows.length - 1),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // GET /transactions/:id/receipt. Backend note: receipt
                // generation is still a stub (placeholder presigned URL, no
                // real PDF yet) — wired anyway so the plumbing is correct
                // end-to-end; see transaction_repository.dart's receiptUrl().
                KButton(
                  label: 'Get receipt',
                  variant: KButtonVariant.ghost,
                  loading: _receiptBusy,
                  onPressed: _receiptBusy ? null : _getReceipt,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KType.body(color: KColor.ink2)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: KType.body(color: KColor.ink, w: KWeight.medium).tnum),
          ),
        ],
      ),
    );
  }
}
