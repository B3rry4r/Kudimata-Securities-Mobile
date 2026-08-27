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
// ROUTING: lib/router/routes.dart has no entry for this screen — see
// docs/redesign/SHARED-CHANGES.md (S-8) for the route constant and GoRoute
// it needs, and where each step screen's post-completion navigation should
// point. This file names no such constant, so it compiles standalone and
// every existing KYC route keeps its current behaviour.
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
// real navigation chain (owned by other screens, not this one) reaches
// liveness (step 4) BEFORE utility_bill.dart (the address half of step 3) —
// see checking.dart's own routing. So it is possible to observe step 4 done
// while step 3 (documents) is not. This screen shows that honestly rather
// than reordering or hiding it: R-34's spirit is "reflect what's real", and
// pretending steps always complete in numeric order would be the same kind
// of invention R-34 forbids for a figure.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
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

class _KycChecklistScreenState extends State<KycChecklistScreen> {
  late final _kycRepo = KycRepository(AppScope.read(context).apiClient);
  late final _bankRepo = BankAccountsRepository(AppScope.read(context).apiClient);
  late Future<List<_ChecklistStep>> _future = _load();

  Future<List<_ChecklistStep>> _load() async {
    final draft = await _kycRepo.getDraft();
    final accounts = draft == null ? const <BankAccountSummary>[] : await _bankRepo.list();

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

  void _retry() => setState(() => _future = _load());

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
                    color: state == _RowState.done ? KColor.gain.withValues(alpha: 0.4) : KColor.hairline,
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
                  if (state == _RowState.current) KIcon('chevronRight', size: 18, color: KColor.indicator),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
