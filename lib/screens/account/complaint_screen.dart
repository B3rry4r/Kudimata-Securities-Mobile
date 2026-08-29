// Account → Complaints — artboard `s53` ("06 Account and Support.dc.html").
//
// R-5: this file used to cite the OLD 97-screen canvas's "Screen 87", an id
// that now points at an unrelated screen in the current 56-artboard canvas.
// Re-pointed to `s53` per RULINGS.md (docs/redesign/evidence/account.json).
//
// s53 draws a "Complaints" HUB: a "Something went wrong?" headline, four
// plain-language category rows (Money missing or delayed / A trade went
// wrong / How I was treated / Something else), an inline "Your open
// complaint" SLA card, and a footer note + "File a complaint" button. It
// does NOT draw the actual filing FORM (topic field, reference input,
// description box, attachment upload) as its own artboard state —
// RULINGS.md's evidence for this screen says so explicitly. The form is
// real, backend-wired functionality the artboard simply doesn't depict
// (the "artboard depicts one moment" principle in SCREEN-AGENT-BRIEF.md),
// so it is kept, not dropped — as a pushed sub-screen (`ComplaintFormScreen`)
// reached by tapping a category row or the footer button.
//
// The 4 category rows map onto 5 of the app's real 6 topics one-for-one
// except "How I was treated", which s53 draws but the old topic list had no
// equivalent for — added. "My verification (KYC)" and "Fees" are real
// topics the code path already served (help_support_screen.dart's own FAQ
// headlines) that s53 doesn't draw as their own row — kept per the mirror of
// R-34 (the code path serves more situations than one artboard depicts) and
// still reachable from the form's own topic picker.
//
// REAL BACKEND: GET /complaints (own-records-only, paginated) backs "Your
// open complaint"; POST /complaints/upload-url + POST /complaints back the
// filing form — see complaint_repository.dart's header. The "answer within
// 10 business days" claim is a real, backend-computed SLA
// (Complaint.answerDueAt, `ANSWER_SLA_BUSINESS_DAYS = 10` in
// Kudimata-Securities-Backend's complaints.service.ts, whose own comment
// calls this "the real, published SLA"), not invented copy.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/paginated_response.dart';
import 'package:kudimata_invest/data/repositories/complaint_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

/// The four categories s53 draws, plus the icon/tint pairing it draws them
/// with — (icon, warm-tinted?, title, sub, the real topic it opens the form
/// on). `warm` true only for the first row (canvas's own `--warm-tint`
/// background; every other row and every icon glyph colour is
/// `--indicator`/`--indicator-tint`, in both light and dark).
const List<(String icon, bool warm, String title, String sub, String topic)> _kCategories = [
  ('alert', true, 'Money missing or delayed', 'Deposits, withdrawals, dividends',
      'Money into or out of my account'),
  ('markets', false, 'A trade went wrong', 'Wrong price, wrong shares, failed order',
      'An order or trade'),
  // Canvas glyph is 'users' — not in this app's fixed icon set (KIcon.has
  // would fall back silently); 'profile' is the closest real glyph for a
  // "how staff treated me" category.
  ('profile', false, 'How I was treated', 'Staff, adviser or agent', 'How I was treated'),
  ('settings', false, 'Something else', 'Anything not listed', 'Something else'),
];

/// Full topic list for the filing form's picker — s53's 4 categories (in the
/// canvas's own order) plus the 2 real categories the code path already
/// served that s53 doesn't draw a row for (verification, fees). See file
/// header.
const List<String> _kComplaintTopics = [
  'Money into or out of my account',
  'An order or trade',
  'How I was treated',
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
  late final _repo = ComplaintRepository(AppScope.read(context).apiClient);
  late Future<PaginatedResponse<Complaint>> _future = _repo.list();

  void _openForm({String? topic}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ComplaintFormScreen(initialTopic: topic)),
    );
  }

  void _openTracked(Complaint complaint) {
    context.push(Routes.acctComplaintTracked, extra: complaint);
  }

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Complaints',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'If we miss the 10 working days, you can take it to the SEC. '
            'We will show you how.',
            style: KType.data(color: KColor.ink3),
          ),
          const SizedBox(height: 10),
          KButton(label: 'File a complaint', onPressed: () => _openForm()),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Something went wrong?', style: KType.title()),
          const SizedBox(height: 6),
          Text('Tell us and we answer within 10 working days.',
              style: KType.body(color: KColor.ink2)),
          const SizedBox(height: 18),
          for (final cat in _kCategories) ...[
            _ComplaintCategoryRow(
              icon: cat.$1,
              warm: cat.$2,
              title: cat.$3,
              sub: cat.$4,
              onTap: () => _openForm(topic: cat.$5),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FutureBuilder<PaginatedResponse<Complaint>>(
            future: _future,
            builder: (context, snapshot) {
              // LOADING: initial GET /complaints in flight.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: KLoadingView(),
                );
              }
              // ERROR: the fetch failed — kept local to this section so a
              // failure here never blocks the (fully static) categories or
              // the "File a complaint" footer button above/below it.
              if (snapshot.hasError) {
                return _InlineSectionError(onRetry: () => setState(() => _future = _repo.list()));
              }
              final open = snapshot.data!.data
                  .where((c) => c.status != ComplaintStatus.resolved)
                  .toList()
                ..sort((a, b) => b.filedAt.compareTo(a.filedAt));
              // EMPTY: no complaint filed yet, or every one filed is
              // resolved — nothing to show, so the section simply doesn't
              // render (matches s53's own singular "Your open complaint"
              // framing; there's nothing open to name).
              if (open.isEmpty) return const SizedBox.shrink();
              final complaint = open.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your open complaint', style: KType.section()),
                  const SizedBox(height: 10),
                  _OpenComplaintCard(complaint: complaint, onTap: () => _openTracked(complaint)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InlineSectionError extends StatelessWidget {
  const _InlineSectionError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KColor.paper,
        border: Border.all(color: KColor.hairline, width: 1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text("Couldn't load your open complaint.",
                style: KType.body(color: KColor.ink2)),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Text('Retry',
                style: KType.body(color: KColor.indicator, w: KWeight.semibold)),
          ),
        ],
      ),
    );
  }
}

/// One of s53's four bordered category cards — icon bubble, title+sub,
/// trailing chevron. Screen-local; not a fork of `KAccountRow` (different
/// shape: an individually-bordered card, not a row inside one grouped
/// `KAccountCard`).
class _ComplaintCategoryRow extends StatelessWidget {
  const _ComplaintCategoryRow({
    required this.icon,
    required this.warm,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final String icon;
  final bool warm;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(color: KColor.hairline, width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: warm ? KColor.warmTint : KColor.indicatorTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: KIcon(icon, size: 18, color: KColor.indicator),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: KType.cardTitle()),
                  const SizedBox(height: 1),
                  Text(sub, style: KType.micro(color: KColor.ink3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            KIcon('chevronRight', size: 17, color: KColor.ink3),
          ],
        ),
      ),
    );
  }
}

/// s53's inline "Your open complaint" card — title, a "Day N of 10" SLA
/// pill, a progress bar, and the raised/reference/reply-by line. All 4
/// figures (category, filed date, reference, due date) are real fields off
/// [Complaint]; nothing here is invented (R-34).
class _OpenComplaintCard extends StatelessWidget {
  const _OpenComplaintCard({required this.complaint, required this.onTap});
  final Complaint complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (dayLabel, progress) = slaProgress(complaint);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(color: KColor.hairline, width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(complaint.category, style: KType.cardTitle())),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration:
                      BoxDecoration(color: KColor.warmTint, borderRadius: BorderRadius.circular(999)),
                  child: Text(dayLabel, style: KType.micro(color: KColor.warmPress)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: KColor.track),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(color: KColor.warmPress),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Raised ${formatComplaintDate(complaint.filedAt)} · reference ${complaint.reference}. '
              'We reply by ${formatComplaintDate(complaint.answerDueAt)}.',
              style: KType.data(color: KColor.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> kComplaintMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatComplaintDate(DateTime d) => '${d.day} ${kComplaintMonths[d.month - 1]} ${d.year}';

/// "Day N of 10" + 0..1 progress, from the real [Complaint.filedAt] /
/// [Complaint.answerDueAt] window and the current time — never a fabricated
/// figure. Escalated complaints (past the window by definition — escalation
/// only opens up the day after `answerDueAt`, see complaint_tracked_screen.
/// dart) read as "Escalated" at full progress rather than an overflowing day
/// count.
(String, double) slaProgress(Complaint c) {
  if (c.status == ComplaintStatus.escalated) return ('Escalated', 1.0);
  final windowDays = c.answerDueAt.difference(c.filedAt).inDays;
  final safeWindow = windowDays > 0 ? windowDays : 10;
  final elapsed = DateTime.now().difference(c.filedAt).inDays + 1;
  final day = elapsed.clamp(1, safeWindow);
  return ('Day $day of $safeWindow', day / safeWindow);
}

/// The real filing form — topic (from [_kComplaintTopics]), an optional
/// order/transaction reference, a free-text description, an optional
/// attachment, the SEC-escalation explainer, and Send. Undrawn by s53 (see
/// file header) but real and backend-wired, so it's kept as a pushed
/// sub-screen rather than dropped.
///
/// Public (not `_ComplaintFormScreen`) because complaint_tracked_screen.dart
/// also opens it directly, pre-filled, for its "File a related complaint"
/// button — see that file for why: appending to an already-filed complaint
/// has no backend endpoint, and the button used to be labelled "Add more
/// information" while silently opening the bare hub instead, the exact
/// "control repointed at different behaviour" defect this project has been
/// finding and fixing elsewhere. Landing here with the topic and reference
/// pre-filled is the honest version of that same real action.
class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key, this.initialTopic, this.initialReference});
  final String? initialTopic;
  final String? initialReference;

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  late String _topic = widget.initialTopic ?? _kComplaintTopics.first;
  late final _referenceController = TextEditingController(text: widget.initialReference ?? '');
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
  /// complaint on submit.
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    }
  }

  void _showEscalationInfo() {
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

/// The "What is this about?" picker sheet. Row styling mirrors
/// _pickers.dart's `_PickerRow` exactly.
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
