// Kudimata Securities — shared KYC in-progress form state.
//
// PHASED KYC (2026-08-20, user directive: "we need to break the KYC into
// parts not all at one submit... so users who goes out and comes back
// don't have to start all over"): each of the 5 KYC screens now submits
// its own slice directly to the backend as soon as it's collected —
// bvn+nin -> POST /kyc-submissions/draft (step 1, creates the draft and
// returns its real id); id document / utility bill -> POST /kyc-documents
// (steps 2/4, registered against that id); liveness selfie -> uploaded the
// same way then verified via POST /kyc-submissions/draft/liveness (step 3);
// next of kin + address -> POST /kyc-submissions/draft/finalize (step 5).
// There is no longer a final bulk submit accumulating everything from
// earlier screens — see KycRepository (lib/data/repositories/
// kyc_repository.dart) for the phased endpoints.
//
// This class now holds ONLY the one thing every later step genuinely needs
// and can't itself re-derive without an extra round trip: the draft's id,
// set by step 1 (or by resuming an existing draft via kyc_intro.dart /
// GET /kyc-submissions/draft) and read by every later step's document
// registration call.
import 'package:flutter/foundation.dart';

/// Shared, in-memory holder for the current KYC draft's id — reached the
/// same way as every other piece of app session state:
/// `AppScope.read(context).kycForm` (see lib/app/app_state.dart).
class KycFormState extends ChangeNotifier {
  /// The current draft KycSubmission's id, once step 1 has created it (or
  /// resume has fetched an existing one). Null before step 1 / after a
  /// [reset].
  String? draftId;

  void setDraftId(String v) {
    draftId = v;
    notifyListeners();
  }

  /// R-45 as amended (DECISIONS.md, 2026-08-29 — owner's correction: "they
  /// can go back but on restart they shouldn't be able to do so... on the
  /// flow they can go back"): the KYC step ROUTES that were already
  /// complete the moment THIS session's flow was entered — snapshotted
  /// exactly once by kyc_intro.dart's resume check (`_checkResume`/`_start`)
  /// against the real draft state (`kyc_checklist_screen.dart`'s
  /// `doneKycStepRoutes`), never recomputed afterward. A route in this set
  /// is "old work from a previous session" — `kycBackTarget`
  /// (_kyc_chrome.dart) sends both hardware back and every step screen's
  /// own on-screen arrow to the checklist hub instead of the linear
  /// predecessor for it, and the checklist hub itself does not route to it
  /// either. A step finished DURING this session is deliberately NOT added
  /// here — it stays reachable by back for the rest of the session, exactly
  /// like today, since correcting a mistake just made must keep working.
  ///
  /// Empty by default (a genuine first-timer has nothing to lock — nothing
  /// is done yet) and in-memory only, same as [draftId] — a restart
  /// naturally re-derives it from the draft via the next resume check
  /// rather than needing to be persisted anywhere, which is exactly the
  /// behaviour wanted: persisting it would defeat the "on restart" trigger
  /// entirely.
  Set<String> lockedStepRoutes = const {};

  void lockSteps(Set<String> routes) {
    lockedStepRoutes = routes;
    notifyListeners();
  }

  // ── Added 2026-08-24 (re-sequencing to the canvas's real 8-step flow) ────
  // Next-of-kin (step 8) no longer finalizes the draft itself — Review &
  // submit (the new final screen) does, so these three fields have to
  // survive the hop between those two screens. Same in-memory-only pattern
  // [draftId] already uses; NOT sent anywhere until review_submit_screen.dart
  // calls KycRepository.finalizeDraft with them.
  String? nextOfKinName;
  String? nextOfKinRelationship;
  String? nextOfKinPhone;

  /// Optional — canvas screen 21 offers an email field; backend's
  /// `NextOfKin.email` (added 2026-08-24) is optional too, so this stays
  /// null rather than blocking Continue when left blank.
  String? nextOfKinEmail;

  void setNextOfKin({
    required String name,
    required String relationship,
    required String phone,
    String? email,
  }) {
    nextOfKinName = name;
    nextOfKinRelationship = relationship;
    nextOfKinPhone = phone;
    nextOfKinEmail = email;
    notifyListeners();
  }

  /// When the liveness selfie was captured/uploaded this session — a real
  /// client-side timestamp (NOT fabricated), shown on the review screen's
  /// "Selfie" row. Null until liveness.dart's capture succeeds, or after a
  /// [reset]; the backend itself has no "captured at" field for this.
  DateTime? selfieCapturedAt;

  void setSelfieCapturedAt(DateTime v) {
    selfieCapturedAt = v;
    notifyListeners();
  }

  /// The PEP declaration's free-text detail (screen 20 "Declarations · PEP")
  /// — see review_submit_screen.dart's own doc comment: `pepSelfDeclared`
  /// itself IS persisted (KycRepository.updateDraftFields), but who/what
  /// position is NOT — no backend field exists for it (confirmed against
  /// UpdateKycDraftFieldsRequest, backend common/types/kyc.types.ts). Held
  /// here purely so the SAME session's review screen can echo back what was
  /// just typed; lost on app restart, same as [reset] below.
  String? pepWho;
  String? pepPosition;

  /// "Do you work for a stockbroker or the NGX?" (s19's real second
  /// question — docs/design/redesign-2026-08/02 Verification.dc.html) —
  /// also has no backend field (see declarations_screen.dart's header
  /// comment); a pure client-side answer, defaults to false (No), matching
  /// both this question's and the PEP question's default state on s19.
  bool brokerOrNgxEmployed = false;

  void setDeclarations({required bool brokerOrNgxEmployed, String? pepWho, String? pepPosition}) {
    this.brokerOrNgxEmployed = brokerOrNgxEmployed;
    this.pepWho = pepWho;
    this.pepPosition = pepPosition;
    notifyListeners();
  }

  /// Clears the held draft id for a fresh attempt (kyc-outcome screen's
  /// "Resubmit documents"/"Start again" actions — see
  /// lib/screens/kyc/outcome_not_approved.dart — and a completed submission
  /// after kyc-next-of-kin's finalize succeeds). Re-entering kyc-bvn-nin
  /// with the FIRST attempt's stale draft id would be wrong; this restarts
  /// step 1 with a clean slate (draftStep1() creates a genuinely new draft
  /// server-side once the previous one is no longer 'draft').
  void reset() {
    draftId = null;
    nextOfKinName = null;
    nextOfKinRelationship = null;
    nextOfKinPhone = null;
    nextOfKinEmail = null;
    selfieCapturedAt = null;
    pepWho = null;
    pepPosition = null;
    brokerOrNgxEmployed = false;
    // A fresh attempt has nothing locked either — see [lockedStepRoutes]'s
    // own doc comment.
    lockedStepRoutes = const {};
    notifyListeners();
  }
}
