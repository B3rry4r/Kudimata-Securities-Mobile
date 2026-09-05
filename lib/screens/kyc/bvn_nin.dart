// KYC — BVN + NIN, artboards s12 "BVN & NIN" and s13 "Details from BVN"
// (docs/design/redesign-2026-08/02 Verification.dc.html) per RULINGS.md.
// Both are "step 1" of the flow, so they live in one file as two internal
// steps (_Step.form / _Step.confirm) rather than two routes: s13 is a
// read-only confirmation the investor either accepts or bounces back from
// to re-enter s12's fields — the same round trip the canvas draws between
// the two artboards.
//
// Ruling R-19 (docs/redesign/DECISIONS.md): BVN/NIN auto-populate is
// adopted, so s13 confirms name/DOB/phone as BVN returned them rather than
// collecting anything — and it must NOT collect an address; that stays a
// separate step elsewhere in the flow (s17, another screen agent's file).
//
// Submits directly to the backend: POST /kyc-submissions/draft {bvn, nin}
// — this call VERIFIES both numbers server-side (via the multi-provider
// KYC chain) AND creates the draft KycSubmission every later step operates
// on. Calling it again (e.g. the investor backs up and edits a typo) just
// re-verifies against the SAME existing draft — see
// KycRepository.draftStep1's doc comment.
//
// STEP COUNT — this file no longer holds one. It used to declare a private
// `_kycTotalSteps` that every other KYC screen then re-spelled as a `7`
// literal; the count now lives in exactly one place, [kKycTotalSteps] in
// _kyc_chrome.dart, and this screen (like every other) states only WHICH step
// it is via [kycStepLabel]. Real sequence: (1) BVN & NIN [this screen],
// (2) CHN, (3) Documents + address (s14/s17, merged), (4) Selfie (s15/s16),
// (5) Bank & DCS (s18/s18b), (6) Source of funds (2026-09-04, SEC No
// Objection condition 2), (7) Declarations (s19), (8) Next of kin.
// personal_details_screen.dart (onboarding/) is NOT and never was one of
// these — see kyc_intro.dart's header for where its fields ended up after
// the A-1 audit fix below.
//
// A-2 (2026-08-29 product-owner audit) — two fixes to s13's confirmation:
//   1. resolvedName/resolvedDob/resolvedPhone (BR-4, MOBILE-REQUESTS.md) now
//      exist on the draftStep1/getDraft response — wired below instead of
//      the "—" placeholders this screen shipped with when the backend gap
//      was still open.
//   2. "if there's a failure in bvn why should it populate dash fields and
//      user still continues" — a draftStep1 call ALWAYS returns 200
//      (verification is a same-call synchronous check, not an async
//      decision), so a real bvn/nin mismatch was previously
//      indistinguishable from a genuine pass: both landed on "Is this
//      you?" with a "Yes, that's me" the investor could just tap through.
//      `verificationSignals.bvn`/`.nin` being explicitly `false` (a real
//      failure, not merely unresolved/null — see KycVerificationSignals'
//      doc comment) now routes to a blocking `_Step.failed` state instead,
//      with no way past it except fixing the numbers and retrying.
//
// A-1 (2026-08-29 audit — "why is there a few more details screen?"): DOB
// collection folds in here now that onboarding/personal_details_screen.dart
// is off the KYC path (see kyc_intro.dart's header). Most investors get
// resolvedDob from the registry lookup above and never see an extra field;
// this only asks directly when the registry didn't resolve one AND the
// account has no dob on file yet.
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
import '_kyc_chrome.dart';

// A Nigerian BVN/NIN are both exactly 11 numeric digits (see
// Kudimata-Securities-Backend .pipeline/conventions.md's BVN/NIN row).
final RegExp _digitsPattern = RegExp(r'^\d{11}$');

enum _Step { form, confirm, failed }

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatDobDisplay(DateTime d) => '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

String _formatDobIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class BvnNinScreen extends StatefulWidget {
  const BvnNinScreen({super.key});

  @override
  State<BvnNinScreen> createState() => _BvnNinScreenState();
}

class _BvnNinScreenState extends State<BvnNinScreen> {
  final _bvn = TextEditingController();
  final _nin = TextEditingController();

  late final _repo = KycRepository(AppScope.read(context).apiClient);

  _Step _step = _Step.form;
  bool _showErrors = false;
  bool _busy = false;
  String? _error;

  // ── Confirm step (s13) state ─────────────────────────────────────────
  KycSubmissionStatus? _confirmResult;

  /// True when neither the registry lookup (resolvedDob) nor the account's
  /// own on-file record has a date of birth — see this file's header (A-1).
  bool _needsDobEntry = false;
  DateTime? _pickedDob;
  bool _confirmShowErrors = false;
  bool _confirmBusy = false;
  String? _confirmError;

  @override
  void dispose() {
    _bvn.dispose();
    _nin.dispose();
    super.dispose();
  }

  Future<void> _confirmBvn() async {
    final bvnValid = _digitsPattern.hasMatch(_bvn.text.trim());
    final ninValid = _digitsPattern.hasMatch(_nin.text.trim());
    if (!bvnValid || !ninValid) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _repo.draftStep1(bvn: _bvn.text.trim(), nin: _nin.text.trim());
      if (!mounted) return;
      final id = result.id;
      if (id != null) AppScope.read(context).kycForm.setDraftId(id);

      // A-2: an explicit `false` is a real verification failure — block
      // continuing rather than showing "Is this you?" with dashes/blanks a
      // "Yes, that's me" could sail past. `null` (never resolved — e.g. a
      // provider outage) is left alone: that's not a failure, it's the
      // existing "unresolved" state finalizeDraft()'s own decision already
      // accounts for later.
      final signals = result.verificationSignals;
      if (signals?.bvn == false || signals?.nin == false) {
        setState(() {
          _confirmResult = result;
          _step = _Step.failed;
        });
        return;
      }

      // A-1: fold DOB collection in here. Only ask directly when the
      // registry gave nothing AND the account has nothing on file already
      // (a returning investor redoing KYC after a rejection/expiry may
      // already have one from a previous pass). When the registry DID
      // resolve one and the account has none on file yet, best-effort
      // auto-save it — see the doc comment on the write below.
      var needsDobEntry = false;
      if (result.resolvedDob == null) {
        String existingDob = '—';
        try {
          existingDob = (await UserRepository(AppScope.read(context).apiClient).personalInfo()).dob;
        } on ApiException {
          // Best-effort — see this method's other catches. Falls through to
          // asking directly, the safe default (never worse than asking once
          // more of someone who already has one on file).
        }
        needsDobEntry = existingDob == '—';
      } else {
        // Registry resolved one — persist it onto the account if nothing's
        // there yet, so `KycSubmission.dob` (which reads the ACCOUNT's
        // on-file value, not this resolved one — see the backend's
        // runIdentityAndAmlChecks doc comment) doesn't stay null purely for
        // want of a write nobody triggered. Best-effort/fire-and-forget in
        // spirit, but awaited so a failure here can be surfaced rather than
        // silently lost — a failure just means the DOB entry may be asked
        // for again later; it never blocks this step.
        try {
          final client = AppScope.read(context).apiClient;
          final existing = (await UserRepository(client).personalInfo()).dob;
          if (!mounted) return;
          if (existing == '—') {
            await UserRepository(client).updateProfile(dob: result.resolvedDob);
          }
        } on ApiException {
          // Non-fatal — the resolved value still displays on this screen
          // either way.
        }
      }

      if (!mounted) return;
      setState(() {
        _confirmResult = result;
        _needsDobEntry = needsDobEntry;
        _step = _Step.confirm;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      // Widened from `on ApiException` only (2026-08-20) — any OTHER
      // exception type used to propagate uncaught, which left `_busy`
      // stuck true forever (a permanent loading spinner) since nothing
      // reset it; see kyc_intro.dart's fix for the report that caught this.
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final adultCutoff = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDob ?? adultCutoff,
      firstDate: DateTime(now.year - 100),
      lastDate: adultCutoff,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _pickedDob = picked);
  }

  Future<void> _proceedFromConfirm() async {
    if (_needsDobEntry && _pickedDob == null) {
      setState(() => _confirmShowErrors = true);
      return;
    }
    if (_needsDobEntry) {
      setState(() {
        _confirmBusy = true;
        _confirmError = null;
      });
      try {
        await UserRepository(AppScope.read(context).apiClient)
            .updateProfile(dob: _formatDobIso(_pickedDob!));
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _confirmBusy = false;
          _confirmError = e.message;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _confirmBusy = false);
    }
    if (!mounted) return;
    context.go(Routes.kycChn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KycTopBar(
              onBack: _step == _Step.form
                  ? () => context.go(Routes.kycIntro)
                  : () => setState(() {
                        _step = _Step.form;
                        _confirmResult = null;
                      }),
              stepLabel: kycStepLabel(1),
            ),
            const KycStepProgress(current: 1),
            Expanded(
              child: switch (_step) {
                _Step.form => _buildForm(),
                _Step.confirm => _buildConfirm(),
                _Step.failed => _buildFailed(),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── s12 — Your BVN and NIN ────────────────────────────────────────────
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KScreenHead(
            title: 'Your BVN and NIN',
            body: "Used once, to confirm you're you. Both must match your official names.",
          ),
          const SizedBox(height: 24),
          KInput(
            label: 'BVN (Bank Verification Number)',
            numeric: true,
            placeholder: '11 digits',
            helper: 'Dial *565*0# on your registered line to see it',
            error: _showErrors && !_digitsPattern.hasMatch(_bvn.text.trim())
                ? 'Enter a valid 11-digit BVN'
                : null,
            controller: _bvn,
            onChanged: (_) {
              if (_showErrors) setState(() {});
            },
            required: true,
          ),
          const SizedBox(height: 20),
          KInput(
            label: 'NIN (National Identification Number)',
            numeric: true,
            placeholder: '11 digits',
            helper: 'On your NIN slip or dial *346#',
            error: _showErrors && !_digitsPattern.hasMatch(_nin.text.trim())
                ? 'Enter a valid 11-digit NIN'
                : null,
            controller: _nin,
            onChanged: (_) {
              if (_showErrors) setState(() {});
            },
            required: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: KType.body(color: KColor.loss)),
          ],
          const SizedBox(height: 20),
          // Compact trust strip (s12's shield note) — NOT the heavier
          // KExplainPanel "comprehension layer" card the previous build of
          // this screen used; that component is a different, roomier
          // pattern (avatar + registered header) the artboard doesn't draw
          // here. "How we protect it" has no real destination in the
          // canvas (its own onClick points back at itself) or anywhere in
          // this app, so it renders as plain copy rather than a dead tap
          // target.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: KRadii.cardR,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KIcon('shield', size: 20, color: KColor.gain),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Your BVN and NIN can't be used to move money. How we protect it",
                    style: KType.body(color: KColor.ink2).copyWith(fontSize: 14, height: 20 / 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          KButton(
            label: 'Confirm BVN',
            loading: _busy,
            onPressed: _busy ? null : _confirmBvn,
          ),
        ],
      ),
    );
  }

  // ── s13 — Is this you? (read-only confirmation, now real data — A-2) ──
  Widget _buildConfirm() {
    final result = _confirmResult!;
    final dobText = result.resolvedDob != null
        ? _formatDobDisplay(DateTime.parse(result.resolvedDob!))
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KScreenHead(
            title: 'Is this you?',
            body: "From your BVN and NIN records. If something's wrong, fix it at your bank first.",
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: KRadii.cardR,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                KKeyValueRow(label: 'Name', value: result.resolvedName ?? '—', first: true),
                if (!_needsDobEntry)
                  KKeyValueRow(label: 'Date of birth', value: dobText ?? '—')
                else
                  _DobPickerRow(
                    value: _pickedDob != null ? _formatDobDisplay(_pickedDob!) : null,
                    onTap: _pickDob,
                    error: _confirmShowErrors && _pickedDob == null,
                  ),
                KKeyValueRow(label: 'Phone', value: result.resolvedPhone ?? '—'),
              ],
            ),
          ),
          if (_needsDobEntry) ...[
            const SizedBox(height: 10),
            Text(
              "We couldn't get your date of birth from your BVN/NIN — enter it once here.",
              style: KType.body(color: KColor.ink3).copyWith(fontSize: 13, height: 18 / 13),
            ),
          ],
          if (_confirmShowErrors && _needsDobEntry && _pickedDob == null) ...[
            const SizedBox(height: 8),
            Text('Select your date of birth to continue',
                style: KType.micro(color: KColor.loss).copyWith(letterSpacing: 0.02 * 10)),
          ],
          if (_confirmError != null) ...[
            const SizedBox(height: 12),
            Text(_confirmError!, style: KType.body(color: KColor.loss)),
          ],
          const SizedBox(height: 28),
          KButton(
            label: "Yes, that's me",
            loading: _confirmBusy,
            onPressed: _confirmBusy ? null : _proceedFromConfirm,
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Re-enter BVN',
            variant: KButtonVariant.ghost,
            onPressed: _confirmBusy
                ? null
                : () => setState(() {
                      _step = _Step.form;
                      _confirmResult = null;
                    }),
          ),
        ],
      ),
    );
  }

  // ── A-2: blocking failure state — a real bvn/nin mismatch, not merely
  // unresolved. No way past this except fixing the numbers and retrying.
  Widget _buildFailed() {
    final signals = _confirmResult?.verificationSignals;
    final reasons = <String>[
      if (signals?.nin == false) 'Your NIN could not be verified',
      if (signals?.bvn == false) 'Your BVN could not be verified',
    ];
    final message = reasons.isNotEmpty
        ? '${reasons.join('. ')}. Double-check the numbers and try again.'
        : "We couldn't verify those details. Double-check the numbers and try again.";
    return KCentered(
      child: KStatusView(
        tone: KStatusTone.error,
        title: "We couldn't verify you",
        message: message,
        primary: 'Try again',
        onPrimary: () => setState(() {
          _step = _Step.form;
          _confirmResult = null;
        }),
      ),
    );
  }
}

/// The DOB row when it needs to be collected directly (A-1) — same visual
/// rhythm as [KKeyValueRow] (label left, value right, hairline divider) but
/// tappable, with a chevron affordance matching this screen's other
/// tappable rows elsewhere in the app. File-local: nothing else in this
/// screen needs a tappable key/value row.
class _DobPickerRow extends StatelessWidget {
  const _DobPickerRow({required this.value, required this.onTap, required this.error});
  final String? value;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: KColor.hairline, width: 1)),
        ),
        child: Row(
          children: [
            RichText(
              text: TextSpan(
                text: 'Date of birth',
                style: KType.data(color: KColor.ink2),
                children: [
                  TextSpan(text: ' *', style: KType.data(color: KColor.loss)),
                ],
              ),
            ),
            const Spacer(),
            Text(
              value ?? 'Select',
              style: KType.data(color: error ? KColor.loss : (value != null ? KColor.ink : KColor.ink3)).tnum,
            ),
            const SizedBox(width: 6),
            KIcon('arrowDown', size: 14, color: error ? KColor.loss : KColor.ink3),
          ],
        ),
      ),
    );
  }
}
