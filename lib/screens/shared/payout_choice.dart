// The payout-destination choice — Nigerian SEC No Objection condition 1
// (2026-09-04), verbatim:
//
//   "The Company is required to configure Direct Cash Settlement (DCS) as the
//   default payout option for investors. Where an investor elects to receive
//   wallet credits instead, the application should require the investor to
//   explicitly opt out of DCS and select the alternative payout option."
//
// ONE component, TWO surfaces. The owner's requirement is that this choice be
// reachable during onboarding AND changeable later from Account. That is two
// screens showing the same question — exactly the situation the build law
// "never fork a widget, a variant is a prop" exists for. So the choice lives
// here once and both bank_dcs_screen.dart (KYC step 5) and
// payout_preference_screen.dart (Account) render it; there is no second copy
// of the copy, the ordering, or the opt-out confirmation to drift.
//
// WHAT MAKES THE OPT-OUT EXPLICIT, in three layers, none of which is decorative:
//   1. DCS is pre-selected. Never wallet, never "nothing selected".
//   2. Choosing wallet credit opens [confirmDcsOptOut] — a sheet that states
//      plainly what is being given up and what happens instead, with the
//      default action being to STAY on DCS. Dismissing it (tapping away,
//      hardware back) leaves the investor on DCS.
//   3. The server refuses a wallet-credit request that does not carry
//      `acknowledgedDcsOptOut: true` (422 DCS_OPT_OUT_NOT_ACKNOWLEDGED). This
//      component is the only thing in the app that sends that flag, and it
//      sends it only after (2) returned true. A future screen that forgets
//      the sheet cannot opt anybody out.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

/// The two options, rendered as a radio pair. [value] is one of [kPayoutDcs]
/// / [kPayoutWallet] and is never null — DCS is the default and something is
/// always selected.
///
/// [dcsAccountLabel] is the bank account DCS would actually pay into, when one
/// is known ("GTBank ****4821"); null renders the honest "you'll add one in
/// the next step / add one to receive payouts" line instead of implying an
/// account exists. [needsDcsAccount] is the server's own flag for "on DCS with
/// nowhere to settle to" and draws the warning; both callers pass what the
/// server told them rather than re-deriving it.
class PayoutChoice extends StatelessWidget {
  const PayoutChoice({
    super.key,
    required this.value,
    required this.onChanged,
    this.dcsAccountLabel,
    this.needsDcsAccount = false,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? dcsAccountLabel;
  final bool needsDcsAccount;
  final bool enabled;

  void _explain(BuildContext context) {
    showKSheet<void>(
      context,
      child: const KExplainPanel(
        title: 'What is Direct Cash Settlement?',
        body: 'Direct Cash Settlement is how the NGX pays investors. When you sell, the money goes '
            'from the exchange to your own bank account — it never sits with us. It is the option '
            'the regulator expects you to be on, and it is what we set you up with unless you tell '
            'us otherwise.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dcsSelected = value == kPayoutDcs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PayoutOption(
          title: 'Pay it to my bank',
          badge: 'Recommended',
          body: dcsAccountLabel != null
              ? 'Direct Cash Settlement. Sale proceeds go from the exchange straight to $dcsAccountLabel.'
              : 'Direct Cash Settlement. Sale proceeds go from the exchange straight to your own bank account.',
          selected: dcsSelected,
          enabled: enabled,
          onTap: () => onChanged(kPayoutDcs),
        ),
        const SizedBox(height: 10),
        _PayoutOption(
          title: 'Hold it in my Kudimata wallet',
          body: 'Sale proceeds stay in your wallet until you withdraw them yourself.',
          selected: !dcsSelected,
          enabled: enabled,
          onTap: () => onChanged(kPayoutWallet),
        ),
        if (dcsSelected && needsDcsAccount) ...[
          const SizedBox(height: 12),
          // Not a scare message — a real, actionable state. The server told us
          // this investor is on DCS with no mandate account, and until they add
          // one their proceeds will land in the wallet and they will be
          // notified. Saying so beforehand is better than letting them find out
          // after a sale.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KColor.warmTint,
              borderRadius: BorderRadius.circular(KRadii.card),
            ),
            child: Text(
              "You don't have a bank account set up for Direct Cash Settlement yet. Until you add "
              'one, sale proceeds will wait in your wallet and we will let you know.',
              style: KType.data(color: KColor.ink2),
            ),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _explain(context),
          behavior: HitTestBehavior.opaque,
          child: Text('What is Direct Cash Settlement?',
              style: KType.data(color: KColor.indicator, w: KWeight.semibold)),
        ),
      ],
    );
  }
}

/// Layer 2 of the explicit opt-out (see this file's header). Returns true only
/// if the investor deliberately confirms leaving Direct Cash Settlement;
/// dismissing the sheet any other way returns false and leaves them on DCS.
///
/// Both callers MUST gate their wallet-credit write on this returning true,
/// and must send `acknowledgedDcsOptOut: true` only in that case — the server
/// refuses the write otherwise, which is the backstop, not the mechanism.
Future<bool> confirmDcsOptOut(BuildContext context) async {
  final confirmed = await showKSheet<bool>(
    context,
    child: const _DcsOptOutSheet(),
  );
  return confirmed == true;
}

class _DcsOptOutSheet extends StatelessWidget {
  const _DcsOptOutSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Turn off Direct Cash Settlement?',
            style: KType.hero(color: KColor.ink).copyWith(fontSize: 24, height: 30 / 24)),
        const SizedBox(height: 12),
        Text(
          'Direct Cash Settlement pays your sale proceeds from the exchange straight into your own '
          'bank account. It is the default, and it is what the regulator expects.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 10),
        Text(
          'If you turn it off, proceeds will be held in your Kudimata wallet instead and you will '
          'have to withdraw them yourself. You can turn it back on any time in Account.',
          style: KType.body(color: KColor.ink2),
        ),
        const SizedBox(height: 20),
        // The DEFAULT action is to stay on DCS — it is the primary button, and
        // it is what a dismissed sheet does too.
        KButton(
          label: 'Keep Direct Cash Settlement',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: 10),
        KButton(
          label: 'Turn it off and use my wallet',
          variant: KButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _PayoutOption extends StatelessWidget {
  const _PayoutOption({
    required this.title,
    required this.body,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });
  final String title;
  final String body;
  final String? badge;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: KMotion.base,
        curve: KMotion.easeSoft,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? KColor.indicatorTint : KColor.paper,
          borderRadius: BorderRadius.circular(KRadii.card),
          border: Border.all(
            color: selected ? KColor.indicator : KColor.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: KRadio(checked: selected, onChanged: enabled ? (_) => onTap() : null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: KType.cardTitle(color: KColor.ink))),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        KStatusPill(status: KStatus.approved, label: badge!, small: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: KType.data(color: KColor.ink2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
