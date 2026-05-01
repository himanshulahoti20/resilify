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
  });

  /// A connectivity problem (DNS lookup failure, no internet, socket reset).
  const Failure.network({
    this.message = 'Network connection failed',
    this.code,
    this.stackTrace,
    this.cause,
  });

  /// The operation did not complete within the configured timeout.
  const Failure.timeout({
    this.message = 'Operation timed out',
    this.code = 408,
    this.stackTrace,
    this.cause,
  });

  /// The server returned a response that could not be interpreted as expected
  /// (e.g. unexpected status, malformed envelope).
  const Failure.badResponse({
    required this.message,
    this.code,
    this.stackTrace,
    this.cause,
  });

  /// Decoding the response body into the target type failed.
  const Failure.parsing({
    this.message = 'Failed to parse response',
    this.code,
    this.stackTrace,
    this.cause,
  });

  /// HTTP 401 — the request lacks valid authentication credentials.
  const Failure.unauthorized({
    this.message = 'Unauthorized',
    this.code = 401,
    this.stackTrace,
    this.cause,
  });

  /// HTTP 403 — the server understood the request but refuses to authorize it.
  const Failure.forbidden({
    this.message = 'Forbidden',
    this.code = 403,
    this.stackTrace,
    this.cause,
  });

  /// HTTP 404 — the target resource does not exist.
  const Failure.notFound({
    this.message = 'Resource not found',
    this.code = 404,
    this.stackTrace,
    this.cause,
  });

  /// HTTP 409 — the request conflicts with the current state of the resource.
  const Failure.conflict({
    this.message = 'Conflict',
    this.code = 409,
    this.stackTrace,
    this.cause,
  });

  /// HTTP 429 — too many requests; the client should back off.
  const Failure.rateLimit({
    this.message = 'Rate limit exceeded',
    this.code = 429,
    this.stackTrace,
    this.cause,
  });

  /// Any 5xx response from the server.
  const Failure.serverError({
    this.message = 'Server error',
    this.code = 500,
    this.stackTrace,
    this.cause,
  });

  /// The request was cancelled before it could complete.
  const Failure.cancelled({
    this.message = 'Operation was cancelled',
    this.code,
    this.stackTrace,
    this.cause,
  });

  /// Catch-all for failures that do not fit any other category.
  const Failure.unknown({
    this.message = 'An unknown error occurred',
    this.code,
    this.stackTrace,
    this.cause,
  });

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

  /// Returns a copy of this failure with the supplied fields overridden.
  Failure copyWith({
    int? code,
    String? message,
    StackTrace? stackTrace,
    Object? cause,
  }) {
    return Failure(
      code: code ?? this.code,
      message: message ?? this.message,
      stackTrace: stackTrace ?? this.stackTrace,
      cause: cause ?? this.cause,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure &&
        other.code == code &&
        other.message == message &&
        other.cause == cause;
  }

  @override
  int get hashCode => Object.hash(code, message, cause);

  @override
  String toString() {
    final buffer = StringBuffer('Failure(');
    if (code != null) buffer.write('code: $code, ');
    buffer.write('message: $message');
    if (cause != null) buffer.write(', cause: $cause');
    buffer.write(')');
    return buffer.toString();
  }
}
