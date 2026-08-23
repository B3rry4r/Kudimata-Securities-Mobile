// Screen 87 — "File a complaint" (2026-08-23 "Soft Landing" canvas exactness
// pass, s87.html; wired to a real backend 2026-08-24). Reached from Help &
// support's "File a complaint" button (previously a bare `mailto:` hand-off
// — see help_support_screen.dart's `_fileComplaint`) or from any failure
// state elsewhere in the app.
//
// REAL BACKEND, wired: Kudimata-Securities-Backend now has a Complaint
// resource (src/complaints/*, src/common/types/complaint.types.ts) —
// POST /complaints/upload-url for the optional attachment, POST /complaints
// to file. See lib/data/repositories/complaint_repository.dart for the
// exact request/response shapes. "Send complaint" files for real and
// navigates to screen 88 (ComplaintTrackedScreen) with the backend's own
// returned Complaint — no more manufactured reference, no more honest-gap
// snackbar.
//
// Category taxonomy (`_kComplaintTopics`) is still a client-side picker
// convenience, not a server enum — FileComplaintDto validates `category` as
// a non-empty string, mirrored from help_support_screen.dart's own FAQ
// headlines: order/trade, money movement, verification, fees, other.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/complaint_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

/// Complaint categories for the "What is this about?" field. No backend
/// taxonomy exists (see file header) — this mirrors the four real question
/// families help_support_screen.dart's FAQ list already surfaces (order
/// filling, money arriving, verification, fees), plus a catch-all, rather
/// than inventing an unrelated list.
const List<String> _kComplaintTopics = [
  'An order or trade',
  'Money into or out of my account',
  'My verification (KYC)',
  'Fees',
  'Something else',
];

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  String _topic = _kComplaintTopics.first; // canvas default: "An order or trade"
  final _referenceController = TextEditingController();
  final _descriptionController = TextEditingController();
  KFileInfo? _attachment;
  String? _attachmentObjectKey;
  bool _uploading = false;
  String? _attachmentError;
  bool _sending = false;
  bool _showErrors = false;

  late final _repo = ComplaintRepository(AppScope.read(context).apiClient);

  @override
  void dispose() {
    _referenceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTopic() async {
    final picked = await showKSheet<String>(
      context,
      title: 'What is this about?',
      child: _ComplaintTopicSheet(selected: _topic),
    );
    if (picked != null) setState(() => _topic = picked);
  }

  /// Real local file selection (file_picker) followed by the real
  /// presigned-upload flow — mirrors id_upload.dart/utility_bill.dart's
  /// pattern exactly: request a presigned URL, PUT the bytes straight to
  /// it, then keep the returned object key to send along with the
  /// complaint on submit (see ComplaintRepository's file header for why
  /// there's no separate "register document" step here, unlike KYC).
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      setState(() => _attachmentError = "Couldn't read that file. Please try again.");
      return;
    }

    setState(() {
      _uploading = true;
      _attachmentError = null;
    });

    final contentType = _contentTypeFor(picked.name);
    try {
      final upload = await _repo.uploadUrl(fileName: picked.name, contentType: contentType);
      await _repo.putFile(upload.uploadUrl, bytes, contentType: contentType);
      if (!mounted) return;
      setState(() {
        _attachment = KFileInfo(name: picked.name, size: picked.size);
        _attachmentObjectKey = upload.objectKey;
        _uploading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _attachmentError = e.message;
      });
    }
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Future<void> _send() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    if (_uploading || _sending) return;

    setState(() => _sending = true);
    try {
      final complaint = await _repo.file(
        category: _topic,
        orderOrTxnRef: _referenceController.text.trim(),
        description: _descriptionController.text.trim(),
        attachmentObjectKey: _attachmentObjectKey,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      context.push(Routes.acctComplaintTracked, extra: complaint);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _showEscalationInfo() {
    // Canvas's "How escalation works" link points at screen 88, but that
    // screen renders one specific, already-filed complaint's status — there
    // is no real complaint here to show yet (see file header). Surfacing
    // the same escalation sentence screen 88 itself carries keeps the
    // promised information honest without faking a tracked-complaint view.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The SEC refers complaints to its Administrative Proceedings '
          'Committee, and its decision can be appealed to the Investments '
          'and Securities Tribunal.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'File a complaint',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We log every complaint in a register, answer within 10 business '
            'days, and report the register to the SEC quarterly.',
            style: KType.data(color: KColor.ink2),
          ),
          const SizedBox(height: 12),
          _TappableField(
            label: 'What is this about?',
            value: _topic,
            placeholder: 'Choose a category',
            onTap: _pickTopic,
          ),
          const SizedBox(height: 12),
          KInput(
            label: 'Reference, if you have one',
            placeholder: 'e.g. KDM-CN-4471',
            controller: _referenceController,
          ),
          const SizedBox(height: 12),
          KInput(
            label: 'What happened?',
            placeholder: 'In your own words',
            controller: _descriptionController,
            multiline: true,
            onChanged: _showErrors ? (_) => setState(() {}) : null,
            error: _showErrors && _descriptionController.text.trim().isEmpty
                ? 'Tell us what happened'
                : null,
          ),
          const SizedBox(height: 12),
          KFileUpload(
            label: 'Anything to attach',
            prompt: _uploading ? 'Uploading…' : 'Screenshot, statement or note',
            hint: 'PDF, PNG or JPG · up to 10 MB',
            helper: _uploading ? 'Uploading your attachment…' : null,
            error: _attachmentError,
            disabled: _uploading,
            file: _attachment,
            onPick: _uploading ? null : _pickAttachment,
            onRemove: _uploading
                ? null
                : () => setState(() {
                      _attachment = null;
                      _attachmentObjectKey = null;
                      _attachmentError = null;
                    }),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showEscalationInfo,
            behavior: HitTestBehavior.opaque,
            child: Text.rich(
              TextSpan(
                style: KType.data(color: KColor.ink3),
                children: [
                  const TextSpan(
                    text: "If we can't resolve it, you can escalate to the SEC, "
                        'and from there to the Investments and Securities '
                        'Tribunal. ',
                  ),
                  TextSpan(
                    text: 'How escalation works.',
                    style: KType.data(color: KColor.ink3, w: KWeight.semibold)
                        .copyWith(decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          KButton(
            label: 'Send complaint',
            loading: _sending,
            onPressed: _uploading || _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

/// Same tappable-field styling as onboarding/personal_details_screen.dart's
/// file-local `_TappableField` — duplicated rather than shared (lib/widgets/
/// components are extended with props, not forked; this is a one-off
/// pick-from-a-sheet field the same shape as that existing pattern, not a
/// new capability KInput itself needs).
class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.upper, style: KType.label(color: KColor.ink2)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
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
                    value ?? placeholder,
                    style: KType.body(color: value != null ? KColor.ink : KColor.ink3),
                  ),
                ),
                const SizedBox(width: 10),
                KIcon('arrowDown', size: 16, color: KColor.ink3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The "What is this about?" picker sheet — five known categories, no search
/// (short enough not to need one, unlike _pickers.dart's 186-country list).
/// Row styling mirrors _pickers.dart's `_PickerRow` exactly.
class _ComplaintTopicSheet extends StatelessWidget {
  const _ComplaintTopicSheet({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < _kComplaintTopics.length; i++)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(_kComplaintTopics[i]),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: KColor.hairline, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(_kComplaintTopics[i], style: KType.cardTitle())),
                    if (_kComplaintTopics[i] == selected) const KIcon('check', size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
