# Composition findings — Phase 2

Scope: `lib/app/app_state.dart`, `lib/router/app_router.dart`,
`lib/data/api/auth_token_store.dart`, `lib/data/api/passcode_store.dart`,
`lib/main.dart`, `lib/screens/onboarding/{splash,log_in,otp,confirm_passcode}_screen.dart`,
`lib/data/repositories/kyc_repository.dart`, `lib/screens/kyc/bvn_nin.dart`.
No file in this list was edited to produce this report.

---

## 1. Does a control depend on a local credential some reachable actor never set?

**Breaks.** Traced actor `interrupted_onboarding_signed_in_no_passcode` (scenario-matrix.json)
end to end:

1. `otp_screen.dart:135` — `await _tokenStore.saveTokens(...)` runs the instant
   OTP verification succeeds, **before** suitability, risk-disclaimer, terms,
   or passcode creation ever run. A real access token is now in secure
   storage.
2. If the app is killed anywhere in that gap (questionnaire, risk disclaimer,
   terms, or create-passcode-but-not-yet-confirmed) and cold-started again,
   `AppState._hydrateSignedIn` (`app_state.dart:415-434`) reads that token
   and sets `signedIn = true` and `coldStartPendingUnlock = true` **from the
   token's mere presence alone** — no passcode check.
3. `AppState._hydratePasscodeSet` (`app_state.dart:443-454`) correctly finds
   nothing in `PasscodeStore` and leaves `passcodeSet = false`.
4. `app_router.dart:520` — the cold-start unlock force is:
   ```dart
   if (state.coldStartPendingUnlock && state.passcodeSet && loc != Routes.login) {
     return Routes.login;
   }
   ```
   This requires `passcodeSet == true`. For this actor it's `false`, so the
   condition never fires — the one mechanism that exists specifically to
   force a local unlock on cold start for a restored session silently does
   not apply.
5. Falls through to `app_router.dart:523`: `if (preAuthOnly.contains(loc)) return Routes.home;`.
   Both `Routes.splash` (the `initialLocation`) and `Routes.welcome` (where
   `splash_screen.dart:81` would otherwise have sent this user, since
   `app.passcodeSet` is false there too) are in `preAuthOnly`
   (`app_router.dart:497-499`). Either way the redirect resolves to
   `Routes.home`.

Net effect: a user interrupted mid-onboarding reopens the app and lands
**directly on Home**, fully "signed in" per the router, having skipped
suitability, the risk disclosure, the remaining legal documents, passcode
creation, and biometric enrolment entirely — with `passcodeSet == false` and
`biometricEnabled == false`. Every control gated on those two flags (the
passcode-dot unlock screen, the biometric key on the keypad, Security's
passcode-verification-before-change screens) has nothing to check against for
this investor, on a device holding a live, funded brokerage session.

This is the same defect class the project's own 2026-08-29 A-6/A-7 fixes
(cited throughout `app_state.dart`'s doc comments) closed for the
"biometric enrolled but never persisted" and "passcode never challenged on
cold start for someone who HAS a passcode" cases — this is a third,
still-open variant: **someone who never got the chance to set a passcode at
all** because they were interrupted before reaching that step.

Second path to the same actor, via a different entry state: `main.dart:148`
— `if (!_state.signedIn || !_state.passcodeSet) return;` — means the resume-lock
(`didChangeAppLifecycleState`, `main.dart:133-159`) is **also** a silent no-op
for this exact actor. Backgrounding and resuming the app, no matter how long,
never challenges them either. Recorded as its own row
(`resumed_after_grace_no_passcode`) in scenario-matrix.json because it's a
genuinely different entry-state (resume vs. cold start), reached through a
different code path (`main.dart` vs. `app_router.dart`), even though the root
cause is the same missing `passcodeSet` guard.

**How I proved it, not just read it:** traced the actual value written to
`AuthTokenStore` (otp_screen.dart) against the actual value read from it at
next launch (`app_state.dart`), then traced every consumer of `signedIn` +
`passcodeSet` together (both `_gateRedirect` and `main.dart`'s resume hook) to
confirm neither one's guard condition is satisfied by this combination. This
is not a hypothetical function reading in isolation — I checked every call
site that *sets* `passcodeSet=true` (`confirm_passcode_screen.dart:145`,
reached only after a passcode create+confirm match) to confirm there is no
other path that sets it before this point in the interrupted-onboarding
sequence.

---

## 2. Does a resume-lock fire on cold start, or only on `paused → resumed`?

**Holds, by design — with the one caveat above.** `main.dart`'s
`didChangeAppLifecycleState` (`main.dart:133-159`) is genuinely gated on the
`paused` → `resumed` transition only: `_pausedAt` is set exclusively in the
`AppLifecycleState.paused` branch (`main.dart:135-138`), and the lock-push
logic requires `pausedAt != null` (`main.dart:147`). A cold start never
passes through this method at all — Flutter does not fire
`didChangeAppLifecycleState` for the initial launch, only for observed
transitions after the app is already running.

Cold start is instead covered by a **separate, purpose-built mechanism**:
`AppState.coldStartPendingUnlock` (`app_state.dart:67-88`, set only inside
`_hydrateSignedIn`) plus `app_router.dart:520`'s redirect check. This is the
correct design — two different entry states, two different guards — and for
the case both guards were built for (`returning_trusted_device_locked`:
`signedIn=true, passcodeSet=true`) it works: traced `_hydrate()`
(`app_state.dart:110-115`) to confirm it awaits all three hydration reads
before a single `notifyListeners()` fires (preventing the exact race its own
doc comment describes at lines 95-109), then traced that notify into
`refreshListenable: state` (`app_router.dart:162`) re-running `_gateRedirect`
with both flags already settled.

The caveat: the cold-start guard shares the *same missing precondition*
(`passcodeSet == true`) as finding 1 above, so "does a resume-lock fire on
cold start" is the wrong question for the actor in finding 1 — the right
question is "does **any** guard fire for a signed-in user with no passcode
on cold start," and the answer there is no, by the same broken composition.

---

## 3. Does the client trust an HTTP status code, or also check a success flag in a 200 payload?

**Holds, and it's a genuinely fixed instance of exactly this bug class.**
`kyc_repository.dart:197-200` (`draftStep1`) always returns HTTP 200 from
`POST /kyc-submissions/draft` — per the repository's own doc comment
(`kyc_repository.dart:36-38`), BVN/NIN verification is a synchronous check
inside that same call, so a real mismatch is **not** a 4xx/5xx, it's a 200
with `verificationSignals.bvn`/`.nin` set to `false` inside the body
(`kyc_repository.dart:143-169`, `KycVerificationSignals`).

Walked the payload's-own-flag-false path in `bvn_nin.dart:118-209`
(`_confirmBvn`): after a successful (200) `draftStep1` call, lines 142-149
explicitly check
```dart
final signals = result.verificationSignals;
if (signals?.bvn == false || signals?.nin == false) {
  setState(() { _confirmResult = result; _step = _Step.failed; });
  return;
}
```
and block all further progress (`_buildFailed()`, `bvn_nin.dart:445-466`) —
no way past it except fixing the numbers and retrying. The file's own header
comment (`bvn_nin.dart:35-44`, dated 2026-08-29, "A-2") documents this as a
**fix** for exactly the failure mode this checklist item exists to catch: "a
real bvn/nin mismatch was previously indistinguishable from a genuine pass."

Checked whether this pattern is needed and present anywhere else a
finance-relevant call could return 200-with-internal-failure: grepped every
repository in `lib/data/repositories/` for a `success`-shaped field
(`order_placement_repository.dart`, `transaction_repository.dart`,
`auth_repository.dart`, etc.) — none of the others carry a
payload-level success/failure boolean distinct from HTTP status; every other
mutating call in this codebase follows the convention documented in
`order_placement_repository.dart`'s own header ("Throws `ApiException` on
failure... never throws a raw DioException"), i.e. failure is HTTP-status-driven
everywhere except this one BVN/NIN case, and that one case is the one already
fixed. I could not find a second live instance of this bug class to report
as still-open.

---

## Bonus finding (outside the three mandatory checks, found while tracing #2)

`RealtimeKycStatus` (`realtime_client.dart:92-110`) decodes **both**
`kycStatus` and `accountStatus` from the `kyc:status` socket event, and its
own doc comment (`realtime_client.dart:96-97`) states plainly: "the two
fields this app's gate actually reacts to are parsed here
(kycStatus/accountStatus)." But `AppState.applyRealtimeKycStatus`
(`app_state.dart:377-384`), the only consumer of this event, reads
`status.kycStatus` three times and **never reads `status.accountStatus` at
all**. If a staff member suspends or dormancy-flags an account while the
investor is signed in with a live socket connection, the push carrying that
change arrives and is silently dropped on the floor — the investor's session
keeps behaving as fully active until the access token's own ~15-minute TTL
expires and a refresh is attempted, or until a manual `personalInfo()` fetch
happens to run (only at login/`hydrateGatingStateAndRoute`, not periodically
during a session). This is a live discrepancy between what the code's own
comment claims it does and what it actually does, at exact citable lines,
and it directly bears on the `suspended_account` / `dormant_account` actors'
live-session behavior — recorded as `status: "unclear"` /
`"pending"` in scenario-matrix.json pending a live-session run, since it
could not be confirmed from the code alone whether this gap is masked in
practice by the token TTL being short enough not to matter.
