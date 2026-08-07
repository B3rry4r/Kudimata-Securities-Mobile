// Kudimata Securities — KYC repository.
//
// One resource per lib/data/api/README.md's convention, backing the final
// kyc-next-of-kin screen's real submission. registry.json's KycSubmission
// resource:
//   POST /kyc-submissions  body {bvn,nin,documentType,nextOfKin,address}
//                          -> KycSubmission (has `id`)
//
// Document upload + registration (POST /kyc-documents/upload-url, the S3
// PUT, and POST /kyc-documents) lives in KycDocumentRepository
// (kyc_document_repository.dart) — see that file's header for the full
// flow, including why document *registration* can only happen after
// [submit] returns a real `kycSubmissionId` (lib/screens/kyc/next_of_kin.dart
// loops over `KycFormState.documents` and calls
// `KycDocumentRepository.registerDocument` once per entry, right after its
// own [submit] call succeeds).
import '../api/api_client.dart';

/// The subset of `KycSubmission` (registry.json) the kyc-submitted screen
/// needs to decide where to route next. `status` is the authoritative field
/// (`pending|review|approved|rejected|flagged|expired`); `vendorDecision`
/// (`no_decision|rejected|approved`) is LumiID's synchronous NIN/BVN check
/// result, surfaced alongside it for completeness.
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
    this.vendorDecision,
    this.bvn,
    this.flagReason,
    this.flagDetail,
    this.attemptCount = 0,
    this.maxAttempts = 1,
  });

  final String status;
  final String? vendorDecision;
  final String? bvn; // masked "••• 4821" — see [KycRepository.me]
  final String? flagReason;
  final String? flagDetail;
  final int attemptCount;
  final int maxAttempts;

  bool get isApproved => status == 'approved';

  /// Whether the investor still has a resubmission attempt available, per
  /// KycSubmission's `attemptCount`/`maxAttempts` (registry.json).
  bool get canResubmit => attemptCount < maxAttempts;
}

class KycRepository {
  const KycRepository(this._client);
  final ApiClient _client;

  /// POST /kyc-submissions. [body] is exactly
  /// `KycFormState.toSubmissionBody()`'s shape. Returns the new
  /// KycSubmission's `id`.
  Future<String> submit(Map<String, dynamic> body) async {
    final response = await _client.post('/kyc-submissions', data: body);
    final data = response.data as Map<String, dynamic>;
    return data['id'] as String;
  }

  /// GET /kyc-submissions/me — the current user's own KycSubmission. The
  /// next-of-kin screen's [submit] call only surfaces the new submission's
  /// `id` (needed immediately, to attach documents); it does not stash the
  /// rest of that response anywhere accessible. The kyc-submitted screen
  /// re-fetches here so it can route on the REAL review outcome (LumiID's
  /// synchronous NIN/BVN checks may already have decided it) rather than a
  /// fixed timer. The kyc-approved screen also calls this defensively on
  /// mount, re-confirming `status` is genuinely `approved` before flipping
  /// AppState.kycApproved rather than trusting unconditionally that it was
  /// only reached after kyc-submitted enforced that same check.
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
    final json = response.data as Map<String, dynamic>;
    return KycSubmissionStatus(
      status: json['status'] as String? ?? 'pending',
      vendorDecision: json['vendorDecision'] as String?,
      bvn: _maskBvn(json['bvn'] as String?),
      flagReason: json['flagReason'] as String?,
      flagDetail: json['flagDetail'] as String?,
      attemptCount: json['attemptCount'] as int? ?? 0,
      maxAttempts: json['maxAttempts'] as int? ?? 1,
    );
  }

  String? _maskBvn(String? bvn) {
    if (bvn == null || bvn.isEmpty) return null;
    if (bvn.length <= 4) return '••• $bvn';
    return '••• ${bvn.substring(bvn.length - 4)}';
  }
}
