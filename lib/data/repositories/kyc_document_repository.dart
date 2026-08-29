// Kudimata Securities — KYC document repository.
//
// See lib/data/api/README.md for the shared convention. The ONE canonical
// repository backing the presigned-upload flow used by kyc-id (ID
// document, step 2), kyc-liveness (selfie, step 3), and utility_bill.dart
// (proof of address, step 4), per registry.json's `KycDocument` resource:
//
//   1. POST /kyc-documents/upload-url  {documentKind, documentName}
//      -> {uploadUrl, objectKey}                          [requestUploadUrl]
//   2. PUT the raw file bytes directly to `uploadUrl`.                [putFile]
//      `uploadUrl` is a presigned object-storage URL, NOT a
//      Kudimata-Securities-Backend endpoint — it must NOT go through the
//      shared `ApiClient`/`client.dio`, because that instance's request
//      interceptor unconditionally attaches this session's `Authorization`
//      bearer token to every request (see api_client.dart's
//      `_buildInterceptor`), which would leak the token to whatever host the
//      presigned URL points at. A bare `Dio()` is used instead — the exact
//      same reasoning api_client.dart itself uses for its own token-refresh
//      call (`Dio(BaseOptions(baseUrl: kApiBaseUrl))`, "no interceptors").
//      Used by kyc-liveness; kyc-id/utility_bill.dart do this PUT themselves
//      with a bare `package:http` client instead (same reasoning, different
//      client).
//   3. POST /kyc-documents {kycSubmissionId, objectKey, documentName,
//      documentKind} — registers the document against the draft
//      KycSubmission (2026-08-20, phased KYC: the draft already exists by
//      this point, created on step 1 — see KycFormState.draftId,
//      lib/screens/kyc/kyc_form_state.dart), so all three screens above
//      call [registerDocument] IMMEDIATELY after their own upload
//      completes, rather than deferring registration to a later bulk call.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient`:
//   final _repo = KycDocumentRepository(AppScope.read(context).apiClient);
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

/// Result of [KycDocumentRepository.requestUploadUrl].
class KycUploadUrl {
  const KycUploadUrl({required this.uploadUrl, required this.objectKey});
  final String uploadUrl;
  final String objectKey;
}

class KycDocumentRepository {
  const KycDocumentRepository(this._client);
  final ApiClient _client;

  /// POST /kyc-documents/upload-url — requests a presigned upload URL for
  /// one KYC document. [documentKind] is one of nin | passport |
  /// drivers_licence | voters_card | proof_of_address | liveness_selfie per
  /// registry.json's `KycDocument` resource (Prisma's `KycDocumentKind`
  /// enum, `common/types/enums.ts`). Goes through the shared
  /// `ApiClient`, so failures surface as [ApiException] as usual.
  Future<KycUploadUrl> requestUploadUrl({
    required String documentKind,
    required String documentName,
  }) async {
    final response = await _client.post('/kyc-documents/upload-url', data: {
      'documentKind': documentKind,
      'documentName': documentName,
    });
    final data = response.data as Map<String, dynamic>;
    return KycUploadUrl(
      uploadUrl: data['uploadUrl'] as String,
      objectKey: data['objectKey'] as String,
    );
  }

  /// PUTs raw file [bytes] straight to a presigned [uploadUrl] returned by
  /// [requestUploadUrl] — deliberately bypasses the shared `ApiClient` (see
  /// file header). Still only ever throws [ApiException], so callers never
  /// need to know this step is implemented differently from every other
  /// repository call.
  Future<void> putFile(
    String uploadUrl,
    Uint8List bytes, {
    required String contentType,
  }) async {
    try {
      await Dio().put<void>(
        uploadUrl,
        data: bytes,
        options: Options(
          contentType: contentType,
          headers: {'Content-Length': bytes.length},
        ),
      );
    } on DioException catch (e) {
      throw ApiException(
        code: 'UPLOAD_FAILED',
        message: e.message ?? 'Uploading the file failed. Please try again.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// POST /kyc-documents — registers an already-uploaded object against the
  /// draft KycSubmission. Called by kyc-id, kyc-liveness, and
  /// utility_bill.dart immediately after their own upload completes — see
  /// file header.
  Future<void> registerDocument({
    required String kycSubmissionId,
    required String objectKey,
    required String documentName,
    required String documentKind,
  }) async {
    await _client.post('/kyc-documents', data: {
      'kycSubmissionId': kycSubmissionId,
      'objectKey': objectKey,
      'documentName': documentName,
      'documentKind': documentKind,
    });
  }
}
