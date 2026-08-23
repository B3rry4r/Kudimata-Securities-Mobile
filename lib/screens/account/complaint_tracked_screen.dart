// Screen 88 — "Complaint · tracked" (2026-08-23 "Soft Landing" canvas
// exactness pass, s88.html; wired to a real backend 2026-08-24). Per the
// canvas footer note this is reached "from 87 or an email link" — i.e.
// after a complaint has actually been filed and the backend hands back a
// reference to track.
//
// REAL BACKEND, wired: takes the SAME `Complaint` model
// complaint_repository.dart declares (the repository's own return type from
// `file()`/`get()`) rather than a parallel view model — complaint_screen.dart
// now navigates here with the exact object `ComplaintRepository.file()`
// returns. This screen derives its display-only bits (register timeline
// steps, status pill tone) from that real model in [_timelineSteps] /
// [_statusSpec] below, rather than requiring a separate summary type.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/data/repositories/complaint_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';
import 'complaint_screen.dart';

/// Backward-compatible alias for `app_router.dart`'s existing route wiring
/// (`Routes.acctComplaintTracked`'s `GoRoute` checks `st.extra is!
/// ComplaintSummary` before constructing this screen — see that file). This
/// screen used to define its own parallel `ComplaintSummary` view model;
/// now that it renders the real `Complaint` wire model directly (see file
/// header), this typedef is a pure alias — NOT a new type — so that
/// existing `is! ComplaintSummary` check keeps compiling and now correctly
/// matches the real `Complaint` objects `complaint_screen.dart` navigates
/// here with, without editing routes.dart/app_router.dart (out of scope for
/// this pass — see complaint_screen.dart's file header). Purely cosmetic to
/// rename that check to `is! Complaint` directly next time those files are
/// touched centrally; behavior is identical either way.
typedef ComplaintSummary = Complaint;

/// One row in the register timeline this screen renders. Not part of the
/// wire model — computed from [Complaint.timeline]/[Complaint.status] by
/// [ComplaintTrackedScreen._timelineSteps]; `state` drives the medallion
/// tint/icon colour and title colour, see `_ComplaintStepRow`.
enum _ComplaintStepState { done, active, upcoming }

class _ComplaintTimelineStep {
  const _ComplaintTimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String icon;
  final String title;
  final String subtitle;
  final _ComplaintStepState state;
}

const String _kEscalationNote =
    'The SEC refers complaints to its Administrative Proceedings '
    'Committee, and its decision can be appealed to the Investments '
    'and Securities Tribunal.';

class ComplaintTrackedScreen extends StatelessWidget {
  const ComplaintTrackedScreen({super.key, required this.complaint});
  final Complaint complaint;

  /// (status pill tone, its default label) for [complaint.status] — backend
  /// enum `logged | reviewing | escalated | resolved` mapped onto the
  /// existing `KStatus` workflow-state vocabulary (feedback.dart) rather
  /// than adding a 5th, complaint-specific status widget.
  (KStatus, String) get _statusSpec => switch (complaint.status) {
        ComplaintStatus.logged => (KStatus.pending, 'Logged'),
        ComplaintStatus.reviewing => (KStatus.review, 'Under review'),
        ComplaintStatus.escalated => (KStatus.flagged, 'Escalated'),
        ComplaintStatus.resolved => (KStatus.approved, 'Resolved'),
      };

  /// Register timeline: one "done" row per real entry in
  /// [Complaint.timeline] (backend's append-only log — today that's just
  /// "Complaint logged" at filing time, since staff-side status-transition/
  /// timeline-append endpoints are out of scope for this backend pass), plus
  /// one forward-looking "active" row narrating where things stand now when
  /// the complaint hasn't reached a terminal state — no fabricated
  /// timestamps for steps that haven't happened yet.
  ///
  /// 2026-08-24: canvas s88 always shows the FULL 3-stage roadmap (logged →
  /// under review → escalate to the SEC), with the not-yet-reached stage
  /// rendered inactive/greyed rather than omitted — that third stage was
  /// missing entirely here for a non-escalated complaint. Its date isn't
  /// fabricated: escalation becomes available the day after the real
  /// `answerDueAt` SLA date, matching canvas's own worked example exactly
  /// (due 30 Mar -> "Available from 31 Mar").
  List<_ComplaintTimelineStep> _timelineSteps() {
    final entries = complaint.timeline ?? const <ComplaintTimelineEntry>[];
    final steps = [
      for (final e in entries)
        _ComplaintTimelineStep(
          icon: _iconFor(e.label),
          title: e.label,
          subtitle: _formatDate(e.at),
          state: _ComplaintStepState.done,
        ),
    ];
    if (complaint.status != ComplaintStatus.resolved) {
      steps.add(
        _ComplaintTimelineStep(
          icon: complaint.status == ComplaintStatus.escalated ? 'alert' : 'clock',
          title: complaint.status == ComplaintStatus.escalated
              ? 'Escalated to the SEC'
              : 'Under review',
          subtitle: 'Answer due by ${_formatDay(complaint.answerDueAt)}',
          state: _ComplaintStepState.active,
        ),
      );
    }
    if (complaint.status != ComplaintStatus.escalated &&
        complaint.status != ComplaintStatus.resolved) {
      final escalatesFrom = complaint.answerDueAt.add(const Duration(days: 1));
      steps.add(
        _ComplaintTimelineStep(
          icon: 'shield',
          title: 'Escalate to the SEC',
          subtitle: 'Available from ${_formatDay(escalatesFrom)} if unresolved',
          state: _ComplaintStepState.upcoming,
        ),
      );
    }
    return steps;
  }

  String _iconFor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('review')) return 'clock';
    if (lower.contains('escalat')) return 'alert';
    if (lower.contains('resolv')) return 'check';
    return 'check';
  }

  @override
  Widget build(BuildContext context) {
    final filed = _formatDate(complaint.filedAt);
    final dueDay = _formatDay(complaint.answerDueAt);
    final (status, defaultLabel) = _statusSpec;
    final steps = _timelineSteps();
    return KAccountSubScaffold(
      title: complaint.reference,
      headerTrailing: KStatusPill(status: status, label: defaultLabel, small: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(complaint.category, style: KType.cardTitle()),
                const SizedBox(height: 8),
                Text(
                  'Filed $filed'
                  '${complaint.orderOrTxnRef != null && complaint.orderOrTxnRef!.isNotEmpty ? ' · about ${complaint.orderOrTxnRef}' : ''}',
                  style: KType.data(color: KColor.ink2),
                ),
                Text(
                  'Answer due by $dueDay · 10 business days',
                  style: KType.data(color: KColor.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _ComplaintStepRow(step: steps[i], last: i == steps.length - 1),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_kEscalationNote, style: KType.data(color: KColor.ink3)),
          const SizedBox(height: 24),
          KButton(
            label: 'Add more information',
            variant: KButtonVariant.secondary,
            // REAL BACKEND GAP, honestly flagged: appending information to
            // an already-filed complaint would need its own investor-facing
            // endpoint (e.g. PATCH /complaints/:id or a
            // /complaints/:id/notes route) — ComplaintsController only ever
            // exposes upload-url/file/findAll/findOne (see
            // complaints.controller.ts), and staff-side timeline-append
            // endpoints are explicitly out of scope for this backend pass
            // (complaints.module.ts's header comment). Pushing a fresh
            // ComplaintScreen is the same honest stand-in this screen used
            // before it had a live entry point — it lets the investor file
            // a new, related complaint today rather than pretending this
            // button appends to the existing one.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ComplaintScreen()),
            ),
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Back to help',
            variant: KButtonVariant.ghost,
            // Routes.acctHelp already exists — context.go (not push) so
            // this lands on Help & support regardless of whether this
            // screen was reached from screen 87 or a standalone email link.
            onPressed: () => context.go(Routes.acctHelp),
          ),
        ],
      ),
    );
  }
}

class _ComplaintStepRow extends StatelessWidget {
  const _ComplaintStepRow({required this.step, required this.last});
  final _ComplaintTimelineStep step;
  final bool last;

  (Color, Color, Color) get _spec => switch (step.state) {
        // (medallion tint, icon colour, title colour)
        _ComplaintStepState.done => (KColor.statusApprovedTint, KColor.gain, KColor.ink),
        _ComplaintStepState.active => (KColor.indicatorTint, KColor.indicator, KColor.ink),
        _ComplaintStepState.upcoming => (KColor.track, KColor.ink2, KColor.ink2),
      };

  @override
  Widget build(BuildContext context) {
    final (tint, iconColor, titleColor) = _spec;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: KIcon(step.icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step.title, style: KType.body(color: titleColor)),
                const SizedBox(height: 2),
                Text(
                  step.subtitle.upper,
                  style: KType.micro(color: KColor.ink3).copyWith(letterSpacing: 0.04 * 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

String _formatDay(DateTime d) => '${d.day} ${_kMonths[d.month - 1]}';
