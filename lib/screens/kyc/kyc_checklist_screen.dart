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
//   step 2 CHN         — optional; treated done once the draft has moved
//                         past it (`currentStep > 2`) OR chn is set. CHN's
//                         own screen always leads into ID upload whether
//                         filled or skipped, so by the time id upload has
//                         registered there is no way to still be "on" CHN.
//   step 3 Documents   — ID + address, ONE checklist item per s11's own
//                         "Documents uploaded · ID · utility bill" row.
//                         `KycSubmissionStatus.currentStep` (server-computed
//                         milestone; see kyc_intro.dart's own derivation
//                         comment) reaches 5 ("ready to finalize") only once
//                         BOTH the id document and the utility bill are in —
//                         done = currentStep >= 5.
//   step 4 Selfie      — currentStep >= 4 (liveness done, milestone "no
//                         utility bill yet" or later).
//   step 5 Bank & DCS  — a primary BankAccountSummary exists
//                         (BankAccountsRepository.list()).
//   step 6 Declarations — pepSelfDeclared != null (a Yes/No has actually
//                         been recorded server-side). The screen's second
//                         question, broker/NGX employment, has no backend
//                         field at all (see declarations_screen.dart) — it
//                         cannot be checked from here across a fresh
//                         session, only pepSelfDeclared can. Filed in
//                         BACKEND_GAPS.md.
//   step 7 Next of kin — never independently "done" while status=='draft':
//                         finalizeDraft() submits next-of-kin AND leaves
//                         'draft' in the same call, so this is always the
//                         last remaining item once 1-6 are done.
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

/// The real per-step "done" derivation — shared by this screen's own hub UI
/// and [nextKycStepRoute] below. See this file's header for the per-step
/// rules and the out-of-order-completion note.
Future<List<_ChecklistStep>> _loadChecklistSteps(ApiClient client) async {
  final kycRepo = KycRepository(client);
  final bankRepo = BankAccountsRepository(client);
  final draft = await kycRepo.getDraft();
  final accounts = draft == null ? const <BankAccountSummary>[] : await bankRepo.list();

  final cs = draft?.currentStep;
  final bvnDone = draft != null;
  final chnDone = draft != null && ((cs != null && cs > 2) || draft.chn != null);
  final documentsDone = cs != null && cs >= 5;
  final selfieDone = cs != null && cs >= 4;
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
      route: documentsDone ? Routes.kycId : (selfieDone ? Routes.kycUtilityBill : Routes.kycId),
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
Future<String> nextKycStepRoute(ApiClient client) async {
  final steps = await _loadChecklistSteps(client);
  final nextIndex = steps.indexWhere((s) => !s.done);
  return nextIndex == -1 ? steps.last.route : steps[nextIndex].route;
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
Future<(int done, int total)?> kycProgressSummary(ApiClient client) async {
  try {
    final steps = await _loadChecklistSteps(client);
    return (steps.where((s) => s.done).length, steps.length);
  } catch (_) {
    return null;
  }
}

class _KycChecklistScreenState extends State<KycChecklistScreen> {
  late final ApiClient _client = AppScope.read(context).apiClient;
  late Future<List<_ChecklistStep>> _future = _loadChecklistSteps(_client);

  void _retry() => setState(() => _future = _loadChecklistSteps(_client));

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
                            onTap: i <= nextIndex || (nextIndex == -1)
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
