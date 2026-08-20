// Kudimata Securities — KYC repository.
//
// One resource per lib/data/api/README.md's convention. registry.json's
// KycSubmission resource, PHASED as of 2026-08-20 (user directive: "we need
// to break the KYC into parts not all at one submit"):
//   POST /kyc-submissions/draft            {bvn,nin} -> KycSubmission (step 1)
//   POST /kyc-submissions/draft/liveness   (no body) -> KycSubmission (step 3)
//   POST /kyc-submissions/draft/finalize   {nextOfKin,address?,city?,state?}
//                                                     -> KycSubmission (step 5)
//   GET  /kyc-submissions/draft            -> KycSubmission | null (resume)
//   GET  /kyc-submissions/me               -> KycSubmission (any status)
//
// Steps 2 (id document) and 4 (utility bill) are plain document uploads —
// see KycDocumentRepository, unchanged by the phased-KYC directive.
//
// The old all-at-once `POST /kyc-submissions` (bvn+nin+documentType+
// nextOfKin+address in one call) still exists server-side but is
// superseded — nothing in this app calls it any more as of this pass.
import 'package:dio/dio.dart' show Options;

import '../api/api_client.dart';

/// The subset of `KycSubmission` (registry.json) the KYC flow's screens
/// need. `status` is the authoritative field
/// (`draft|pending|review|approved|rejected|flagged|expired`); `vendorDecision`
/// (`no_decision|rejected|approved`) is the verification provider's
/// synchronous NIN/BVN check result, surfaced alongside it for completeness.
///
/// `id` (2026-08-20, phased KYC) is the draft/submission id — needed by
/// id_upload.dart/liveness.dart/utility_bill.dart to register a document
/// against it (`POST /kyc-documents {kycSubmissionId: id, ...}`).
///
/// `currentStep`/`totalSteps` (2026-08-20, phased KYC) are present only
/// while `status == 'draft'` — see KycFlowStep's doc comment for how a
/// step number maps to a route.
///
/// `bvn` (added for the account-personal screen's masked "BVN" row) is
/// optional and defaults to null so the existing kyc-submitted/kyc-approved
/// callers, which never read it, are unaffected — see [KycRepository.me]'s
/// doc comment for why it's pre-masked here rather than left raw.
///
/// `flagReason`/`flagDetail`/`attemptCount`/`maxAttempts` (added for the
/// kyc-outcome screen — see lib/screens/kyc/outcome_not_approved.dart) are
/// additive the same way: optional/defaulted so existing callers that never
/// read them are unaffected. Per registry.json's KycSubmission resource,
/// `flagReason`/`flagDetail` are nullable strings and `attemptCount`/
/// `maxAttempts` are non-nullable integers; `attemptCount` defaults to 0 and
/// `maxAttempts` to 1 if the backend ever omits them, so a missing/malformed
/// response still yields "no attempts left" (safe: shows Contact support,
/// never wrongly offers Resubmit).
class KycSubmissionStatus {
  const KycSubmissionStatus({
    required this.status,
    this.id,
    this.vendorDecision,
    this.bvn,
    this.flagReason,
    this.flagDetail,
    this.attemptCount = 0,
    this.maxAttempts = 1,
    this.currentStep,
    this.totalSteps,
  });

  final String status;
  final String? id;
  final String? vendorDecision;
  final String? bvn; // masked "••• 4821" — see [KycRepository.me]
  final String? flagReason;
  final String? flagDetail;
  final int attemptCount;
  final int maxAttempts;
  final int? currentStep;
  final int? totalSteps;

  bool get isApproved => status == 'approved';
  bool get isDraft => status == 'draft';

  /// Whether the investor still has a resubmission attempt available, per
  /// KycSubmission's `attemptCount`/`maxAttempts` (registry.json).
  bool get canResubmit => attemptCount < maxAttempts;
}

class KycRepository {
  const KycRepository(this._client);
  final ApiClient _client;

  /// POST /kyc-submissions/draft (phased KYC step 1) — bvn + nin. Creates
  /// the draft KycSubmission everything else in the flow operates on, or
  /// re-verifies the SAME existing draft if one is already in progress
  /// (redoing step 1, e.g. fixing a typo, is safe to call again).
  Future<KycSubmissionStatus> draftStep1({required String bvn, required String nin}) async {
    final response = await _client.post('/kyc-submissions/draft', data: {'bvn': bvn, 'nin': nin});
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /kyc-submissions/draft/liveness (phased KYC step 3) — no body.
  /// Requires the liveness selfie to already be uploaded+registered
  /// (KycDocumentRepository, documentKind='liveness_selfie') against the
  /// current draft; this call is what actually triggers the verification.
  ///
  /// Uses a longer receive timeout than ApiClient's 15s default (2026-08-20:
  /// "liveness works but... the timer is too low") — a real face-liveness
  /// ML pass on the backend's LumiID call can genuinely take longer than a
  /// plain lookup (the backend itself now allows up to 45s for that one
  /// call — see LumiidAdapter.verifyLiveness), so this client needs to wait
  /// at least that long too, or it gives up and shows a timeout error
  /// before the backend's own (successful) response ever arrives.
  Future<KycSubmissionStatus> verifyDraftLiveness() async {
    final response = await _client.post(
      '/kyc-submissions/draft/liveness',
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /kyc-submissions/draft/finalize (phased KYC step 5) — next of kin
  /// + address. Requires steps 2-4 (id document, liveness, utility bill)
  /// already done, or this throws [ApiException] (400) naming which step
  /// is missing. Turns the draft into a real, reviewable submission —
  /// `status` leaves 'draft' on success.
  Future<KycSubmissionStatus> finalizeDraft({
    required String nextOfKinName,
    required String nextOfKinRelationship,
    required String nextOfKinPhone,
    String? address,
    String? city,
    String? state,
  }) async {
    final response = await _client.post('/kyc-submissions/draft/finalize', data: {
      'nextOfKin': {
        'name': nextOfKinName,
        'relationship': nextOfKinRelationship,
        'phone': nextOfKinPhone,
      },
      'address': ?address,
      'city': ?city,
      'state': ?state,
    });
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /kyc-submissions/draft (resume support) — the investor's current
  /// in-progress draft, or null if there is none (never started, or
  /// already finalized/decided). kyc_intro.dart's "Start" button and
  /// hydrateGatingStateAndRoute (log_in_screen.dart) both call this to
  /// resume at the right step instead of always restarting at step 1.
  Future<KycSubmissionStatus?> getDraft() async {
    final response = await _client.get('/kyc-submissions/draft');
    final data = response.data;
    if (data == null) return null;
    return _fromJson(data as Map<String, dynamic>);
  }

  /// GET /kyc-submissions/me — the current user's own KycSubmission
  /// (whatever it currently is — draft or a real decided/pending one). The
  /// kyc-submitted screen re-fetches here so it can route on the REAL
  /// review outcome rather than a fixed timer. The kyc-approved screen also
  /// calls this defensively on mount, re-confirming `status` is genuinely
  /// `approved` before flipping AppState.kycApproved rather than trusting
  /// unconditionally that it was only reached after kyc-submitted enforced
  /// that same check.
  ///
  /// Also backs the account-personal screen's masked "BVN" row (the
  /// [bvn]/[KycSubmissionStatus.bvn] field). Per
  /// kyc-submissions.service.ts's `resolveSensitiveField`/
  /// `FULL_BVN_NIN_ROLES`, the backend actually returns the investor's own
  /// `bvn` in full plaintext for this endpoint ("it's their own data, they
  /// already know it") — it does NOT mask it server-side the way it does
  /// for the `support` role. The Personal Info design nonetheless displays
  /// BVN masked ('••• 4821', the literal this replaces), so masking happens
  /// here, client-side, mirroring the backend's own `***last4` mask shape
  /// (KycFieldEncryptionService.mask) but with the design's bullet-character
  /// prefix instead of asterisks.
  Future<KycSubmissionStatus> me() async {
    final response = await _client.get('/kyc-submissions/me');
    return _fromJson(response.data as Map<String, dynamic>);
  }

  KycSubmissionStatus _fromJson(Map<String, dynamic> json) {
    return KycSubmissionStatus(
      status: json['status'] as String? ?? 'pending',
      id: json['id'] as String?,
      vendorDecision: json['vendorDecision'] as String?,
      bvn: _maskBvn(json['bvn'] as String?),
      flagReason: json['flagReason'] as String?,
      flagDetail: json['flagDetail'] as String?,
      attemptCount: json['attemptCount'] as int? ?? 0,
      maxAttempts: json['maxAttempts'] as int? ?? 1,
      currentStep: json['currentStep'] as int?,
      totalSteps: json['totalSteps'] as int?,
    );
  }

  String? _maskBvn(String? bvn) {
    if (bvn == null || bvn.isEmpty) return null;
    if (bvn.length <= 4) return '••• $bvn';
    return '••• ${bvn.substring(bvn.length - 4)}';
  }
}
