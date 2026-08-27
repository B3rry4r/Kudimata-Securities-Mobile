// KYC — Address + utility bill upload, part of the merged "Documents" step
// (step 3 of 7 — shares this number with id_upload.dart's ID half;
// renumbered from 5 of 8 on 2026-08-27 per X-2/bvn_nin.dart's derivation).
// Artboard s17/s17d
// ("Where do you live?", 02 Verification.dc.html) — RULING R-19
// (docs/redesign/DECISIONS.md): "BVN/NIN auto-populate is adopted, AND an
// address step is kept... s17 already pairs address fields with the
// utility-bill upload — build that." So this screen, previously
// upload-only, now also collects the street address / State / LGA the
// canvas draws alongside the file dropzone, on the SAME screen (not a
// separate step).
//
// documentKind 'proof_of_address' already existed in the backend schema
// (2026-08-20 phased-KYC directive: "we need to collect Utility bill") —
// unchanged upload wiring below. What's new is the three address fields.
//
// Where the address goes: there is no KYC-side "address" write at this
// step — KycRepository.finalizeDraft (step 8, next_of_kin/review_submit,
// another agent's screen) accepts address/city/state but isn't called
// until much later, and staging these into KycFormState so that screen can
// send them would mean editing lib/screens/kyc/kyc_form_state.dart, which
// every other KYC screen also reads/writes — a genuinely shared file, so
// per SCREEN-AGENT-BRIEF.md rule 5/6 that's a cross-screen change, not
// mine to make unilaterally. Filed as X-3 in SHARED-CHANGES.md.
//
// Instead this screen writes straight to the ALREADY-REAL, already-wired
// PATCH /users/me (UserRepository.updateProfile — the same call
// onboarding/personal_details_screen.dart makes for its own
// residentialAddress/city/state fields), so nothing here is a dead
// control: Street address -> residentialAddress, State -> state. LGA has
// no dedicated backend field anywhere (grepped registry.json's User and
// KycSubmission types — neither has one), so it's sent via updateProfile's
// `city` param: this app's OWN existing city field already uses an LGA
// name as its example value (personal_details_screen.dart's city
// placeholder is literally "Ikeja", a Lagos LGA), so this reuses the
// closest existing real field rather than inventing one or discarding the
// input. Recorded here for a human to override if that mapping is wrong.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_document_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_address_data.dart';
import '_kyc_chrome.dart';

class UtilityBillScreen extends StatefulWidget {
  const UtilityBillScreen({super.key});

  @override
  State<UtilityBillScreen> createState() => _UtilityBillScreenState();
}

class _UtilityBillScreenState extends State<UtilityBillScreen> {
  final _street = TextEditingController();
  String? _state;
  String? _lga;

  KFileInfo? _file;
  bool _uploading = false;
  String? _uploadError;

  bool _saving = false;
  bool _showErrors = false;

  late final _docRepo = KycDocumentRepository(AppScope.read(context).apiClient);
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);

  @override
  void dispose() {
    _street.dispose();
    super.dispose();
  }

  Future<void> _pickState() async {
    final picked = await showAddressStatePicker(context, selected: _state);
    if (picked == null) return;
    setState(() {
      _state = picked;
      // A new state invalidates any LGA already chosen under the old one.
      if (_lga != null && !(kLgasByState[picked] ?? const []).contains(_lga)) {
        _lga = null;
      }
    });
  }

  Future<void> _pickLga() async {
    if (_state == null) return;
    final picked = await showAddressLgaPicker(context, state: _state!, selected: _lga);
    if (picked == null) return;
    setState(() => _lga = picked);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(
              onBack: () => context.go(Routes.kycLiveness),
              stepLabel: 'Verification · 3 of 7',
            ),
            const KycStepProgress(total: 7, current: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(
                      title: 'Where do you live?',
                      body: 'A recent utility bill confirms it, any bill under 3 months old.',
                    ),
                    const SizedBox(height: 20),
                    KInput(
                      label: 'Street address',
                      placeholder: '12 Awolowo Road',
                      controller: _street,
                      onChanged: _showErrors ? (_) => setState(() {}) : null,
                      error: _showErrors && _street.text.trim().isEmpty
                          ? 'Enter your street address'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _AddrSelectField(
                            label: 'State',
                            value: _state,
                            placeholder: 'Select',
                            onTap: _pickState,
                            error: _showErrors && _state == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AddrSelectField(
                            label: 'LGA',
                            value: _lga,
                            placeholder: _state == null ? 'Pick a state first' : 'Select',
                            disabled: _state == null,
                            onTap: _pickLga,
                            error: _showErrors && _state != null && _lga == null
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    KFileUpload(
                      label: 'Utility bill',
                      hint: 'JPG or PDF, up to 10MB',
                      prompt: _uploading ? 'Uploading…' : 'Tap to upload, or take a photo',
                      helper: _uploading ? 'Uploading your document…' : null,
                      error: _uploadError ??
                          (_showErrors && _file == null
                              ? 'Upload a utility bill to continue'
                              : null),
                      disabled: _uploading || busy,
                      file: _file,
                      onPick: (_uploading || busy) ? null : _pickAndUpload,
                      onRemove: (_uploading || busy)
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
                label: 'Save & continue',
                loading: _saving,
                onPressed: (_uploading || _saving) ? null : _continue,
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
      final uploadUrl = await _docRepo.requestUploadUrl(
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
      await _docRepo.registerDocument(
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

  Future<void> _continue() async {
    final valid =
        _street.text.trim().isNotEmpty && _state != null && _lga != null && _file != null;
    if (!valid) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _saving = true);
    try {
      // See file header: LGA has no backend field of its own, so it rides
      // along in `city` — the closest existing real field.
      await _userRepo.updateProfile(
        residentialAddress: _street.text.trim(),
        state: _state,
        city: _lga,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSaveErrorSheet(message: e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSaveErrorSheet(message: 'Something went wrong. Please try again.');
      return;
    }
    if (!mounted) return;
    context.go(Routes.kycBankDcs);
  }

  void _showSaveErrorSheet({required String message}) {
    showKSheet<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: KStatusView(
          tone: KStatusTone.error,
          title: "Couldn't save your address",
          message: message,
          primary: 'Try again',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// A tappable "select"-styled field — same visual shape as
/// onboarding/personal_details_screen.dart's own `_TappableField`, mirrored
/// here (not imported) per this codebase's per-screen small-widget
/// convention of duplicating rather than sharing.
class _AddrSelectField extends StatelessWidget {
  const _AddrSelectField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.disabled = false,
    this.error,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final bool disabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final borderColor = error != null ? KColor.loss : KColor.hairline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.upper, style: KType.label(color: disabled ? KColor.ink3 : KColor.ink2)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: disabled ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: disabled ? KColor.bg : KColor.paper,
              borderRadius: BorderRadius.circular(KRadii.input),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KType.body(
                        color: value != null ? KColor.ink : KColor.ink3,
                        w: KWeight.medium),
                  ),
                ),
                const SizedBox(width: 6),
                KIcon('arrowDown', size: 16, color: KColor.ink3),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 7),
          Text(error!, style: KType.micro(color: KColor.loss).copyWith(letterSpacing: 0.02 * 10)),
        ],
      ],
    );
  }
}
