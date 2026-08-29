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
// refreshKycGatingState), so no extra fetch is needed for it.
//
// R-5 correction (2026-08-27, docs/redesign/DECISIONS.md): this file used
// to cite "#s45" for the account hub — that id is from the OLD 97-screen
// canvas and now points at an unrelated screen. The real, current artboard
// for this hub is `06 Account and Support.dc.html#s51` ("51 · Account
// hub"). "Log out" now appears on BOTH this screen (added 2026-08-24, direct
// instruction: "logout should be on the account screen please... its too
// hard to see" — s51 itself has no sign-out affordance drawn at all, so this
// row is a kept, deliberate addition, not a design match) and Security
// (kept there too — see security_screen.dart's own R-5 note).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/app/feature_flags.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/ai_repository.dart';
import 'package:kudimata_invest/data/repositories/corporate_actions_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'account_widgets.dart';

/// Menu row (title, route, icon, sub). Order and membership are s51's own
/// ("51 · Account hub") plus the app's real extra rows s51 doesn't draw —
/// see this list's trailing comments for exactly which. s51's own icon
/// names ('users' for Personal details, 'flag' for Corporate actions) have
/// no glyph in lib/widgets/k_icon.dart's registry (frozen — SEE REPORT,
/// SHARED-CHANGE REQUEST) — KIconBubble silently falls back to 'card' for
/// any unregistered name, which would be worse than a deliberate, adjacent
/// substitute, so those two rows use 'profile'/'transfer' instead.
List<(String title, String route, String? icon, String? sub)> _menuRows(int pendingCorpActions) {
  return [
    // s51: 'doc' · "Statements and contract notes" · "One per broker,
    // monthly" — title corrected to s51's own row text (2026-08-29
    // exactness pass; this used to read "Statements & documents", a paraphrase
    // with no ruling behind it).
    ('Statements and contract notes', Routes.acctStatements, 'doc', 'One per broker, monthly'),
    // s51: 'shield' · "Face ID, passcode, devices" — reworded to this app's
    // own cross-platform toggle name (security_screen.dart deliberately
    // calls it "Biometric unlock", not "Face ID" — Android has no Face ID).
    ('Security', Routes.acctSecurity, 'shield', 'Biometric unlock, passcode, devices'),
    // s51: 'users' (unregistered, see header note) · "Name, contact,
    // address". Title kept as "Personal info", NOT s58's "Personal
    // details" — suitability_result_screen.dart and dormant_account_screen.dart
    // (both out of this pass's scope) already say "Account › Personal
    // info" verbatim; renaming here alone would silently break that
    // cross-screen breadcrumb. SHARED-CHANGE REQUEST filed in the report.
    // 2026-08-29 exactness pass: s51's own row text is "Personal details",
    // not "Personal info" — the prior comment here defended "Personal info"
    // for cross-screen breadcrumb consistency with suitability_result_screen.dart
    // and dormant_account_screen.dart's "Account › Personal info" copy, but a
    // defence for keeping a divergence isn't a ruling that authorises it, and
    // no entry in docs/redesign/DECISIONS.md covers this label. Renamed to
    // match s51; the other two screens are out of this pass's scope and now
    // read one word out of step with this row — SHARED-CHANGE REQUEST filed
    // in the report so that breadcrumb gets the same fix.
    ('Personal details', Routes.acctPersonal, 'profile', 'Name, contact, address'),
    // 2026-08-24: trailing bank name/masked number removed per direct
    // product instruction ("You tab should not show the user bank account
    // and number... so that the bank account and DCS can sit properly") —
    // s51 doesn't draw this row at all (see report: rows the artboard
    // omits), but it's real and wired, so it stays.
    ('Bank accounts & DCS', Routes.acctBanks, 'card', 'Linked accounts, DCS mandate'),
    // D-3 (SHARED-CHANGES.md, 2026-08-27 removals pass, R-6): the
    // AI-credits line is parked behind kAiCreditsEnabled — see
    // lib/app/feature_flags.dart. Screen + repository stay in the tree.
    if (kAiCreditsEnabled) ('Plans & credits', Routes.acctPlans, null, null),
    if (kAiCreditsEnabled) ('Refer & earn', Routes.acctRefer, null, null),
    // s51: 'flag' (unregistered, see header note) · "1 waiting: Zenith
    // rights issue". The named ticker is a drawn example, not a real
    // figure this screen can source cheaply — R-34 territory — so the
    // count alone is computed from the same real
    // CorporateActionsRepository data corporate_actions_screen.dart uses
    // (open + not-yet-elected/voted), and only the count is shown.
    (
      'Corporate actions',
      Routes.corpActions,
      'transfer',
      pendingCorpActions > 0 ? '$pendingCorpActions waiting' : 'AGM votes, dividends, rights issues',
    ),
    // s51: 'alert' · "Raise one, or track yours" — real, wired
    // (complaint_screen.dart posts to a real backend). Not previously a
    // hub row (only reachable via Help & support's "File a complaint"
    // button); s51 draws it as its own row, so it's added here too — both
    // entry points are real, neither is fake.
    ('Complaints', Routes.acctComplaint, 'alert', 'Raise one, or track yours'),
    // D-2 (SHARED-CHANGES.md, 2026-08-27 removals pass, R-16): permanent
    // entry point for price_alerts_screen.dart now that watchlist_screen.dart
    // — its only other entry point — is gone. Keeps s50 reachable and gives
    // the saved-assets data (WatchlistRepository) a reader. Not an s51 row.
    ('My alerts', Routes.priceAlerts, 'bell', 'Price alerts on saved assets'),
    // Restored 2026-08-27: was hidden 2026-08-24 (direct instruction:
    // "please hide everything on tax") because the mobile StatementKind
    // enum had no tax kinds, so tax_documents_screen.dart could only show
    // static "not available" copy. That's fixed — the enum now carries
    // `whtCreditNote`/`annualTaxSummary` (statements_repository.dart) and
    // the screen makes real `GET /statements?kind=` calls for both, so the
    // row no longer points at a dead end.
    (
      'Tax documents',
      Routes.acctTax,
      'doc',
      'Annual summary, WHT credit notes',
    ),
    // s51 calls this row "Terms and disclosures" with a "All eight documents"
    // sub — R-8/C-4 (DECISIONS.md) already ruled the real set is 4
    // documents, not 8, so that clause is not transcribed (would be a
    // false claim). 2026-08-24: trailing document count removed per direct
    // product instruction as a separate, earlier decision.
    //
    // 2026-08-29 exactness pass: title corrected from "Legal" to s51's own
    // "Terms and disclosures" — no DECISIONS.md ruling authorises "Legal",
    // it was a paraphrase. Also moved back up to sit directly before "Data
    // and privacy" — s51's own row order is …Complaints → Terms and
    // disclosures → Data and privacy (its last drawn row); this used to sit
    // dead last, after two undrawn rows, which silently reordered the two
    // drawn rows relative to each other.
    ('Terms and disclosures', Routes.acctLegal, 'doc', 'Terms, risk disclosure, client agreement'),
    // s51: 'settings' · "Consents, export, deletion" — s51's own last row.
    // 2026-08-29 exactness pass: "Data & privacy" -> "Data and privacy" —
    // s51 spells it out, no ampersand; no ruling authorises the shorthand.
    ('Data and privacy', Routes.acctDataPrivacy, 'settings', 'Consents, export, deletion'),
    // Not an s51 row — kept, real, wired (FAQ + contact channels + file a
    // complaint).
    ('Help & support', Routes.acctHelp, 'mail', 'FAQs, contact, file a complaint'),
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
  late final _corpActionsRepo = CorporateActionsRepository(AppScope.read(context).apiClient);
  late Future<(PersonalInfo, AiCreditStatus, int)> _future = _load();

  // Local-only — no app-wide language/locale persistence exists anywhere in
  // this app yet, same as onboarding/welcome_slider_screen.dart's and
  // document_summary_screen.dart's own KLanguageSwitch usage.
  String _lang = 'en';

  // Drives the Log out button's spinner/disabled state while the real
  // network sign-out call is in flight — see _signOut's doc comment.
  bool _signingOut = false;

  Future<(PersonalInfo, AiCreditStatus, int)> _load() async {
    final infoFuture = _userRepo.personalInfo();
    final creditsFuture = _aiRepo.credits();
    final pendingFuture = _pendingCorpActions();
    return (await infoFuture, await creditsFuture, await pendingFuture);
  }

  /// Real count of rights issues/AGM meetings still waiting on this
  /// investor's decision — same "open and not yet acted on" test
  /// corporate_actions_screen.dart's own hub uses. This is a decorative
  /// sub-line on a menu row, not the hub's primary data, so a failure here
  /// falls back to 0 (no "N waiting" clause) rather than failing the whole
  /// Account screen's load.
  Future<int> _pendingCorpActions() async {
    try {
      final (rightsIssues, agmMeetings) =
          await (_corpActionsRepo.rightsIssues(), _corpActionsRepo.agmMeetings()).wait;
      final pendingRights =
          rightsIssues.where((r) => r.status == CorpActionStatus.open && !r.alreadyElected).length;
      final pendingAgm =
          agmMeetings.where((a) => a.status == CorpActionStatus.open && !a.alreadyVoted).length;
      return pendingRights + pendingAgm;
    } on ApiException {
      return 0;
    }
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final kycApproved = AppScope.of(context).kycApproved;
    return Scaffold(
      backgroundColor: KColor.bg,
      // AUDIT-2026-08-29 (s51 exactness pass): s51 draws "You" as a plain
      // 26px/800-weight title sitting directly under the status bar — NOT a
      // `KDetailHeader` bar with a back chevron (the prior comment here
      // defended that chevron by citing R-28's "pushed from Home's header
      // avatar", but R-28 only rules HOW this screen is reached, not what
      // its own header renders; s51 itself has no back affordance drawn
      // anywhere, same as every other tab-root screen — see
      // markets_screen.dart's identical bare `Text(_, style: KType.title())`
      // pattern, reused here rather than forking a new header widget).
      // Going back still works exactly as before: edge-swipe and hardware
      // back were never wired through the chevron in the first place.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 0),
              child: Align(alignment: Alignment.centerLeft, child: Text('You', style: KType.title())),
            ),
            Expanded(
              child: FutureBuilder<(PersonalInfo, AiCreditStatus, int)>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const KLoadingView();
                  }
                  if (snapshot.hasError) {
                    return KErrorView(onPrimary: _reload);
                  }
                  final (info, credits, pendingCorpActions) = snapshot.data!;
                  return _AccountBody(
                    info: info,
                    credits: credits,
                    pendingCorpActions: pendingCorpActions,
                    verified: kycApproved,
                    lang: _lang,
                    onLangChanged: (v) => setState(() => _lang = v),
                    // Personal info can change name/avatar (this screen's
                    // own header); Plans & credits can change the balance
                    // shown here (the compact meter + the menu row both push
                    // there) — both refetch this screen's data on return,
                    // same "persistent tab, never disposed, so nothing
                    // refreshes without this" fix as account_screen.dart's
                    // earlier stale-data bug.
                    onReturnFromPersonalInfo: _reload,
                    onReturnFromPlans: _reload,
                    signingOut: _signingOut,
                    onSignOut: () => _signOut(context, (busy) {
                      if (mounted) setState(() => _signingOut = busy);
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voluntary sign-out. Mirrors security_screen.dart's `_signOut` exactly —
/// same endpoint, same tolerance of a failed call, same `signOut()` (NOT
/// `forceSignOut()`, which would wipe this device's passcode; see
/// AppState.signOut()'s doc comment).
///
/// 2026-08-29 fix: reported live as "logout ... just hangs and shows
/// nothing until it goes through" — the real `/auth/logout` call is a
/// network round trip with no feedback while in flight. [onBusyChanged]
/// lets the caller (a State, since a plain function has nowhere to hold
/// that flag) show a pressed/disabled spinner button for the duration and
/// refuse a second tap.
Future<void> _signOut(BuildContext context, ValueChanged<bool> onBusyChanged) async {
  onBusyChanged(true);
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
  // Not reset on this success path — this screen is about to be popped by
  // the route change above, so there is no surviving mounted instance for
  // the reset to matter to.
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.info,
    required this.credits,
    required this.pendingCorpActions,
    required this.verified,
    required this.lang,
    required this.onLangChanged,
    required this.onReturnFromPersonalInfo,
    required this.onReturnFromPlans,
    required this.signingOut,
    required this.onSignOut,
  });

  final PersonalInfo info;
  final AiCreditStatus credits;
  final int pendingCorpActions;
  final bool verified;
  final String lang;
  final ValueChanged<String> onLangChanged;

  /// Whether the real /auth/logout network call is in flight — drives the
  /// Log out button's spinner and refusal of a second tap (see _signOut's
  /// doc comment above).
  final bool signingOut;
  final VoidCallback onSignOut;

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
    // s51's own caption is a single inline line: "✓ Verified · CHN 0912455"
    // — no account-lifecycle clause at all, because its mock investor is a
    // plain active/verified account. Real accountStatus (active/frozen/
    // dormant/...) is data the design's happy path never had to represent
    // but this screen must not silently drop — a frozen/dormant investor
    // losing that signal here is a real regression, not a cosmetic one — so
    // a non-active status is appended to whichever line (verified or
    // unverified) is showing, rather than invented into the design or thrown
    // away to match it (R-30: non-happy states are owed by us, not the
    // canvas).
    final hasChn = info.cscsNumber != '—' && info.cscsNumber.isNotEmpty;
    final statusLower = info.accountStatus.trim().toLowerCase();
    final nonActiveStatus = statusLower.isEmpty || statusLower == 'active'
        ? null
        : '${info.accountStatus[0].toUpperCase()}${info.accountStatus.substring(1)} account';
    // s51's own text for the verified line — "Verified" alone until KYC
    // assigns a CHN, then "Verified · CHN ####".
    final verifiedLine = [
      'Verified',
      if (hasChn) 'CHN ${info.cscsNumber}',
      ?nonActiveStatus,
    ].join(' · ');
    final unverifiedLine = [
      if (hasChn) 'CHN ${info.cscsNumber}',
      ?nonActiveStatus,
    ].join(' · ');
    final subtitle = verified ? verifiedLine : unverifiedLine;

    final rows = _menuRows(pendingCorpActions);

    return SingleChildScrollView(
      // Pushed screen now (R-28) — no floating KBottomNav sits under this
      // screen any more, so there's nothing to clear at the bottom; matches
      // the plain bottom:32 every other KAccountSubScaffold-chromed screen
      // scrolls to.
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header — AUDIT-2026-08-29/A-3 fix: s51 draws this row
          // (illustrated Avatar, name, and a small inline "✓ Verified · CHN
          // ..." line in `--gain`) inside its own paper/hairline card,
          // separate from the menu list below.
          //
          // 2026-08-29 exactness pass: the verified affordance itself was
          // still wrong — a `KStatusPill` badge reading "VERIFIED" plus a
          // separate "Account live" subtitle line, not s51's single inline
          // check-mark + "Verified · CHN ..." caption under the name. s51
          // draws no unverified state at all, so that branch keeps the
          // existing pill (a real, sensible non-happy state per R-30,
          // not an invented design element).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: KCard(
              padding: const EdgeInsets.all(18),
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
                        const SizedBox(height: 3),
                        if (verified)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KIcon('check', size: 13, color: KColor.gain),
                              const SizedBox(width: 6),
                              Text(subtitle, style: KType.data(color: KColor.gain)),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(subtitle, style: KType.data(color: KColor.ink3)),
                              const SizedBox(width: 8),
                              const KStatusPill(status: KStatus.pending, label: 'Unverified', small: true),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Plans & credits sits as its own compact row above the menu
          // group in the mockup (CreditMeter + a link) — link colour is the
          // design's default bare-`<a>` accent (var(--indicator)), not ink.
          // 2026-08-24: real balance (AiCreditStatus) instead of a hardcoded
          // 7-of-10 literal — see AiCreditsService on the backend.
          //
          // D-3 (SHARED-CHANGES.md, 2026-08-27 removals pass, R-6): parked
          // behind kAiCreditsEnabled along with the "Plans & credits" menu
          // row above — this is the other entry point into that screen.
          if (kAiCreditsEnabled)
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
          if (kAiCreditsEnabled) const SizedBox(height: 12),
          // Menu group — s51's own rows carry a leading icon bubble + a
          // one-line sub caption under each title (2026-08-27 exactness
          // pass against the CURRENT s51, replacing the prior pass's "bare
          // rows, no bubble" note — that note described the OLD, now
          // unrelated #s45; see this file's header for the R-5 correction).
          //
          // 2026-08-29 exactness pass: s51's own bubble is a tinted,
          // border-radius-12 plate (KIconBubble's [tint] prop, added this
          // pass), not this widget's plain neutral hairline circle — every
          // row is `--indicator-tint` except Corporate actions, which s51
          // draws on `--warm-tint` (still with an indicator-coloured icon).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  KAccountRow(
                    title: rows[i].$1,
                    icon: rows[i].$3,
                    iconTint: rows[i].$2 == Routes.corpActions ? KColor.warmTint : KColor.indicatorTint,
                    sub: rows[i].$4,
                    standalone: true,
                    onTap: () async {
                      await context.push(rows[i].$2);
                      if (rows[i].$2 == Routes.acctPersonal) {
                        onReturnFromPersonalInfo();
                      }
                    },
                    right: const KRowChevron(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Log out (2026-08-24, direct instruction: "logout should be on
          // the account screen please... its too hard to see"). s51 itself
          // draws NO sign-out affordance anywhere on the hub (re-verified
          // 2026-08-27 against the current s51 markup) — this row is a
          // kept, deliberate usability addition, not a design match.
          // Security keeps its own copy too (see security_screen.dart);
          // this is an addition, not a move, so neither route regresses for
          // anyone used to the other.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: KButton(
              label: 'Log out',
              variant: KButtonVariant.ghost,
              fullWidth: true,
              loading: signingOut,
              onPressed: signingOut ? null : onSignOut,
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
          // s51's own footer line, below its Log out button. Version number
          // dropped ("v3.1" in the artboard) — this app has no user-facing
          // build/version string convention anywhere else (checked); a
          // literal build number nobody maintains for user display would be
          // exactly the kind of unverified figure R-34 exists to keep out.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                'Kudimata Securities Ltd · SEC registered',
                textAlign: TextAlign.center,
                style: KType.micro(color: KColor.ink3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
