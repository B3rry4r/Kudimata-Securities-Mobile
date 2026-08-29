// Statement · per broker. No artboard (restyle-only per RULINGS.md — the
// old code comment cited "screen 76" from the pre-renumbering 97-screen
// canvas; per R-5, that id points at an unrelated screen in the current
// 56-artboard canvas and is stripped rather than kept as a false citation).
// Pushed from a monthly-statement row in statements_screen.dart (mirrors
// how a contract-note row already pushes contract_note_screen.dart).
//
// This pass brings the screen onto the KAccountSubScaffold/KCard idiom the
// rest of the Account cluster uses (contract_note_screen.dart,
// tax_documents_screen.dart, statements_screen.dart) — same header shape,
// same card token — instead of the bespoke Scaffold + shadowed Container it
// had. Content, copy and functionality are unchanged; this is restyle-only,
// not a redesign.
//
// Real backend limitation, flagged rather than faked — TWO separate gaps:
//
// 1. No broker dimension exists anywhere on this backend. The old canvas's
//    per-broker statement mock (a "Brokers · 1 of 1" summary field,
//    all-brokers opening/closing totals, then one section PER EXECUTING
//    BROKER with its own account number, holdings, movements and subtotal)
//    has no real counterpart: holding_detail_screen.dart's own header
//    comment already documents the direct check against this backend's
//    real types (Order/Holding, confirmed against prisma/schema.prisma) —
//    no brokerId/brokerCode field anywhere, this app is single-broker
//    today. statements_repository.dart's `Statement` model is the same
//    story — {id, kind, title, periodOrTradeRef, fileSizeBytes, generatedAt,
//    fileObjectKey}, no broker field, no client/CHN field, no
//    balance/holdings/movements breakdown at all on the list resource.
//    What IS real and verified (2026-08-24, against
//    Kudimata-Securities-Backend's statement-pdf.service.ts directly): the
//    generated PDF genuinely renders consolidated opening/closing totals
//    then one section per executing broker with its own holdings,
//    movements and subtotal — the generator is structurally per-broker
//    even though only one broker exists in practice today. So the "full
//    breakdown is in the PDF" copy below is a verified true claim, not an
//    invented one (R-9/R-34) — it is the inline rendering of that same
//    breakdown that doesn't exist, which is what the callout says.
// 2. The dividend movement row concept ("28 Feb · MTN dividend +₦4,120.00")
//    has no backing data on this resource either: lib/data/models.dart's
//    `TxnType` enum is {fund, withdraw, buy, sell, convert} — no
//    `dividend` value — the same gap holding_detail_screen.dart already
//    found and documented.
//
// Given none of the structured per-broker content exists on the list/detail
// resource this screen actually receives, it renders the real document
// metadata that IS on the wire (title, generated date, file size — the
// same `Statement.sub` getter contract_note_screen.dart already uses), and
// one honest explainer for everything else, instead of fabricating broker
// names, balances or holdings that would look like real money but aren't.
//
// DOWNLOAD (2026-08-29, product owner: "download should download and not
// open a link"): this button used to hand the presigned S3 URL straight to
// `launchUrl`, which kicks the investor out to a browser tab instead of
// saving anything. Fixed on Android/iOS: fetch the presigned URL's bytes
// with a PLAIN `http` client (not the shared ApiClient/Dio — same reasoning
// kyc-id's direct-to-S3 upload already documents: this app's own
// Authorization header has no business on a presigned S3 request), write
// them to a real on-device file, then hand that file to the OS share sheet
// (share_plus) — save-to-Files/Drive/etc. from there is the investor's own
// choice, same as any other app's document share. `web` keeps `url_launcher`
// (a genuinely different mechanism there — the browser owns downloads, not
// this app). The presigned URL itself is never logged, shown, or passed to
// Share as text — only the downloaded bytes are shared, as a file.
//
// A statement whose PDF was never actually rendered/uploaded (a placeholder
// row — see StatementsRepository's own header on why some still are) fails
// the S3 GET with an XML error body, not a PDF; that surfaces as a real,
// readable error here rather than sharing the error body as if it were the
// document.
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/app/app_state.dart';

import 'package:kudimata_invest/data/repositories/statements_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

class StatementDetailScreen extends StatefulWidget {
  const StatementDetailScreen({super.key, required this.statement});
  final Statement statement;

  @override
  State<StatementDetailScreen> createState() => _StatementDetailScreenState();
}

class _StatementDetailScreenState extends State<StatementDetailScreen> {
  bool _downloading = false;

  Statement get statement => widget.statement;

  /// Downloads the statement's real stored PDF via a short-lived presigned
  /// URL (GET /statements/:id/download-url), then hands the actual file to
  /// the OS (see file header). A statement with `fileSizeBytes == 0` never
  /// got a file stored (its render or upload failed), and says so up front
  /// rather than attempting a download that can only fail.
  Future<void> _download() async {
    if (_downloading) return;
    if (statement.fileSizeBytes == 0) {
      _notAvailable("This statement's PDF isn't available to download.");
      return;
    }
    setState(() => _downloading = true);
    try {
      final url = await StatementsRepository(AppScope.read(context).apiClient)
          .downloadUrl(statement.id);
      if (url.isEmpty) {
        _notAvailable("This statement's PDF isn't available to download.");
        return;
      }

      if (kIsWeb) {
        // The browser owns the download surface on web — a different
        // mechanism entirely, kept as-is (see file header).
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok && mounted) _notAvailable("Couldn't open the download. Try again.");
        return;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        // S3 returns an XML error body (not a PDF) for an object that was
        // never actually uploaded — a real, readable failure, not a
        // silently "successful" share of garbage bytes.
        _notAvailable("This statement's PDF isn't available to download.");
        return;
      }

      final fileName = '${_safeFileName(statement.title)}.pdf';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], fileNameOverrides: [fileName]),
      );
    } on ApiException catch (e) {
      if (mounted) _notAvailable(e.message);
    } catch (_) {
      if (mounted) _notAvailable("Couldn't download the file. Try again.");
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _notAvailable(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      // The statement's own period label ("August 2026 · all brokers"),
      // not a generic "Statement" title.
      title: statement.title,
      headerTrailing: KIconButton(
        icon: 'download',
        semanticLabel: 'Download',
        // Disabled (not just re-triggered) while a download is already in
        // flight — the footer button below carries the real progress
        // state/spinner for this same action.
        onPressed: _downloading ? null : _download,
      ),
      footer: KButton(
        label: _downloading ? 'Downloading…' : 'Download PDF',
        iconLeft: 'download',
        loading: _downloading,
        onPressed: _downloading ? null : _download,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const KMark(size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Kudimata Securities Ltd', style: KType.cardTitle()),
                          Text(statement.sub, style: KType.data(color: KColor.ink3).tnum),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: KColor.hairline),
                const SizedBox(height: 16),
                // See file header point 1 — this claim is verified against
                // the real PDF generator, not asserted on faith.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KColor.track,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'The full breakdown is in the PDF — your opening and closing '
                    'balances, then every holding, movement and subtotal for each '
                    'broker that executed for you.',
                    style: KType.body(color: KColor.ink2),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: KColor.hairline),
                const SizedBox(height: 16),
                // Verified against statement-pdf.service.ts's own compliance
                // copy — "dividends are net of withholding tax" is a direct
                // match, not a transcribed mock figure.
                Text(
                  'Valuations are market closing prices. Dividends are net of '
                  'withholding tax.',
                  style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 2026-08-29: dropped the blanket "Statements are not emailed"
          // claim this line used to make. It stopped being universally true
          // the moment request_statement_screen.dart's flow shipped — a
          // statement requested there IS emailed (StatementGeneratorService.
          // generateRange) — and nothing on this resource's wire shape says
          // which path produced the statement being viewed here, so a
          // blanket claim either direction would be a guess. What stays
          // true for every statement regardless of how it was produced:
          // download keeps a copy on the device.
          Text(
            'Download keeps a copy on your device.',
            style: KType.data(color: KColor.ink3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A statement title ("August 2026 · all brokers") turned into a safe
/// on-device filename — strips the characters real titles here actually
/// contain (`·`, `/`, spaces) rather than a generic placeholder name, so a
/// shared/saved file is still recognisable as the statement it came from.
String _safeFileName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-');
  final trimmed = cleaned.replaceAll(RegExp(r'^-|-$'), '');
  return trimmed.isEmpty ? 'statement' : trimmed;
}
