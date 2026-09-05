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

/// A single source-of-funds answer — Nigerian SEC No Objection condition 2
/// (2026-09-04): "a dedicated 'Source of Funds' field within the onboarding
/// questionnaire to support appropriate investor profiling and the required
/// AML/CFT due diligence."
///
/// `code` is the wire value (the backend's `SourceOfFunds` enum); `label` is
/// what the investor reads. Paired here, in lib/data/, because the code is a
/// wire shape and a screen must never invent one.
class SourceOfFundsOption {
  const SourceOfFundsOption(this.code, this.label);
  final String code;
  final String label;
}

/// The nine answers, in the order the flow offers them — mirrors the
/// backend's `SourceOfFunds` Prisma enum and `SOURCE_OF_FUNDS_VALUES`
/// (src/kyc-submissions/dto/source-of-funds.validators.ts) exactly.
///
/// A CLOSED list, not free text: an AML/CFT profiling answer that cannot be
/// compared across investors does not support screening. `other` is the
/// escape hatch and requires a written description — see
/// [KycRepository.updateDraftFields] and source_of_funds_screen.dart.
const List<SourceOfFundsOption> kSourceOfFundsOptions = [
  SourceOfFundsOption('salary_employment', 'Salary or employment income'),
  SourceOfFundsOption('business_income', 'Business income'),
  SourceOfFundsOption('savings', 'Savings'),
  SourceOfFundsOption('investment_returns', 'Investment returns'),
  SourceOfFundsOption('gift', 'A gift'),
  SourceOfFundsOption('inheritance', 'Inheritance'),
  SourceOfFundsOption('loan', 'A loan'),
  SourceOfFundsOption('property_sale', 'Sale of property'),
  SourceOfFundsOption('other', 'Something else'),
];

/// The code the free-text description belongs to. Named rather than spelled
/// as a bare string at each of the four places that test for it.
const String kSourceOfFundsOtherCode = 'other';

/// Longest occupation the backend accepts — mirrors OCCUPATION_MAX_LENGTH in
/// the backend's src/common/occupation.ts, which is the single definition of
/// this bound on that side. Declared here in lib/data/ (not on the screen)
/// because it is part of the wire contract: a screen that let an investor type
/// 300 characters would be building a request the server refuses.
///
/// Occupation is FREE TEXT, deliberately unlike [kSourceOfFundsOptions]' closed
/// list. Source of funds is a profiling answer that only supports AML screening
/// if it is comparable across investors, so it must be a closed list. Occupation
/// is an identification answer — SEC (Capital Market Operators) AML/CFT/CPF
/// Regulations 2022, reg 50(3)(e), "verification of employment or public
/// position held" — and it is genuinely open-ended; any list short enough to
/// show would be wrong for someone, and pushing real answers into an "Other"
/// bucket destroys the exact detail the regulation asks for.
const int kOccupationMaxLength = 100;

/// Shortest occupation the backend accepts (OCCUPATION_MIN_LENGTH, same file).
/// Two characters, so "HR" fits.
const int kOccupationMinLength = 2;

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
    this.nin,
    this.chn,
    this.pepSelfDeclared,
    this.sourceOfFunds,
    this.sourceOfFundsOther,
    this.occupation,
    this.documentType,
    this.documents = const [],
    this.flagReason,
    this.flagDetail,
    this.attemptCount = 0,
    this.maxAttempts = 1,
    this.currentStep,
    this.totalSteps,
    this.verificationSignals,
    this.failureReasons,
    this.resolvedName,
    this.resolvedDob,
    this.resolvedPhone,
    this.nextOfKin,
    this.canRetry = false,
  });

  final String status;
  final String? id;
  final String? vendorDecision;
  final String? bvn; // masked "••• 4821" — see [KycRepository.me]
  /// Masked the SAME way as [bvn] (see [KycRepository._maskBvn]) — the
  /// backend applies no server-side masking to nin any more than it does to
  /// bvn for the investor's own GET .../me|draft, so this mirrors bvn's
  /// existing client-side masking rather than showing it in full on the
  /// review screen (added 2026-08-24 for review_submit_screen.dart).
  final String? nin;
  /// Added 2026-08-24 (canvas screens 15/22) — the CSCS CHN, not masked
  /// server-side (kyc-submissions.service.ts's toWire: "not sensitive like
  /// bvn/nin"), so not masked here either.
  final String? chn;
  final bool? pepSelfDeclared;

  /// Source of funds — Nigerian SEC No Objection condition 2 (2026-09-04),
  /// the AML/CFT profiling answer collected at its own KYC step. One of
  /// [kSourceOfFundsOptions]' codes, or null on a draft that has not reached
  /// that step yet. Not masked server-side (it is a declaration the investor
  /// typed, not a credential), so not masked here either.
  final String? sourceOfFunds;

  /// The free text behind [sourceOfFunds] == 'other'. Non-null only for
  /// 'other', and required by the server in that case — see
  /// [KycRepository.updateDraftFields].
  final String? sourceOfFundsOther;

  /// The investor's occupation or public position — SEC (Capital Market
  /// Operators) AML/CFT/CPF Regulations 2022, reg 50(3)(e): "verification of
  /// employment or public position held". Collected on the SAME KYC step as
  /// [sourceOfFunds] (step 6) and required by the same server-side finalize
  /// gate; null on a draft that has not reached that step yet. Free text,
  /// bounded — see [kOccupationMaxLength].
  final String? occupation;

  /// Set once step 2 (id document) registers — null on a fresh draft.
  final String? documentType;
  /// Every document registered against this submission/draft so far —
  /// added 2026-08-24 for review_submit_screen.dart's per-step summary rows
  /// (id file count, proof-of-address filename/date).
  final List<KycDocumentSummary> documents;
  final String? flagReason;
  final String? flagDetail;
  final int attemptCount;
  final int maxAttempts;
  final int? currentStep;
  final int? totalSteps;

  /// The real per-check verification breakdown (2026-08-20 fix — reported:
  /// "on the dashboard and on the app WE CAN'T TELL WHAT WAS WRONG" for a
  /// rejected/flagged account). Null entries mean that check never ran
  /// (e.g. no liveness selfie yet); `false` is an actual reason to
  /// reject/flag. See outcome_not_approved.dart's _failedChecks for how
  /// this becomes plain-language copy.
  final KycVerificationSignals? verificationSignals;

  /// R-50 (DECISIONS.md, 2026-08-31) / BR-10 (BACKEND_GAPS.md): the
  /// structured per-reason breakdown outcome_not_approved.dart renders —
  /// see [KycFailureReason]'s own doc comment. Served by the backend as of
  /// 2026-09-01 (`failureReasons` on `GET /kyc-submissions/me|draft`).
  ///
  /// Null means the response carried no such field at all — an older
  /// backend. An empty list is a different, real answer: "structured, and
  /// nothing failed". The two are kept distinguishable (no `?? const []`)
  /// because outcome_not_approved.dart treats them differently.
  final List<KycFailureReason>? failureReasons;

  /// The BVN/NIN registry's OWN resolved name/date-of-birth/phone from the
  /// most recent lookup (BR-4, MOBILE-REQUESTS.md 2026-08-27 — added for
  /// bvn_nin.dart's `s13` "Is this you?" confirmation, A-2 2026-08-29 audit
  /// fix). Distinct from an account's own on-file name/dob (never carried
  /// on this model at all) — these three are null whenever no lookup has
  /// run yet, every provider failed, or the provider's response simply
  /// omitted that field; that's a normal, expected "not available" outcome,
  /// not an error, same meaning null already carries on
  /// [verificationSignals]'s booleans.
  final String? resolvedName;

  /// ISO-8601 date (`YYYY-MM-DD`), or null — see [resolvedName].
  final String? resolvedDob;
  final String? resolvedPhone;

  /// The next of kin already recorded on this submission server-side
  /// (2026-09-01). Parsed for ONE reason: a self-service retry reuses the
  /// same submission row, and re-finalizing it (POST /kyc-submissions/
  /// draft/finalize) requires next-of-kin in the body — so without this the
  /// app would have to make the investor re-type details the server is
  /// already holding, which is precisely what a targeted retry exists to
  /// avoid. Null on a submission that has not been finalized yet.
  final KycNextOfKin? nextOfKin;

  /// Whether `POST /kyc-submissions/retry` would be GRANTED on this
  /// submission right now — the backend's own `canRetry`, which is the
  /// literal predicate that endpoint throws from (KycSubmissionsService.
  /// retryRefusal). Read it; never re-derive retry eligibility here.
  ///
  /// This app used to decide for itself, from `status` plus
  /// [canResubmit] — which is how a `pending` submission left open by a
  /// verification-provider outage sat on submitted.dart's "we're reviewing
  /// your details" forever: the server would have happily re-run the
  /// unanswered check, and no screen in this app ever asked it to.
  ///
  /// Defaults to false when the field is absent (an older backend), so a
  /// missing value can only ever HIDE a control, never offer a dead one.
  final bool canRetry;

  bool get isApproved => status == 'approved';
  bool get isDraft => status == 'draft';

  /// True when this submission is open only because a verification
  /// provider never ANSWERED a check — not because the investor failed
  /// one. The backend's shape for that (see its `unansweredChecks()`): a
  /// still-open `pending`/`review` decision with no staff flagReason,
  /// which the server is nonetheless willing to retry. There is nothing
  /// for the investor to redo in this state; the retry re-runs the lookup
  /// server-side from the BVN/NIN already on the row.
  bool get isAwaitingUnansweredCheck =>
      canRetry && flagReason == null && (status == 'pending' || status == 'review');

  /// Whether the investor still has a resubmission attempt available, per
  /// KycSubmission's `attemptCount`/`maxAttempts` (registry.json).
  bool get canResubmit => attemptCount < maxAttempts;

  /// True when a staff member just rejected this submission but
  /// resubmission room remains — the backend's updateDecision() sends
  /// status back to 'pending' in that case (not a terminal 'rejected'),
  /// per the frozen contract's own status-transition rule, but it DOES
  /// persist the reason onto flagReason/flagDetail (2026-08-20 fix). A
  /// plain not-yet-decided 'pending' submission never has flagReason set —
  /// only this exact path does — so this is an unambiguous signal, not a
  /// guess. Fixes: "it was rejected but app still told me under review".
  bool get isRejectedWithRoomToRetry => status == 'pending' && flagReason != null;
}

/// See [KycSubmissionStatus.verificationSignals]. Each field: true (passed),
/// false (failed — a real reason to reject/flag), null (never attempted).
///
/// The backend also serves a sixth signal, `sanctions`, which this app
/// deliberately does not read. Two independent reasons, either enough on
/// its own:
///   - Kudimata's AML/sanctions screening is switched off, so that boolean
///     is null on every response — and this app renders a null signal as a
///     spinner (submitted.dart's checklist), which would show an investor
///     a check that appears to be running and never finishes.
///   - Even switched on, an investor may not be told anything specific
///     about it. A match reaches this app only as the backend's single
///     generic [KycFailureReason] — see that class for the legal reason.
/// So there is no honest rendering of the boolean here, and adding one
/// would create a screen that only becomes correct if a provider is
/// switched on.
class KycVerificationSignals {
  const KycVerificationSignals({
    required this.nin,
    required this.bvn,
    required this.name,
    required this.dob,
    required this.liveness,
  });

  factory KycVerificationSignals.fromJson(Map<String, dynamic> json) {
    return KycVerificationSignals(
      nin: json['nin'] as bool?,
      bvn: json['bvn'] as bool?,
      name: json['name'] as bool?,
      dob: json['dob'] as bool?,
      liveness: json['liveness'] as bool?,
    );
  }

  final bool? nin;
  final bool? bvn;
  final bool? name;
  final bool? dob;
  final bool? liveness;
}

/// One reason a KYC submission failed/was flagged, in words an investor can
/// act on — R-50 (DECISIONS.md, 2026-08-31): "the app tells them what
/// actually went wrong... the investor has to know what to do differently,
/// or the retry is a lottery." Served by the backend as of 2026-09-01
/// (BR-10, BACKEND_GAPS.md): `GET /kyc-submissions/me|draft` carries a
/// `failureReasons` array of `{code, message, retryable}`, built by the
/// single `buildFailureReasons()` in the backend's
/// kyc-submissions.service.ts.
///
/// **The sentences live in the backend and only there.** This class used to
/// be an empty promise: nothing sent `failureReasons`, so
/// outcome_not_approved.dart re-derived reasons from
/// [KycVerificationSignals]'s booleans using its own second copy of the
/// same five sentences, and stamped `retryable: true` on every one — which
/// is precisely the claim a sanctions/AML hold must never carry. That copy
/// is gone. This app renders [message] and never composes its own.
class KycFailureReason {
  const KycFailureReason({required this.code, required this.message, required this.retryable});

  /// [retryable] defaults to FALSE when the key is missing, matching
  /// [KycSubmissionStatus.canRetry]'s rule: a value this app did not
  /// receive may only ever hide a control, never offer one. Guessing
  /// `true` is the exact mistake this whole field exists to prevent — the
  /// one shape that must not be guessed is a compliance hold.
  factory KycFailureReason.fromJson(Map<String, dynamic> json) => KycFailureReason(
        code: json['code'] as String? ?? '',
        message: json['message'] as String? ?? '',
        retryable: json['retryable'] as bool? ?? false,
      );

  /// The failed check's own name — `nin`, `bvn`, `name`, `dob`,
  /// `liveness` — so `failedKycStepRoutes` (kyc_checklist_screen.dart) can
  /// send the investor back to the step that produced it. Never rendered;
  /// the investor reads [message].
  ///
  /// `compliance_hold` is the backend's tip-off-safe generic case and
  /// names no step on purpose. Any OTHER value — a check added to the
  /// backend after this build shipped — is treated the same way: its
  /// [message] is shown as a plain sentence and it routes to no step. An
  /// unrecognised code is not an error and must never be one.
  final String code;

  /// Investor-facing, plain language, specific enough to act on — "your
  /// selfie didn't match your ID photo", not "verification failed". For a
  /// sanctions/AML hold this is the backend's own deliberately generic
  /// copy (R-50's one exception, below) and is rendered verbatim — this
  /// app must never try to make it more specific.
  final String message;

  /// False for a decision the investor cannot change by trying again — a
  /// sanctions/AML match most of all (R-50: naming that specific reason is
  /// "tipping off", an offence under Nigerian AML law, so the backend
  /// deliberately sends a generic [message] with `retryable: false`
  /// instead of a real reason). When ANY reason on a submission is
  /// non-retryable, outcome_not_approved.dart treats the WHOLE case as a
  /// decision, never mixes a "try again" control into the same screen as
  /// a reason nobody can act on.
  final bool retryable;
}

/// The next-of-kin block already stored on a KycSubmission — see
/// [KycSubmissionStatus.nextOfKin]. Mirrors the backend's own `NextOfKin`
/// wire shape (common/types/kyc.types.ts) exactly: name, relationship,
/// phone, and an optional email.
class KycNextOfKin {
  const KycNextOfKin({
    required this.name,
    required this.relationship,
    required this.phone,
    this.email,
  });

  factory KycNextOfKin.fromJson(Map<String, dynamic> json) => KycNextOfKin(
        name: json['name'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
      );

  final String name;
  final String relationship;
  final String phone;
  final String? email;
}

/// One registered KycDocument (registry.json) — see
/// [KycSubmissionStatus.documents]. Only the fields review_submit_screen.dart
/// actually needs (document kind, its own display name, when it was
/// uploaded); the full KycDocument wire shape carries more (id, objectKey)
/// that no mobile screen reads.
class KycDocumentSummary {
  const KycDocumentSummary({required this.documentKind, required this.documentName, this.uploadedAt});
  final String documentKind;
  final String documentName;
  final DateTime? uploadedAt;

  factory KycDocumentSummary.fromJson(Map<String, dynamic> json) => KycDocumentSummary(
        documentKind: json['documentKind'] as String? ?? '',
        documentName: json['documentName'] as String? ?? '',
        uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? ''),
      );
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
    // Both connectTimeout AND receiveTimeout need overriding, not just
    // receiveTimeout (2026-08-20 follow-up fix — still hit a 15s timeout
    // after the first attempt: the error was Dio's CONNECT-timeout message,
    // not receive-timeout. On Flutter web, Dio's XHR-based adapter has no
    // real separate connect/receive phases, so connectTimeout — left at
    // its 15s BaseOptions default — was still the one governing this
    // whole long-running call).
    final response = await _client.post(
      '/kyc-submissions/draft/liveness',
      options: Options(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
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
    String? nextOfKinEmail,
    String? address,
    String? city,
    String? state,
  }) async {
    final response = await _client.post('/kyc-submissions/draft/finalize', data: {
      'nextOfKin': {
        'name': nextOfKinName,
        'relationship': nextOfKinRelationship,
        'phone': nextOfKinPhone,
        'email': ?nextOfKinEmail,
      },
      'address': ?address,
      'city': ?city,
      'state': ?state,
    });
    return _fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH /kyc-submissions/draft (2026-08-24, canvas screens 15 "CHN" and
  /// 20 "Declarations · PEP") — a lightweight field update on the caller's
  /// EXISTING draft, independent of the heavier verification steps. At
  /// least one of [chn]/[pepSelfDeclared] should be passed; either omitted
  /// leaves that field untouched server-side (see
  /// UpdateKycDraftFieldsRequest's doc comment, backend
  /// common/types/kyc.types.ts).
  ///
  /// [sourceOfFunds]/[sourceOfFundsOther] were added 2026-09-04 (SEC No
  /// Objection condition 2). The server enforces the pairing rule: 'other'
  /// REQUIRES a non-empty [sourceOfFundsOther] and every other answer refuses
  /// one, both 400s. source_of_funds_screen.dart applies the same rule in the
  /// UI so the investor sees it as a field error rather than a request
  /// failure, but the server is the one that decides.
  ///
  /// [occupation] was added 2026-09-05 (SEC AML/CFT/CPF Regulations 2022, reg
  /// 50(3)(e)). It is collected on the SAME screen as [sourceOfFunds] and rides
  /// this SAME endpoint — no new route was added for it. The server trims it,
  /// collapses internal whitespace and stores the normalised form, so a value
  /// read back may differ in spacing from the one sent; send it trimmed anyway
  /// so the two agree. Refused server-side (400 OCCUPATION_REQUIRED) when it is
  /// empty or whitespace-only.
  Future<KycSubmissionStatus> updateDraftFields({
    String? chn,
    bool? pepSelfDeclared,
    String? sourceOfFunds,
    String? sourceOfFundsOther,
    String? occupation,
  }) async {
    final response = await _client.patch('/kyc-submissions/draft', data: {
      'chn': ?chn,
      'pepSelfDeclared': ?pepSelfDeclared,
      'sourceOfFunds': ?sourceOfFunds,
      'sourceOfFundsOther': ?sourceOfFundsOther,
      'occupation': ?occupation,
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

  /// POST /kyc-submissions/retry (no body) — a self-service retry on the
  /// caller's own most recent submission. Grantable exactly when
  /// [KycSubmissionStatus.canRetry] is true; throws [ApiException] (409 /
  /// 422) otherwise, so the button is never a lie in either direction.
  ///
  /// Server-side this REUSES the same submission row rather than starting
  /// a new one: every check that passed keeps its verdict, the ID document
  /// and the utility bill are left alone, only a failed liveness selfie is
  /// deleted, and any check a provider never answered is re-run
  /// immediately from the BVN/NIN already on the row — which is why this
  /// call takes no arguments and asks the investor for nothing.
  ///
  /// The response tells the caller what happened. `status == 'draft'`
  /// means work was handed back: walk the investor through the steps whose
  /// [KycSubmissionStatus.verificationSignals] came back `false` (see
  /// `failedKycStepRoutes`, kyc_checklist_screen.dart) and re-finalize.
  /// Any other status means the retry resolved on its own and the
  /// submission has a real decision again.
  ///
  /// Uses the same widened timeouts [verifyDraftLiveness] does, for the
  /// same reason: this call can re-run a registry lookup (and, when the
  /// selfie was the unanswered check, a face-liveness pass) inline.
  Future<KycSubmissionStatus> retry() async {
    final response = await _client.post(
      '/kyc-submissions/retry',
      options: Options(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return _fromJson(response.data as Map<String, dynamic>);
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
      nin: _maskBvn(json['nin'] as String?),
      chn: json['chn'] as String?,
      pepSelfDeclared: json['pepSelfDeclared'] as bool?,
      sourceOfFunds: json['sourceOfFunds'] as String?,
      sourceOfFundsOther: json['sourceOfFundsOther'] as String?,
      occupation: json['occupation'] as String?,
      documentType: json['documentType'] as String?,
      documents: (json['documents'] as List<dynamic>? ?? const [])
          .map((d) => KycDocumentSummary.fromJson(d as Map<String, dynamic>))
          .toList(),
      flagReason: json['flagReason'] as String?,
      flagDetail: json['flagDetail'] as String?,
      attemptCount: json['attemptCount'] as int? ?? 0,
      maxAttempts: json['maxAttempts'] as int? ?? 1,
      currentStep: json['currentStep'] as int?,
      totalSteps: json['totalSteps'] as int?,
      verificationSignals: json['verificationSignals'] != null
          ? KycVerificationSignals.fromJson(json['verificationSignals'] as Map<String, dynamic>)
          : null,
      // BR-10 — see KycFailureReason's own doc comment. Kept nullable (not
      // `?? const []`) so an empty array, which means "structured, and
      // nothing failed", stays distinguishable from an older backend that
      // sends no such field at all.
      failureReasons: (json['failureReasons'] as List<dynamic>?)
          ?.map((r) => KycFailureReason.fromJson(r as Map<String, dynamic>))
          .toList(),
      resolvedName: json['resolvedName'] as String?,
      resolvedDob: json['resolvedDob'] as String?,
      resolvedPhone: json['resolvedPhone'] as String?,
      nextOfKin: json['nextOfKin'] != null
          ? KycNextOfKin.fromJson(json['nextOfKin'] as Map<String, dynamic>)
          : null,
      // Absent (older backend) reads as false — see [canRetry]'s own doc
      // comment: a missing value must only ever hide a control.
      canRetry: json['canRetry'] as bool? ?? false,
    );
  }

  String? _maskBvn(String? bvn) {
    if (bvn == null || bvn.isEmpty) return null;
    if (bvn.length <= 4) return '••• $bvn';
    return '••• ${bvn.substring(bvn.length - 4)}';
  }
}
