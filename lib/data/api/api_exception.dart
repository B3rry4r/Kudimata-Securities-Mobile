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

  /// The message to actually put in front of an investor.
  ///
  /// A `VALIDATION_ERROR` envelope's own `message` is the useless string
  /// "Validation failed"; the actionable part is in `details`, e.g.
  /// `{field: "newPassword", issue: "newPassword must be at least 8 characters
  /// and include a number and a special character"}`. Screens were showing the
  /// summary and dropping the detail, so a password rejected for missing a
  /// special character told the investor only that something had failed —
  /// on the reset-password screen, which they are using precisely because
  /// they cannot get into their account.
  ///
  /// Falls back to [message] whenever there is no usable detail, so a caller
  /// can use this everywhere without checking the code first.
  String get displayMessage {
    final list = details;
    if (list == null || list.isEmpty) return message;
    final issues = <String>[];
    for (final entry in list) {
      if (entry is Map && entry['issue'] is String) {
        final issue = (entry['issue'] as String).trim();
        if (issue.isNotEmpty) issues.add(issue);
      }
    }
    if (issues.isEmpty) return message;
    // Sentence-case the field-prefixed wording the API uses ("newPassword must
    // be...") so it reads as a sentence rather than a variable name.
    return issues.map(_humanise).join('\n');
  }

  static String _humanise(String issue) {
    final m = RegExp(r'^([a-z]+(?:[A-Z][a-z]*)*)\s+(.*)$').firstMatch(issue);
    if (m == null) return issue;
    final words = m
        .group(1)!
        .replaceAllMapped(RegExp(r'([A-Z])'), (x) => ' ${x[1]!.toLowerCase()}')
        .trim();
    final rest = m.group(2)!;
    return '${words[0].toUpperCase()}${words.substring(1)} $rest';
  }

  @override
  String toString() => 'ApiException($code, status: $statusCode): $message';
}
