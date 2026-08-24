// Contract note document (design screen 66).
//
// 2026-08-24 REWRITE — reported live: "CONTRACT NOTE NOT SHOWING INSTEAD
// SHOWING ME LOGOS AND DOCUMENT SIZE... DOWNLOAD NOT WORKING".
//
// Both complaints were accurate. This screen only ever received a
// `Statement` ({id, kind, title, periodOrTradeRef, fileSizeBytes,
// generatedAt, fileObjectKey}), and nothing linked that back to the Order
// whose figures the note represents — so it rendered the only real data it
// had (a title, a date, a file size) beside the partner logos, and its
// Download / Email buttons were honest-but-inert snackbars.
//
// Both blockers are now closed server-side:
//   - Order persists its own commission / exchange-fee / VAT / total /
//     settlement-date / contractNoteRef (see the backend's
//     src/orders/fees.ts and the Order model), so the itemised breakdown is
//     real stored data rather than a client-side guess at order time.
//   - `Statement.periodOrTradeRef` now carries that same KDM-CN-xxxx
//     reference, so a note resolves 1:1 to its order via
//     GET /orders/contract-note/:ref.
//   - The PDF is really rendered and stored, so the download is a real
//     presigned URL rather than a promise.
//
// Layout follows design 66: issuer + reference, executed-through, client /
// trade dates, the itemised money rows, the emphasised total, the footer
// disclosure, and the fee-explainer line beneath the card.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class ContractNoteScreen extends StatefulWidget {
  const ContractNoteScreen({super.key, required this.statement});
  final Statement statement;

  @override
  State<ContractNoteScreen> createState() => _ContractNoteScreenState();
}

class _ContractNoteScreenState extends State<ContractNoteScreen> {
  late final _repo = StatementsRepository(AppScope.read(context).apiClient);
  late Future<ContractNote> _future = _load();

  Future<ContractNote> _load() {
    final ref = widget.statement.periodOrTradeRef;
    if (ref == null || ref.isEmpty) {
      // Older contract notes were filed before references existed; there is
      // nothing to resolve them to, and saying so beats a spinner forever.
      return Future.error(
        ApiException(
          code: 'NOT_FOUND',
          message: 'This note has no reference to look up.',
          statusCode: 404,
        ),
      );
    }
    return _repo.contractNote(ref);
  }

  Future<void> _download(ContractNote note) async {
    final url = note.downloadUrl;
    if (url == null) {
      _snack("This note's PDF isn't available to download yet.");
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) _snack("Couldn't open the download. Try again.");
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Contract note',
      child: FutureBuilder<ContractNote>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            // A 404 is NOT a transient failure and must not offer a retry
            // that can never succeed — reported live as "the receipt screen
            // doesn't stay open, it always falls back into a broken retry
            // screen". Contract notes filed before 2026-08-24 stored a
            // transaction id in `periodOrTradeRef` rather than a KDM-CN
            // reference, so they resolve to no order and 404 every time.
            final err = snapshot.error;
            final isMissing = err is ApiException && err.statusCode == 404;
            if (isMissing) {
              return const KEmptyView(
                icon: 'card',
                title: 'Itemised note not available',
                message: 'This note was filed before we started recording the fee '
                    'breakdown, so there is nothing itemised to show. Notes from new '
                    'orders include the full breakdown and a downloadable PDF.',
                illustrationName: 'empty-statements',
              );
            }
            return KErrorView(onPrimary: () => setState(() => _future = _load()));
          }
          return _NoteBody(note: snapshot.data!, onDownload: _download);
        },
      ),
    );
  }
}

/// Executing-broker logos, keyed by the broker name the backend returns.
///
/// Mirrors ContractNotePdfService.BROKER_LOGOS on the server so the app
/// screen and the downloaded PDF show the same mark. A map, not a hardcoded
/// image, because the sponsoring-broker arrangement is expected to change
/// and grow — the design canvas's own note on screen 66 says "a second
/// broker just adds a logo".
const Map<String, String> _kBrokerLogos = {
  'Blue Marina Securities Limited': 'assets/partners/blue-marina.png',
};

class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.note, required this.onDownload});
  final ContractNote note;
  final Future<void> Function(ContractNote) onDownload;

  @override
  Widget build(BuildContext context) {
    final isBuy = note.side == 'buy';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: KColor.paper,
            border: Border.all(color: KColor.hairline),
            borderRadius: KRadii.cardR,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Issuer + reference
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KMark(size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kudimata Securities Ltd', style: KType.cardTitle()),
                          const SizedBox(height: 2),
                          Text(
                            'Contract note · ${note.contractNoteRef}'.upper,
                            style: KType.micro(color: KColor.ink3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _hair(),
              // Executed through
              Container(
                width: double.infinity,
                color: KColor.bg,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  children: [
                    Text('Executed through'.upper, style: KType.micro(color: KColor.ink3)),
                    const SizedBox(width: 12),
                    // The executing broker's LOGO, matching the rendered PDF
                    // and design 66 — 2026-08-24: this row showed the broker
                    // as plain text while the PDF carried the mark, so the
                    // same document looked different in the app and in the
                    // downloaded file. Falls back to the name when a broker
                    // has no logo shipped, so adding one is a file plus a
                    // map entry and nothing else changes.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _kBrokerLogos.containsKey(note.executingBroker)
                            ? Image.asset(
                                _kBrokerLogos[note.executingBroker]!,
                                height: 16,
                                fit: BoxFit.contain,
                              )
                            : Text(
                                note.executingBroker,
                                style: KType.data(color: KColor.ink),
                                textAlign: TextAlign.right,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              _hair(),
              // Client / trade dates
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Client',
                        value: note.clientName,
                        sub: note.chn == null ? null : 'CHN ${note.chn}',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Field(
                        label: 'Trade date',
                        value: _dateTime(note.tradeDate),
                        sub: note.settlesOn == null
                            ? null
                            : 'Settles ${_shortDate(note.settlesOn!)} · T+3',
                      ),
                    ),
                  ],
                ),
              ),
              _hair(),
              // Itemised money rows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    _Row(isBuy ? 'Bought' : 'Sold', '${note.assetName} · ${note.ticker}'),
                    _Row('Shares · price',
                        '${_trimUnits(note.units)} · ${_naira(note.fillPriceKobo)}'),
                    _Row('Consideration', _naira(note.considerationKobo)),
                    _Row('Broker commission', _naira(note.commissionKobo)),
                    _Row('NGX · SEC · CSCS fees', _naira(note.exchangeFeesKobo)),
                    _Row('VAT on fees', _naira(note.vatKobo), last: true),
                  ],
                ),
              ),
              _hair(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(isBuy ? 'Total paid' : 'Total received',
                          style: KType.cardTitle()),
                    ),
                    Text(_naira(note.totalKobo), style: KType.cardTitle()),
                  ],
                ),
              ),
              _hair(),
              Container(
                width: double.infinity,
                color: KColor.bg,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Text(
                  'Kudimata Securities Ltd, SEC-registered · shares registered to your CHN at '
                  'the CSCS on settlement · this is a record of an executed order, not advice · '
                  'fees comprise broker commission plus NGX, SEC and CSCS charges and VAT.',
                  style: KType.micro(color: KColor.ink3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_naira(note.totalFeesKobo)} of the total is fees. Commission is ours; the rest '
          'belongs to the exchange and the regulator.',
          style: KType.data(color: KColor.ink3),
        ),
        const SizedBox(height: 20),
        KButton(
          label: 'Download PDF',
          iconLeft: 'download',
          fullWidth: true,
          onPressed: () => onDownload(note),
        ),
        const SizedBox(height: 10),
        // The canvas's "Email me this receipt" is deliberately NOT rendered:
        // the contract note is ALREADY emailed automatically the moment an
        // order fills, with this same PDF attached (design screen 69). A
        // second button that re-sends it needs a real re-send endpoint,
        // which doesn't exist — and the previous build's version of this
        // button was an inert snackbar, which is what "the email button runs
        // into couldn't load" was about.
        Text(
          'A copy of this note was emailed to you when the order filled.',
          style: KType.data(color: KColor.ink3),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _hair() => Container(height: 1, color: KColor.hairline);
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.sub});
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.upper, style: KType.micro(color: KColor.ink3)),
        const SizedBox(height: 2),
        Text(value, style: KType.data(color: KColor.ink)),
        if (sub != null) Text(sub!, style: KType.data(color: KColor.ink2)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
            ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KType.data(color: KColor.ink2))),
          Text(value, style: KType.data(color: KColor.ink)),
        ],
      ),
    );
  }
}

String _naira(int kobo) {
  final v = (kobo / 100).toStringAsFixed(2);
  final parts = v.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₦$whole.${parts[1]}';
}

String _trimUnits(String units) =>
    units.contains('.') ? units.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : units;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _dateTime(DateTime d) {
  final l = d.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${_months[l.month - 1]} ${l.year} · $hh:$mm';
}

String _shortDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]}';
}
