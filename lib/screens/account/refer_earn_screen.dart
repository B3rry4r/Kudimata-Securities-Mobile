// Stage 9 — Refer & earn (pushed). One ink BalancePanel (earnings) + referral
// code card with copy + numbered "how it works" + share. Mirrors `ReferEarn`
// in extra-screens.jsx.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class ReferEarnScreen extends StatelessWidget {
  const ReferEarnScreen({super.key});

  static const String _code = 'CHIDI-2026';
  static const List<String> _steps = [
    'Share your code with a friend',
    'They sign up and fund their wallet',
    'You both earn ₦1,000',
  ];

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Refer & earn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KBalancePanel(
            label: "You've earned",
            balance: '₦4,000',
            chart: Text(
              'From 4 friends who joined.',
              style: KType.body(color: KColor.featureInk2),
            ),
          ),
          const SizedBox(height: 16),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const KEyebrow('Your referral code'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _code,
                        style: KType.section()
                            .copyWith(letterSpacing: 0.04 * 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // SEAM: copy-to-clipboard (and referral attribution) plug in here.
                    KButton(
                      label: 'Copy',
                      variant: KButtonVariant.secondary,
                      size: KButtonSize.sm,
                      fullWidth: false,
                      iconLeft: 'transfer',
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const KEyebrow('How it works'),
          const SizedBox(height: 12),
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KColor.feature,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: KType.micro(color: KColor.featureInk, w: KWeight.semibold)
                        .copyWith(fontSize: 12, letterSpacing: 0, height: 1.0)
                        .tnum,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_steps[i], style: KType.body(color: KColor.ink)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // SEAM: native share sheet plugs in here.
          KButton(label: 'Share invite', iconLeft: 'send', onPressed: () {}),
        ],
      ),
    );
  }
}
