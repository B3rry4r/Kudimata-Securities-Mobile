// Kudimata Securities — Wallet screens: WalletScreen (root tab — transaction
// history only) and TransactionDetailScreen (pushed; KStatusView-style
// summary + detail rows). NGX-only: no USD wallet / Convert flow in the UI
// (HIDE phase — TxnType.convert stays as dead code below).
//
// NON-CUSTODIAL WALLET REDESIGN (backend supersedes.json S-11): Kudimata
// holds no client funds, so there is no stored balance to show and no
// standalone Add money / Withdraw action — a buy collects payment through
// its own checkout step (trade_flows.dart) and a sell/a failed buy's refund
// pays out automatically. This screen is now purely
// TransactionRepository.list()-backed history — the KBalancePanel, action
// row, and wallet_flows.dart's showAddMoneyFlow/showWithdrawFlow sheets they
// launched are gone.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/widgets/widgets.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/transaction_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1 · WALLET HOME (root tab — shell provides the bottom nav).
// ─────────────────────────────────────────────────────────────────────────────

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final _txnRepo = TransactionRepository(AppScope.read(context).apiClient);
  late Future<List<Txn>> _future = _load();

  Future<List<Txn>> _load() async {
    final page = await _txnRepo.list();
    return page.data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = _load());
            await _future;
          },
          child: FutureBuilder<List<Txn>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const KLoadingView();
              }
              if (snapshot.hasError) {
                return KErrorView(
                  onPrimary: () => setState(() => _future = _load()),
                );
              }
              return _WalletBody(txns: snapshot.data!);
            },
          ),
        ),
      ),
    );
  }
}

class _WalletBody extends StatelessWidget {
  const _WalletBody({required this.txns});
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Tab root: clear the floating KBottomNav (~70px + 12 margin + safe area).
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 100),
      children: [
        const KScreenHead(title: 'Wallet'),
        const SizedBox(height: 20),

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
          KEmptyView.transactions(onAction: () => context.go(Routes.markets))
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
        TxnType.refund => 'arrowDownLeft',
      };

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(
                color: KColor.bg,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: KColor.hairline, width: 1)),
              ),
              child: KIcon(_icon, size: 18),
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
        TxnType.refund => 'Refund',
      };

  (KStatusTone, String, Color) _status(TxnStatus s) => switch (s) {
        TxnStatus.completed => (KStatusTone.success, 'Completed', KColor.gain),
        TxnStatus.pending => (KStatusTone.pending, 'Pending', KColor.ink2),
        TxnStatus.failed => (KStatusTone.error, 'Failed', KColor.loss),
      };

  Future<void> _getReceipt() async {
    setState(() => _receiptBusy = true);
    try {
      await _repo.receiptUrl(widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt requested — check your email shortly.')),
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

        final (_, statusLabel, dotColor) = _status(txn.status);
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
                            _StatusPill(label: statusLabel, dotColor: dotColor),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.dotColor});
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: KColor.bg,
        borderRadius: BorderRadius.circular(KRadii.pill),
        border: Border.all(color: KColor.hairline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label.upper, style: KType.label(color: KColor.ink2)),
        ],
      ),
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
