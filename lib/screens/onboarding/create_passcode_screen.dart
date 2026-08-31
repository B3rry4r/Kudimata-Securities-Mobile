// Artboard `s05` (+ dark `s05d`) in `01 Getting In.dc.html` — 6 dots fill
// from the keypad; at 6 digits we advance to confirm. Ported from
// screens.jsx CreatePasscode. Mid-flow gated, no tab bar.
//
// R-11 (docs/redesign/DECISIONS.md): the app keeps 6 digits with a separate
// confirm step everywhere, including login — "The canvas's 4-digit
// single-entry screen is not adopted; its *look* is." So the numpad/dots
// visual language is `s05`'s, the digit count and confirm step are not.
//
// 2026-08-27 (SCREEN-AGENT-BRIEF.md R-5 audit): this file's comments used to
// cite "#s07"/"#s08" — ids from the retired 97-screen canvas. In the current
// canvas this screen is `s05`; its own top bar draws only a back arrow, no
// step label at all (`s04`, the OTP screen before it, is the one that says
// "Step 4 of 4" — the numbered steps end there). The "Step 3 of 4" label
// this screen had grown is dropped below to match.
//
// Re-entry (reentry): Security's "Change passcode" (security_screen.dart)
// PUSHes here with `extra: true` for an already-signed-in investor, instead
// of the gated onboarding flow reaching it via go(). When reentry is set we
// keep using push() to advance to confirm (so the Security/account stack
// underneath survives) and pop back to Security on the back arrow, instead
// of the onboarding go()/otp-back behaviour.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'confirm_passcode_screen.dart';
import 'onboarding_scaffold.dart';

class CreatePasscodeScreen extends StatefulWidget {
  const CreatePasscodeScreen({super.key, this.reentry = false, this.email});

  /// True when re-entering this flow from Security's "Change passcode"
  /// rather than first-time onboarding. Defaults to false so the ordinary
  /// signup → passcode → biometric → KYC flow is unaffected when this isn't
  /// explicitly set.
  final bool reentry;

  /// The account this new passcode belongs to — known with certainty at
  /// both call sites that pass it (otp_screen.dart post-signup,
  /// log_in_screen.dart post-login), threaded through to
  /// confirm_passcode_screen.dart so it doesn't need to re-derive this via
  /// an API call. Null for Security's reentry (no fresh login just
  /// happened) — that screen resolves it itself instead.
  final String? email;

  @override
  State<CreatePasscodeScreen> createState() => _CreatePasscodeScreenState();
}

class _CreatePasscodeScreenState extends State<CreatePasscodeScreen> {
  String _code = '';
  // Guards against a real double-submit bug: with _code already at 6 digits
  // (advance already triggered below), a further tap on any digit key left
  // `_code` unchanged (the `_code.length < 6` guard blocked it) but the
  // `if (_code.length == 6)` check below still re-ran unconditionally — so
  // every stray tap while the confirm screen was already loading pushed (or
  // go()'d) it again. Set synchronously, no `await` in between, so there's
  // no gap a rapid second tap could land in.
  bool _navigating = false;

  void _onKey(String k) {
    if (_navigating) return;
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (_code.length < 6) {
        _code += k;
      }
    });
    if (_code.length == 6) {
      _navigating = true;
      // Hand the chosen passcode to the confirm step (mismatch checked there).
      final args = ConfirmPasscodeArgs(code: _code, reentry: widget.reentry, email: widget.email);
      if (widget.reentry) {
        // Push (not go) so the Security/account stack below stays intact —
        // confirm's success pops back through both screens to Security. A
        // pushed route can also come back to THIS screen (confirm's own
        // back arrow just pops once) — when it does, release the guard so
        // a retry is possible instead of a keypad stuck disabled forever.
        context.push(Routes.confirmPasscode, extra: args).then((_) {
          if (mounted) setState(() => _navigating = false);
        });
      } else {
        context.go(Routes.confirmPasscode, extra: args);
      }
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
            KOnboardTopBar(
              // `s05` draws no step label at all — see file header.
              stepLabel: null,
              // `s05`'s own back arrow targets `s04` (the OTP screen)
              // directly — matches the real flow again as of 2026-08-31
              // (R-51, DECISIONS.md): the dedicated post-OTP terms screen
              // this used to route back to instead is gone, and otp_screen.
              // dart now hands off to this screen directly, same as the
              // canvas always drew.
              onBack: () => widget.reentry ? context.pop() : context.go(Routes.otp),
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 22,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ported 1:1 from `s05`'s block: a centered flex column —
                  // title, then body, THEN the dots (not dots-then-body) —
                  // gap:10px between children, dots additionally offset
                  // margin-top:18px. The block sits near the top with its
                  // own padding; the keypad is pushed to the bottom by the
                  // Spacer below (CSS margin-top:auto in the mockup — same
                  // mechanism), so the gap between them is intentional, not
                  // a layout bug.
                  Text(
                    'Create a passcode',
                    textAlign: TextAlign.center,
                    style: KType.title(color: KColor.ink),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Six digits. You'll use it to open the app and to approve withdrawals.",
                    textAlign: TextAlign.center,
                    style: KType.body(color: KColor.ink3),
                  ),
                  const SizedBox(height: 28),
                  KPasscodeDots(filled: _code.length),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: KKeypad(onKey: _onKey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
