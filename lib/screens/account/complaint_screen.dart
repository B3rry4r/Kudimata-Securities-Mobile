// Screen 87 — "File a complaint" (2026-08-23 "Soft Landing" canvas exactness
// pass, s87.html). Reached from Help & support's "File a complaint" button
// (previously a bare `mailto:` hand-off — see help_support_screen.dart's
// `_fileComplaint`) or from any failure state elsewhere in the app.
//
// REAL BACKEND GAP, flagged rather than faked: no complaint/ticketing
// resource exists anywhere in this app's backend contract — confirmed
// against Kudimata-Securities-Backend/.pipeline/registry.json (no
// "complaint" or "ticket" match) and its account-help.json fragment (no
// reads/actions declared for this screen family at all). The canvas wires
// "Send complaint" straight to screen 88 (a tracked-complaint view) with a
// generated reference like "CMP-2026-0184", but manufacturing that reference
// and navigating on as if the complaint had actually been filed would be
// exactly the "faking success" this app's convention explicitly avoids
// (withdraw_mandate_screen.dart, plans_screen.dart). So this screen builds
// the full, real form — category picker, reference/description inputs, a
// real local file picker for the optional attachment — and on submit tells
// the investor honestly that filing isn't wired to a backend yet, the same
// pattern as those two screens, rather than pretending a complaint was
// registered.
//
// What a real complaint/ticketing resource would need (for whoever wires the
// backend): POST /complaints {category, reference?, description,
// attachmentObjectKey?} -> Complaint {id, reference, status, filedAt,
// answerDueAt, ...}; GET /complaints/:id or GET /complaints/:id/timeline for
// screen 88's status + step history; and a category taxonomy (this screen's
// `_kComplaintTopics`, mirrored from help_support_screen.dart's own FAQ
// headlines: order/trade, money movement, verification, fees, other).
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  bool _showErrors = false;

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

  /// Real local file selection (file_picker, same package
  /// utility_bill.dart/id_upload.dart already use) — no fake preview. There
  /// is simply nowhere to upload it to yet (see file header), so unlike
  /// those KYC screens this never calls a repository; it just holds the
  /// picked file for display, matching this screen's honest-form-no-fake-
  /// submission stance end to end.
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    setState(() => _attachment = KFileInfo(name: picked.name, size: picked.size));
  }

  bool get _canSend => _descriptionController.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) {
      setState(() => _showErrors = true);
      return;
    }
    // Honest gap, not a fake success — see file header.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Filing a complaint isn't available yet — email us instead and we'll log it by hand.",
        ),
      ),
    );
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
            prompt: 'Screenshot, statement or note',
            hint: 'PDF, PNG or JPG · up to 10 MB',
            file: _attachment,
            onPick: _pickAttachment,
            onRemove: () => setState(() => _attachment = null),
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
          KButton(label: 'Send complaint', onPressed: _send),
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
