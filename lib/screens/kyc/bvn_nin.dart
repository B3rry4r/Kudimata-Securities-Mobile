// KYC 2 — BVN + NIN, combined onto one screen (step 1 of 5). Two 11-digit
// numeric fields. Mirrors the old separate Bvn screen's UI, plus a NIN
// field moved here from id_upload.dart (2026-08-20, phased-KYC directive —
// user picked the 4-step preview grouping BVN+NIN on one screen before
// asking for liveness to become its own separate 5th step).
//
// Submits directly to the backend: POST /kyc-submissions/draft {bvn, nin}
// — this call VERIFIES both numbers server-side (via the multi-provider
// KYC chain) AND creates the draft KycSubmission every later step operates
// on. Calling it again (e.g. the investor backs up and edits a typo) just
// re-verifies against the SAME existing draft — see
// KycRepository.draftStep1's doc comment.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import '_kyc_chrome.dart';

// A Nigerian BVN/NIN are both exactly 11 numeric digits (see
// Kudimata-Securities-Backend .pipeline/conventions.md's BVN/NIN row).
final RegExp _digitsPattern = RegExp(r'^\d{11}$');

class BvnNinScreen extends StatefulWidget {
  const BvnNinScreen({super.key});

  @override
  State<BvnNinScreen> createState() => _BvnNinScreenState();
}

class _BvnNinScreenState extends State<BvnNinScreen> {
  final _bvn = TextEditingController();
  final _nin = TextEditingController();

  late final _repo = KycRepository(AppScope.read(context).apiClient);

  bool _showErrors = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _bvn.dispose();
    _nin.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
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
      context.go(Routes.kycId);
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
            KycTopBar(onBack: () => context.go(Routes.kycIntro)),
            const KycStepProgress(total: 5, current: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KScreenHead(title: 'Verify your identity'),
                    const SizedBox(height: 24),
                    KInput(
                      label: 'BVN',
                      numeric: true,
                      placeholder: '0000000000',
                      helper:
                          'We use this only to verify your identity — we never see your bank.',
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
                      label: 'NIN',
                      numeric: true,
                      placeholder: '00000000000',
                      helper: 'Your 11-digit National Identification Number.',
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
                    const KExplainPanel(
                      title: 'What is a BVN for?',
                      body:
                          "It's the number your bank already uses to prove you are you. We use it to match your name to your bank account so your money can only ever come back to you.",
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KSpace.gutter, 0, KSpace.gutter, KSpace.gutter),
              child: KButton(
                label: 'Verify',
                loading: _busy,
                onPressed: _busy ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
