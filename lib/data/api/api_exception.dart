// Kudimata Securities — typed API error.
//
// Every non-2xx response from the backend arrives as
// `{"error":{"code","message","details"}}` (Kudimata-Securities-Backend
// .pipeline/conventions.md, "Error envelope"). ApiClient's error interceptor
// parses that envelope (or synthesizes one for network/timeout failures) and
// throws THIS type — never a raw DioException — so every repository and
// screen catches exactly ONE exception shape. See lib/data/api/README.md.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
  });

  /// Machine-readable error code from the envelope, e.g. "VALIDATION_ERROR".
  /// See [sessionExpiredCode] for the one code ApiClient synthesizes itself.
  final String code;

  /// Human-readable summary — safe to show directly as a KErrorView message.
  final String message;

  /// Optional structured detail list, e.g. `[{"field":"email","issue":"..."}]`.
  final List<dynamic>? details;

  /// The HTTP status code that produced this error, when known (null for
  /// pure network failures such as no connectivity or a timeout).
  final int? statusCode;

  /// Code ApiClient uses when a 401 could not be silently resolved (refresh
  /// attempt failed or no refresh token was stored). ApiClient also calls
  /// AppState.forceSignOut() in that path, so by the time a screen sees this
  /// exception the session is already cleared and the router will bounce to
  /// sign-in. Screens don't need to special-case it — an ordinary KErrorView
  /// is fine — but may check `e.isSessionExpired` for sharper copy.
  static const sessionExpiredCode = 'SESSION_EXPIRED';

  bool get isSessionExpired => code == sessionExpiredCode;

  @override
  String toString() => 'ApiException($code, status: $statusCode): $message';
}
