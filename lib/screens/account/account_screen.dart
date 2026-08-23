// Stage 9 — Account hub (root tab). Profile header (UserProfile) + a grouped
// menu of the 8 sub-screens + sign out. Root tab: builds a Scaffold body WITHOUT
// a bottom nav (the shell owns KBottomNav). Mirrors `Profile` in settings-screens.jsx.
//
// Wired to GET /users/me via UserRepository (see lib/data/api/README.md for
// the FutureBuilder convention) and to POST /auth/logout for real session
// teardown on sign-out.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/models.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

// Menu order mirrors the design. `icon` maps to the fixed KIcon set; route is
// the pushed sub-screen target.
// Order and membership match the canvas mockup's #s45 block exactly
// (2026-08-23 exactness pass) — Personal info, Security, Bank accounts,
// Statements, Refer & earn, Help & support, Legal. "Notifications" was
// dropped: it's not a row on this screen in the mockup (reachable from
// Home's bell icon instead, screen 29) — an extra row this port had added.
// Corporate actions / Tax documents / Data & privacy are in the mockup but
// link to screen ids beyond this 66-screen canvas (unmocked, unbuilt) —
// correctly omitted rather than linking somewhere real for something fake.
const List<(String icon, String title, String route)> _items = [
  ('profile', 'Personal info', Routes.acctPersonal),
  ('fingerprint', 'Security', Routes.acctSecurity),
  ('wallet', 'Bank accounts', Routes.acctBanks),
  ('card', 'Statements & documents', Routes.acctStatements),
  ('send', 'Refer & earn', Routes.acctRefer),
  ('search', 'Help & support', Routes.acctHelp),
  ('card', 'Legal', Routes.acctLegal),
];

// Plans & credits sits as its own row above the menu group, alongside a
// compact credit meter — screen 45. Static example numbers: no real
// AI-credit metering backend exists yet (docs/redesign/PLAN.md).
const int _exampleCreditsUsed = 3;
const int _exampleCreditsTotal = 10;

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final _repo = UserRepository(AppScope.read(context).apiClient);
  late Future<UserProfile> _future = _repo.me();

  Future<void> _signOut(BuildContext context) async {
    final app = AppScope.read(context);
    try {
      await app.apiClient.post('/auth/logout');
    } on ApiException {
      // A network hiccup shouldn't trap the user signed in locally — fall
      // through to local teardown regardless of whether the API call
      // succeeded.
    }
    // signOut(), not forceSignOut() — a plain voluntary sign-out preserves
    // this device's passcode (BUG-03) instead of wiping it; see
    // AppState.signOut()'s doc comment.
    await app.signOut();
    if (!context.mounted) return;
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<UserProfile>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                onPrimary: () => setState(() => _future = _repo.me()),
              );
            }
            return _AccountBody(
              user: snapshot.data!,
              onSignOut: () => _signOut(context),
            );
          },
        ),
      ),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.user, required this.onSignOut});

  final UserProfile user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Root tab: clear the floating KBottomNav (~70px + margin + safe area)
      // so the "Log out" button isn't hidden behind it.
      padding: const EdgeInsets.only(top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header — canvas mockup #s45 uses the illustrated Avatar
          // (seeded per-user, per readme.md's "Characters are generated, not
          // drawn"), not a bare initials-in-circle (2026-08-23 exactness
          // pass — the prior port used the wrong identity treatment here).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Row(
              children: [
                KAvatar(seed: user.email, size: 56),
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
          // The mockup's "Verified" StatusPill + "CHN ••• · NGX account
          // live" subtitle need cscsNumber/verification-status fields that
          // UserRepository.me() (UserProfile) doesn't carry — only
          // UserRepository.personalInfo()/KycRepository.me() do (see
          // personal_info_screen.dart's _fetchBvn for the exact pattern).
          // Flagged, not added here: needs a second fetch wired in
          // alongside _future above, not a one-line change.
          const SizedBox(height: 16),
          // Plans & credits sits as its own compact row above the menu
          // group in the mockup (CreditMeter + a link), not as the menu's
          // first item (2026-08-23 exactness pass).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: GestureDetector(
              onTap: () => context.push(Routes.acctPlans),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const KCreditMeter(
                    used: _exampleCreditsUsed,
                    total: _exampleCreditsTotal,
                    compact: true,
                  ),
                  const SizedBox(width: 10),
                  Text('Plans & credits', style: KType.data(color: KColor.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: KButton(
              label: 'Log out',
              variant: KButtonVariant.ghost,
              iconLeft: 'back',
              onPressed: onSignOut,
            ),
          ),
        ],
      ),
    );
  }
}
