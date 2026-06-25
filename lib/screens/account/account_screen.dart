// Stage 9 — Account hub (root tab). Profile header (UserProfile) + a grouped
// menu of the 8 sub-screens + sign out. Root tab: builds a Scaffold body WITHOUT
// a bottom nav (the shell owns KBottomNav). Mirrors `Profile` in settings-screens.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/data/mock.dart';
import 'package:kudimata_securities/data/models.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'account_widgets.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  // Menu order mirrors the design. `icon` maps to the fixed KIcon set; route is
  // the pushed sub-screen target.
  static const List<(String icon, String title, String route)> _items = [
    ('profile', 'Personal info', Routes.acctPersonal),
    ('fingerprint', 'Security', Routes.acctSecurity),
    ('wallet', 'Bank accounts', Routes.acctBanks),
    ('card', 'Statements & documents', Routes.acctStatements),
    ('bell', 'Notifications', Routes.acctNotifications),
    ('send', 'Refer & earn', Routes.acctRefer),
    ('search', 'Help & support', Routes.acctHelp),
    ('card', 'Legal', Routes.acctLegal),
  ];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.map((p) => p.isEmpty ? '' : p[0]).take(2).join();
    return letters.toUpperCase();
  }

  void _signOut(BuildContext context) {
    // SEAM: real session teardown (clear tokens / secure store) plugs in here.
    AppScope.read(context).setSignedIn(false);
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile user = MockData.user;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // Root tab: clear the floating KBottomNav (~70px + margin + safe area)
          // so the "Log out" button isn't hidden behind it.
          padding: const EdgeInsets.only(top: 20, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KColor.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: KColor.hairline, width: 1),
                      ),
                      child: Text(
                        _initials(user.fullName),
                        style: KType.section()
                            .copyWith(fontSize: 22, height: 1.0),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(user.fullName, style: KType.section()),
                          const SizedBox(height: 2),
                          Text(user.email, style: KType.body(color: KColor.ink3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Menu group.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
                child: KAccountCard(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      KAccountRow(
                        icon: _items[i].$1,
                        title: _items[i].$2,
                        right: const KRowChevron(),
                        first: i == 0,
                        onTap: () => context.push(_items[i].$3),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
                child: KButton(
                  label: 'Log out',
                  variant: KButtonVariant.ghost,
                  iconLeft: 'back',
                  onPressed: () => _signOut(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
