// Rights issue detail (screen 82, 2026-08-23 "Soft Landing" — new feature
// area). Pushed with a RightsIssueFixture `extra`, same pattern as
// account/withdraw_mandate_screen.dart's BankAccountSummary `extra`.
//
// Real backend gap, flagged rather than faked: there is no rights-issue
// entity or subscription endpoint anywhere in this app or in
// Kudimata-Securities-Backend/.pipeline/registry.json (see
// corporate_actions_data.dart's header). s82.html's own footer says "Take
// up" should land on screen 37 (order placed) "with the rights reference",
// and "Let it lapse" should "record the decision and stop the reminders" —
// both are real backend actions (place a subscription order against the
// CSCS; persist a lapse decision) that don't exist yet. So neither button
// silently succeeds or fakes navigating to an order-confirmation screen
// (which would tell the investor money moved when it didn't) — both surface
// the same honest "not available yet" message
// withdraw_mandate_screen.dart/plans_screen.dart use elsewhere in this app.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'corporate_actions_data.dart';
import 'corporate_actions_widgets.dart';

class RightsIssueScreen extends StatefulWidget {
  const RightsIssueScreen({super.key, this.rightsIssue = kMockRightsIssue});
  final RightsIssueFixture rightsIssue;

  @override
  State<RightsIssueScreen> createState() => _RightsIssueScreenState();
}

class _RightsIssueScreenState extends State<RightsIssueScreen> {
  late final _controller =
      TextEditingController(text: widget.rightsIssue.entitlementShares.toString());
  late int _units = widget.rightsIssue.entitlementShares;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final parsed = int.tryParse(value.trim());
    setState(() {
      _units = parsed == null
          ? 0
          : parsed.clamp(0, widget.rightsIssue.entitlementShares);
    });
  }

  String get _costLabel {
    final total = _units * widget.rightsIssue.rightsPricePerShare;
    final fixed = total.toStringAsFixed(2);
    final parts = fixed.split('.');
    final buf = StringBuffer();
    final whole = parts[0];
    for (var i = 0; i < whole.length; i++) {
      final fromEnd = whole.length - i;
      if (i != 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '₦$buf.${parts[1]}';
  }

  void _notAvailable(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rightsIssue;
    return KCorpActionScaffold(
      title: '${r.companyName} rights issue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: BorderRadius.circular(KRadii.card),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                KFactRow(
                  label: 'Your entitlement',
                  value: '${r.entitlementShares} shares · ${r.ratioLabel}',
                  first: true,
                ),
                KFactRow(label: 'Rights price', value: r.rightsPriceLabel),
                KFactRow(label: 'Market price today', value: r.marketPriceLabel),
                KFactRow(
                  label: 'Cost to take it all',
                  value: r.costToTakeAllLabel,
                  emphasis: true,
                ),
                KFactRow(label: 'Closes', value: r.closesLabel),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KInput(
            label: 'How many will you take?',
            controller: _controller,
            numeric: true,
            keyboardType: TextInputType.number,
            suffix: 'of ${r.entitlementShares}',
            helper: 'Wallet ${r.walletBalanceLabel} · part of the entitlement is fine',
            onChanged: _onChanged,
          ),
          const SizedBox(height: 12),
          const KExplainPanel(
            title: 'What happens if I ignore it?',
            body: 'Your slice of the company gets smaller and you keep your ₦3,360. '
                "Neither choice is wrong — taking it up only makes sense if you still "
                'want more GTCO.',
          ),
          const SizedBox(height: 20),
          KButton(
            label: _units > 0 ? 'Take up $_units for $_costLabel' : 'Take up 0 shares',
            onPressed: _units > 0
                ? () => _notAvailable(
                    "Taking up a rights issue isn't available yet — contact support to "
                    'subscribe to this offer.')
                : null,
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Let it lapse',
            variant: KButtonVariant.ghost,
            onPressed: () => _notAvailable(
                "Recording a lapse decision isn't available yet — this offer will "
                'keep showing as needing an answer until it closes.'),
          ),
        ],
      ),
    );
  }
}
