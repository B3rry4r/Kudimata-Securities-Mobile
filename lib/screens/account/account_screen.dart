// Stage 9 — Account hub (root tab). Profile header (Avatar + StatusPill) +
// a compact credits row + a grouped menu of the account sub-screens +
// LanguageSwitch. Root tab: builds a Scaffold body WITHOUT a bottom nav (the
// shell owns KBottomNav). Mirrors `Profile` in settings-screens.jsx.
//
// Wired to GET /users/me (personalInfo — cscsNumber/accountStatus/fullName),
// GET /bank-accounts (primary bank's masked number for the "Bank accounts &
// DCS" row) and GET /legal-documents (row count for "Legal") per
// lib/data/api/README.md's FutureBuilder convention. "Verified" comes from
// AppState.kycApproved — already refreshed at login (see
// refreshKycGatingState), so no extra fetch is needed for it. "Log out" was
// removed from this screen (2026-08-23 exactness pass): the canvas's #s45
// body has no sign-out affordance at all — that lives on Security (#s50,
// see security_screen.dart) instead, alongside "Freeze my account".
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/data/repositories/legal_documents_repository.dart';
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
List<(String title, String route, String? trailing)> _menuRows({
  required BankAccountSummary? primaryBank,
  required int? legalDocCount,
}) {
  final bankTrailing =
      primaryBank == null ? null : '${primaryBank.bankName} ${primaryBank.accountNumberMasked}';
  final legalTrailing = (legalDocCount == null || legalDocCount == 0)
      ? null
      : '$legalDocCount document${legalDocCount == 1 ? '' : 's'}';
  return [
    ('Personal info', Routes.acctPersonal, null),
    ('Bank accounts & DCS', Routes.acctBanks, bankTrailing),
    ('Plans & credits', Routes.acctPlans, null),
    ('Statements & documents', Routes.acctStatements, null),
    ('Security', Routes.acctSecurity, null),
    ('Refer & earn', Routes.acctRefer, null),
    ('Corporate actions', Routes.corpActions, null),
    ('Tax documents', Routes.acctTax, null),
    ('Data & privacy', Routes.acctDataPrivacy, null),
    ('Help & support', Routes.acctHelp, null),
    ('Legal', Routes.acctLegal, legalTrailing),
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
  late final _banksRepo = BankAccountsRepository(AppScope.read(context).apiClient);
  late final _legalRepo = LegalDocumentsRepository(AppScope.read(context).apiClient);
  late Future<(PersonalInfo, BankAccountSummary?, int?)> _future = _load();

  // Local-only — no app-wide language/locale persistence exists anywhere in
  // this app yet, same as onboarding/welcome_slider_screen.dart's and
  // document_summary_screen.dart's own KLanguageSwitch usage.
  String _lang = 'en';

  Future<(PersonalInfo, BankAccountSummary?, int?)> _load() async {
    final infoFuture = _userRepo.personalInfo();
    final bankFuture = _fetchPrimaryBank();
    final legalFuture = _fetchLegalCount();
    final info = await infoFuture;
    final bank = await bankFuture;
    final legalCount = await legalFuture;
    return (info, bank, legalCount);
  }

  /// A 404/empty list just means no bank account is linked yet — a normal
  /// state (see bank_accounts_screen.dart's own empty state), not a reason
  /// to fail this whole screen. Same "optional secondary fetch" pattern as
  /// personal_info_screen.dart's `_fetchBvn`. Catches broadly (not just
  /// [ApiException]): the trailing meta text on this row is purely
  /// cosmetic, so any failure to fetch it — including a malformed response
  /// — should degrade to "no trailing text", never take down the whole
  /// Account hub.
  Future<BankAccountSummary?> _fetchPrimaryBank() async {
    try {
      final accounts = await _banksRepo.list();
      if (accounts.isEmpty) return null;
      for (final a in accounts) {
        if (a.primary) return a;
      }
      return accounts.first;
    } catch (_) {
      return null;
    }
  }

  /// Same "cosmetic trailing text, never worth failing the screen over"
  /// reasoning as [_fetchPrimaryBank].
  Future<int?> _fetchLegalCount() async {
    try {
      final docs = await _legalRepo.list();
      return docs.length;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycApproved = AppScope.of(context).kycApproved;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(PersonalInfo, BankAccountSummary?, int?)>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const KLoadingView();
            }
            if (snapshot.hasError) {
              return KErrorView(
                onPrimary: () => setState(() => _future = _load()),
              );
            }
            final (info, primaryBank, legalCount) = snapshot.data!;
            return _AccountBody(
              info: info,
              primaryBank: primaryBank,
              legalCount: legalCount,
              verified: kycApproved,
              lang: _lang,
              onLangChanged: (v) => setState(() => _lang = v),
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
    required this.primaryBank,
    required this.legalCount,
    required this.verified,
    required this.lang,
    required this.onLangChanged,
  });

  final PersonalInfo info;
  final BankAccountSummary? primaryBank;
  final int? legalCount;
  final bool verified;
  final String lang;
  final ValueChanged<String> onLangChanged;

  @override
  Widget build(BuildContext context) {
    // Subtitle mirrors the canvas's "CHN 1234567890 · NGX account live"
    // shape with real data: cscsNumber is '—' until KYC assigns one, and
    // accountStatus reflects the real lifecycle state (active/frozen/
    // dormant/...) rather than assuming every account is live.
    final hasChn = info.cscsNumber != '—' && info.cscsNumber.isNotEmpty;
    final statusLower = info.accountStatus.trim().toLowerCase();
    final statusText = statusLower.isEmpty || statusLower == 'active'
        ? 'NGX account live'
        : '${info.accountStatus[0].toUpperCase()}${info.accountStatus.substring(1)} account';
    final subtitle = hasChn ? 'CHN ${info.cscsNumber} · $statusText' : statusText;

    final rows = _menuRows(primaryBank: primaryBank, legalDocCount: legalCount);

    return SingleChildScrollView(
      // Root tab: clear the floating KBottomNav (~70px + margin + safe area)
      // so the menu's bottom row isn't hidden behind it.
      padding: const EdgeInsets.only(top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header — canvas mockup #s45 uses the illustrated Avatar
          // (seeded per-user, per readme.md's "Characters are generated, not
          // drawn"), a "CHN ... · NGX account live" subtitle, and a
          // "Verified" StatusPill next to it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Row(
              children: [
                KAvatar(seed: info.email, size: 56),
                const SizedBox(width: 14),
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
                    onTap: () => context.push(rows[i].$2),
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
