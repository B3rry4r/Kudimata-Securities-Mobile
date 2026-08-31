// Stage 9 — Personal info (pushed).
//
// R-5 correction (2026-08-27, docs/redesign/DECISIONS.md): this file used
// to cite "#s49" — that id is from the OLD 97-screen canvas. The real,
// current artboard is `06 Account and Support.dc.html#s58` ("58 · Personal
// details"), which draws a materially different shape from what this
// screen had: an avatar+"Change avatar" row up top, a green "Verified"
// banner, three LOCKED rows (Legal name/DOB/CHN, each with a reason
// caption) rather than five plain label:value rows, and each editable
// field (Phone/Email/Home address) as its own tappable "Change" row rather
// than inline `KInput`s with one page-level "Save changes" button. Rebuilt
// against s58 below — see this file's per-section notes for what was and
// wasn't adopted verbatim.
//
// Screen title stays "Personal info", NOT s58's own "Personal details" —
// dormant_account_screen.dart (out of this pass's scope) already says
// "Account › Personal info" verbatim; see account_screen.dart's own note on
// the same row. SHARED-CHANGE REQUEST filed in the report (a repo-wide
// rename is a separate, reviewed pass, not a silent one-file drift).
//
// 2026-08-24: dropped the "Investor profile · {profile}" card + Retake
// link (direct product instruction, "we don't need that anymore"). The
// suitability questionnaire this used to point at (as still reachable
// elsewhere) is itself gone now — removed entirely, 2026-08-31, R-51,
// DECISIONS.md — so there is no "retake" affordance anywhere any more, not
// just not surfaced a second time here.
//
// Wired to GET /users/me (UserRepository.personalInfo — firstName/middleName/lastName/email/
// phone/dob/residentialAddress) and GET /kyc-submissions/me
// (KycRepository.me — masked bvn) per lib/data/api/README.md's
// FutureBuilder convention. Both are fetched together with Future.wait so
// the screen shows one loading state instead of two staggered ones.
//
// Legal name is deliberately NOT editable anywhere on this screen — s58's
// own locked row shows a lock glyph and, per its own caption ("Change it at
// your bank first, then ask us to re-check"), implies a bank-first process.
// NOT adopted: nothing in this app ties a legal-name correction to "your
// bank" — the real, existing process is "contact support" (Help & support
// already carries this), so that caption is used instead of transcribing an
// unverified claim about how a name change works (R-34/the brief's "claims,
// not just figures" rule).
//
// s58's own bottom "Go to Security" button + "Bank account changes live
// under Security, and take a 24-hour hold" line has TWO wrong claims for
// this app: bank accounts live under their own Account-hub row
// (Routes.acctBanks / bank_accounts_screen.dart), not under Security, and
// grepping the backend for any bank-account-change hold mechanism found
// nothing — same null result wallet_flows.dart's header comment already
// recorded for the withdraw-destination row's identical "24-hour security
// hold" claim. The footer element ships; its factual claims don't —
// destination corrected to the real bank-accounts screen, the hold clause
// dropped.
//
// City/state editing (added 2026-08-07, supersedes.json S-9) stays as a
// secondary "Add city & state" link, shown only while either is missing —
// not an s58 row at all, but real: the post-signup onboarding step can be
// skipped or fail with no way back to it, and this is the only other place
// in the app that completes them.
//
// 2026-08-29, product owner ruling: name, phone number and home address
// cannot be changed by the investor — only email can (identity/KYC-bound
// fields; the verified BVN/NIN submission was checked against them, and a
// silent change would break that tie). This OUTRANKS s58, which draws a
// "Change" affordance on Phone and Home address (per this file's own R-5
// note above, on old id "#s49" no less) — do not "fix" the missing
// affordance back in.
//
// Legal name was already locked (see _LockedRow below, pre-dating this
// ruling). Phone and Home address are now the SAME shape — plain,
// non-tappable value rows — rather than the editable-card shape s58 draws
// and this screen used to render. Their real, wired edit paths
// (`UserRepository.updateProfile(phone: …)` / `(residentialAddress: …)`,
// both live PATCH /users/me calls) are removed from this screen along with
// the "Change" affordance; the endpoint itself still accepts both fields —
// see this pass's report re: server-side lockdown being a separate task.
// Email is the one row that keeps a "Change" tap — still routed to the
// honest "not available yet" message below, since no email-change endpoint
// exists either (see this file's own `_emailNotAvailable` note and
// BACKEND_GAPS.md's "s58 — Personal details: no email-change capability").
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '../onboarding/_pickers.dart';
import 'account_widgets.dart';

/// Splits a stored E.164 phone into "dial label + local number" for
/// display — matching the canvas's `prefix="+234" value="801 234 5678"`
/// split (2026-08-23 exactness pass; the prior version showed the full
/// E.164 string in one plain field). 2026-08-29: this used to hardcode
/// `+234`, which was wrong the moment sign_up_screen.dart's phone field
/// stopped defaulting every account to Nigeria — a stored non-Nigerian
/// number would have rendered as garbage (`+234 +15551234567`). Now uses
/// the same [countryForE164]/[localPartOf] pair (_pickers.dart) that
/// splits a phone back apart everywhere else it's re-edited.
String _displayPhone(String raw) {
  if (raw.isEmpty) return '—';
  final country = countryForE164(raw);
  return '${country.dialLabel} ${localPartOf(raw, country)}';
}

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late final _userRepo = UserRepository(AppScope.read(context).apiClient);
  late final _kycRepo = KycRepository(AppScope.read(context).apiClient);
  late Future<(PersonalInfo, String)> _future = _load();

  Future<(PersonalInfo, String)> _load() async {
    final infoFuture = _userRepo.personalInfo();
    final bvnFuture = _fetchBvn();
    final info = await infoFuture;
    final bvn = await bvnFuture;
    return (info, bvn);
  }

  /// A 404 here just means this investor hasn't submitted KYC yet — a
  /// perfectly normal state (browsing no longer requires KYC first, see
  /// home_screen.dart's prompt card), not a reason to fail this whole
  /// screen. Mirrors asset_detail_screen.dart's `_fetchHolding` — same
  /// "404 on an optional secondary fetch means 'nothing yet', not an
  /// error" pattern.
  Future<String> _fetchBvn() async {
    try {
      final kyc = await _kycRepo.me();
      return kyc.bvn ?? '—';
    } on ApiException catch (e) {
      if (e.statusCode == 404) return '—';
      rethrow;
    }
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return KAccountSubScaffold(
      title: 'Personal info',
      // s58's own pinned-bottom footer — see this file's header note for
      // why its "Go to Security"/"24-hour hold" copy isn't transcribed
      // as-is. The element ships (a real, working destination); its two
      // false claims don't.
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.gutter, 14, KSpace.gutter, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bank account changes are made from Bank accounts & DCS.',
              style: KType.data(color: KColor.ink3),
            ),
            const SizedBox(height: 9),
            KButton(
              label: 'Go to bank accounts',
              onPressed: () => context.push(Routes.acctBanks),
            ),
          ],
        ),
      ),
      child: FutureBuilder<(PersonalInfo, String)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoadingView();
          }
          if (snapshot.hasError) {
            return KErrorView(
              onPrimary: _reload,
            );
          }
          final (info, bvn) = snapshot.data!;
          return _PersonalInfoBody(
            key: ValueKey(info.phone + info.residentialAddress + info.city + (info.state)),
            info: info,
            bvn: bvn,
            repo: _userRepo,
            onSaved: _reload,
          );
        },
      ),
    );
  }
}

class _PersonalInfoBody extends StatelessWidget {
  const _PersonalInfoBody({
    super.key,
    required this.info,
    required this.bvn,
    required this.repo,
    required this.onSaved,
  });

  final PersonalInfo info;
  final String bvn;
  final UserRepository repo;
  final VoidCallback onSaved;

  Future<void> _addCityState(BuildContext context) async {
    final saved = await showKSheet<bool>(
      context,
      title: 'City & state',
      child: _CityStateSheet(repo: repo, info: info),
    );
    if (saved == true) onSaved();
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final picked = await showAvatarPicker(context, selected: info.avatarKey);
    if (picked == null) return;
    await repo.updateProfile(avatarKey: picked);
    onSaved();
  }

  @override
  Widget build(BuildContext context) {
    // bvn/dob are blank for exactly one reason: this investor hasn't
    // submitted KYC yet (BVN comes from the KYC flow itself; DOB from the
    // post-signup onboarding step that leads into it) — never a data bug.
    final verified = bvn != '—';
    final missingKyc = bvn == '—' || info.dob == '—';
    final missingCityState = info.city == '—' || info.state == '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // s58's own top row: avatar + name + "Change avatar" link. Moved up
        // from the old "You can change these" card (2026-08-27 exactness
        // pass against s58) — avatar itself is a real, user-chosen field
        // not on s58 originally (added 2026-08-24, direct instruction),
        // kept in this new position rather than dropped.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (info.avatarKey != null)
              KAvatar(avatarKey: info.avatarKey!, size: 56)
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: KColor.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: KColor.hairline, width: 1),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(info.fullName, style: KType.cardTitle()),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _changeAvatar(context),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      info.avatarKey != null ? 'Change avatar' : 'Choose an avatar',
                      style: KType.data(color: KColor.indicator, w: KWeight.semibold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // s58: green "Verified" banner. Real (bvn present means KYC
        // cleared) — same statusApprovedTint/gain-check treatment
        // statements_screen.dart's own real green callout uses. s58's own
        // copy names a specific date ("Verified on 14 March 2026"); no
        // verification-date field exists anywhere (UserRepository /
        // KycRepository — checked), so that clause is dropped rather than
        // invented (R-34).
        if (verified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: KColor.statusApprovedTint, borderRadius: KRadii.illoR),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: KIcon('check', size: 17, color: KColor.gain),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Verified. Locked details come from your BVN and NIN.',
                    style: KType.data(color: KColor.ink2),
                  ),
                ),
              ],
            ),
          ),
        if (verified) const SizedBox(height: 16),
        // Locked rows — s58: Legal name / Date of birth / CHN, each with a
        // lock glyph + a reason caption (2026-08-27 exactness pass; the
        // prior single-line label:value card also carried a separate
        // "BVN · NIN" row, folded into the banner above instead, matching
        // s58 which doesn't draw it as its own row).
        //
        // "Account status" isn't an s58 row at all, but it's real and
        // directly relevant (the freeze feature makes it so) — kept as a
        // fourth, unlocked row rather than dropped, per the brief's "code
        // path serves more than the drawn moment" reasoning.
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _LockedRow(
                label: 'Legal name',
                value: info.fullName,
                sub: 'Contact support to change this.',
                first: true,
              ),
              _LockedRow(label: 'Date of birth', value: info.dob, sub: 'From your BVN record.'),
              _LockedRow(
                label: 'CHN',
                value: info.cscsNumber,
                sub: 'Issued by CSCS, stays with you for life.',
              ),
              _LockedRow(
                label: 'Account status',
                value: info.accountStatus.isEmpty
                    ? '—'
                    : info.accountStatus[0].toUpperCase() + info.accountStatus.substring(1),
                sub: null,
                showLock: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Found live 2026-08-19: blank "—" rows above with no explanation
        // read as broken. Route straight to the KYC intro rather than a
        // dead-end "contact support" — that copy only makes sense once
        // verified, for correcting an otherwise-locked field.
        if (missingKyc) ...[
          KAccountCard(
            children: [
              KAccountRow(
                title: 'Complete your KYC',
                sub: 'Verify your BVN and identity to fill in these details',
                right: const KRowChevron(),
                first: true,
                onTap: () => context.push(Routes.kycIntro),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        // 2026-08-29, product owner ruling (this file's header note): only
        // email is investor-editable now — Phone and Home address dropped
        // their "Change" affordance, so this section no longer promises to
        // change all three. Renamed from "You can change these".
        Text('Contact details'.upper, style: KType.label()),
        const SizedBox(height: 14),
        // s58: Phone / Email / Home address, each its own card row. s58
        // draws all three as tappable "Change" rows (not inline fields + one
        // page-level Save) with hint captions ("Needs an SMS code" / "Needs
        // an email code" / "Needs a recent utility bill") asserting
        // verification gates this app doesn't implement — those hints were
        // already dropped (R-34's "claims, not just figures"); "Employment
        // status" (s58's third field, a Select) stays skipped — no such
        // field exists anywhere in the backend's User model.
        //
        // Phone and Home address are now READ-ONLY (see this file's header
        // ruling note) — `onChange: null` renders the value with no
        // trailing "Change" link, same shape as _LockedRow's facts above
        // without duplicating that widget's lock-glyph/reason-caption
        // treatment, which is specifically for BVN/CSCS-sourced facts.
        _EditableFieldRow(
          label: 'Phone',
          value: _displayPhone(info.phone),
          onChange: null,
        ),
        const SizedBox(height: 10),
        // Read-only, like every other field on this screen. Ruled by the
        // product owner 2026-08-29: nothing here is investor-editable — not
        // name, phone or address, and not email either.
        //
        // This row used to keep a "Change" tap whose only outcome was a
        // snackbar saying email changes were not available yet. That was
        // honest while a change flow was still intended; once the ruling
        // said none is coming, an affordance that can only ever refuse is a
        // dead control, and a dead control is worse than an absent one — the
        // investor taps it, learns nothing they could not have been told,
        // and trusts the next control slightly less.
        //
        // Email deliberately has no change flow: it doubles as the login
        // credential and the password-reset destination, so swapping it
        // without verifying the new address would trade a locked-field
        // problem for an account-takeover one. If that changes, it needs an
        // OTP-verified flow, not a re-enabled button here.
        _EditableFieldRow(
          label: 'Email',
          value: info.email.isEmpty ? '—' : info.email,
          onChange: null,
        ),
        const SizedBox(height: 10),
        _EditableFieldRow(
          label: 'Home address',
          value: info.residentialAddress,
          onChange: null,
        ),
        if (missingCityState) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _addCityState(context),
            behavior: HitTestBehavior.opaque,
            child: Text('Add city & state', style: KType.data(color: KColor.indicator)),
          ),
        ],
      ],
    );
  }
}

/// One locked, label:value row with a lock glyph and a reason caption — s58's
/// Legal name / Date of birth / CHN shape. [showLock] is false for the
/// extra "Account status" row (real, kept, but not a BVN-derived fact s58
/// would show a lock glyph on).
class _LockedRow extends StatelessWidget {
  const _LockedRow({
    required this.label,
    required this.value,
    required this.sub,
    this.first = false,
    this.showLock = true,
  });

  final String label;
  final String value;
  final String? sub;
  final bool first;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: first ? BorderSide.none : BorderSide(color: KColor.hairline, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: KType.data(color: KColor.ink3)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(value, style: KType.cardTitle(), textAlign: TextAlign.right)),
                  if (showLock) ...[
                    const SizedBox(width: 6),
                    KIcon('lock', size: 13, color: KColor.ink3),
                  ],
                ],
              ),
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: KType.micro(color: KColor.ink3)),
          ],
        ],
      ),
    );
  }
}

/// One field's own bordered row — s58's Phone/Email/Home address shape
/// (small caption label, bold value, a "Change" link), replacing the old
/// inline `KInput` + page-level "Save changes" button.
///
/// [onChange] is nullable (2026-08-29, product owner ruling — see this
/// file's header note): Phone and Home address are no longer investor-
/// editable, so they render as a plain value with no trailing "Change"
/// link, while Email keeps one.
class _EditableFieldRow extends StatelessWidget {
  const _EditableFieldRow({required this.label, required this.value, required this.onChange});

  final String label;
  final String value;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: KType.micro(color: KColor.ink3)),
                const SizedBox(height: 2),
                Text(value, style: KType.cardTitle()),
              ],
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onChange,
              behavior: HitTestBehavior.opaque,
              child: Text('Change', style: KType.data(color: KColor.indicator, w: KWeight.semibold)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Secondary sheet for the city/state completion gap (see this file's
/// header comment) — kept out of the main inline form so the screen still
/// matches the canvas exactly once both are already set.
class _CityStateSheet extends StatefulWidget {
  const _CityStateSheet({required this.repo, required this.info});

  final UserRepository repo;
  final PersonalInfo info;

  @override
  State<_CityStateSheet> createState() => _CityStateSheetState();
}

class _CityStateSheetState extends State<_CityStateSheet> {
  late final _city = TextEditingController(
    text: widget.info.city == '—' ? '' : widget.info.city,
  );
  late String? _state = widget.info.state == '—' ? null : widget.info.state;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickState() async {
    final picked = await showStatePicker(context, selected: _state);
    if (picked != null) setState(() => _state = picked);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.updateProfile(
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        state: _state,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KInput(
          label: 'City',
          placeholder: 'Ikeja',
          controller: _city,
        ),
        const SizedBox(height: 16),
        _TappableField(
          label: 'State',
          value: _state,
          placeholder: 'Select your state',
          onTap: _pickState,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: KType.micro(color: KColor.loss)),
        ],
        const SizedBox(height: 22),
        KButton(
          label: 'Save',
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Same styling as onboarding/personal_details_screen.dart's file-local
/// `_TappableField` (KInput-styled but read-only/tappable, opens a picker
/// sheet) — duplicated rather than shared per this codebase's convention;
/// lib/widgets/ is frozen so this can't live there.
class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.upper, style: KType.label(color: KColor.ink2)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: KColor.paper,
              borderRadius: BorderRadius.circular(KRadii.input),
              border: Border.all(color: KColor.hairline, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    style: KType.body(color: value != null ? KColor.ink : KColor.ink3),
                  ),
                ),
                const SizedBox(width: 10),
                KIcon('arrowDown', size: 16, color: KColor.ink3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
