// Kudimata Securities — generic paginated list wrapper.
//
// Matches the backend's pagination convention (.pipeline/conventions.md):
// `{"data":[...],"meta":{"page","pageSize","total","totalPages"}}`. Use this
// for any endpoint whose registry.json response shape is `PaginatedList<T>`
// (e.g. GET /transactions, GET /orders, GET /holdings, GET /notifications).
//
// Endpoints whose shape is a bare `list<T>` (e.g. GET /assets/trending) are
// NOT paginated — parse those as a plain `List<T>` instead, do not wrap them
// in PaginatedResponse.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<T> data;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasNextPage => page < totalPages;

  /// [fromJsonT] parses a single item's JSON map — pass the same per-model
  /// parser a non-paginated call would use.
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromJsonT,
  ) {
    final rawData = (json['data'] as List<dynamic>?) ?? const [];
    final meta = (json['meta'] as Map<String, dynamic>?) ?? const {};
    return PaginatedResponse<T>(
      data: rawData.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      page: meta['page'] as int? ?? 1,
      pageSize: meta['pageSize'] as int? ?? rawData.length,
      total: meta['total'] as int? ?? rawData.length,
      totalPages: meta['totalPages'] as int? ?? 1,
    );
  }
}
