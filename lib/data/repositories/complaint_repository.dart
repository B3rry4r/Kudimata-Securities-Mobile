// Kudimata Securities — Complaint repository.
//
// Backs complaint_screen.dart (file) and complaint_tracked_screen.dart
// (track), wired 2026-08-24 once Kudimata-Securities-Backend shipped a real
// Complaint resource (see that backend repo's
// src/common/types/complaint.types.ts and src/complaints/
// complaints.controller.ts — investor-facing only, own-records-only; staff
// status-transition/timeline-append endpoints are explicitly out of scope
// for this pass per complaints.module.ts's header comment).
//
// Upload flow mirrors kyc_document_repository.dart's KycDocument pattern
// EXACTLY (same presigned-S3-PUT shape, distinct field names per this
// resource's own DTOs — {fileName, contentType} instead of
// {documentKind, documentName}):
//
//   1. POST /complaints/upload-url {fileName, contentType}
//      -> {uploadUrl, objectKey}                            [uploadUrl]
//   2. PUT the raw file bytes directly to `uploadUrl`.          [putFile]
//      `uploadUrl` is a presigned object-storage URL, NOT a
//      Kudimata-Securities-Backend endpoint — it must NOT go through the
//      shared `ApiClient`/`client.dio` (its interceptor unconditionally
//      attaches this session's Authorization bearer token to every
//      request, which would leak the token to whatever host the presigned
//      URL points at). A bare `Dio()` is used instead, same as
//      KycDocumentRepository.putFile.
//   3. POST /complaints {category, orderOrTxnRef?, description,
//      attachmentObjectKey?} -> Complaint. Unlike the KYC flow there is no
//      separate "register the document" step — the attachment's objectKey
//      is just one field on the complaint itself, filed in one call.
//
// Construct with the ONE shared ApiClient, reached via
// `AppScope.read(context).apiClient`:
//   final _repo = ComplaintRepository(AppScope.read(context).apiClient);
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/paginated_response.dart';

/// Mirrors the backend's `ComplaintStatus` union
/// (`'logged' | 'reviewing' | 'escalated' | 'resolved'`). Staff-side
/// transition endpoints don't exist yet in this pass, so in practice every
/// complaint filed through this app stays `logged` — the other values are
/// still modelled here so `GET /complaints`/`GET /complaints/:id` render
/// correctly once those endpoints land.
enum ComplaintStatus { logged, reviewing, escalated, resolved }

ComplaintStatus _statusFromJson(String? raw) => switch (raw) {
      'reviewing' => ComplaintStatus.reviewing,
      'escalated' => ComplaintStatus.escalated,
      'resolved' => ComplaintStatus.resolved,
      _ => ComplaintStatus.logged,
    };

/// One entry in [Complaint.timeline] — an append-only register log entry
/// (backend's `ComplaintTimelineEntry`: `{label, at, by}`).
class ComplaintTimelineEntry {
  const ComplaintTimelineEntry({required this.label, required this.at, required this.by});

  final String label;
  final DateTime at;
  final String by;

  factory ComplaintTimelineEntry.fromJson(Map<String, dynamic> json) => ComplaintTimelineEntry(
        label: json['label'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        by: json['by'] as String? ?? '',
      );
}

/// Wire shape for the Complaint resource — matches
/// Kudimata-Securities-Backend's `Complaint` type exactly (see
/// src/common/types/complaint.types.ts). The ONE complaint model in this
/// app — complaint_tracked_screen.dart renders this directly rather than
/// keeping a second, parallel view model.
class Complaint {
  const Complaint({
    required this.id,
    required this.reference,
    required this.userId,
    required this.category,
    this.orderOrTxnRef,
    required this.description,
    this.attachmentObjectKey,
    required this.status,
    required this.filedAt,
    required this.answerDueAt,
    this.timeline,
  });

  final String id;
  final String reference;
  final String userId;
  final String category;
  final String? orderOrTxnRef;
  final String description;
  final String? attachmentObjectKey;
  final ComplaintStatus status;
  final DateTime filedAt;
  final DateTime answerDueAt;
  final List<ComplaintTimelineEntry>? timeline;

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        category: json['category'] as String? ?? '',
        orderOrTxnRef: json['orderOrTxnRef'] as String?,
        description: json['description'] as String? ?? '',
        attachmentObjectKey: json['attachmentObjectKey'] as String?,
        status: _statusFromJson(json['status'] as String?),
        filedAt: DateTime.tryParse(json['filedAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        answerDueAt:
            DateTime.tryParse(json['answerDueAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        timeline: (json['timeline'] as List<dynamic>?)
            ?.map((e) => ComplaintTimelineEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Result of [ComplaintRepository.uploadUrl].
class ComplaintUploadUrl {
  const ComplaintUploadUrl({required this.uploadUrl, required this.objectKey});
  final String uploadUrl;
  final String objectKey;
}

class ComplaintRepository {
  const ComplaintRepository(this._client);
  final ApiClient _client;

  /// POST /complaints/upload-url — requests a presigned upload URL for an
  /// optional complaint attachment. [contentType] must be one of
  /// image/jpeg, image/png, application/pdf (backend's
  /// `COMPLAINT_ATTACHMENT_CONTENT_TYPES`, matching complaint_screen.dart's
  /// own file-picker allowlist). Goes through the shared `ApiClient`, so
  /// failures surface as [ApiException] as usual.
  Future<ComplaintUploadUrl> uploadUrl({
    required String fileName,
    required String contentType,
  }) async {
    final response = await _client.post('/complaints/upload-url', data: {
      'fileName': fileName,
      'contentType': contentType,
    });
    final data = response.data as Map<String, dynamic>;
    return ComplaintUploadUrl(
      uploadUrl: data['uploadUrl'] as String,
      objectKey: data['objectKey'] as String,
    );
  }

  /// PUTs raw file [bytes] straight to a presigned [uploadUrl] returned by
  /// [uploadUrl] — deliberately bypasses the shared `ApiClient` (see file
  /// header). Still only ever throws [ApiException], mirroring
  /// KycDocumentRepository.putFile exactly.
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

  /// POST /complaints — files a new complaint for the caller. Unlike the
  /// KYC upload flow, an attachment is just a field on this one call — no
  /// separate "register the document" step.
  Future<Complaint> file({
    required String category,
    String? orderOrTxnRef,
    required String description,
    String? attachmentObjectKey,
  }) async {
    final response = await _client.post('/complaints', data: {
      'category': category,
      'orderOrTxnRef': ?(orderOrTxnRef != null && orderOrTxnRef.isNotEmpty ? orderOrTxnRef : null),
      'description': description,
      'attachmentObjectKey': ?attachmentObjectKey,
    });
    return Complaint.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /complaints — the caller's own complaints, paginated
  /// (`PaginatedList<Complaint>` per registry.json's pagination convention).
  Future<PaginatedResponse<Complaint>> list({int page = 1, int pageSize = 20}) async {
    final response = await _client.get(
      '/complaints',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PaginatedResponse<Complaint>.fromJson(
      response.data as Map<String, dynamic>,
      Complaint.fromJson,
    );
  }

  /// GET /complaints/:id
  Future<Complaint> get(String id) async {
    final response = await _client.get('/complaints/$id');
    return Complaint.fromJson(response.data as Map<String, dynamic>);
  }
}
