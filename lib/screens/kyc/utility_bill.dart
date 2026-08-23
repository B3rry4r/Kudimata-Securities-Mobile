// KYC 6 — utility bill upload (step 4 of 5). NEW screen (2026-08-20,
// phased-KYC directive: "we need to collect Utility bill") — documentKind
// 'proof_of_address' already existed in the backend schema, it just was
// never collected anywhere in the KYC flow's UI until now. Mirrors
// id_upload.dart's file-dropzone pattern (no ID-type chips needed — there's
// only one kind of document here).
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

class UtilityBillScreen extends StatefulWidget {
  const UtilityBillScreen({super.key});

  @override
  State<UtilityBillScreen> createState() => _UtilityBillScreenState();
}

class _UtilityBillScreenState extends State<UtilityBillScreen> {
  KFileInfo? _file;
  bool _uploading = false;
  String? _uploadError;
  bool _showErrors = false;

  late final _repo = KycDocumentRepository(AppScope.read(context).apiClient);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(onBack: () => context.go(Routes.kycLiveness)),
            const KycStepProgress(total: 5, current: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Upload a utility bill',
                      body: 'Dated in the last three months and showing the address you gave us.',
                    ),
                    const SizedBox(height: 20),
                    KFileUpload(
                      label: 'Proof of address',
                      hint: 'JPG or PDF · up to 10 MB',
                      prompt: _uploading ? 'Uploading…' : 'Tap to upload, or take a photo',
                      helper: _uploading ? 'Uploading your document…' : null,
                      error: _uploadError ??
                          (_showErrors && _file == null
                              ? 'Upload a utility bill to continue'
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
                    const SizedBox(height: 20),
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const KEyebrow('We accept'),
                          const SizedBox(height: 8),
                          Text(
                            'PHCN or IBEDC bill · water bill · waste bill · bank statement with your address · tenancy agreement',
                            style: KType.body(color: KColor.ink2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const KNudgeCard(
                      title: "Bill not in your name?",
                      body:
                          'Upload it anyway and add a short note in the next step — our desk reviews these by hand.',
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

    try {
      final uploadUrl = await _repo.requestUploadUrl(
        documentKind: 'proof_of_address',
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
        documentName: 'Proof of address',
        documentKind: 'proof_of_address',
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
    context.go(Routes.kycNextOfKin);
  }
}
