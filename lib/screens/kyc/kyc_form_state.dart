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

  /// Clears the held draft id for a fresh attempt (kyc-outcome screen's
  /// "Resubmit documents"/"Start again" actions — see
  /// lib/screens/kyc/outcome_not_approved.dart — and a completed submission
  /// after kyc-next-of-kin's finalize succeeds). Re-entering kyc-bvn-nin
  /// with the FIRST attempt's stale draft id would be wrong; this restarts
  /// step 1 with a clean slate (draftStep1() creates a genuinely new draft
  /// server-side once the previous one is no longer 'draft').
  void reset() {
    draftId = null;
    notifyListeners();
  }
}
