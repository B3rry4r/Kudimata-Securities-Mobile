# KYC flow audit — end to end

Triggered by the product owner completing their own KYC and landing exactly
on the row this audit uses as its worked example:

```
status = flagged
vendorDecision = rejected
flagReason = vendor_verification_failed
attemptCount = 0, maxAttempts = 3
vendorDetail: nin=true, bvn=true, liveness=false, name=true
```

Their words: *"the app showed me the liveness error, with no option of
retry rather a deceptive manual review and I go to dashboard and see auto
rejected, how is user going to input back???"*

Scope: `Kudimata-Securities-Mobile`, `Kudimata-Securities-Backend`,
`Kudimata-Securities-Dashboard`. No code changed. No live LumiID/YouVerify/
Dojah calls made — every claim below is read from source, not observed live.

---

## 1. The state machine, from evidence

`KycSubmission.status` is `draft|pending|review|approved|rejected|flagged|
expired` (`Kudimata-Securities-Backend/src/common/types/enums.ts:12`).
`vendorDecision` is `no_decision|approved|rejected`
(`enums.ts:79`). I grepped every assignment site in
`kyc-submissions.service.ts` for both fields — the table below is only rows
that code actually produces, not the full type-level cross product.

| status | vendorDecision | flagReason | What set it | What investor sees | What staff see | Can investor move forward? |
|---|---|---|---|---|---|---|
| `draft` | `no_decision` | null | `draftStep1()` (`kyc-submissions.service.ts:423`) or an in-progress `finalizeDraft` precondition failure | `kyc_checklist_screen.dart` hub, resumable at the real next incomplete step (`kyc_checklist_screen.dart:106-159`) | Excluded from staff `findAll` by default (`kyc-submissions.service.ts:1092`, "an in-progress draft is never a real case for the desk") | Yes — continues the 7-step flow |
| `pending` | `no_decision` | null | Signals mixed/partial at `create()`/`finalizeDraft()` (`kyc-submissions.service.ts:325`, `:642`) — `deriveVendorDecision` falls through when signals disagree without any being `false` (`:1451-1454`) | `submitted.dart` polling "We're reviewing" (`submitted.dart:180-210`) | Shows in the dashboard queue (`app/kyc/page.tsx:248`) | No self-service action; waits on a real staff decision, which **is** reachable here (case is in the queue) |
| `pending` | any | set (staff reason) | `updateDecision()` reject with `nextAttemptCount < maxAttempts` (`kyc-submissions.service.ts:1183-1184`) — `KycSubmissionStatus.isRejectedWithRoomToRetry` (`lib/data/repositories/kyc_repository.dart:140`) | `outcome_not_approved.dart` `_buildRejected` — "Resubmit documents" (`outcome_not_approved.dart:169-188`) | Same queue entry, now with `flagReason`/`internalNote` from the reject | **Yes** — the only status/vendorDecision combination in this whole system with a real, working retry button |
| `approved` | `approved` | null | Every attempted signal `true` — auto-approve (`kyc-submissions.service.ts:322-325`, `:637-641`) or a staff `approve` (`:1180`) | `approved.dart` | `isDecided = true` (`app/kyc/[id]/page.tsx:304`), locked | Done — trading gate lifts |
| **`flagged`** | **`rejected`** | `vendor_verification_failed` | `create()`/`finalizeDraft()` when `deriveVendorDecision` sees **any** signal `=== false` (`kyc-submissions.service.ts:1442-1447`), regardless of how many other signals passed | `outcome_not_approved.dart` `_buildFlagged` — "Your account needs manual review... you can keep using the app" (`outcome_not_approved.dart:191-210`); home banner: "Manual review is under way" (`app/app_state.dart:716-722`) | **Not in the queue** (`app/kyc/page.tsx:248-249` fetches only `status: pending`/`review`); not in `assignedTo`; no staff notification fired | **No.** Only button is "Back to home." See §2, dead end #1. |
| `rejected` | `rejected` | staff reason | `updateDecision()` reject with `nextAttemptCount >= maxAttempts` (`:1184`) — genuinely terminal, all 3 attempts spent | `_buildRejected`, `canResubmit=false` → "Contact support" (`outcome_not_approved.dart:183-184`) | `isResubmissionLimitReached` label (`app/kyc/[id]/page.tsx:306`), locked | No, by design — correctly labelled terminal |
| `review` | any | — | **Never assigned.** Grepped the whole service file; nothing sets `status: 'review'` on a `KycSubmission`. | n/a | Dashboard still queries for it (`app/kyc/page.tsx:249`, `app/overview/page.tsx:132,138`) and reserves a filter chip for it | Dead enum value — see §2 |
| `expired` | any | — | **Never assigned.** Same grep, no hit. | `_buildExpired` — "Start again" (`outcome_not_approved.dart:212-221`) is fully built for a state nothing produces | n/a | Dead enum value — see §2 |

Two structural notes that don't fit the table:

- `status` and `vendorDecision` are **not** shown to different audiences —
  `toWire()` (`kyc-submissions.service.ts:1537-1604`) puts both fields on
  the wire unmasked for every viewer role. `GET /kyc-submissions/me`
  (investor, `:1069`) and `GET /kyc-submissions/:id` (staff, `:1127`) return
  the identical two fields off the identical row. What differs is which
  field each *client* chose to foreground — see §3.
- `assertNewAttemptAllowed()` (`kyc-submissions.service.ts:748-757`) — the
  guard both `create()` and `draftStep1()` call before allowing a new
  attempt — only blocks when `previous.status === 'approved'` or
  `previous.status === 'rejected' && attemptCount >= maxAttempts`. A
  `flagged` previous submission satisfies **neither** condition, so
  `POST /kyc-submissions/draft` would technically succeed against this exact
  row today if anything ever called it. Nothing does — see §2.

---

## 2. Dead ends, worst first

### #1 — `flagged`: the most common outcome, and the only one with zero exit (DEFECT)

This is the reported row's own state, and it is reachable by the single
most ordinary partial failure this system has: one signal out of five comes
back `false` while the rest pass. `deriveVendorDecision`
(`kyc-submissions.service.ts:1415-1456`) does:

```ts
if (signals.some(([, v]) => v === false)) {
  return { vendorDecision: 'rejected', vendorDetail: `...(${describe()})` };
}
```

Any single `false` — liveness (a lighting/camera/network problem, the
highest-noise signal in the set) is treated identically to a sanctions hit.
That decision flows straight into `status = flagged`
(`:322-325`, `:637-641`), and from there:

- **The investor has no self-service path.** `outcome_not_approved.dart`'s
  own header comment states the policy outright (`:40-44`): *"flagged:
  needs a human reviewer, not a resubmission, so there is never a resubmit
  action here."* `_buildFlagged()` (`:191-210`) renders exactly one button:
  "Back to home." Confirmed by checking every route that could reach
  `Routes.kycBvn`/`Routes.kycIntro` from this state: the home banner's
  `tradingEligibilityGap` for `'flagged'` routes to `Routes.kycOutcome`
  only (`app/app_state.dart:716-720`), never to intro/bvn; and
  `personal_info_screen.dart`'s "Complete your KYC" entry only appears when
  `bvn == '—'` (`personal_info_screen.dart:231`), which is false here since
  BVN *did* resolve.
- **No staff member is notified, assigned, or shown this case by default.**
  See §4 for the full staff-side finding — the dashboard's queue query
  structurally excludes `status: flagged`.
- **No notification of any kind is sent to the investor when this state is
  entered.** See §5.
- **`attemptCount` stays 0/3 forever unless a staff member acts** — and per
  §4, staff acting on it is close to accidental. See dead end #2.

This is not "the vendor rejected them and there's nothing to be done" — nin,
bvn, and name all verified. It is a system that told the product owner a
human was looking at their case, while doing nothing to make that true, and
offering them nothing to do about it themselves.

### #2 — The 3-attempt budget is real code, but the only thing that spends it is a staff action nobody is directed to take (DEFECT, confirmed)

`attemptCount`/`maxAttempts` only change in one place:
`updateDecision()`'s reject branch (`kyc-submissions.service.ts:1178-1184`),
gated behind `STAFF_DECISION_ROLES`
(`kyc-submissions.controller.ts:191-192`, `27`). Grepped every mutation of
`attemptCount` in the service (`grep -n attemptCount` — 12 hits, listed
above in the investigation): every write path traces back to either a
straight copy-forward (`previous ? previous.attemptCount : 0`, at `create()`
and `draftStep1()`) or this one staff-only increment. There is no investor
route, webhook handler, or scheduled job that increments it.

Combined with #1: the only way `attemptCount` ever moves off 0 for a
`flagged` case is a staff member opening `/kyc/{id}` and clicking Reject —
which, per §4, requires them to already have the exact submission ID, because
the case isn't in the queue. Three allowed attempts that are structurally
unreachable from the state they're supposed to rescue is worse than
advertising one attempt: the wire shape (`maxAttempts: 3`) tells the
investor there is a safety net, and nothing in the reachable UI proves it out.

### #3 — `review` and `expired` are fully-built dead code paths (minor, DEFECT-adjacent)

Neither status value is ever assigned by the backend (confirmed by grep
across `kyc-submissions.service.ts` and the rest of `src/`, output empty
both times). Yet:

- The mobile app has a complete `_buildExpired()` view with a "Start again"
  CTA (`outcome_not_approved.dart:212-221`) for a status nothing produces.
- The dashboard reserves a "Review" filter chip, fetches `status: "review"`
  in both the KYC queue and the desk overview
  (`app/kyc/page.tsx:249`, `app/overview/page.tsx:132`), and a stats line
  ("Sent to the desk") implicitly counts on it.

Not a user-facing dead end (nobody lands here), but it's effort spent on
states that can't occur, and — more importantly — a `review` state clearly
*was* intended to exist as a distinct "actively being looked at by a human"
signal, separate from `flagged`. It doesn't; nothing sets it. That gap is
likely exactly where a real "this case is now assigned and someone is on
it" mechanism was supposed to live, and its absence is part of why
`flagged`'s "manual review is under way" copy has nothing behind it.

---

## 3. What the app says vs. what the row means

| Surface | Copy | What the row actually supports |
|---|---|---|
| `outcome_not_approved.dart:191-210` (`_buildFlagged`) | "Your account needs manual review... One of our team is taking a closer look" | Nobody is assigned (`assignedTo` stays null — never set outside `updateDecision`, `:1191`), nobody is notified (§5), and the case is excluded from the default staff queue (§4). "Taking a closer look" describes a process that does not run. |
| `app/app_state.dart:716-722` (home banner) | "Manual review is under way" | Same gap. The comment right above it (`:718-720`) already concedes the *investor*-facing promise problem ("No in-app notification mechanism backs a 'we'll tell you' promise") but stops short of the deeper problem: no review is backed either. |
| `app/kyc/page.tsx:61` (`vendorPill`) | "Auto-rejected" (label), rendered with `status="flagged"` (orange) tone | Technically correct as a label for `vendorDecision`, but it is the ONLY place in either surface that uses the word "rejected" about this row, and it's what a reviewer scanning the table sees first. The in-code comment at `:55-60` shows the team already fought this exact confusion once (2026-08-20, "why is the dashboard now showing rejected") and split the pill from the Status column — but the flagged row never reaches that table to be seen split or otherwise (§4). |
| `app/kyc/[id]/page.tsx:117` | `Vendor auto-decision: ${vendorDecisionLabel(...)}` on the case detail page | This one is accurate and unambiguous *if a staff member reaches the page* — the mismatch is upstream (getting there at all), not this line. |

The product owner's own framing — "manual review" vs. "auto rejected" for
the same case — is not a wording bug on one side. It is two different
fields (`status` vs `vendorDecision`) each rendered honestly by its own
client, with no surface anywhere that shows both together *and* is
reachable in the normal flow. The one screen that does show both
(`app/kyc/[id]/page.tsx:116-118`, `:377`) is the one screen staff never land
on for this case (§4).

---

## 4. Staff side: can a reviewer actually clear this case?

**Yes, if they reach `/kyc/{id}` directly — no, through any normal
workflow.**

What works, confirmed by reading the code:

- `updateDecision()` (`kyc-submissions.service.ts:1163-1279`) is a real,
  reachable endpoint. `PATCH /kyc-submissions/:id/decision`, gated to
  `kyc_reviewer|compliance_officer|super_admin`
  (`kyc-submissions.controller.ts:191-206`, `27`).
- The case detail page's Approve button is wired to it
  (`app/kyc/[id]/page.tsx:334-347`, `confirmApprove` → `decideKyc(id,
  "approve")`), gated only by `canDecide = hasSavedNote && !isDecided`
  (`:303-308`) — `isDecided` is `false` for `flagged` (only true/rejected
  lock it, `:304`), so this case is fully actionable once reached.
- The reviewer sees the real per-check breakdown
  (`verificationSignals`, wired at `app/kyc/[id]/page.tsx:77-92`) showing
  liveness failed while nin/bvn/name passed, plus the actual liveness selfie
  image fetched via presigned URL (`:202-233`). Nothing about the
  information is hidden from them.
- Approving flips `status` to `approved`, calls
  `usersService.updateKycStatus(..., 'approved')`, and pushes a realtime
  event (`kyc-submissions.service.ts:1208-1211`) — this **does** unblock the
  investor's trading gate immediately.

What doesn't work:

- **The case is not in the queue.** `app/kyc/page.tsx:248-249` builds the
  entire table from `Promise.all([listKycSubmissions({status:'pending'}),
  listKycSubmissions({status:'review'})])`. A `flagged` row is in neither
  set. `app/overview/page.tsx:132,137-138` (the desk landing page) makes the
  same two calls. There is no code path in either page that ever requests
  `status: 'flagged'`. The backend has no such restriction — `findAll()`
  defaults to `{ not: 'draft' }` when no status filter is given
  (`kyc-submissions.service.ts:1092`) and would return this row on an
  unfiltered or `status=flagged` call — this is a dashboard-only omission,
  fixable without touching the backend.
- The "Flagged" filter chip that does exist (`app/kyc/page.tsx:339`,
  `501-506`) filters the *already-fetched* `submissions` array by
  `vendorDecision === 'rejected'` — it can only ever surface a
  pending/review row whose vendor auto-decision happens to be `rejected`
  (e.g. a PEP-override `no_decision` case reconsidered), never a genuinely
  `flagged`-status row, because that row was never fetched in the first
  place. Its own count badge (`chipCounts.flagged`, `:349-356`) is computed
  off the same `pending`/`review`-only `queued` set, so it will silently
  read low/zero even when flagged cases exist.
- **`app/users/[id]/page.tsx`** — the one other place a reviewer might land
  on this case, e.g. via a support ticket naming the investor — does fetch
  the row unfiltered by status (`listKycSubmissions({userId, page:1,
  pageSize:1})`, `:169`) and does display it (`:602-690`, including
  `vendorDetail`, documents, liveness %, provider checks). But there is no
  link, button, or copyable ID anywhere on that panel back to `/kyc/{id}`
  (grepped for `href`/`Link`/`router.push` referencing kyc on that file —
  none). A reviewer here can *see* the problem and still cannot *act* on it
  without independently discovering the submission's UUID.
- **Dead control**: the Approve modal's "Ask the client to re-take the
  liveness capture at next sign-in" checkbox
  (`app/kyc/[id]/page.tsx:745`, `reTakeLiveness` state) is never read by
  `confirmApprove` (`:334-348`) and `decideKyc()`'s signature
  (`lib/api/client.ts:542`) has no such parameter — there is also no schema
  field anywhere backend-side for it. Checking it does nothing. Same
  species of defect as the four dead controls fixed in the mobile app's own
  most recent commit (`8173fa0`).

So: the decision endpoint, the UI to drive it, and the information a
reviewer needs are all real and would clear this exact case in one click.
The thing standing between "flagged" and "approved" is not missing
functionality — it's that nothing routes a human to the button.

---

## 5. Notifications: silent on the exact path that matters

Grepped every call site of `EmailMessageService.sendNotification` and
`NotificationsService.create` in `kyc-submissions.service.ts` — there are
exactly two:

1. `autoApproveSideEffects()` (`:947-985`) — but it returns immediately
   unless `vendorDecision === 'approved'` (`:956`, `if (vendorDecision !==
   'approved') return;`). Never fires for a `rejected`/`flagged` or
   `no_decision`/`pending` auto outcome.
2. `updateDecision()` (`:1262-1287`) — fires on every **staff** decision,
   approve or reject, both email (`kyc-decision` template) and an in-app
   `NotificationsService.create` row.

Consequence: when `create()`/`finalizeDraft()` auto-produces `flagged`
(the reported case) or `pending` (partial/no_decision), the investor
receives **zero** notification — no email, no in-app row — at the moment
their status changes. They find out only by opening the app and either
hitting the home banner or navigating into KYC themselves. This mirrors
the sibling-product gap referenced in the brief: KYC decisions here *are*
notified, but only the staff-decision path, not the (far more common)
auto-decision path — and the auto-`flagged` path is exactly the one this
whole audit is about.

The LumiID webhook handler (`handleLumiidWebhook`,
`:1296-1364`) updates `vendorDecision`/`vendorDetail`/`providerChecks`
directly on the row but never touches `status`, never recomputes it via
`finalizeVendorDecision`, and never sends a notification either — a
separate, smaller gap not exercised by the reported case (this flow uses
the synchronous check path, not the webhook), noted for completeness.

---

## 6. What a partial failure should do — code behaviour vs. recommendation

**What the code does today:** `deriveVendorDecision`
(`kyc-submissions.service.ts:1415-1456`) treats the signal set as an
all-or-nothing AND. `nin=true, bvn=true, name=true, liveness=false` and
`nin=false, bvn=false, name=false, sanctions=true` produce the *identical*
`vendorDecision: 'rejected'` outcome — the function has no concept of which
signal failed or how many. `dob` isn't even in the reported row's signal
set (the input array only includes checks that were attempted,
`:1424-1434`), so a 4-of-5 pass with liveness the sole failure and a 1-of-4
pass both collapse to the same "some false → rejected" branch.

I can confirm the code's behavior precisely; whether it's *correct* is a
product call, not mine to make. What I can say from evidence:

- The 2026-08-29 comment already sitting in this file (`:1063-1067`) about
  the PEP override shows the team has separately reasoned about exactly
  this class of question before — "blocking approval on a review nobody
  performs is worse for the investor than not blocking it" — and ruled the
  PEP-hit-alone case should **not** stop auto-approval, specifically because
  no desk exists to review it. The `flagged` outcome analyzed in this audit
  is the same shape of problem (a single signal stopping an otherwise-clean
  case) with the opposite resolution (hard stop, and a review promise that,
  per §1 and §4, is equally unbacked) — this asymmetry is worth putting to
  the owner directly, since one override for a similar situation already
  exists on this exact file for a similar reason.
- Liveness specifically has a materially different failure profile
  (camera/lighting/connectivity) than NIN/BVN registry mismatches or a
  sanctions hit — the code doesn't currently distinguish "which check
  failed" for routing purposes, only for the investor-facing explanation
  text (`_failedChecks()`, `outcome_not_approved.dart:157-167`).

**Needs the owner's ruling**, not a fix I should make unilaterally:
whether a liveness-only failure with nin/bvn/name all passing should (a)
auto-permit a bounded number of immediate self-service liveness retries
before ever reaching `flagged`, (b) still land on `flagged` but with a real
review process behind it, or (c) something else. Whichever is chosen, the
"promise a human is looking" copy must either become true or be removed —
that half is not optional either way.

---

## 7. Recommendations

### Defects — the system does not do what it already claims to do

1. **Route `status: flagged` into the dashboard's KYC queue and desk
   overview.** `app/kyc/page.tsx:248-249` and `app/overview/page.tsx:132,
   137-138` need a third `listKycSubmissions({status: 'flagged'})` call
   merged in, same pattern already used for pending/review. This alone
   makes every other piece of already-working machinery (§4) actually
   reachable. No backend change required.
2. **Fix the "Flagged" chip's source and count** (`app/kyc/page.tsx:339`,
   `349-356`) to read from the real flagged set once #1 lands, not derive
   it from `vendorDecision` inside the pending/review subset.
3. **Send a real notification (email + in-app) the moment an auto-decision
   lands**, not only on a staff decision — extend the `autoApproveSideEffects`
   call site or add a sibling call in `create()`/`finalizeDraft()` for the
   `rejected`/`flagged` and `no_decision`/`pending` outcomes, mirroring what
   `updateDecision()` already does at `:1262-1287`.
4. **Remove or wire the dead "Ask the client to re-take the liveness
   capture at next sign-in" checkbox** (`app/kyc/[id]/page.tsx:745`) — it
   currently does nothing and looks like it does something, the exact
   pattern the mobile app just finished cleaning up.
5. **Link from the user profile's KYC panel to `/kyc/{id}`**
   (`app/users/[id]/page.tsx:602-690`) so a reviewer who finds a case via a
   user lookup can act on it without hand-typing a UUID.
6. **Either implement `review`/`expired` KYC states or remove the code built
   for them** — `_buildExpired()` (`outcome_not_approved.dart:212-221`) and
   the dashboard's "Review" chip/queries currently maintain UI for states
   the backend never produces.
7. Either back the "manual review is under way" / "one of our team is
   taking a closer look" copy with a real mechanism (from #1 + #3, once a
   human is actually notified and the case is actually visible), or soften
   the copy to not assert an active process — same standard this codebase
   already applied to the dropped "we'll notify you"/"24-hour hold" claims
   elsewhere in this same file (`submitted.dart`'s own header comments
   document that precedent).

### Needs the owner's decision — deliberate behaviour, arguably wrong

1. **Should a liveness-only failure, with nin/bvn/name all verified, hard-stop
   at `flagged` at all**, or should the investor get one or more immediate
   self-service liveness retries before it ever reaches a human-review
   state? (§6)
2. **Should `flagged` ever offer a resubmit action**, the way the
   post-staff-reject `pending` state does today (`outcome_not_approved.dart:
   36-39` records this as a deliberate choice, not an oversight) — or is
   the right fix entirely on the staff-discoverability side (§4/§7-1),
   leaving `flagged` correctly gated behind a human?
3. **Is "any single failed signal ⇒ reject" the intended AML posture**,
   given the PEP override on this same function already treats one
   signal-class as non-blocking for a documented reason (§6)? If liveness
   should get different treatment than a sanctions/registry mismatch, that
   changes `deriveVendorDecision`'s shape, not just its wiring.
4. Once #1/#2 above are decided, whether `maxAttempts: 3` should be spent by
   self-service retries, by staff decisions, or both — currently only the
   staff path spends it at all (§2).
