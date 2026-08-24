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
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/ai_repository.dart';
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
// compact credit meter — screen 45. 2026-08-24: real balance from
// AiCreditStatus instead of the canvas's static "7 of 10" example — the
// backend tracks a plain balance + ledger, not a fixed per-period total, so
// "total" is derived here for display: the free trial grant when the
// investor has no active plan, or that plan's per-cycle credit grant.
const int _freeTrialCredits = 3;

int _creditsTotal(AiCreditStatus credits) => switch (credits.plan) {
      'plus' => 60,
      'pro' => 250,
      _ => _freeTrialCredits,
    };

int _creditsUsed(AiCreditStatus credits) =>
    (_creditsTotal(credits) - credits.creditsRemaining).clamp(0, _creditsTotal(credits));

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final _aiRepo = AiRepository(AppScope.read(context).apiClient);
  late Future<(PersonalInfo, AiCreditStatus)> _future = _load();

  // Local-only — no app-wide language/locale persistence exists anywhere in
  // this app yet, same as onboarding/welcome_slider_screen.dart's and
  // document_summary_screen.dart's own KLanguageSwitch usage.
  String _lang = 'en';

  Future<(PersonalInfo, AiCreditStatus)> _load() async {
    final infoFuture = _userRepo.personalInfo();
    final creditsFuture = _aiRepo.credits();
    return (await infoFuture, await creditsFuture);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final kycApproved = AppScope.of(context).kycApproved;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(PersonalInfo, AiCreditStatus)>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(onPrimary: _reload);
            }
            final (info, credits) = snapshot.data!;
            return _AccountBody(
              info: info,
              credits: credits,
              verified: kycApproved,
              lang: _lang,
              onLangChanged: (v) => setState(() => _lang = v),
              // Personal info can change name/avatar (this screen's own
              // header); Plans & credits can change the balance shown here
              // (the compact meter + the menu row both push there) — both
              // refetch this screen's data on return, same "persistent tab,
              // never disposed, so nothing refreshes without this" fix as
              // account_screen.dart's earlier stale-data bug.
              onReturnFromPersonalInfo: _reload,
              onReturnFromPlans: _reload,
            );
          },
        ),
      ),
    );
  }
}

/// Voluntary sign-out. Mirrors security_screen.dart's `_signOut` exactly —
/// same endpoint, same tolerance of a failed call, same `signOut()` (NOT
/// `forceSignOut()`, which would wipe this device's passcode; see
/// AppState.signOut()'s doc comment).
Future<void> _signOut(BuildContext context) async {
  final app = AppScope.read(context);
  try {
    await app.apiClient.post('/auth/logout');
  } on ApiException {
    // A network hiccup shouldn't trap someone signed in locally — fall
    // through to local teardown either way.
  }
  await app.signOut();
  if (!context.mounted) return;
  context.go(Routes.login);
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.info,
    required this.credits,
    required this.verified,
    required this.lang,
    required this.onLangChanged,
    required this.onReturnFromPersonalInfo,
    required this.onReturnFromPlans,
  });

  final PersonalInfo info;
  final AiCreditStatus credits;
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

  /// Same reasoning as [onReturnFromPersonalInfo] — Plans & credits is the
  /// one destination that can change [credits] (subscribe/cancel).
  final VoidCallback onReturnFromPlans;

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
      // bottom:160, not 100 — the floating bottom nav overlays this scroll
      // view, and the Log out button added below the menu card (2026-08-24)
      // sat underneath it at the old value, half-hidden.
      padding: const EdgeInsets.only(top: 20, bottom: 160),
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
          // 2026-08-24: real balance (AiCreditStatus) instead of a hardcoded
          // 7-of-10 literal — see AiCreditsService on the backend.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: GestureDetector(
              onTap: () async {
                await context.push(Routes.acctPlans);
                onReturnFromPlans();
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  KCreditMeter(
                    used: _creditsUsed(credits),
                    total: _creditsTotal(credits),
                    kind: credits.plan == null ? 'trial' : 'plan',
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
          const SizedBox(height: 20),
          // Log out (2026-08-24, direct instruction: "logout should be on
          // the account screen please... its too hard to see"). It lived
          // ONLY on the Security screen — two taps deep behind a row whose
          // label says nothing about signing out, which is where the
          // canvas (#s50) put it, but which in practice meant nobody could
          // find it. Security keeps its copy; this is an addition, not a
          // move, so neither route regresses for anyone used to the other.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: KButton(
              label: 'Log out',
              variant: KButtonVariant.ghost,
              fullWidth: true,
              onPressed: () => _signOut(context),
            ),
          ),
          const SizedBox(height: 8),
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
