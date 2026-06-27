// Stage 9 — Bank accounts (pushed). Linked-bank list (with a Primary tag) + an
// add action. Mirrors `BankAccounts` in extra-screens.jsx.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class BankAccountsScreen extends StatelessWidget {
  const BankAccountsScreen({super.key});

  static const List<(String name, String mask, bool primary)> _banks = [
    ('GTBank', '••• 4821', true),
    ('Access Bank', '••• 1180', false),
  ];

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Bank accounts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KAccountCard(
            children: [
              for (var i = 0; i < _banks.length; i++)
                _BankRow(
                  name: _banks[i].$1,
                  mask: _banks[i].$2,
                  primary: _banks[i].$3,
                  first: i == 0,
                ),
            ],
          ),
          const SizedBox(height: 16),
          // SEAM: bank-linking flow (account verification / mandate provider)
          // plugs in here.
          KButton(label: 'Add bank account', iconLeft: 'plus', onPressed: () {}),
        ],
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  const _BankRow({
    required this.name,
    required this.mask,
    required this.primary,
    required this.first,
  });
  final String name;
  final String mask;
  final bool primary;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? BorderSide.none
              : BorderSide(color: KColor.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Row(
        children: [
          const KIconBubble('wallet', iconSize: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(name, style: KType.cardTitle(w: KWeight.medium)),
                    if (primary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KRadii.pill),
                          border: Border.all(color: KColor.hairline, width: 1),
                        ),
                        child: Text('Primary',
                            style: KType.micro(color: KColor.ink3)
                                .copyWith(letterSpacing: 0.06 * 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(mask,
                    style: KType.micro(color: KColor.ink3)
                        .copyWith(letterSpacing: 0.06 * 10)
                        .tnum),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const KRowChevron(),
        ],
      ),
    );
  }
}
