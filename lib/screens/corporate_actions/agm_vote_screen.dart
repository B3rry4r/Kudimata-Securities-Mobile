// AGM · vote your shares (screen 83, 2026-08-23 "Soft Landing" — new
// feature area). Pushed with an AgmFixture `extra`.
//
// Real backend gap: there is no AGM/resolution/proxy-vote entity or
// endpoint anywhere in this app or in Kudimata-Securities-Backend/.pipeline/
// registry.json (see corporate_actions_data.dart's header). s83.html's
// footer says "Submit" should go "back to 81 marked voted" and "the full
// notice is sent as a PDF through the document email" — both real backend
// actions (persisting a proxy vote per resolution; emailing a document)
// that don't exist yet. Selecting For/Against/Abstain per resolution is
// real local UI state (so the screen feels alive and matches the design's
// selected chips), but tapping either button surfaces the same honest "not
// available yet" message the rest of this app uses rather than pretending
// the vote was recorded or the email was sent.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_data.dart';
import 'corporate_actions_widgets.dart';

enum _Ballot { forIt, against, abstain }

class AgmVoteScreen extends StatefulWidget {
  const AgmVoteScreen({super.key, this.agm = kMockAgm});
  final AgmFixture agm;

  @override
  State<AgmVoteScreen> createState() => _AgmVoteScreenState();
}

class _AgmVoteScreenState extends State<AgmVoteScreen> {
  // Every resolution defaults to "For", matching s83.html's own chips
  // (selected="{{ true }}" on the first PillChip of both shown resolutions).
  late final Map<int, _Ballot> _votes = {
    for (final r in widget.agm.resolutions) r.index: _Ballot.forIt,
  };

  void _notAvailable(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final agm = widget.agm;
    return KCorpActionScaffold(
      title: '${agm.companyName} AGM',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You hold ${agm.sharesHeld} shares, so you have ${agm.sharesHeld} votes on '
            'each resolution. Votes close ${agm.votesCloseLabel}, the meeting is '
            '${agm.meetingLabel}.',
            style: KType.data(color: KColor.ink2),
          ),
          const SizedBox(height: 12),
          for (final resolution in agm.resolutions) ...[
            _ResolutionCard(
              resolution: resolution,
              selected: _votes[resolution.index]!,
              onChanged: (b) => setState(() => _votes[resolution.index] = b),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'We submit your votes as your proxy and email the confirmation.',
            style: KType.data(color: KColor.ink3),
          ),
          const SizedBox(height: 20),
          KButton(
            label: 'Submit my votes',
            onPressed: () => _notAvailable(
                "Submitting proxy votes isn't available yet — contact support to vote "
                'this AGM.'),
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Email me the notice of meeting',
            variant: KButtonVariant.ghost,
            onPressed: () => _notAvailable(
                "Emailing the notice of meeting isn't available yet — check back soon."),
          ),
        ],
      ),
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.resolution,
    required this.selected,
    required this.onChanged,
  });

  final AgmResolutionFixture resolution;
  final _Ballot selected;
  final ValueChanged<_Ballot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('${resolution.index} · ${resolution.title}', style: KType.cardTitle()),
          const SizedBox(height: 10),
          Row(
            children: [
              KPillChip(
                label: 'For',
                selected: selected == _Ballot.forIt,
                onTap: () => onChanged(_Ballot.forIt),
              ),
              const SizedBox(width: 8),
              KPillChip(
                label: 'Against',
                selected: selected == _Ballot.against,
                onTap: () => onChanged(_Ballot.against),
              ),
              const SizedBox(width: 8),
              KPillChip(
                label: 'Abstain',
                selected: selected == _Ballot.abstain,
                onTap: () => onChanged(_Ballot.abstain),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
