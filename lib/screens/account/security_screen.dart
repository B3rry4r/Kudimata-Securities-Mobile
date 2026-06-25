// Stage 9 — Security (pushed). Change passcode row + biometric & 2FA KSwitches.
// Biometric reflects AppState.biometricEnabled. Mirrors `Security` in
// settings-screens.jsx.
import 'package:flutter/material.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _twoFa = true;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return KAccountSubScaffold(
      title: 'Security',
      child: KAccountCard(
        children: [
          KAccountRow(
            icon: 'card',
            title: 'Change passcode',
            sub: 'Last changed 12 days ago',
            right: const KRowChevron(),
            first: true,
            // SEAM: change-passcode flow plugs in here.
            onTap: () {},
          ),
          KAccountRow(
            icon: 'fingerprint',
            title: 'Biometric unlock',
            sub: 'Unlock with your face or fingerprint',
            crossAlign: CrossAxisAlignment.start,
            right: KSwitch(
              checked: app.biometricEnabled,
              // SEAM: real biometric enrolment plugs in here.
              onChanged: (v) => app.setBiometric(v),
            ),
          ),
          KAccountRow(
            icon: 'eye',
            title: 'Two-factor authentication',
            sub: 'Extra check at sign-in',
            crossAlign: CrossAxisAlignment.start,
            right: KSwitch(
              checked: _twoFa,
              onChanged: (v) => setState(() => _twoFa = v),
            ),
          ),
        ],
      ),
    );
  }
}
