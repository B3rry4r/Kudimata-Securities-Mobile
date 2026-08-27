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
// STEP COUNT: the canvas's own checklist (s11) numbers this "Step 1 of 5"
// — but its 5 only covers the artboards the canvas drew. The app's OTHER
// (not-yet-renumbered) KYC screens say "of 8" — chn_screen.dart "2 of 8",
// id_upload.dart "3 of 8", liveness.dart/checking.dart "4 of 8",
// utility_bill.dart "5 of 8", bank_dcs_screen.dart "6 of 8",
// declarations_screen.dart "7 of 8", next_of_kin.dart "8 of 8". Neither
// number is right once R-9 is applied:
//   - The old "8" already excludes the dropped review-before-submit step
//     (it was never one of the 8 — see the removed _KycRow list this
//     screen's own kyc_intro.dart sibling used to carry). So dropping
//     review doesn't change 8 by itself.
//   - What DOES change it: s11's checklist counts "Documents uploaded ·
//     ID · utility bill" as ONE item, where the app currently runs it as
//     TWO separate steps (id_upload.dart step 3, utility_bill.dart step
//     5). Merging those per the canvas takes 8 down to 7.
// Real sequence: (1) BVN & NIN [this screen], (2) CHN, (3) Documents +
// address (s14/s17, merged), (4) Selfie (s15/s16), (5) Bank & DCS
// (s18/s18b), (6) Two questions/Declarations (s19), (7) Next of kin —
// order otherwise unchanged from the app's existing sequence. This screen
// ships "1 of 7"; every other KYC screen still says "of 8" and needs the
// same renumbering in one coordinated pass — filed as X-2 in
// docs/redesign/SHARED-CHANGES.md rather than done piecemeal here, since
// those are other agents' screens.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

// A Nigerian BVN/NIN are both exactly 11 numeric digits (see
// Kudimata-Securities-Backend .pipeline/conventions.md's BVN/NIN row).
final RegExp _digitsPattern = RegExp(r'^\d{11}$');

const int _kycTotalSteps = 7; // see the step-count note above

enum _Step { form, confirm }

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
      // s12 -> s13: BVN/NIN verified, show the read-only confirmation
      // rather than advancing straight into the next collection step.
      setState(() => _step = _Step.confirm);
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
                  : () => setState(() => _step = _Step.form),
              stepLabel: 'Verification · 1 of $_kycTotalSteps',
            ),
            const KycStepProgress(total: _kycTotalSteps, current: 1),
            Expanded(
              child: _step == _Step.form ? _buildForm() : _buildConfirm(),
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

  // ── s13 — Is this you? (read-only confirmation) ──────────────────────
  Widget _buildConfirm() {
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
          // BACKEND GAP (filed in docs/redesign/BACKEND_GAPS.md): the
          // draftStep1/getDraft response has no resolved name/date-of-birth
          // /phone from the BVN/NIN check — only masked bvn/nin and
          // pass-fail verificationSignals booleans. Per R-34, the figures
          // are omitted rather than shown as the canvas's mock "Adebayo
          // Okonkwo" — the row labels still ship, values read "—". Same
          // reasoning drops the design's "Matches the name on your
          // account" checkmark line entirely: that's a computed match
          // result with nothing to compute it from.
          Container(
            decoration: BoxDecoration(
              color: KColor.paper,
              border: Border.all(color: KColor.hairline, width: 1),
              borderRadius: KRadii.cardR,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: const Column(
              children: [
                KKeyValueRow(label: 'Name', value: '—', first: true),
                KKeyValueRow(label: 'Date of birth', value: '—'),
                KKeyValueRow(label: 'Phone', value: '—'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          KButton(
            label: "Yes, that's me",
            onPressed: () => context.go(Routes.kycChn),
          ),
          const SizedBox(height: 10),
          KButton(
            label: 'Re-enter BVN',
            variant: KButtonVariant.ghost,
            onPressed: () => setState(() => _step = _Step.form),
          ),
        ],
      ),
    );
  }
}
