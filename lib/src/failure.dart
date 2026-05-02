/// Defines the [Failure] value type returned by every failed [Result].
library;

/// An immutable, structured description of *why* an operation failed.
///
/// `resilify` never throws from its public API. Instead, recoverable problems
/// surface as a [Failure] wrapped inside an `Error` variant of `Result<T>`.
///
/// Use the named constructors ([Failure.network], [Failure.timeout], etc.) to
/// model the most common HTTP / IO failure modes with consistent semantics.
class Failure {
  /// Creates a generic failure. Prefer the named constructors when one of the
  /// well-known categories applies.
  const Failure({
    required this.message,
    this.code,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  });

  /// A connectivity problem (DNS lookup failure, no internet, socket reset).
  const Failure.network({
    this.message = 'Network connection failed',
    this.code,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  });

  /// The operation did not complete within the configured timeout.
  const Failure.timeout({
    this.message = 'Operation timed out',
    this.code = 408,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  });

  /// The server returned a response that could not be interpreted as expected
  /// (e.g. unexpected status, malformed envelope).
  const Failure.badResponse({
    required this.message,
    this.code,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  });

  /// Decoding the response body into the target type failed.
  const Failure.parsing({
    this.message = 'Failed to parse response',
    this.code,
    this.stackTrace,
    this.cause,
  }) : retryAfter = null;

  /// HTTP 401 — the request lacks valid authentication credentials.
  const Failure.unauthorized({
    this.message = 'Unauthorized',
    this.code = 401,
    this.stackTrace,
    this.cause,
  }) : retryAfter = null;

  /// HTTP 403 — the server understood the request but refuses to authorize it.
  const Failure.forbidden({
    this.message = 'Forbidden',
    this.code = 403,
    this.stackTrace,
    this.cause,
  }) : retryAfter = null;

  /// HTTP 404 — the target resource does not exist.
  const Failure.notFound({
    this.message = 'Resource not found',
    this.code = 404,
    this.stackTrace,
    this.cause,
  }) : retryAfter = null;

  /// HTTP 409 — the request conflicts with the current state of the resource.
  const Failure.conflict({
    this.message = 'Conflict',
    this.code = 409,
    this.stackTrace,
    this.cause,
  }) : retryAfter = null;

  /// HTTP 429 — too many requests; the client should back off.
  ///
  /// When the server sends a `Retry-After` header, parse it via
  /// [Failure.parseRetryAfter] and pass the resulting [Duration] as
  /// [retryAfter] so callers can sleep exactly that long before retrying.
  const Failure.rateLimit({
    this.message = 'Rate limit exceeded',
    this.code = 429,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  });

  /// Any 5xx response from the server.
  const Failure.serverError({
    this.message = 'Server error',
    this.code = 500,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  });

  /// The request was cancelled before it could complete.
  const Failure.cancelled({
    this.message = 'Operation was cancelled',
    this.code,
    this.stackTrace,
    this.cause,
  }) : retryAfter = null;

  /// Catch-all for failures that do not fit any other category.
  const Failure.unknown({
    this.message = 'An unknown error occurred',
    this.code,
    this.stackTrace,
    this.cause,
  }) : retryAfter = null;

  /// Maps an HTTP status [code] onto the most specific named [Failure]
  /// constructor available, falling back to [Failure.badResponse] for any
  /// other 4xx and [Failure.serverError] for any other 5xx. Codes outside the
  /// 4xx/5xx ranges produce a generic [Failure].
  factory Failure.fromStatusCode(
    int code, {
    String? message,
    StackTrace? stackTrace,
    Object? cause,
  }) {
    switch (code) {
      case 401:
        return Failure.unauthorized(
          message: message ?? 'Unauthorized',
          stackTrace: stackTrace,
          cause: cause,
        );
      case 403:
        return Failure.forbidden(
          message: message ?? 'Forbidden',
          stackTrace: stackTrace,
          cause: cause,
        );
      case 404:
        return Failure.notFound(
          message: message ?? 'Resource not found',
          stackTrace: stackTrace,
          cause: cause,
        );
      case 408:
        return Failure.timeout(
          message: message ?? 'Operation timed out',
          stackTrace: stackTrace,
          cause: cause,
        );
      case 409:
        return Failure.conflict(
          message: message ?? 'Conflict',
          stackTrace: stackTrace,
          cause: cause,
        );
      case 429:
        return Failure.rateLimit(
          message: message ?? 'Rate limit exceeded',
          stackTrace: stackTrace,
          cause: cause,
        );
    }
    if (code >= 500 && code < 600) {
      return Failure.serverError(
        message: message ?? 'Server error',
        code: code,
        stackTrace: stackTrace,
        cause: cause,
      );
    }
    if (code >= 400 && code < 500) {
      return Failure.badResponse(
        message: message ?? 'Bad response',
        code: code,
        stackTrace: stackTrace,
        cause: cause,
      );
    }
    return Failure(
      message: message ?? 'HTTP $code',
      code: code,
      stackTrace: stackTrace,
      cause: cause,
    );
  }

  /// Whether [code] sits in the 4xx range.
  bool get is4xx => code != null && code! >= 400 && code! < 500;

  /// Whether [code] sits in the 5xx range.
  bool get is5xx => code != null && code! >= 500 && code! < 600;

  /// Whether this failure looks transient and worth retrying — true for any
  /// 5xx, plus 408 (timeout) and 429 (rate limit). Failures with no [code]
  /// (network, parsing, cancelled, unknown) are *not* assumed retryable here
  /// because they cannot be distinguished from each other by code alone;
  /// callers who want network-level retries should pass a custom `retryIf`
  /// that inspects [cause].
  bool get isRetryable {
    if (is5xx) return true;
    return code == 408 || code == 429;
  }

  /// Optional protocol- or domain-specific code (typically the HTTP status).
  final int? code;

  /// Human-readable explanation of the failure.
  final String message;

  /// Stack trace captured at the point of failure, if available.
  final StackTrace? stackTrace;

  /// The underlying error/exception that triggered this failure, if any.
  final Object? cause;

  /// Server-supplied hint for how long to wait before retrying, typically
  /// extracted from an HTTP `Retry-After` header on a 429 or 503 response.
  ///
  /// Use [Failure.parseRetryAfter] to convert a raw header value into a
  /// [Duration]. Pair with `RetryHelper.retry`'s `retryIf` to honor the
  /// server's back-off hint:
  ///
  /// ```dart
  /// await RetryHelper.retry(
  ///   () => api.get(...),
  ///   retryIf: (f) => f.isRetryable,
  ///   delay: failure.retryAfter ?? const Duration(milliseconds: 500),
  /// );
  /// ```
  final Duration? retryAfter;

  /// Parses an HTTP `Retry-After` header value into a [Duration].
  ///
  /// Supports the **seconds form** of RFC 7231 §7.1.3 (e.g. `"120"`). Negative
  /// values clamp to [Duration.zero]. Returns `null` if [header] is `null`,
  /// blank, or non-numeric.
  ///
  /// The HTTP-date form (`"Wed, 21 Oct 2026 07:28:00 GMT"`) is intentionally
  /// not parsed here so the core library stays free of `dart:io`. Callers that
  /// need it can decode the date themselves and pass the resulting [Duration]
  /// to the [retryAfter] field directly.
  static Duration? parseRetryAfter(String? header) {
    if (header == null) return null;
    final trimmed = header.trim();
    if (trimmed.isEmpty) return null;
    final seconds = int.tryParse(trimmed);
    if (seconds == null) return null;
    return Duration(seconds: seconds < 0 ? 0 : seconds);
  }

  /// Returns a copy of this failure with the supplied fields overridden.
  Failure copyWith({
    int? code,
    String? message,
    StackTrace? stackTrace,
    Object? cause,
    Duration? retryAfter,
  }) {
    return Failure(
      code: code ?? this.code,
      message: message ?? this.message,
      stackTrace: stackTrace ?? this.stackTrace,
      cause: cause ?? this.cause,
      retryAfter: retryAfter ?? this.retryAfter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure &&
        other.code == code &&
        other.message == message &&
        other.cause == cause &&
        other.retryAfter == retryAfter;
  }

  @override
  int get hashCode => Object.hash(code, message, cause, retryAfter);

  @override
  String toString() {
    final buffer = StringBuffer('Failure(');
    if (code != null) buffer.write('code: $code, ');
    buffer.write('message: $message');
    if (retryAfter != null) buffer.write(', retryAfter: $retryAfter');
    if (cause != null) buffer.write(', cause: $cause');
    buffer.write(')');
    return buffer.toString();
  }
}
