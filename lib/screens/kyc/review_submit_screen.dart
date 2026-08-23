// KYC — Review & submit (canvas screen 22). NEW screen (2026-08-24,
// re-sequencing to the canvas's real 8-step flow). Reached after next of
// kin (step 8); THIS screen is now the one that calls
// POST /kyc-submissions/draft/finalize (KycRepository.finalizeDraft) — see
// next_of_kin.dart's header comment for what moved.
//
// Data sources for the summary rows below:
//   - BVN·NIN, CHN, ID (documentType + document count), proof of address
//     (document name/date) — all real, fetched fresh via
//     KycRepository.getDraft() (extended 2026-08-24 to carry nin/chn/
//     documentType/documents — see that file's KycSubmissionStatus).
//   - Bank · DCS — the real primary bank account, via
//     BankAccountsRepository.list() (the SAME resource bank_dcs_screen.dart
//     just wrote to).
//   - Selfie "captured at" — KycFormState.selfieCapturedAt, a real
//     client-side timestamp set by liveness.dart's capture, since the
//     backend has no such field.
//   - Declarations' "who"/"position"/"trade for self" detail, and Next of
//     kin's name/relationship/phone — KycFormState, THIS SESSION ONLY (no
//     backend field for the PEP detail or next-of-kin isn't finalized until
//     Submit below; see declarations_screen.dart's header comment).
//   - The "Anything we should know?" note — pure UI, nowhere to send it:
//     FinalizeKycDraftRequest (backend common/types/kyc.types.ts) has no
//     free-text note field. Kept as a local-only field, NOT submitted — a
//     real, flaggable gap, not faked.
//
// Each row's "Edit"/"Retake" link `context.push`es back to that exact step
// (kept on the Navigator stack, unlike the linear flow's own `context.go`
// steps) so a plain back-tap returns straight here; every new screen this
// pass added (chn/bank-dcs/declarations) is resume-aware (pre-fills from
// the draft/KycFormState) for the same reason. The existing id/liveness/
// utility-bill screens do NOT pre-populate an already-uploaded file (a
// pre-existing limitation of the resume architecture, not new here) — an
// "Edit" into one of those means re-uploading, then walking forward through
// the remaining steps again to land back on this Review screen.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/bank_accounts_repository.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/screens/shared/state_views.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'kyc_form_state.dart';

class ReviewSubmitScreen extends StatefulWidget {
  const ReviewSubmitScreen({super.key});

  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  late final _kycRepo = KycRepository(AppScope.read(context).apiClient);
  late final _bankRepo = BankAccountsRepository(AppScope.read(context).apiClient);

  late Future<(KycSubmissionStatus?, BankAccountSummary?)> _future = _load();
  final _note = TextEditingController();
  bool _submitting = false;

  Future<(KycSubmissionStatus?, BankAccountSummary?)> _load() async {
    final draft = await _kycRepo.getDraft();
    final accounts = await _bankRepo.list();
    final primaries = accounts.where((a) => a.primary).toList();
    return (draft, primaries.isEmpty ? null : primaries.first);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = AppScope.read(context);
    final form = app.kycForm;
    setState(() => _submitting = true);
    try {
      await _kycRepo.finalizeDraft(
        nextOfKinName: form.nextOfKinName ?? '',
        nextOfKinRelationship: form.nextOfKinRelationship ?? '',
        nextOfKinPhone: form.nextOfKinPhone ?? '',
        nextOfKinEmail: form.nextOfKinEmail,
      );
      if (!mounted) return;
      form.reset();
      app.setKycSubmitted(true);
      context.go(Routes.kycSubmitted);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorSheet(context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorSheet(context, message: 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = AppScope.of(context).kycForm;
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No step-count/progress-bar chrome — the canvas's own s22
            // markup omits it (unlike s14-s21), so KDetailHeader (a plain
            // back-chevron + title) is the right match, not KycTopBar.
            // Explicit `onBack` target, not the default maybePop(): this
            // screen is reached via next_of_kin.dart's `context.go(...)`,
            // which replaces rather than pushes, so there's no Navigator
            // entry to pop back to (same reasoning as every other KYC
            // screen's KycTopBar — see _kyc_chrome.dart's header comment).
            KDetailHeader(title: 'Check before you send', onBack: () => context.go(Routes.kycNextOfKin)),
            Expanded(
              child: FutureBuilder<(KycSubmissionStatus?, BankAccountSummary?)>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: KLoadingView(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: KErrorView(onPrimary: () => setState(() => _future = _load())),
                    );
                  }
                  final (draft, bank) = snapshot.data ?? (null, null);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        KSpace.gutter, 16, KSpace.gutter, KSpace.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KCard(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Column(
                            children: [
                              _ReviewRow(
                                label: 'BVN · NIN',
                                value: '${draft?.bvn ?? '—'} · ${draft?.nin ?? '—'}',
                                action: 'Edit',
                                first: true,
                                onTap: () => context.push(Routes.kycBvn),
                              ),
                              _ReviewRow(
                                label: 'CHN',
                                value: draft?.chn != null ? draft!.chn! : 'Not provided — one will be assigned',
                                action: 'Edit',
                                onTap: () => context.push(Routes.kycChn),
                              ),
                              _ReviewRow(
                                label: 'ID',
                                value: _idSummary(draft),
                                action: 'Edit',
                                onTap: () => context.push(Routes.kycId),
                              ),
                              _ReviewRow(
                                label: 'Selfie',
                                value: form.selfieCapturedAt != null
                                    ? 'Captured ${_formatDateTime(form.selfieCapturedAt!)}'
                                    : 'Captured',
                                action: 'Retake',
                                onTap: () => context.push(Routes.kycLiveness),
                              ),
                              _ReviewRow(
                                label: 'Proof of address',
                                value: _addressDocSummary(draft),
                                action: 'Edit',
                                onTap: () => context.push(Routes.kycUtilityBill),
                              ),
                              _ReviewRow(
                                label: 'Bank · DCS',
                                value: bank != null
                                    ? '${bank.bankName} ${bank.accountNumberMasked} · Direct Cash Settlement ${bank.primary ? 'on' : 'off'}'
                                    : 'Not added yet',
                                action: 'Edit',
                                onTap: () => context.push(Routes.kycBankDcs),
                              ),
                              _ReviewRow(
                                label: 'Declarations',
                                value: _declarationsSummary(draft, form),
                                action: 'Edit',
                                onTap: () => context.push(Routes.kycDeclarations),
                              ),
                              _ReviewRow(
                                label: 'Next of kin',
                                value: form.nextOfKinName != null
                                    ? '${form.nextOfKinName} · ${form.nextOfKinRelationship ?? '—'}'
                                    : 'Not provided',
                                action: 'Edit',
                                last: true,
                                onTap: () => context.push(Routes.kycNextOfKin),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        KInput(
                          label: 'Anything we should know?',
                          placeholder: 'Optional note for the desk',
                          controller: _note,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'By submitting you confirm these details are yours and accurate. Kudimata Securities Ltd is required to verify them before your CSCS account opens.',
                          style: KType.data(color: KColor.ink3),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(
                label: 'Submit for verification',
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _idSummary(KycSubmissionStatus? draft) {
    if (draft == null || draft.documentType == null) return 'Not uploaded yet';
    const labels = {
      'nin': 'NIN slip',
      'passport': 'Passport',
      'drivers_licence': "Driver's licence",
      'voters_card': "Voter's card",
    };
    final label = labels[draft.documentType] ?? draft.documentType!;
    const idKinds = {'nin', 'passport', 'drivers_licence', 'voters_card'};
    final count = draft.documents.where((d) => idKinds.contains(d.documentKind)).length;
    return '$label · $count file${count == 1 ? '' : 's'}';
  }

  String _addressDocSummary(KycSubmissionStatus? draft) {
    final matches = (draft?.documents ?? const <KycDocumentSummary>[])
        .where((d) => d.documentKind == 'proof_of_address')
        .toList();
    if (matches.isEmpty) return 'Not uploaded yet';
    final doc = matches.first;
    final when = doc.uploadedAt != null ? _formatDate(doc.uploadedAt!) : '';
    return when.isEmpty ? doc.documentName : '${doc.documentName} · $when';
  }

  String _declarationsSummary(KycSubmissionStatus? draft, KycFormState form) {
    final pep = draft?.pepSelfDeclared;
    final parts = <String>[
      pep == true ? 'Politically exposed: Yes' : (pep == false ? 'Politically exposed: No' : 'Not answered yet'),
    ];
    if (pep == true && form.pepWho != null) parts.add(form.pepWho!);
    if (form.tradeForSelf) parts.add('trading for myself');
    return parts.join(' · ');
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatDateTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_formatDate(d)} · $hh:$mm';
}

/// Shown when the finalize call fails — mirrors the identically-named
/// helper next_of_kin.dart used to have before finalize moved here.
void _showErrorSheet(BuildContext context, {required String message}) {
  showKSheet<void>(
    context,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: KStatusView(
        tone: KStatusTone.error,
        title: 'Submission failed',
        message: message,
        primary: 'Try again',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    required this.action,
    required this.onTap,
    this.first = false,
    this.last = false,
  });
  final String label;
  final String value;
  final String action;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: first || last ? 12 : 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: KColor.hairline, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(), style: KType.micro(color: KColor.ink3)),
                const SizedBox(height: 2),
                Text(value, style: KType.data(color: KColor.ink).tnum),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(action, style: KType.data(color: KColor.indicator)),
            ),
          ),
        ],
      ),
    );
  }
}
