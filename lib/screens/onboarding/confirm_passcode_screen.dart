// No artboard of its own — R-11 (docs/redesign/DECISIONS.md) keeps the
// create+confirm pair everywhere including login ("A typo with no confirm
// step locks a user out of their own account"), while the current canvas
// (`01 Getting In.dc.html`) draws only a single 4-digit passcode screen
// (`s05`). This screen adopts `s05`'s look for the second, confirm-only
// step create_passcode_screen.dart's own header explains — re-enter to
// confirm. Mismatch tints the dots loss and shows the error line (the
// design's seeded state). On match we set passcodeSet and advance to
// biometric. Ported from screens.jsx ConfirmPasscode.
//
// 2026-08-27 (SCREEN-AGENT-BRIEF.md R-5 audit): dropped this file's own
// "Step 3 of 4" KOnboardTopBar label and its stale "#s08" comment citation
// (an id from the retired 97-screen canvas) — see
// create_passcode_screen.dart's matching fix; this screen keeps the same
// back-arrow-only chrome for visual consistency with the create step it
// immediately follows.
//
// Re-entry (widget.reentry): when this flow is entered from Security's
// "Change passcode" (an already-signed-in investor) rather than first-time
// onboarding, create_passcode_screen.dart PUSHes here (instead of the
// gated-flow's go()) so the Security/account stack underneath survives. On
// a match we pop back to it (twice — dismissing this screen and the create
// step) and show a confirmation SnackBar, instead of continuing into
// biometric/KYC.
//
// A THIRD case (AppState.loginPasscodeSetup — see that flag's doc comment in
// app_state.dart): a fresh email+password login (log_in_screen.dart) that
// just created this device's first-ever local passcode. Neither of the two
// existing branches fits it — it isn't first-time signup onboarding (so
// shouldn't continue into Biometric/KYC-intro unconditionally) and it isn't
// Security's reentry (there's no Security screen underneath to pop back
// to; this was reached via go(), not push()). It's threaded via AppState
// rather than GoRouter `extra` because app_router.dart's ConfirmPasscode
// route builder only ever forwards `reentry`/`created`, not a third field.
// On a match we hand off to log_in_screen.dart's
// [hydrateGatingStateAndRoute], which fetches this investor's REAL
// KYC/suitability state from the server and routes to wherever that state
// actually says they belong (KYC, suitability, or straight to Home for an
// already-fully-onboarded account) instead of always restarting Biometric/KYC.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/data/api/api_exception.dart';
import 'package:kudimata_invest/data/api/passcode_store.dart';
import 'package:kudimata_invest/data/repositories/user_repository.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart' show KSpinner;
import 'log_in_screen.dart' show hydrateGatingStateAndRoute;
import 'onboarding_scaffold.dart';

/// Payload passed via GoRouter `extra` from create_passcode_screen.dart.
class ConfirmPasscodeArgs {
  const ConfirmPasscodeArgs({required this.code, this.reentry = false, this.email});

  /// The passcode chosen on the create step.
  final String code;

  /// See [ConfirmPasscodeScreen.reentry].
  final bool reentry;

  /// See [ConfirmPasscodeScreen.email].
  final String? email;
}

class ConfirmPasscodeScreen extends StatefulWidget {
  const ConfirmPasscodeScreen({super.key, this.created, this.reentry = false, this.email});

  /// The passcode chosen on the create step (passed via GoRouter `extra`).
  final String? created;

  /// True when re-entering this flow from Security's "Change passcode"
  /// rather than first-time onboarding. Defaults to false so the ordinary
  /// signup → passcode → biometric → KYC flow is unaffected when this isn't
  /// explicitly set.
  final bool reentry;

  /// The account this passcode belongs to, threaded from
  /// create_passcode_screen.dart — known with certainty for a fresh
  /// signup/login, so used directly rather than re-derived via an API call.
  /// Null for Security's reentry, where [_evaluate] falls back to
  /// GET /users/me since no fresh login just supplied it.
  final String? email;

  @override
  State<ConfirmPasscodeScreen> createState() => _ConfirmPasscodeScreenState();
}

class _ConfirmPasscodeScreenState extends State<ConfirmPasscodeScreen> {
  String _code = '';
  bool _error = false;
  String _errorText = "That didn't match. Try the six digits again.";
  final _passcodeStore = PasscodeStore();

  // ── Busy state (2026-08-29, "confirm pin shows all the pin entered but
  // users dont know something is happening") ─────────────────────────────
  //
  // Once the sixth digit lands, [_evaluate] hashes+writes to secure storage
  // and — for Security's reentry path, which doesn't already know the
  // account email — makes a real network call (GET /users/me) before it can
  // route anywhere. None of that showed on screen: the dots just sat full
  // while the handler ran, which is exactly what "frozen" looks like.
  //
  // [_busy] is set the instant evaluation starts (before any `await`, so
  // there's no async gap for a second call to slip through) and gates the
  // keypad immediately — no visual flicker risk there, it's just "reject
  // taps while a submission is in flight". [_showSpinner] is the visual
  // half: it only flips on if the work is still running after
  // [_spinnerThreshold], so a secure-storage write that resolves in a few
  // ms (the common signup/login path — no network call at all, see
  // [_evaluate]'s non-reentry branches) never flashes a spinner it doesn't
  // need. Once shown, [_settle] holds it up for [_minSpinnerVisible] so a
  // call that finishes just after the threshold doesn't flash off again a
  // beat later.
  bool _busy = false;
  bool _showSpinner = false;
  Timer? _spinnerTimer;
  static const _spinnerThreshold = Duration(milliseconds: 150);
  static const _minSpinnerVisible = Duration(milliseconds: 300);

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  void _onKey(String k) {
    if (_busy) return; // keypad refuses input while a submission is in flight
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
        _error = false;
      } else if (_code.length < 6) {
        _code += k;
        _error = false;
      }
    });
    if (_code.length == 6) _evaluate();
  }

  /// Cancels the pending spinner timer and, if the spinner actually made it
  /// on screen, waits out whatever's left of [_minSpinnerVisible] before the
  /// caller flips [_busy]/[_showSpinner] back off or navigates away — so a
  /// call that resolves just after [_spinnerThreshold] doesn't show a
  /// one-frame flash instead of a real busy state.
  Future<void> _settle(DateTime started) async {
    _spinnerTimer?.cancel();
    if (_showSpinner) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed < _minSpinnerVisible) {
        await Future.delayed(_minSpinnerVisible - elapsed);
      }
    }
  }

  Future<void> _evaluate() async {
    // Defensive: _onKey already refuses input once _busy is true, but this
    // keeps _evaluate itself safe against any other caller and makes the
    // guard obvious at the one place all the side effects happen. Set
    // synchronously (no `await` before it) so there is no gap a second
    // near-simultaneous call could land in — this is also the fix for a
    // real double-submit bug: the old code re-ran _evaluate() on every
    // keypress once _code was already 6 digits (a stray tap while the
    // first call was still in flight re-drove the whole hash/store/route
    // sequence a second time).
    if (_busy) return;
    setState(() => _busy = true);
    final started = DateTime.now();
    _spinnerTimer = Timer(_spinnerThreshold, () {
      if (mounted) setState(() => _showSpinner = true);
    });

    final created = widget.created;
    // No created code available (e.g. deep link): accept as the demo path.
    final matches = created == null || _code == created;
    if (!matches) {
      await _settle(started);
      if (!mounted) return;
      setState(() {
        _error = true;
        _errorText = "That didn't match. Try the six digits again.";
        _busy = false;
        _showSpinner = false;
      });
      return;
    }
    try {
      final app = AppScope.read(context);
      // Scope the passcode to the account that set it (BUG-03 — see
      // PasscodeStore's file header). widget.email is known with certainty
      // for a fresh signup/login (threaded from otp_screen.dart /
      // log_in_screen.dart via create_passcode_screen.dart) — used
      // directly, no network round trip. Only Security's reentry lacks it,
      // so that's the one case that falls back to GET /users/me.
      //
      // 2026-08-15 follow-up: this used to ALWAYS resolve the owner via
      // GET /users/me, even when the email was already known — a single
      // transient failure there permanently mis-scoped the passcode
      // (silently stored an empty owner), which then never matched on any
      // future login, forcing that account through create/confirm +
      // biometric + personal-details again on every single sign-in
      // ("I see a few more details screens, I've done all these before").
      // Still best-effort where a network call is genuinely needed
      // (reentry): a transient failure there just means the owner check
      // misses on the next login (forces one extra create/confirm round),
      // not a reason to strand the investor on this screen.
      var owner = widget.email ?? '';
      if (owner.isEmpty) {
        try {
          owner = (await UserRepository(app.apiClient).me()).email;
        } on ApiException {
          // best-effort — see comment above.
        }
      }
      // Persist a salted hash of the confirmed passcode so log_in_screen.dart
      // has a real local value to verify a re-entered passcode against — see
      // PasscodeStore. AppState.setPasscode(true) is kept alongside this: it's
      // the in-memory gate flag the router/other screens already read.
      await _passcodeStore.setPasscode(created ?? _code, owner: owner);
      if (!mounted) return;
      app.setPasscode(true);
      if (widget.reentry) {
        // Re-entry from Security: confirm the change and return there,
        // rather than continuing into onboarding's biometric/KYC screens.
        // Create+confirm were both pushed (not go()'d) so two pops land
        // back on Security with the account tab/shell intact. Nothing else
        // async happens on this branch, so settle here (not before the
        // if/else) so the elapsed time it measures covers the whole wait.
        await _settle(started);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passcode updated')),
        );
        context.pop(); // dismiss Confirm.
        context.pop(); // dismiss Create -> back to Security.
      } else if (kIsWeb) {
        // No local_auth backing store on web — skip straight past biometric
        // enrolment, same as BiometricScreen's own "Maybe later" path,
        // straight to Home, for BOTH first-time signup and a fresh login
        // setting up its first local passcode on this device
        // (loginPasscodeSetup) — same reasoning either way: there's no
        // biometric capability to offer here at all. 2026-08-24: signup used
        // to detour through "a few more details"
        // (personal_details_screen.dart) first; that whole detour is gone —
        // DOB/address/city/state/phone are collected as part of starting KYC
        // instead (kyc_intro.dart's `_start()`) — so there's nothing left to
        // conditionally skip here. Consume loginPasscodeSetup (a harmless
        // no-op write when it was never set, i.e. the signup path) so it can
        // never leak into a later, unrelated flow.
        // hydrateGatingStateAndRoute makes its own (variable-length) network
        // calls and navigates internally once it's done — no settle() here:
        // the busy/spinner state stays up through that whole call, exactly
        // as it should for the slowest of the three branches, and simply
        // vanishes with this screen once it navigates away.
        app.setLoginPasscodeSetup(false);
        await hydrateGatingStateAndRoute(context);
      } else {
        // B-1 fix (2026-08-29 audit — "where is the ask for biometrics...
        // on new sign in?"): this used to send loginPasscodeSetup straight to
        // hydrateGatingStateAndRoute, skipping Biometric entirely for a
        // fresh sign-in setting up its FIRST local passcode on THIS device —
        // exactly the moment the owner expects the ask (a device with
        // biometrics available but not yet enabled for this account). Both
        // first-time signup and this case now reach Biometric the same way;
        // BiometricScreen itself calls hydrateGatingStateAndRoute once the
        // investor answers either way (enable or "Maybe later" — see its
        // file header). loginPasscodeSetup is consumed here (a no-op write
        // when it was never set) so it can never leak into a later,
        // unrelated flow.
        app.setLoginPasscodeSetup(false);
        // Nothing else async happens on this branch, so settle here (not
        // before the if/else) so the elapsed time it measures covers the
        // whole wait.
        await _settle(started);
        if (!mounted) return;
        context.go(Routes.biometric);
      }
    } catch (_) {
      // Any failure here — a secure-storage write error, an unexpected
      // exception from the owner lookup, or from hydrateGatingStateAndRoute
      // — used to propagate straight out of this handler with nothing on
      // screen ever resetting: the dots would just sit full and filled
      // forever, exactly the "hangs" bug this whole pass exists to fix,
      // except unrecoverable instead of just unexplained. Return to an
      // interactive state with a visible reason instead.
      await _settle(started);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _showSpinner = false;
        _error = true;
        _errorText = "Couldn't save your passcode. Please try again.";
      });
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
              // No step label — matches `s05`'s chrome; see file header.
              stepLabel: null,
              // Refuses to navigate away mid-submission, same reasoning as
              // the keypad guard in _onKey — leaving mid-write wouldn't
              // corrupt anything (every await already checks `mounted`),
              // but it would silently abandon a passcode-set/route decision
              // the investor just triggered.
              onBack: _busy
                  ? () {}
                  : () => widget.reentry
                      ? context.pop()
                      : context.go(Routes.createPasscode),
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 22,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Same shape as create_passcode_screen.dart's `s05` block —
                  // centered column, title then body then dots (dots get an
                  // extra margin-top:18 on top of the 10px flex gap), keypad
                  // pushed to the bottom by the Spacer (mockup's
                  // margin-top:auto) rather than the whole group centering.
                  Text(
                    'Enter it again',
                    textAlign: TextAlign.center,
                    style: KType.title(color: KColor.ink),
                  ),
                  if (_error) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText,
                      textAlign: TextAlign.center,
                      style: KType.body(color: KColor.loss, w: KWeight.medium),
                    ),
                  ] else if (_showSpinner) ...[
                    // No busy state is drawn on `s05` in the canvas (it
                    // draws no confirm step at all — see file header), so
                    // this borrows the same spinner/caption language the
                    // rest of the app already uses for a slow call (e.g.
                    // legal_preview_screen.dart's download row) rather than
                    // inventing a new one. Occupies the same slot the
                    // mismatch error text uses — the two never show together
                    // (a mismatch fails fast, well under the spinner's own
                    // threshold, so by the time it could show, _evaluate has
                    // already returned).
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KSpinner(size: 16, color: KColor.ink3),
                        const SizedBox(width: 8),
                        Text('Confirming…', style: KType.body(color: KColor.ink3)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  KPasscodeDots(filled: _code.length, error: _error),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    // IgnorePointer backs up the _onKey guard at the hit-test
                    // level (belt-and-suspenders, not load-bearing on its
                    // own); the dimming is what actually tells a sighted user
                    // the keypad isn't listening right now.
                    child: IgnorePointer(
                      ignoring: _busy,
                      child: Opacity(
                        opacity: _busy ? 0.5 : 1,
                        child: KKeypad(onKey: _onKey),
                      ),
                    ),
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
