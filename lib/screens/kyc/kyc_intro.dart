// KYC — intro. Artboard s10/s10d (docs/design/redesign-2026-08/02
// Verification.dc.html) per RULINGS.md — a single scene, headline, body and
// one "Start" primary. The canvas's own step-by-step checklist lives on a
// SEPARATE artboard, s11 "Checklist hub" (the flow's spine — every later
// step returns to it), built as its own screen at
// kyc_checklist_screen.dart / Routes.kycChecklist (S-8, DECISIONS.md's
// SHARED-CHANGES.md).
//
// RESUME (2026-08-20, phased-KYC directive: "so users who goes out and
// comes back don't have to start all over"): "Start" first checks
// GET /kyc-submissions/draft SOLELY to populate AppState.kycForm.draftId —
// every step screen past step 1 needs that set before it can upload
// anything (see AppState.kycDraftStep's own doc comment for the incident
// this fixed). It then hands off to the checklist hub rather than jumping
// straight to a specific step itself (X-5, SHARED-CHANGES.md, 2026-08-27):
// the hub already re-derives exactly which step is next from the same real
// draft/account data and is the one place that logic should live, now that
// it exists as its own re-enterable screen instead of computing it here
// too.
//
// 2026-08-29 (A-1 audit fix — "why is there a few more details screen? why
// is that still there"): this used to detour a fresh "Start" tap through
// onboarding/personal_details_screen.dart first, gated on a
// dob/address/city/state/phone completeness check. Removed entirely:
//   - Address/city/state duplicated utility_bill.dart's own s17 address
//     fields verbatim (same PATCH /users/me target) — a pure double-entry.
//   - Phone duplicated sign_up_screen.dart's own phone field (BR-3, added
//     after this screen's detour existed) — also a double-entry now.
//   - DOB has no other writer anywhere in the app. Rather than keep a
//     whole separate interrupting screen alive for one field, it now
//     folds into bvn_nin.dart's own "Is this you?" confirmation (step 1) —
//     the BVN/NIN registry resolves a DOB there for most investors (BR-4);
//     that screen only asks directly when the registry didn't resolve one
//     AND the account doesn't already have one on file.
// personal_details_screen.dart itself is kept (not deleted — reported as a
// removal candidate) since its own route is still walked by
// test/route_walk_test.dart and still reachable directly if deep-linked.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/repositories/kyc_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class KycIntroScreen extends StatefulWidget {
  const KycIntroScreen({super.key});

  @override
  State<KycIntroScreen> createState() => _KycIntroScreenState();
}

class _KycIntroScreenState extends State<KycIntroScreen> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      final draft = await KycRepository(app.apiClient).getDraft();
      if (!mounted) return;
      if (draft != null && draft.id != null) {
        app.kycForm.setDraftId(draft.id!);
        context.go(Routes.kycChecklist);
        return;
      }
      context.go(Routes.kycBvn);
    } catch (_) {
      // Best-effort — if the resume check itself fails for ANY reason
      // (network, an unexpected response shape, not just ApiException —
      // widened 2026-08-20 after this got reported stuck on the loading
      // spinner forever despite the underlying request succeeding: a
      // narrower `on ApiException` catch let some other exception type
      // propagate uncaught, which meant `_busy` never got reset since the
      // `finally` below didn't exist yet either), fall through to a normal
      // fresh start rather than stranding the investor on this screen. Step
      // 1 re-checks/re-creates a draft regardless.
      if (!mounted) return;
      context.go(Routes.kycBvn);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, KSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // s10's only header chrome is a single close affordance (no
              // back chevron, no step strip — this is entered once, before
              // step 1 exists). Wired to Home, the same exit the old
              // "Look around first" ghost button gave — s10 doesn't draw a
              // second button, so that affordance moved into this icon.
              // Align (not a bare child of this CrossAxisAlignment.stretch
              // Column) keeps the fixed 40x40 circle from being stretched
              // into a smeared oval — Container.tighten intersects a fixed
              // width against the Column's tight full-width constraint and
              // loses.
              Align(
                alignment: Alignment.centerLeft,
                child: KIconButton(
                  icon: 'close',
                  semanticLabel: 'Not now',
                  onPressed: _busy ? null : () => context.go(Routes.home),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const KIllustration('kyc-intro', role: KIlloRole.state, tone: KIlloTone.sun),
                        const SizedBox(height: 28),
                        Text(
                          "Let's verify your identity",
                          style: KType.hero(color: KColor.ink)
                              .copyWith(fontSize: 32, height: 38 / 32, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'It keeps your money safe. Takes about 5 minutes.',
                          style: KType.body(color: KColor.ink2).copyWith(fontSize: 17, height: 26 / 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              KButton(
                label: 'Start',
                loading: _busy,
                onPressed: _busy ? null : _start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
