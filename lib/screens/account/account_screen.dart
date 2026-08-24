// Stage 9 — Account hub (root tab). Profile header (Avatar + StatusPill) +
// a compact credits row + a grouped menu of the account sub-screens +
// LanguageSwitch. Root tab: builds a Scaffold body WITHOUT a bottom nav (the
// shell owns KBottomNav). Mirrors `Profile` in settings-screens.jsx.
//
// Wired to GET /users/me (personalInfo — cscsNumber/accountStatus/fullName)
// per lib/data/api/README.md's FutureBuilder convention. Neither "Bank
// accounts & DCS" nor "Legal" fetch/show trailing meta text anymore
// (2026-08-24, direct product instruction — see _menuRows: the bank
// name/masked number crowded that row, and the document count was
// dropped separately). "Verified" comes from
// AppState.kycApproved — already refreshed at login (see
// refreshKycGatingState), so no extra fetch is needed for it. "Log out" was
// removed from this screen (2026-08-23 exactness pass): the canvas's #s45
// body has no sign-out affordance at all — that lives on Security (#s50,
// see security_screen.dart) instead, alongside "Freeze my account".
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

/// Menu row (title, route, optional trailing meta text). Order and
/// membership match the canvas mockup's #s45 block exactly (re-verified
/// 2026-08-23 against the real s45.html body, not against other screens'
/// footer notes — a prior pass had wrongly dropped "Plans & credits",
/// "Corporate actions" and "Tax documents" from this list, reasoning from
/// #s81/#s85's OWN footer notes ("entry from 38, 39..."/"from 52 tab...")
/// instead of #s45's actual markup, which unambiguously lists all three as
/// rows here — s45.html is the ground truth for what's ON s45, footer notes
/// on other screens are non-exhaustive entry-point hints, not an override).
/// "Notifications" stays correctly dropped — not a row on this screen in
/// the mockup (reachable from Home's bell icon instead, screen 29).
List<(String title, String route, String? trailing)> _menuRows() {
  return [
    ('Personal info', Routes.acctPersonal, null),
    // 2026-08-24: trailing bank name/masked number removed per direct
    // product instruction ("You tab should not show the user bank account
    // and number... so that the bank account and DCS can sit properly") —
    // canvas s45 does show it ("GTB ••••6789"), but a long bank name
    // crowded this row; the full detail is one tap away on the Bank
    // accounts & DCS screen itself.
    ('Bank accounts & DCS', Routes.acctBanks, null),
    ('Plans & credits', Routes.acctPlans, null),
    ('Statements & documents', Routes.acctStatements, null),
    ('Security', Routes.acctSecurity, null),
    ('Refer & earn', Routes.acctRefer, null),
    ('Corporate actions', Routes.corpActions, null),
    ('Tax documents', Routes.acctTax, null),
    ('Data & privacy', Routes.acctDataPrivacy, null),
    ('Help & support', Routes.acctHelp, null),
    // 2026-08-24: trailing document count removed per direct product
    // instruction — canvas s45 literally shows "8 documents" here, but the
    // real count is arguably churn-prone/uninteresting to an investor, and
    // was explicitly asked to be dropped.
    ('Legal', Routes.acctLegal, null),
  ];
}

// Plans & credits sits as its own row above the menu group, alongside a
// compact credit meter — screen 45. used=7/total=10 mirrors the canvas's own
// example values exactly; no real AI-credit metering backend exists yet
// (docs/redesign/PLAN.md), so these stay static.
const int _exampleCreditsUsed = 7;
const int _exampleCreditsTotal = 10;

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late Future<PersonalInfo> _future = _userRepo.personalInfo();

  // Local-only — no app-wide language/locale persistence exists anywhere in
  // this app yet, same as onboarding/welcome_slider_screen.dart's and
  // document_summary_screen.dart's own KLanguageSwitch usage.
  String _lang = 'en';

  @override
  Widget build(BuildContext context) {
    final kycApproved = AppScope.of(context).kycApproved;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<PersonalInfo>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                onPrimary: () => setState(() => _future = _userRepo.personalInfo()),
              );
            }
            return _AccountBody(
              info: snapshot.data!,
              verified: kycApproved,
              lang: _lang,
              onLangChanged: (v) => setState(() => _lang = v),
              onReturnFromPersonalInfo: () =>
                  setState(() => _future = _userRepo.personalInfo()),
            );
          },
        ),
      ),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.info,
    required this.verified,
    required this.lang,
    required this.onLangChanged,
    required this.onReturnFromPersonalInfo,
  });

  final PersonalInfo info;
  final bool verified;
  final String lang;
  final ValueChanged<String> onLangChanged;

  /// This screen (a persistent tab under StatefulNavigationShell, never
  /// disposed on tab switches) fetched [info] exactly once — reported live
  /// as "it is a none update until you refresh bug": editing the avatar (or
  /// name) on Personal info and coming back here kept showing the stale
  /// pre-edit data, since nothing ever told this tab to re-fetch. Personal
  /// info is the one row whose target screen can change what THIS screen
  /// displays (name/avatar), so its push is awaited and triggers a refetch
  /// on return — every other row's target doesn't affect this screen's own
  /// data, so they stay a plain push.
  final VoidCallback onReturnFromPersonalInfo;

  @override
  Widget build(BuildContext context) {
    // Subtitle mirrors the canvas's "CHN 1234567890 · NGX account live"
    // shape with real data: cscsNumber is '—' until KYC assigns one, and
    // accountStatus reflects the real lifecycle state (active/frozen/
    // dormant/...) rather than assuming every account is live.
    final hasChn = info.cscsNumber != '—' && info.cscsNumber.isNotEmpty;
    final statusLower = info.accountStatus.trim().toLowerCase();
    final statusText = statusLower.isEmpty || statusLower == 'active'
        ? 'Account live'
        : '${info.accountStatus[0].toUpperCase()}${info.accountStatus.substring(1)} account';
    final subtitle = hasChn ? 'CHN ${info.cscsNumber} · $statusText' : statusText;

    final rows = _menuRows();

    return SingleChildScrollView(
      // Root tab: clear the floating KBottomNav (~70px + margin + safe area)
      // so the menu's bottom row isn't hidden behind it.
      padding: const EdgeInsets.only(top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header — canvas mockup #s45 uses the illustrated Avatar,
          // a "CHN ... · Account live" subtitle, and a "Verified"
          // StatusPill next to it. 2026-08-24: the avatar is now a real,
          // user-chosen field (info.avatarKey) — an investor who hasn't
          // picked one gets no avatar circle at all, just their name (see
          // KAvatar's doc comment), not a generated placeholder.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Row(
              children: [
                if (info.avatarKey != null) ...[
                  KAvatar(avatarKey: info.avatarKey!, size: 56),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(info.fullName, style: KType.section()),
                      const SizedBox(height: 2),
                      Text(subtitle, style: KType.data(color: KColor.ink3)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                KStatusPill(
                  status: verified ? KStatus.approved : KStatus.pending,
                  label: verified ? 'Verified' : 'Unverified',
                  small: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Plans & credits sits as its own compact row above the menu
          // group in the mockup (CreditMeter + a link) — link colour is the
          // design's default bare-`<a>` accent (var(--indicator)), not ink.
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
                  Text('Plans & credits', style: KType.data(color: KColor.indicator)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Menu group — plain text + chevron rows, no leading icon bubble
          // (the canvas's #s45 rows are bare `<a>`s with just a title span
          // and a chevron `Icon`; icon bubbles never appear here).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: KAccountCard(
              children: [
                for (var i = 0; i < rows.length; i++)
                  KAccountRow(
                    title: rows[i].$1,
                    first: i == 0,
                    onTap: () async {
                      await context.push(rows[i].$2);
                      if (rows[i].$2 == Routes.acctPersonal) {
                        onReturnFromPersonalInfo();
                      }
                    },
                    right: rows[i].$3 == null
                        ? const KRowChevron()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(rows[i].$3!, style: KType.data(color: KColor.ink3)),
                              const SizedBox(width: 8),
                              const KRowChevron(),
                            ],
                          ),
                  ),
              ],
            ),
          ),
          // English/Pidgin switch temporarily hidden (2026-08-24, direct
          // product instruction) — no real Pidgin translation exists
          // anywhere in the app yet; showing the switch implied a feature
          // that isn't there. `lang`/`onLangChanged` stay threaded through
          // unchanged so this is a one-line restore once Pidgin is real.
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
          //   child: KLanguageSwitch(value: lang, onChanged: onLangChanged),
          // ),
        ],
      ),
    );
  }
}
