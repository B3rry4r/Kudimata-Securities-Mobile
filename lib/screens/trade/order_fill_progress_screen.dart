// Flow, spec screen 80 — "Order lifecycle · part-fills" (2026-08-23 "Soft
// Landing" exactness pass). UI-ready, NOT wired into any real navigation
// path — same class of gap as price_moved_screen.dart's screen 62, but for
// a different reason: no partial-fill DATA exists anywhere in this app's
// model. `Txn` (lib/data/models.dart) collapses every order to exactly one
// of three states — completed/pending/failed (confirmed against
// orders_repository.dart's own doc comment on `_statusFromJson`) — there is
// no fills array, no filled/total unit counts, no per-fill price or
// timestamp, and no per-fill contract-note reference. A real backend would
// need the Order resource to expose something like `{ filledUnits,
// totalUnits, fills: [{units, price, filledAt, contractNoteRef}] }`, plus a
// way for the client to learn about each fill as it happens (poll or push) —
// none of that exists today. Built ready for that day rather than wired to
// fabricated numbers for every real sell order (most of which never
// part-fill, and none of which this client can currently tell apart from a
// normal fill anyway).
//
// "Cancel the unfilled ..." has the same gap order_status_screen.dart's own
// comment already flags: no cancel-order endpoint exists to call yet. Both
// buttons here take caller-supplied callbacks (mirroring
// price_moved_screen.dart's style) rather than baking in route/repo
// knowledge, so wiring them up is a one-line change once the real
// capabilities exist.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// One line in the fill timeline — either a completed fill ("25 sold at
/// ₦268.40") or the still-open remainder ("20 still on the market").
class OrderFillEvent {
  const OrderFillEvent({required this.unitsLabel, required this.timeLabel, this.done = true});
  final String unitsLabel;
  final String timeLabel;
  final bool done;
}

String _formatShares(double units) =>
    units == units.roundToDouble() ? units.toStringAsFixed(0) : units.toStringAsFixed(1);

class OrderFillProgressScreen extends StatelessWidget {
  const OrderFillProgressScreen({
    super.key,
    required this.ticker,
    required this.requestedUnits,
    required this.filledUnits,
    required this.fills,
    required this.remainingUnits,
    required this.remainingNote,
    required this.onSeeContractNotes,
    required this.onCancelUnfilled,
  });

  final String ticker;
  final double requestedUnits;
  final double filledUnits;

  /// Completed fills only — the still-open remainder is rendered separately
  /// below, via [remainingUnits]/[remainingNote], to match spec 80's own
  /// three-row example (two done, one pending) without callers needing to
  /// build that last row's `done: false` styling themselves.
  final List<OrderFillEvent> fills;
  final double remainingUnits;
  final String remainingNote;
  final VoidCallback onSeeContractNotes;
  final VoidCallback onCancelUnfilled;

  @override
  Widget build(BuildContext context) {
    final progress = requestedUnits > 0 ? (filledUnits / requestedUnits).clamp(0.0, 1.0) : 0.0;
    final rows = [
      ...fills,
      OrderFillEvent(
        unitsLabel: '${_formatShares(remainingUnits)} still on the market',
        timeLabel: remainingNote,
        done: false,
      ),
    ];

    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(
        title: 'Sell $ticker · ${_formatShares(requestedUnits)}',
        trailing: const KStatusPill(status: KStatus.pending, label: 'Part-filled', small: true),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 16, KSpace.gutter, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border.all(color: KColor.hairline, width: 1),
                borderRadius: KRadii.cardR,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Filled so far', style: KType.body(color: KColor.ink2)),
                      ),
                      Text(
                        '${_formatShares(filledUnits)} of ${_formatShares(requestedUnits)}',
                        style: KType.cardTitle().tnum,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: KColor.track,
                      color: KColor.indicator,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$ticker is trading thinly today, so the order fills in pieces. '
                    'Each piece gets its own contract note.',
                    style: KType.body(color: KColor.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: KColor.paper,
                border: Border.all(color: KColor.hairline, width: 1),
                borderRadius: KRadii.cardR,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    _FillRow(event: rows[i], last: i == rows.length - 1),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You get one notification per fill, and one when the order closes. Nothing silent.',
              style: KType.body(color: KColor.ink3),
            ),
            const SizedBox(height: 20),
            KButton(
              label: 'See the contract notes',
              variant: KButtonVariant.secondary,
              onPressed: onSeeContractNotes,
            ),
            const SizedBox(height: 10),
            KButton(
              label: 'Cancel the unfilled ${_formatShares(remainingUnits)}',
              variant: KButtonVariant.destructive,
              onPressed: onCancelUnfilled,
            ),
          ],
        ),
      ),
    );
  }
}

class _FillRow extends StatelessWidget {
  const _FillRow({required this.event, required this.last});
  final OrderFillEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: event.done ? KColor.statusApprovedTint : KColor.track,
              shape: BoxShape.circle,
            ),
            child: KIcon(event.done ? 'check' : 'clock', size: 13,
                color: event.done ? KColor.gain : KColor.ink2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event.unitsLabel, style: KType.data(color: KColor.ink)),
                Text(event.timeLabel, style: KType.micro(color: KColor.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
