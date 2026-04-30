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

  /// HTTP 404 — the target resource does not exist.
  const Failure.notFound({
    this.message = 'Resource not found',
    this.code = 404,
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
