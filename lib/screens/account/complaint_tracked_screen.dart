// Screen 88 — "Complaint · tracked" (2026-08-23 "Soft Landing" canvas
// exactness pass, s88.html). Per the canvas footer note this is reached
// "from 87 or an email link" — i.e. after a complaint has actually been
// filed and the backend hands back a reference to track.
//
// REAL BACKEND GAP: no complaint/ticketing resource exists yet (see
// complaint_screen.dart's file header for the full note and the shape a
// real one would need). Because there is nothing to file yet,
// complaint_screen.dart's "Send complaint" does NOT navigate here with a
// manufactured reference — that would be exactly the fake-success pattern
// this app avoids. This screen is still built in full, honest, canvas-exact
// shape (status header, filed/answer-by summary card, three-step register
// timeline, actions) and takes a real [ComplaintSummary] so it is ready to
// wire the moment `GET /complaints/:id` exists; there is just no live route
// pushing into it yet.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';
import 'complaint_screen.dart';

/// One step in the complaint's register timeline (canvas: logged → under
/// review → escalate). `state` drives the medallion tint/icon colour and
/// title colour — see `_ComplaintStepRow`.
enum ComplaintStepState { done, active, upcoming }

class ComplaintTimelineStep {
  const ComplaintTimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String icon;
  final String title;
  final String subtitle;
  final ComplaintStepState state;
}

/// Everything screen 88 renders for one filed complaint. No backend model
/// exists for this yet (see file header) — this mirrors the shape
/// `GET /complaints/:id` would need to return.
class ComplaintSummary {
  const ComplaintSummary({
    required this.reference,
    required this.title,
    required this.filedOn,
    this.about,
    required this.answerDueOn,
    required this.status,
    this.statusLabel,
    required this.timeline,
    this.escalationNote =
        'The SEC refers complaints to its Administrative Proceedings '
            'Committee, and its decision can be appealed to the Investments '
            'and Securities Tribunal.',
  });

  final String reference;
  final String title;
  final DateTime filedOn;
  final String? about;
  final DateTime answerDueOn;
  final KStatus status;
  final String? statusLabel;
  final List<ComplaintTimelineStep> timeline;
  final String escalationNote;
}

class ComplaintTrackedScreen extends StatelessWidget {
  const ComplaintTrackedScreen({super.key, required this.complaint});
  final ComplaintSummary complaint;

  @override
  Widget build(BuildContext context) {
    final filed = _formatDate(complaint.filedOn);
    final dueDay = _formatDay(complaint.answerDueOn);
    return KAccountSubScaffold(
      title: complaint.reference,
      headerTrailing: KStatusPill(
        status: complaint.status,
        label: complaint.statusLabel,
        small: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(complaint.title, style: KType.cardTitle()),
                const SizedBox(height: 8),
                Text(
                  'Filed $filed'
                  '${complaint.about != null ? ' · about ${complaint.about}' : ''}',
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
                for (var i = 0; i < complaint.timeline.length; i++)
                  _ComplaintStepRow(
                    step: complaint.timeline[i],
                    last: i == complaint.timeline.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(complaint.escalationNote, style: KType.data(color: KColor.ink3)),
          const SizedBox(height: 24),
          KButton(
            label: 'Add more information',
            variant: KButtonVariant.secondary,
            // Stand-in for context.push(Routes.acctComplaint) (canvas
            // nav.s87) — that route constant doesn't exist yet (routes.dart
            // is wired centrally, see complaint_screen.dart's file header),
            // so this pushes the screen directly so the button still works
            // today; swap to the go_router route once it lands.
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
  final ComplaintTimelineStep step;
  final bool last;

  (Color, Color, Color) get _spec => switch (step.state) {
        // (medallion tint, icon colour, title colour)
        ComplaintStepState.done => (KColor.statusApprovedTint, KColor.gain, KColor.ink),
        ComplaintStepState.active => (KColor.indicatorTint, KColor.indicator, KColor.ink),
        ComplaintStepState.upcoming => (KColor.track, KColor.ink2, KColor.ink2),
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
