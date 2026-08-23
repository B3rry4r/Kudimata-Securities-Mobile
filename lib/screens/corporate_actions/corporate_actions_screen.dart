// Corporate actions hub (screen 81, 2026-08-23 "Soft Landing" — a genuinely
// new feature area, previously unbuilt). Header text is "Things to decide"
// per s81.html's own in-frame markup (the "Corporate actions" label is the
// design canvas's catalog title for the screen, not the on-screen copy).
//
// No CorporateActionsRepository exists — see corporate_actions_data.dart's
// header for the full backend-gap writeup. This screen is real, complete UI
// fed by that file's static fixtures, the same house convention
// lib/screens/account/plans_screen.dart established for a feature whose
// backend doesn't exist yet.
//
// Entry point (report to the wiring agent — router files are out of scope
// here): from lib/screens/portfolio/portfolio_screen.dart (screen 38) or
// lib/screens/portfolio/holding_detail_screen.dart (screen 39), or a
// notification, per s81.html's own footer note. Suggested spot: a row/
// button near the top of PortfolioScreen's holdings list (e.g. a
// KNudgeCard-style banner or a plain row under the balance panel) — this
// screen needs no ticker/holding argument, so it can be reached the same
// way from either screen.
//
// Routes.dart / app_router.dart are explicitly out of scope for this pass
// (see this cluster's report), so the 3 pushes below use their target path
// literals directly rather than Routes.* constants that don't exist yet —
// the wiring agent should promote these 4 literals
// ('/corporate-actions', '/corporate-actions/rights-issue',
// '/corporate-actions/agm', '/corporate-actions/dividends') to Routes
// constants and register them centrally; nothing here needs to change when
// that happens beyond swapping the literal for the constant.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_data.dart';
import 'corporate_actions_widgets.dart';

class CorporateActionsScreen extends StatelessWidget {
  const CorporateActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KCorpActionScaffold(
      title: 'Things to decide',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Companies you own are doing things. Two need an answer from you.',
            style: KType.data(color: KColor.ink2),
          ),
          const SizedBox(height: 12),
          KDecisionCard(
            deadlineLabel: 'Closes ${kMockRightsIssue.closesShortLabel}',
            title: '${kMockRightsIssue.companyName} rights issue · '
                '${kMockRightsIssue.ratioLabel}',
            body: 'You can buy ${kMockRightsIssue.entitlementShares} new shares at '
                '${kMockRightsIssue.rightsPriceLabel} — below today\'s '
                '${kMockRightsIssue.marketPriceLabel}.',
            onTap: () => context.push('/corporate-actions/rights-issue', extra: kMockRightsIssue),
          ),
          const SizedBox(height: 12),
          KDecisionCard(
            deadlineLabel: 'Votes close ${kMockAgm.votesCloseLabel}',
            title: '${kMockAgm.companyName} AGM · ${kMockAgm.resolutions.length} resolutions',
            body: 'Vote your ${kMockAgm.sharesHeld} shares, or let it pass.',
            onTap: () => context.push('/corporate-actions/agm', extra: kMockAgm),
          ),
          const SizedBox(height: 12),
          // Settled action — reports only, no decision needed, so it's a
          // plain (non-tappable) card per s81.html.
          Container(
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
                    const KStatusPill(status: KStatus.approved, label: 'Done for you', small: true),
                    const SizedBox(width: 10),
                    Text('28 FEB', style: KType.micro(color: KColor.ink3)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Zenith bonus shares · 1 for 10', style: KType.cardTitle()),
                const SizedBox(height: 2),
                Text(
                  '40 free shares were added to your holding. Nothing to do.',
                  style: KType.data(color: KColor.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const KNudgeCard(
            tone: KNudgeTone.grape,
            title: 'What is a rights issue?',
            body: 'The company is raising money and offering existing owners first '
                'refusal, usually below the market price.',
          ),
          const SizedBox(height: 20),
          KButton(
            label: 'Dividends and unclaimed money',
            variant: KButtonVariant.ghost,
            onPressed: () => context.push('/corporate-actions/dividends'),
          ),
        ],
      ),
    );
  }
}
