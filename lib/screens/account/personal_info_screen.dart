// Stage 9 — Personal info (pushed). Read-only KInput-style rows: tracked
// UPPERCASE label + tabular value. Mirrors `PersonalInfo` in extra-screens.jsx.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockData.user;
    final rows = <(String, String)>[
      ('Full name', user.fullName),
      ('Date of birth', '14 Mar 1996'),
      ('Email', user.email),
      ('Phone', user.phone),
      ('Residential address', '12 Bourdillon Road, Lagos'),
      ('BVN', '••• 4821'),
    ];

    return KAccountSubScaffold(
      title: 'Personal info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KAccountCard(
            children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      top: i == 0
                          ? BorderSide.none
                          : const BorderSide(color: KColor.hairline, width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(rows[i].$1.upper, style: KType.label()),
                      const SizedBox(height: 5),
                      Text(rows[i].$2,
                          style: KType.cardTitle(w: KWeight.medium).tnum),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'To change your name or BVN, contact support.',
              style: KType.body(color: KColor.ink3),
            ),
          ),
          const SizedBox(height: 16),
          // SEAM: profile-edit form (and the KYC/identity provider that backs
          // name/BVN changes) plugs in here.
          KButton(label: 'Edit details', onPressed: () {}),
        ],
      ),
    );
  }
}
