// Kudimata Securities — KYC document repository.
//
// See lib/data/api/README.md for the shared convention. The ONE canonical
// repository (previously duplicated as three near-identical
// implementations — KycDocumentsRepository and part of KycRepository — now
// merged here) backing the presigned-upload flow used by kyc-id (ID
// document), kyc-liveness (selfie), and kyc-next-of-kin (registration), per
// registry.json's `KycDocument` resource:
//
//   1. POST /kyc-documents/upload-url  {documentKind, documentName}
//      -> {uploadUrl, objectKey}                          [requestUploadUrl]
//      Used by kyc-id and kyc-liveness.
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
//      Used by kyc-liveness; kyc-id does this PUT itself with a bare
//      `package:http` client instead (same reasoning, different client) —
//      see lib/screens/kyc/id_upload.dart.
//   3. POST /kyc-documents {kycSubmissionId, objectKey, documentName,
//      documentKind} — registers the document against a REAL KYC
//      submission. `kycSubmissionId` only exists after the final
//      `POST /kyc-submissions` call (next-of-kin screen, last of 5) — so
//      this step cannot run from kyc-id or kyc-liveness. Those screens
//      instead call [requestUploadUrl] (+ [putFile] for kyc-liveness), then
//      accumulate `objectKey` via `KycFormState.registerUploadedDocument`
//      (see lib/screens/kyc/kyc_form_state.dart) for kyc-next-of-kin to
//      register once a submission id exists. [registerDocument] is called
//      by kyc-next-of-kin, once per accumulated document, right after its
//      own `POST /kyc-submissions` call (via KycRepository.submit,
//      kyc_repository.dart) succeeds — not used by kyc-id/kyc-liveness.
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
  /// drivers_licence | proof_of_address | liveness_selfie per
  /// registry.json's `KycDocument` resource. Goes through the shared
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

  /// POST /kyc-documents — registers an already-uploaded object against a
  /// real KYC submission. Only callable once a `kycSubmissionId` exists
  /// (i.e. after `POST /kyc-submissions` on the next-of-kin screen) — see
  /// file header. Not used by kyc-id or kyc-liveness themselves.
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
