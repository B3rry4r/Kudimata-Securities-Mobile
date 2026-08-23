// Corporate actions — local shared bits for this cluster's 4 screens.
// Mirrors lib/screens/account/account_widgets.dart's pattern of small,
// screen-local helpers rather than growing the shared lib/widgets/ library
// for one-cluster shapes (readme.md's "never fork a shared component" rule
// is about K* components; a local private row/scaffold widget used only
// inside one feature folder is the established escape hatch — see
// account_widgets.dart's own KAccountRow/KIconBubble/KAccountCard).
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// Pushed-screen scaffold for this cluster: KDetailHeader + scrollable body
/// with the standard 20px gutter. Same shape as
/// account_widgets.dart's KAccountSubScaffold, kept local since corporate
/// actions isn't an Account sub-flow.
class KCorpActionScaffold extends StatelessWidget {
  const KCorpActionScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: KDetailHeader(title: title),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KSpace.gutter, 12, KSpace.gutter, 24),
          child: child,
        ),
      ),
    );
  }
}

/// One label/value row inside a hairline card — "Your entitlement · 80
/// shares · 1 for 5" etc (#s82's fact table). [emphasis] renders the value
/// in cardTitle weight for the one standout row ("Cost to take it all").
class KFactRow extends StatelessWidget {
  const KFactRow({
    super.key,
    required this.label,
    required this.value,
    this.first = false,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool first;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KType.data(color: KColor.ink2))),
          Text(
            value,
            style: (emphasis ? KType.cardTitle() : KType.data(color: KColor.ink)).tnum,
          ),
        ],
      ),
    );
  }
}

/// A tappable "needs a decision" card on the hub — the review-status rights
/// issue / AGM cards in #s81.
class KDecisionCard extends StatelessWidget {
  const KDecisionCard({
    super.key,
    required this.deadlineLabel,
    required this.title,
    required this.body,
    this.onTap,
  });

  final String deadlineLabel;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColor.paper,
          border: Border.all(color: KColor.hairline, width: 1),
          borderRadius: BorderRadius.circular(KRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const KStatusPill(status: KStatus.review, label: 'Needs you', small: true),
                const SizedBox(width: 10),
                Text(deadlineLabel.toUpperCase(),
                    style: KType.micro(color: KColor.ink3)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: KType.cardTitle()),
            const SizedBox(height: 2),
            Text(body, style: KType.data(color: KColor.ink2)),
          ],
        ),
      ),
    );
  }
}
