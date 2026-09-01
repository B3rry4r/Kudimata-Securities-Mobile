// KYC checklist hub — artboard s11/s11d ("02 Verification.dc.html" per
// RULINGS.md). NEW screen (R-33-style build work — no app counterpart existed;
// this screen agent's own assignment names it explicitly).
//
// Functionally distinct from kyc_intro.dart (s10): s10 is a one-shot entry
// with resume logic, entered once before step 1 exists. s11 is the flow's
// SPINE — "every later step returns to it" (the canvas's own section-2
// caption) — meant to be re-entered after EVERY completed step, not just at
// the start.
//
// ROUTING — RESOLVED (2026-08-29 audit): the S-8 route request below has
// landed. `Routes.kycChecklist` ('/kyc/checklist') is registered in
// app_router.dart as a themed+gated GoRoute, and it's part of the KYC-flow
// route set app_router.dart tracks for its own back-stack handling. Left the
// history above intact — see kyc_intro.dart's `_start()` for the real
// resume entry point onto this screen.
//
// PROGRESS — derived from real data, nothing invented:
//   step 1 BVN & NIN   — a draft exists at all (draftStep1 always sets both).
//   step 2 CHN         — draft.chn != null, OR a primary-ID document exists
//                         (proof the investor already moved past CHN via a
//                         deliberate skip, which leaves chn permanently
//                         null — see _loadChecklistSteps's own note on
//                         `chnDone`).
//   step 3 Documents   — ID + address, ONE checklist item per s11's own
//                         "Documents uploaded · ID · utility bill" row. Done
//                         once `draft.documents` contains BOTH a primary-ID
//                         kind (nin/passport/drivers_licence/voters_card)
//                         AND a proof_of_address kind.
//   step 4 Selfie      — draft.documents contains a liveness_selfie kind.
//   step 5 Bank & DCS  — a primary BankAccountSummary exists
//                         (BankAccountsRepository.list()).
//   step 6 Declarations — pepSelfDeclared != null (a Yes/No has actually
//                         been recorded server-side). The screen's old
//                         second question (broker/NGX employment) was
//                         removed entirely 2026-09-01 (owner ruling — see
//                         declarations_screen.dart's header) rather than
//                         ever gaining a backend field, so pepSelfDeclared
//                         alone is now a complete signal for this step.
//   step 7 Next of kin — never independently "done" while status=='draft':
//                         finalizeDraft() submits next-of-kin AND leaves
//                         'draft' in the same call, so this is always the
//                         last remaining item once 1-6 are done.
//
// 2026-08-29 (product-owner audit — resume loop: "did the document upload,
// went to liveness, closed the app... reopened, did documents again, did
// the selfie, went to checking, and it took me back to document upload
// again!"): steps 2-4 above used to be read off `draft.currentStep`
// (`cs`) — the backend's PHASED-KYC counter — instead of the real document
// evidence now used: `chnDone = cs > 2`, `documentsDone = cs >= 5`,
// `selfieDone = cs >= 4`. That counter is a single sequential number
// (computeCurrentStep(), kyc-submissions.service.ts): it only reaches 4
// once liveness is VERIFIED (not merely uploaded — `livenessVerifiedSignal`
// set, which only happens once checking.dart's own POST /kyc-submissions/
// draft/liveness call completes), and only reaches 5 once liveness AND the
// utility bill are BOTH done. So `documentsDone` (an item that has nothing
// to do with liveness) silently required liveness to ALSO be verified, and
// if that verification call was ever slow, retried, or interrupted (app
// killed mid-check, exactly as reported), `cs` stayed stuck below 4-5 even
// though the ID document really was uploaded — sending `nextKycStepRoute`
// back to Documents forever. `draft.documents` (already parsed —
// KycRepository, KycDocumentSummary) carries the real per-document
// evidence directly and is used for every one of steps 2-4 now; none of
// them reads `currentStep` any more. Per-item "done" can never regress
// once evidence exists, which a single derived counter could.
//
// NOTE — steps 3 and 4 are not always done in canvas order. The app's own
// real navigation chain reaches liveness (step 4) BEFORE utility_bill.dart
// (the address half of step 3) — see id_upload.dart's own routing. So it is
// possible to observe step 4 done while step 3 (documents) is not. This
// screen shows that honestly rather than reordering or hiding it: R-34's
// spirit is "reflect what's real", and pretending steps always complete in
// numeric order would be the same kind of invention R-34 forbids for a
// figure.
//
// A-4 (2026-08-29 product-owner audit — "two foolish screens that can
// interrupt when you want to go to the next thing"): this hub used to sit
// BETWEEN every consecutive step — chn_screen.dart, checking.dart,
// bank_dcs_screen.dart and declarations_screen.dart all routed here on
// completion, forcing a tap through this screen's own UI just to continue.
// The step derivation below is unchanged and still correct (it's the one
// place that logic should live — X-5, SHARED-CHANGES.md), but it's now
// ALSO exposed as [nextKycStepRoute], a plain function with no UI, which
// those four screens call directly to advance straight to the real next
// step instead. This screen itself is unchanged and stays reachable as the
// RESUME point for an investor re-entering KYC part-way (kyc_intro.dart's
// `_start()`) — it just no longer sits between two steps that are both
// already in progress.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_client.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class KycChecklistScreen extends StatefulWidget {
  const KycChecklistScreen({super.key});

  @override
  State<KycChecklistScreen> createState() => _KycChecklistScreenState();
}

class _ChecklistStep {
  const _ChecklistStep({required this.title, required this.note, required this.done, required this.route});
  final String title;
  final String note;
  final bool done;
  final String route;
}

/// Document kinds that count as a "primary ID" for the Documents checklist
/// item — matches Prisma's `KycDocumentKind`/`KycSubmissionDocumentType`
/// enums (`Kudimata-Securities-Backend/prisma/schema.prisma`) and
/// id_upload.dart's own picker (including 'voters_card', added 2026-08-29).
const _primaryIdDocumentKinds = {'nin', 'passport', 'drivers_licence', 'voters_card'};

/// The real per-step "done" derivation — shared by this screen's own hub UI
/// and [nextKycStepRoute] below. See this file's header for the per-step
/// rules, the 2026-08-29 fix away from the backend's `currentStep` counter,
/// and the out-of-order-completion note.
Future<List<_ChecklistStep>> _loadChecklistSteps(ApiClient client, {bool chnSkipped = false}) async {
  final kycRepo = KycRepository(client);
  final bankRepo = BankAccountsRepository(client);
  final draft = await kycRepo.getDraft();
  final accounts = draft == null ? const <BankAccountSummary>[] : await bankRepo.list();

  final documents = draft?.documents ?? const <KycDocumentSummary>[];
  final hasIdDocument = documents.any((d) => _primaryIdDocumentKinds.contains(d.documentKind));
  final hasUtilityBill = documents.any((d) => d.documentKind == 'proof_of_address');
  final hasLivenessSelfie = documents.any((d) => d.documentKind == 'liveness_selfie');

  final bvnDone = draft != null;
  // CHN has no "skipped" flag of its own — a skip leaves chn permanently
  // null, exactly like never having reached this step at all. The other
  // real evidence that the investor is PAST it: chn_screen.dart's own
  // Continue/Skip both always advance into id_upload.dart next (filled or
  // skipped alike — see that file's own A-8 header note), so a primary ID
  // document existing is unambiguous proof CHN was already left behind,
  // filled or not. Without this, an investor who deliberately skips CHN
  // would show it "not done" forever and nextKycStepRoute would send them
  // back to it after every later step — the same species of resume-loop
  // bug this file's 2026-08-29 fix above exists to prevent, just for CHN's
  // own indirect signal instead of the backend's currentStep counter.
  //
  // 2026-08-31 fix ("CHN does not still work on skip"): hasIdDocument is
  // real evidence, but it cannot exist yet at the one moment this actually
  // mattered — chn_screen.dart's own _goToNextStep(), called synchronously
  // off the skip tap, before id_upload.dart (the next screen) has ever run.
  // At that exact moment draft.chn is still null (by design — see
  // chn_screen.dart's header) AND hasIdDocument is still false, so chnDone
  // came back false and nextKycStepRoute sent the investor right back to
  // the CHN screen they had just left — Skip doing nothing. chnSkipped is
  // KycFormState.chnSkippedThisSession, set by chn_screen.dart the instant
  // it decides to skip; it plugs exactly that one-tick gap for the rest of
  // this session, the same session-local pattern lockedStepRoutes already
  // uses for a fact the backend has no field of its own for.
  final chnDone = draft?.chn != null || hasIdDocument || chnSkipped;
  final documentsDone = hasIdDocument && hasUtilityBill;
  final selfieDone = hasLivenessSelfie;
  final bankDone = accounts.any((a) => a.primary);
  final declarationsDone = draft?.pepSelfDeclared != null;

  return [
    _ChecklistStep(
      title: 'BVN & NIN confirmed',
      note: 'Verified with NIBSS',
      done: bvnDone,
      route: Routes.kycBvn,
    ),
    _ChecklistStep(
      title: 'CHN',
      note: 'Optional — for returning investors',
      done: chnDone,
      route: Routes.kycChn,
    ),
    _ChecklistStep(
      title: 'Documents uploaded',
      note: 'ID · utility bill',
      // Sends you to whichever half is still outstanding, not always the
      // ID screen — see this file's header note on out-of-order steps.
      done: documentsDone,
      route: !hasIdDocument ? Routes.kycId : (!hasUtilityBill ? Routes.kycUtilityBill : Routes.kycId),
    ),
    _ChecklistStep(
      title: 'Take a selfie',
      note: '2 minutes',
      done: selfieDone,
      route: Routes.kycLiveness,
    ),
    _ChecklistStep(
      title: 'Add your bank account',
      note: 'For withdrawals and dividends',
      done: bankDone,
      route: Routes.kycBankDcs,
    ),
    _ChecklistStep(
      title: 'Two quick questions',
      note: 'Regulator requires them',
      done: declarationsDone,
      route: Routes.kycDeclarations,
    ),
    _ChecklistStep(
      title: 'Next of kin',
      note: "Who to contact if we can't reach you",
      done: false,
      route: Routes.kycNextOfKin,
    ),
  ];
}

/// A-4 fix: the real next KYC screen to continue to, derived from the SAME
/// live backend state the checklist hub's own UI uses — call this on step
/// completion instead of routing to [Routes.kycChecklist] so finishing a
/// step advances straight to the next one. Never returns the checklist hub
/// itself; when every step is done this returns the last step's route
/// (next_of_kin.dart), same as the hub's own "Continue" button falls back
/// to today.
/// `chnSkipped` — [KycFormState.chnSkippedThisSession] — lets a caller that
/// just acted on a CHN skip (chn_screen.dart) tell this derivation about it
/// a beat before the draft's own downstream evidence can; see
/// `_loadChecklistSteps`'s 2026-08-31 note on `chnDone`.
Future<String> nextKycStepRoute(ApiClient client, {bool chnSkipped = false}) async {
  final steps = await _loadChecklistSteps(client, chnSkipped: chnSkipped);
  final nextIndex = steps.indexWhere((s) => !s.done);
  return nextIndex == -1 ? steps.last.route : steps[nextIndex].route;
}

/// The KYC step routes an investor has to REDO, in this flow's own order —
/// derived from the per-check verification signals the submission already
/// carries (`KycSubmissionStatus.verificationSignals`), nothing else.
///
/// 2026-09-01, defect B. outcome_not_approved.dart's "Try again" used to
/// call `KycFormState.reset()` and `context.go(Routes.kycBvn)` — the whole
/// flow from step 1, no matter what actually failed. The backend had
/// already stopped doing that: its retry keeps every check that passed and
/// deletes only a failed liveness selfie. So an investor whose BVN, NIN,
/// name and date of birth all verified and whose selfie alone came back
/// bad was sent to re-enter a BVN the server had just confirmed.
///
/// The mapping is the flow's own, not a new one:
///   nin / bvn / name / dob  -> [Routes.kycBvn]. All four are produced by
///       the SAME step-1 call (POST /kyc-submissions/draft re-runs the
///       registry lookup and re-derives the name/dob cross-check from its
///       answer), so they collapse to one route rather than four.
///   liveness                -> [Routes.kycLiveness]. Its selfie was
///       deleted server-side on the retry, so the checklist derivation
///       above independently agrees this step is outstanding.
///
/// A `null` signal is deliberately NOT a step to redo: null means the
/// provider never answered, and the backend's retry re-runs that itself
/// without asking the investor for anything (see `KycRepository.retry`).
/// Only `false` — a check that ran and failed — is work for a human.
///
/// Returns `[Routes.kycBvn]` when there are no signals at all to narrow by
/// (an older backend, or a failure recorded before per-signal reporting
/// existed): the flow's start is the only honest answer there, and it is
/// what this screen did for every case before this function existed.
/// Returns an EMPTY list when signals are present and none failed — there
/// is genuinely nothing for the investor to redo.
///
/// 2026-09-01: the backend's `failureReasons` is preferred over the raw
/// booleans when it is present, because its `code` IS the signal name and
/// it is the field that also says whether the case may be retried at all.
/// A code this build does not recognise — one the backend adds after this
/// build ships — maps to no step rather than to a guess, which is also
/// exactly what `compliance_hold` (the tip-off-safe generic reason) needs.
List<String> failedKycStepRoutes(KycSubmissionStatus status) {
  final reasons = status.failureReasons;
  if (reasons != null) {
    final routes = {for (final r in reasons) _kycStepRouteByFailureCode[r.code]};
    return [
      if (routes.contains(Routes.kycBvn)) Routes.kycBvn,
      if (routes.contains(Routes.kycLiveness)) Routes.kycLiveness,
    ];
  }
  final signals = status.verificationSignals;
  if (signals == null) return const [Routes.kycBvn];
  return [
    if (signals.nin == false ||
        signals.bvn == false ||
        signals.name == false ||
        signals.dob == false)
      Routes.kycBvn,
    if (signals.liveness == false) Routes.kycLiveness,
  ];
}

/// Which step a `failureReasons` code sends the investor back to — the same
/// four-into-one collapse the signal mapping above describes, keyed by the
/// backend's own code instead of a boolean. Any code absent from this map
/// routes nowhere; see [failedKycStepRoutes].
const Map<String, String> _kycStepRouteByFailureCode = {
  'nin': Routes.kycBvn,
  'bvn': Routes.kycBvn,
  'name': Routes.kycBvn,
  'dob': Routes.kycBvn,
  'liveness': Routes.kycLiveness,
};

/// R-45 as amended (DECISIONS.md, 2026-08-29): the routes of every step
/// that is ALREADY done, from the same real per-item derivation
/// [_loadChecklistSteps] uses for everything else. Called exactly once, by
/// kyc_intro.dart's resume check, to snapshot [AppState.kycForm]'s
/// `lockedStepRoutes` — "old work from a previous session" the investor
/// should not be able to walk back into, as opposed to a step finished
/// during the CURRENT session, which stays reachable by back.
Future<Set<String>> doneKycStepRoutes(ApiClient client, {bool chnSkipped = false}) async {
  final steps = await _loadChecklistSteps(client, chnSkipped: chnSkipped);
  return steps.where((s) => s.done).map((s) => s.route).toSet();
}

/// C-3 fix (2026-08-29 product-owner audit — "the kyc count on unverified
/// home still wrong"): the real "N of 7 done" figure for a surface OUTSIDE
/// this hub (home_screen.dart's `_VerifyBanner`) that needs it. Deliberately
/// NOT `KycSubmissionStatus.currentStep`/`totalSteps` — those are the
/// backend's phased-KYC gating numbers (`KYC_TOTAL_STEPS = 5` in
/// kyc-submissions.service.ts), frozen at the 5-step id/liveness/utility-bill
/// model from 2026-08-20 and never updated for the CHN/Bank & DCS/
/// Declarations steps the 2026-08-24 canvas re-sequencing added — a fresh
/// draft with CHN and the bank account both done can report
/// `currentStep: 3` of `totalSteps: 5` even though 4 of the real 7 steps are
/// finished. Filed as a backend gap (BACKEND_GAPS.md) rather than papered
/// over: this reuses [_loadChecklistSteps]'s own real, per-item derivation
/// instead (the SAME one the hub's own UI and [nextKycStepRoute] already
/// trust), so the two surfaces can never disagree about what "done" means.
/// Returns null on any fetch failure so the caller can omit the figure
/// entirely rather than show a stale or guessed one (R-34).
Future<(int done, int total)?> kycProgressSummary(ApiClient client, {bool chnSkipped = false}) async {
  try {
    final steps = await _loadChecklistSteps(client, chnSkipped: chnSkipped);
    return (steps.where((s) => s.done).length, steps.length);
  } catch (_) {
    return null;
  }
}

class _KycChecklistScreenState extends State<KycChecklistScreen> {
  late final ApiClient _client = AppScope.read(context).apiClient;
  bool get _chnSkipped => AppScope.read(context).kycForm.chnSkippedThisSession;
  late Future<List<_ChecklistStep>> _future =
      _loadChecklistSteps(_client, chnSkipped: _chnSkipped);

  void _retry() =>
      setState(() => _future = _loadChecklistSteps(_client, chnSkipped: _chnSkipped));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                // s11's only header chrome is a single close affordance,
                // same as s10 — wired to Home, the same exit kyc_intro.dart
                // already uses for its own close icon.
                child: KIconButton(
                  icon: 'close',
                  semanticLabel: 'Close',
                  onPressed: () => context.go(Routes.home),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<_ChecklistStep>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const KLoadingView();
                  }
                  if (snapshot.hasError) {
                    return KErrorView(onPrimary: _retry);
                  }
                  // The checklist itself is never empty — it always lists
                  // the same 7 fixed steps, whether 0 or 6 of them are done
                  // yet, so KEmptyView's "nothing here" framing does not
                  // apply to this screen: a fresh draft with zero completed
                  // steps is still a fully-populated, correct render, not an
                  // absence of content.
                  final steps = snapshot.data!;
                  final doneCount = steps.where((s) => s.done).length;
                  final nextIndex = steps.indexWhere((s) => !s.done);
                  final next = nextIndex == -1 ? steps.last : steps[nextIndex];
                  // R-45 as amended (DECISIONS.md, 2026-08-29 — owner's
                  // correction: "they can go back but on restart they
                  // shouldn't be able to do so... on the flow they can go
                  // back"): a step this session already had done when it
                  // entered the flow (AppState.kycForm.lockedStepRoutes,
                  // snapshotted once by kyc_intro.dart's resume check) is
                  // "old work from a previous session" and gets no tap
                  // target here, same as it gets no back-button target
                  // (kycBackTarget, _kyc_chrome.dart). A step finished
                  // DURING this session is NOT in that set, so it stays
                  // tappable — an investor correcting a mistake just made
                  // must still be able to.
                  final locked = AppScope.read(context).kycForm.lockedStepRoutes;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(KSpace.gutter, 8, KSpace.gutter, KSpace.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Same large-headline treatment kyc_intro.dart (s10)
                        // already uses for its own hero title.
                        Text("You're almost there",
                            style: KType.hero(color: KColor.ink)
                                .copyWith(fontSize: 30, height: 36 / 30, letterSpacing: -0.6)),
                        const SizedBox(height: 8),
                        Text('$doneCount of ${steps.length} done. Next: ${next.title.toLowerCase()}.',
                            style: KType.body(color: KColor.ink2).copyWith(fontSize: 17, height: 26 / 17)),
                        const SizedBox(height: 26),
                        for (var i = 0; i < steps.length; i++)
                          _StepRow(
                            step: steps[i],
                            index: i,
                            state: i < nextIndex || (nextIndex == -1 && i < steps.length - 1)
                                ? _RowState.done
                                : i == nextIndex
                                    ? _RowState.current
                                    : _RowState.upcoming,
                            isLast: i == steps.length - 1,
                            // Tappable when it's the current outstanding
                            // step OR it was done DURING this session
                            // (never a step still ahead of `nextIndex`, and
                            // never a locked one — see this file's R-45
                            // note above). A done row still renders fully
                            // (tick, note, colour — unchanged above) even
                            // when locked; it simply has no tap target,
                            // rather than a handler wired to do nothing.
                            // This depends entirely on `done` reflecting
                            // REAL evidence (see _loadChecklistSteps's own
                            // 2026-08-29 note on the resume-loop fix) — a
                            // wrongly-"done" step would lock an investor out
                            // of one they still need, which is worse than
                            // the bug this fixes.
                            onTap: (i <= nextIndex || nextIndex == -1) && !locked.contains(steps[i].route)
                                ? () => context.go(steps[i].route)
                                : null,
                          ),
                        const SizedBox(height: 8),
                        KButton(
                          label: 'Continue · ${next.title}',
                          onPressed: () => context.go(next.route),
                        ),
                      ],
                    ),
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

enum _RowState { done, current, upcoming }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.state,
    required this.isLast,
    required this.onTap,
  });
  final _ChecklistStep step;
  final int index;
  final _RowState state;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color dotBg;
    final Color dotFg;
    final Widget dotChild;
    final Color titleColor;
    switch (state) {
      case _RowState.done:
        dotBg = KColor.gain;
        dotFg = KColor.featureInk;
        dotChild = KIcon('check', size: 16, color: dotFg);
        titleColor = KColor.ink;
        break;
      case _RowState.current:
        dotBg = KColor.indicator;
        dotFg = KColor.featureInk;
        dotChild = Text('${index + 1}', style: KType.cardTitle(color: dotFg));
        titleColor = KColor.indicator;
        break;
      case _RowState.upcoming:
        dotBg = KColor.track;
        dotFg = KColor.ink2;
        dotChild = Text('${index + 1}', style: KType.cardTitle(color: dotFg));
        titleColor = KColor.ink2;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // IntrinsicHeight — the connector-line Column below has an Expanded
      // child (the vertical line between dots), which needs a BOUNDED
      // height to size against. Bare, this Row sits inside a Column inside
      // a SingleChildScrollView, all of which pass unbounded height down —
      // IntrinsicHeight measures the Row's own content once and hands that
      // fixed height down to every child, giving the connector something
      // real to fill. Found live: without it, every step but the last threw
      // during layout/semantics (never a loud red-screen error — this
      // screen was never actually rendered before this pass, see
      // DECISIONS.md's flow-pass task) instead of drawing the connector.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: dotBg, shape: BoxShape.circle),
                  child: dotChild,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: state == _RowState.done
                          ? KColor.gain.withValues(alpha: 0.4)
                          : KColor.hairline,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 24, top: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(step.title, style: KType.cardTitle(color: titleColor)),
                          Text(step.note, style: KType.data(color: KColor.ink3)),
                        ],
                      ),
                    ),
                    if (state == _RowState.current)
                      KIcon('chevronRight', size: 18, color: KColor.indicator),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
