// KYC 3 — ID upload, part of the merged "Documents" step (step 3 of 8 —
// shares this number with utility_bill.dart's address/proof-of-address half;
// renumbered 8->7 2026-08-27 per X-2/bvn_nin.dart's derivation). Artboard
// s14/s14d ("Your documents",
// 02 Verification.dc.html) draws a row-list ID-type picker — NOT a
// dropdown/sheet — where the three rows themselves ARE the picker; tapping
// one selects it, then Continue drives the real presigned-upload flow
// (registry.json "KycDocument": POST /kyc-documents/upload-url -> presigned
// S3 PUT -> POST /kyc-documents; see
// lib/data/repositories/kyc_document_repository.dart). NIN itself moved to
// bvn_nin.dart (step 1) — 2026-08-20 phased-KYC directive; this screen only
// asks the investor to PHOTOGRAPH one of the three, it doesn't collect the
// NIN number again.
//
// Rebuilt from the earlier sheet-picker + separate dropzone layout to match
// s14's actual structure (2026-08-27 redesign pass) — see the row list
// below. s14 itself draws only three rows (NIN slip / Driver's licence /
// International passport) with no Voter's card anywhere.
//
// 2026-08-29 (product-owner audit, 7th false comment this pass caught): a
// prior pass dropped a 4th Voter's card chip here on the claimed grounds
// that Kudimata-Securities-Backend's `documentKind` enum was
// `nin|passport|drivers_licence|proof_of_address|liveness_selfie` with "no
// voters_card value, ever". That was false — checked against the schema,
// not memory: `prisma/schema.prisma`'s `KycSubmissionDocumentType` AND
// `KycDocumentKind` both carry `voters_card`, `common/types/enums.ts`
// mirrors it, `KYC_DOCUMENT_KIND_VALUES` (kyc-documents/dto/upload-url.dto.
// ts) validates it via `@IsIn`, and kyc-submissions.service.ts's own
// computeCurrentStep() already treats it as a primary ID alongside
// nin/passport/drivers_licence. None of the KYC identity providers
// (Dojah/YouVerify/LumiID adapters) verify the ID *document image* at
// all — they only verify the BVN/NIN *number* — so there is no vendor-side
// gap either; a voter's card upload is registered and reviewed exactly
// like the other three. The row is back, matching both the schema and the
// fact that a Nigerian voter's card is an ordinary primary ID here. This
// IS a design-canvas gap (s14 draws only three rows) rather than a backend
// one, since the backend already supports it — not filed in
// BACKEND_GAPS.md, which is for backend gaps, not canvas ones.
//
// Registers the uploaded document IMMEDIATELY (POST /kyc-documents), unlike
// the old flow — a real draft KycSubmission already exists by this point
// (created on step 1), so there's no more need to stash the objectKey in
// KycFormState for a later bulk registration.
//
// 2026-08-29 (A-4 audit fix): this screen used to forward straight to
// Routes.kycUtilityBill on success. That's wrong against the backend's own
// gating — KycSubmissionsService.computeCurrentStep() (the source of
// `currentStep`/`documentType`) checks liveness BEFORE it ever looks at the
// utility bill: no ID doc -> step 2; ID doc but no liveness -> step 3;
// liveness done but no utility bill -> step 4; else done. Reaching
// utility_bill.dart before liveness left `currentStep` stuck at 3 forever
// (its own gate short-circuits there), even after the utility bill
// uploaded. (The checklist hub's "documents done"/"selfie done" rows no
// longer read `currentStep` at all as of the resume-loop fix in
// kyc_checklist_screen.dart — they read the real per-document evidence
// directly — but the underlying
// forward-order problem this paragraph fixes is unchanged.) liveness.dart's
// own back button used to point here (`onBack: () => context.go(Routes.
// kycId)`) and utility_bill.dart's own back button used to point at
// liveness (`onBack: () => context.go(Routes.kycLiveness)`) — both were
// written assuming THIS screen forwards into liveness next; only the
// forward wiring here disagreed (both back targets have since moved to the
// checklist hub — see routes.dart gatedBackTarget's 2026-08-29 note; this
// paragraph is about FORWARD order, which is unaffected). Now forwards to
// Routes.kycLiveness, matching both of
// those and the backend's real step order (id -> liveness -> utility bill).
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_document_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

class _IdType {
  const _IdType(this.id, this.label, {this.subtitle});
  final String id;
  final String label;
  final String? subtitle;
}

class IdUploadScreen extends StatefulWidget {
  const IdUploadScreen({super.key});

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  // Order + copy matches s14's three rows exactly, with one label kept as
  // direct product feedback overrode it 2026-08-24 ("NIN not NIN slip" —
  // the KYC check verifies the NIN number, not the physical slip, so the
  // plainer label is the accurate one; canvas literally says "NIN slip").
  // "International passport" and "Driver's licence" already match the
  // canvas verbatim. "Voter's card" is a 4th row the canvas doesn't draw at
  // all — added 2026-08-29 per direct product-owner instruction, backed by
  // a verified backend schema check (see this file's header) rather than
  // canvas conformance.
  static const _types = [
    _IdType('nin', 'NIN', subtitle: 'Fastest to verify'),
    _IdType('licence', "Driver's licence"),
    _IdType('passport', 'International passport'),
    _IdType('voters_card', "Voter's card"),
  ];

  String? _type;
  KFileInfo? _file;
  bool _uploading = false;
  String? _uploadError;
  bool _showErrors = false;

  late final _repo = KycDocumentRepository(AppScope.read(context).apiClient);

  // id_upload.dart's local chip ids are 'nin' | 'passport' | 'licence' |
  // 'voters_card'; KycSubmission.documentType (and KycDocument.
  // documentKind) is enum(nin,passport,drivers_licence,voters_card,...) —
  // map 'licence' accordingly. 'voters_card' is already spelled exactly
  // like the wire enum, so it passes through unchanged; a near-miss spelling
  // here would pass client-side but fail the backend's `@IsIn` validator,
  // and the failure would look like a broken upload, not a typo, so this
  // stays a single explicit mapping rather than a "looks the same" pass-through.
  String _documentKindFor(String type) => type == 'licence' ? 'drivers_licence' : type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(
              // R-45 as amended: locked (pre-restart) goes to the checklist
              // hub, in-session goes to the normal predecessor — see
              // kycBackTarget's own doc comment.
              onBack: () => context.go(kycBackTarget(context, Routes.kycId)),
              stepLabel: kycStepLabel(3),
            ),
            const KycStepProgress(current: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Your documents',
                      body: "Pick one ID to photograph. You'll take a selfie next.",
                    ),
                    const SizedBox(height: 24),
                    for (var i = 0; i < _types.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _IdTypeCard(
                        icon: 'doc',
                        label: _types[i].label,
                        subtitle: _types[i].subtitle,
                        selected: _type == _types[i].id,
                        disabled: _uploading,
                        onTap: _uploading
                            ? null
                            : () => setState(() {
                                  _type = _types[i].id;
                                  _uploadError = null;
                                }),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Take the photo in daylight. All four corners visible.',
                      style: KType.body(color: KColor.ink3).copyWith(height: 20 / 14, fontSize: 14),
                    ),
                    if (_showErrors && _type == null) ...[
                      const SizedBox(height: 10),
                      Text('Select an ID type to continue',
                          style: KType.micro(color: KColor.loss).copyWith(letterSpacing: 0.02 * 10)),
                    ],
                    if (_uploadError != null) ...[
                      const SizedBox(height: 10),
                      Text(_uploadError!,
                          style: KType.micro(color: KColor.loss).copyWith(letterSpacing: 0.02 * 10)),
                    ],
                    if (_uploading) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const KSpinner(size: 16),
                          const SizedBox(width: 10),
                          Text('Uploading your document…', style: KType.body(color: KColor.ink3)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(
                label: 'Continue',
                loading: _uploading,
                onPressed: _uploading ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Row select + Continue drives the upload:
  //   1. POST /kyc-documents/upload-url {documentKind, documentName}
  //      -> {uploadUrl, objectKey}                      (KycDocumentRepository)
  //   2. PUT the picked file's bytes to `uploadUrl` directly — a bare
  //      `package:http` client, NOT the shared ApiClient/Dio instance, since
  //      that instance's interceptor would attach this app's own
  //      Authorization header to the S3 request.
  //   3. POST /kyc-documents {kycSubmissionId, objectKey, documentName,
  //      documentKind} — the draft from step 1 already exists, so this
  //      registers immediately rather than deferring to a later bulk call.
  Future<void> _continue() async {
    final type = _type;
    if (type == null) {
      setState(() => _showErrors = true);
      return;
    }
    if (_file != null) {
      // Already uploaded this session (e.g. Continue tapped again after a
      // successful upload, before navigation lands) — just advance.
      context.go(Routes.kycLiveness);
      return;
    }

    final draftId = AppScope.read(context).kycForm.draftId;
    if (draftId == null) {
      setState(() => _uploadError = 'Something went wrong — please restart verification.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      setState(() => _uploadError = "Couldn't read that file. Please try again.");
      return;
    }

    setState(() {
      _uploading = true;
      _uploadError = null;
    });

    final documentKind = _documentKindFor(type);
    try {
      final uploadUrl = await _repo.requestUploadUrl(
        documentKind: documentKind,
        documentName: picked.name,
      );
      final putResponse = await http.put(
        Uri.parse(uploadUrl.uploadUrl),
        body: bytes,
        headers: {'Content-Type': _contentTypeFor(picked.name)},
      );
      if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
        throw Exception('S3 upload failed with status ${putResponse.statusCode}');
      }
      await _repo.registerDocument(
        kycSubmissionId: draftId,
        objectKey: uploadUrl.objectKey,
        documentName: _documentName(documentKind),
        documentKind: documentKind,
      );
      if (!mounted) return;
      setState(() {
        _file = KFileInfo(name: picked.name, size: picked.size);
        _uploading = false;
      });
      context.go(Routes.kycLiveness);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = 'Upload failed. Please try again.';
      });
    }
  }

  String _documentName(String kind) => switch (kind) {
        'nin' => 'NIN',
        'passport' => 'International passport',
        'drivers_licence' => "Driver's licence",
        'voters_card' => "Voter's card",
        _ => kind,
      };

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}

/// One ID-type row — s14's own picker IS this list (no separate modal
/// sheet): a tinted icon plate, title (+ optional subtitle), and a trailing
/// glyph that reads chevron-right when unselected and check when selected
/// (the design draws only the static chevron; the check/border highlight is
/// added here since a "pick one of three, then Continue" flow needs a real
/// visible selection state — R-30's spirit, not a design deviation).
class _IdTypeCard extends StatelessWidget {
  const _IdTypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
    this.subtitle,
  });

  final String icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: KColor.paper,
          borderRadius: BorderRadius.circular(KRadii.card),
          border: Border.all(
            color: selected ? KColor.indicator : KColor.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KColor.indicatorTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: KIcon(icon, size: 20, color: KColor.indicator),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: KType.cardTitle().copyWith(color: disabled ? KColor.ink3 : KColor.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: KType.body(color: KColor.ink3).copyWith(fontSize: 14)),
                  ],
                ],
              ),
            ),
            KIcon(selected ? 'check' : 'chevronRight',
                size: 18, color: selected ? KColor.indicator : KColor.ink3),
          ],
        ),
      ),
    );
  }
}
