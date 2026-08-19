// KYC 3 — ID upload (step 2 of 4). ID-type chips + NIN number + a file
// dropzone wired to the real presigned-upload flow (registry.json
// "KycDocument": POST /kyc-documents/upload-url -> presigned S3 PUT ->
// stash the objectKey; see lib/data/repositories/kyc_document_repository.dart
// for the full contract + the kycSubmissionId-timing note). Mirrors IdUpload.
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

// A Nigerian NIN is exactly 11 numeric digits — same shape as the BVN
// validated on the previous step (bvn.dart's `_bvnPattern`). `nin` is a
// required, always-sent field on `POST /kyc-submissions`
// (Kudimata-Securities-Backend src/kyc-submissions/dto/submit-kyc.dto.ts:
// `@IsNotEmpty() nin`) regardless of which ID document type the investor
// chooses to upload here — so this screen collects it unconditionally, not
// only when `documentType == 'nin'`.
final RegExp _ninPattern = RegExp(r'^\d{11}$');

class IdUploadScreen extends StatefulWidget {
  const IdUploadScreen({super.key});

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  static const _types = [
    _IdType('nin', 'NIN'),
    _IdType('passport', 'Passport'),
    _IdType('licence', "Driver's licence"),
  ];

  String _type = 'nin';
  final _nin = TextEditingController();

  KFileInfo? _file;
  String? _objectKey;
  bool _uploading = false;
  String? _uploadError;
  bool _showErrors = false;

  late final _repo = KycDocumentRepository(AppScope.read(context).apiClient);

  // id_upload.dart's local chip ids are 'nin' | 'passport' | 'licence';
  // KycSubmission.documentType (and KycDocument.documentKind) is
  // enum(nin,passport,drivers_licence,...) — map 'licence' accordingly
  // (see kyc_form_state.dart's header comment).
  String get _documentKind => _type == 'licence' ? 'drivers_licence' : _type;

  @override
  void dispose() {
    _nin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(onBack: () => context.go(Routes.kycBvn)),
            const KycStepProgress(current: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Upload your ID'),
                    const SizedBox(height: 20),
                    const KEyebrow('ID type'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in _types)
                          KPillChip(
                            label: t.label,
                            selected: _type == t.id,
                            onTap: () => setState(() => _type = t.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    KInput(
                      label: 'NIN',
                      numeric: true,
                      placeholder: '00000000000',
                      helper: 'Your 11-digit National Identification Number.',
                      error: _showErrors && !_ninPattern.hasMatch(_nin.text.trim())
                          ? 'Enter a valid 11-digit NIN'
                          : null,
                      controller: _nin,
                      onChanged: (_) {
                        if (_showErrors) setState(() {});
                      },
                    ),
                    const SizedBox(height: 24),
                    KFileUpload(
                      label: 'Upload your ID',
                      hint: 'JPG or PDF, up to 10MB',
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
                                _objectKey = null;
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

  // ID type chip picker + file dropzone (was a mock file picker that always
  // "picked" a fake 'id-document.jpg' — see git history) now do the real
  // presigned-upload flow:
  //   1. POST /kyc-documents/upload-url {documentKind, documentName}
  //      -> {uploadUrl, objectKey}                      (KycDocumentRepository)
  //   2. PUT the picked file's bytes to `uploadUrl` directly — a bare
  //      `package:http` client, NOT the shared ApiClient/Dio instance, since
  //      that instance's interceptor would attach this app's own
  //      Authorization header to the S3 request (see
  //      kyc_document_repository.dart's file header).
  // The resulting objectKey is stashed via
  // `KycFormState.registerUploadedDocument` (NOT `POST /kyc-documents`
  // itself — no KycSubmission exists yet at this point in the flow; see that
  // repository's file header for the full kycSubmissionId-timing note).
  Future<void> _pickAndUpload() async {
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
      if (!mounted) return;
      AppScope.read(context).kycForm.registerUploadedDocument(uploadUrl.objectKey, documentKind);
      setState(() {
        _file = KFileInfo(name: picked.name, size: picked.size);
        _objectKey = uploadUrl.objectKey;
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

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  void _continue() {
    final validNin = _ninPattern.hasMatch(_nin.text.trim());
    if (!validNin || _file == null || _objectKey == null) {
      setState(() => _showErrors = true);
      return;
    }
    final kycForm = AppScope.read(context).kycForm;
    kycForm.setNin(_nin.text.trim());
    kycForm.setDocumentType(_documentKind);
    context.go(Routes.kycLiveness);
  }
}
