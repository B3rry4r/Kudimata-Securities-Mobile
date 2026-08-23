// KYC 3 — ID upload (step 2 of 5). ID-type chips + a file dropzone wired to
// the real presigned-upload flow (registry.json "KycDocument": POST
// /kyc-documents/upload-url -> presigned S3 PUT -> POST /kyc-documents;
// see lib/data/repositories/kyc_document_repository.dart). NIN itself
// moved to bvn_nin.dart (step 1) — 2026-08-20 phased-KYC directive.
//
// Registers the uploaded document IMMEDIATELY (POST /kyc-documents), unlike
// the old flow — a real draft KycSubmission already exists by this point
// (created on step 1), so there's no more need to stash the objectKey in
// KycFormState for a later bulk registration.
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
  const _IdType(this.id, this.label);
  final String id;
  final String label;
}

class IdUploadScreen extends StatefulWidget {
  const IdUploadScreen({super.key});

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  static const _types = [
    _IdType('nin', 'NIN'),
    _IdType('passport', 'International passport'),
    _IdType('licence', "Driver's licence"),
    _IdType('voters_card', "Voter's card"),
  ];

  String _type = 'nin';

  /// Opens the ID-type list in its own sheet instead of a row of pill chips
  /// (2026-08-20 fix — reported: "the UI doesn't properly show users that
  /// you have to select rather she felt she had to upload all"). A `Wrap`
  /// of same-looking selectable chips reads ambiguously as "pick some/all
  /// of these", especially once a 4th option was added; a single compact
  /// field showing ONE chosen value (same pattern bank_accounts_screen.dart
  /// already uses for its bank picker) makes "pick exactly one" obvious.
  Future<void> _pickType() async {
    final picked = await showKSheet<String>(
      context,
      title: 'ID type',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _types.length; i++)
            _IdTypeRow(
              label: _types[i].label,
              selected: _type == _types[i].id,
              first: i == 0,
              onTap: () => Navigator.of(context).pop(_types[i].id),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _type = picked);
  }

  KFileInfo? _file;
  bool _uploading = false;
  String? _uploadError;
  bool _showErrors = false;

  late final _repo = KycDocumentRepository(AppScope.read(context).apiClient);

  // id_upload.dart's local chip ids are 'nin' | 'passport' | 'licence';
  // KycSubmission.documentType (and KycDocument.documentKind) is
  // enum(nin,passport,drivers_licence,...) — map 'licence' accordingly.
  String get _documentKind => _type == 'licence' ? 'drivers_licence' : _type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(onBack: () => context.go(Routes.kycBvn)),
            const KycStepProgress(total: 5, current: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Upload your ID',
                      body: 'All four corners visible, no glare.',
                    ),
                    const SizedBox(height: 20),
                    const KEyebrow('ID type'),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickType,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: KColor.paper,
                          borderRadius: BorderRadius.circular(KRadii.input),
                          border: Border.all(color: KColor.hairline, width: 1),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _types.firstWhere((t) => t.id == _type).label,
                                style: KType.body(color: KColor.ink, w: KWeight.medium),
                              ),
                            ),
                            const SizedBox(width: 10),
                            KIcon('chevronRight', size: 20, color: KColor.ink3),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    KFileUpload(
                      label: 'Upload your ID',
                      hint: 'JPG or PDF · up to 10 MB',
                      prompt: _uploading ? 'Uploading…' : 'Tap to upload, or take a photo',
                      helper: _uploading ? 'Uploading your document…' : null,
                      error: _uploadError ??
                          (_showErrors && _file == null
                              ? 'Upload your ID document to continue'
                              : null),
                      disabled: _uploading,
                      file: _file,
                      onPick: _uploading ? null : _pickAndUpload,
                      onRemove: _uploading
                          ? null
                          : () => setState(() {
                                _file = null;
                                _uploadError = null;
                              }),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(
                label: 'Continue',
                onPressed: _uploading ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ID type chip picker + file dropzone:
  //   1. POST /kyc-documents/upload-url {documentKind, documentName}
  //      -> {uploadUrl, objectKey}                      (KycDocumentRepository)
  //   2. PUT the picked file's bytes to `uploadUrl` directly — a bare
  //      `package:http` client, NOT the shared ApiClient/Dio instance, since
  //      that instance's interceptor would attach this app's own
  //      Authorization header to the S3 request.
  //   3. POST /kyc-documents {kycSubmissionId, objectKey, documentName,
  //      documentKind} — the draft from step 1 already exists, so this
  //      registers immediately rather than deferring to a later bulk call.
  Future<void> _pickAndUpload() async {
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

    final documentKind = _documentKind;
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

  void _continue() {
    if (_file == null) {
      setState(() => _showErrors = true);
      return;
    }
    context.go(Routes.kycLiveness);
  }
}

/// One row in the ID-type picker sheet — same shape as
/// bank_accounts_screen.dart's own _BankOptionRow, duplicated rather than
/// shared per this codebase's per-screen small-widget convention.
class _IdTypeRow extends StatelessWidget {
  const _IdTypeRow({
    required this.label,
    required this.selected,
    required this.first,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: KType.cardTitle())),
            if (selected) const KIcon('check', size: 18),
          ],
        ),
      ),
    );
  }
}
