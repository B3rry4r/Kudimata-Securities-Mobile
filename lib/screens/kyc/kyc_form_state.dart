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

  /// Bug fix (2026-08-31, "CHN does not still work on skip"): set the
  /// instant chn_screen.dart's investor picks "No, or I'm not sure" and
  /// taps the skip control. Session-local, in-memory only — same pattern
  /// as [lockedStepRoutes]/[selfieCapturedAt] above, for the same reason:
  /// the backend has no "CHN was skipped" field of its own (chn_screen.dart's
  /// own header — a skip leaves `chn` permanently null, indistinguishable
  /// from never having reached the step). kyc_checklist_screen.dart's
  /// `_loadChecklistSteps` used to infer "past CHN" only from a primary-ID
  /// document existing on the draft — real evidence, but evidence that
  /// cannot exist yet at the exact moment a skip is happening, since
  /// id_upload.dart is the NEXT screen. That made `nextKycStepRoute` re-read
  /// "CHN not done" immediately after the skip it was supposed to act on,
  /// routing the investor straight back to the screen they just left —
  /// indistinguishable from Skip doing nothing. This flag closes that one
  /// tick of the gap; [reset] below clears it same as the rest.
  bool chnSkippedThisSession = false;

  void markChnSkipped() {
    chnSkippedThisSession = true;
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

  void setDeclarations({String? pepWho, String? pepPosition}) {
    this.pepWho = pepWho;
    this.pepPosition = pepPosition;
    notifyListeners();
  }

  /// Clears the held draft id for a genuinely FRESH attempt (kyc-outcome's
  /// "Start again" for an expired submission, and a completed submission
  /// after kyc-next-of-kin's finalize succeeds). Re-entering kyc-bvn-nin
  /// with the previous attempt's stale draft id would be wrong; this
  /// restarts step 1 with a clean slate (draftStep1() creates a genuinely
  /// new draft server-side once the previous one is no longer 'draft').
  ///
  /// [keepDraft] — 2026-09-01, defect B. A self-service retry
  /// (POST /kyc-submissions/retry) does NOT start a new attempt: the
  /// backend REUSES the same submission row, keeps every check that
  /// passed, keeps the ID document and the utility bill, and deletes only
  /// a failed liveness selfie. Wiping [draftId] and the next-of-kin block
  /// on that path threw all of that away on the client's side and marched
  /// the investor back to step 1 no matter what actually failed — the
  /// unconditional wipe this parameter exists to end. A retry therefore
  /// clears only what it is about to redo; a restart still clears
  /// everything, exactly as before.
  ///
  /// [selfieCapturedAt] is cleared either way: it is a display-only
  /// timestamp for a selfie that is about to be recaptured (retry) or has
  /// no submission left to belong to (restart). So are the PEP free-text
  /// fields and the session-local navigation flags, which never survived a
  /// round trip in the first place.
  void reset({bool keepDraft = false}) {
    if (!keepDraft) {
      draftId = null;
      nextOfKinName = null;
      nextOfKinRelationship = null;
      nextOfKinPhone = null;
      nextOfKinEmail = null;
    }
    selfieCapturedAt = null;
    pepWho = null;
    pepPosition = null;
    // A fresh attempt has nothing locked either — see [lockedStepRoutes]'s
    // own doc comment.
    lockedStepRoutes = const {};
    chnSkippedThisSession = false;
    notifyListeners();
  }
}
