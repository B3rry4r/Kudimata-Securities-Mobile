// Kudimata Securities — shared KYC in-progress form state.
//
// WHY THIS EXISTS: the KYC screens (bvn → id-upload → liveness → next-of-kin)
// each collect a different slice of ONE eventual submission, but only the
// LAST screen (next-of-kin) calls the real backend:
//   POST /kyc-submissions   body: {bvn, nin, documentType, nextOfKin}
// (see /workspace/projects/Kudimata-Securities-Backend/.pipeline/registry.json,
// KycSubmission resource). Fields entered on earlier screens must survive
// in-memory until that final call — today each screen only holds its own
// TextEditingControllers and discards them on navigation (see the
// STUB-kyc-* entries in .pipeline/fragments/kyc-*.json). This class is the
// ONE shared place every screen stashes its piece, so multiple screen-wiring
// agents don't each invent a different mechanism.
//
// HOW TO USE (mirrors AppState/AppScope exactly — no new InheritedWidget):
//   AppScope.read(context).kycForm.setBvn(_bvn.text);         // on Continue
//   AppScope.read(context).kycForm.registerUploadedDocument(  // after upload
//       objectKey, 'nin');
//   final body = AppScope.read(context).kycForm.toSubmissionBody();
//   // next-of-kin screen: POST /kyc-submissions with `body`, then on success
//   // AppScope.read(context).setKycSubmitted(true) as today.
//
// `documentType` on `KycSubmission` is `enum(nin,passport,drivers_licence,
// resubmission)` — id_upload.dart's local ids are 'nin' | 'passport' |
// 'licence'; the kyc-id wiring agent must map 'licence' -> 'drivers_licence'
// before calling [setDocumentType].
//
// `nin` (the National Identification Number string) is required by the final
// POST body but none of the screens today have a text field for it —
// id_upload.dart only captures a document TYPE + an uploaded file. The
// kyc-id (or a future) screen-wiring agent must add a way to collect it (or
// this stays null and the final call fails validation) — that decision is
// out of scope for this shared holder.
//
// name/dob/address/city/state are DELIBERATELY NOT collected here anymore
// (2026-08-07, supersedes.json S-9) — they moved to the post-signup
// onboarding step (screens/onboarding/personal_details_screen.dart), which
// persists them straight to the User record via PATCH /users/me. KYC now
// starts from BVN; "personal details" is onboarding, not identity
// verification. [toSubmissionBody] omits address/city/state entirely —
// KycSubmissionsService falls back to the investor's on-file User record for
// all three when they're absent from the request body.
import 'package:flutter/foundation.dart';

/// One uploaded KYC document, as recorded by the presigned-upload flow
/// (`POST /kyc-documents/upload-url` -> upload bytes -> `POST /kyc-documents`).
/// `documentKind` matches the backend enum: nin | passport | drivers_licence |
/// proof_of_address | liveness_selfie.
@immutable
class KycUploadedDocument {
  const KycUploadedDocument({required this.objectKey, required this.documentKind});

  final String objectKey;
  final String documentKind;
}

/// Shared, in-memory holder for everything the 5 KYC screens collect before
/// the single real `POST /kyc-submissions` call on the next-of-kin screen.
/// Reached the same way as every other piece of app session state:
/// `AppScope.read(context).kycForm` (see lib/app/app_state.dart).
class KycFormState extends ChangeNotifier {
  // kyc-bvn (step 1).
  String? bvn;

  // kyc-id (step 2). NIN number string (see file header — no current screen
  // field collects this) and the resolved documentType enum value.
  String? nin;
  String? documentType; // nin | passport | drivers_licence | resubmission

  // kyc-id + kyc-liveness: uploaded documents (presigned-upload flow).
  // kyc-liveness registers its selfie here too, with documentKind
  // 'liveness_selfie'.
  final List<KycUploadedDocument> _documents = [];
  List<KycUploadedDocument> get documents => List.unmodifiable(_documents);

  // kyc-next-of-kin (step 4 / final screen).
  String? nextOfKinName;
  String? nextOfKinRelationship;
  String? nextOfKinPhone;

  void setBvn(String v) {
    bvn = v;
    notifyListeners();
  }

  void setNin(String v) {
    nin = v;
    notifyListeners();
  }

  void setDocumentType(String v) {
    documentType = v;
    notifyListeners();
  }

  void setNextOfKinName(String v) {
    nextOfKinName = v;
    notifyListeners();
  }

  void setNextOfKinRelationship(String v) {
    nextOfKinRelationship = v;
    notifyListeners();
  }

  void setNextOfKinPhone(String v) {
    nextOfKinPhone = v;
    notifyListeners();
  }

  /// Records one uploaded KYC document (from kyc-id's ID upload or
  /// kyc-liveness's selfie capture), after the presigned-upload flow
  /// (`POST /kyc-documents/upload-url` then `POST /kyc-documents`) completes.
  /// [objectKey] is the object storage key returned by upload-url;
  /// [documentKind] is one of nin | passport | drivers_licence |
  /// proof_of_address | liveness_selfie.
  void registerUploadedDocument(String objectKey, String documentKind) {
    _documents.add(KycUploadedDocument(objectKey: objectKey, documentKind: documentKind));
    notifyListeners();
  }

  /// Assembles the exact `POST /kyc-submissions` request body — bvn, nin,
  /// documentType, and nextOfKin (object) — per registry.json's KycSubmission
  /// POST endpoint. address/city/state are deliberately omitted (see file
  /// header): KycSubmissionsService falls back to the investor's on-file
  /// User record, populated by the onboarding personal-details step. Call
  /// this from the next-of-kin screen's submit handler, once fields
  /// collected earlier in the flow are read through this shared holder.
  Map<String, dynamic> toSubmissionBody() {
    return {
      'bvn': bvn,
      'nin': nin,
      'documentType': documentType,
      'nextOfKin': {
        'name': nextOfKinName,
        'relationship': nextOfKinRelationship,
        'phone': nextOfKinPhone,
      },
    };
  }

  /// Clears every collected field for a fresh resubmission attempt (kyc
  /// outcome screen's "Resubmit documents"/"Start again" actions — see
  /// lib/screens/kyc/outcome_not_approved.dart). Re-entering kyc-bvn with the
  /// FIRST attempt's stale data would be wrong (e.g. a rejected document
  /// upload should not silently carry over); this restarts the collection
  /// flow with a clean slate. `documents` is a private growable list, so
  /// it's cleared in place rather than reassigned.
  void reset() {
    bvn = null;
    nin = null;
    documentType = null;
    _documents.clear();
    nextOfKinName = null;
    nextOfKinRelationship = null;
    nextOfKinPhone = null;
    notifyListeners();
  }
}
