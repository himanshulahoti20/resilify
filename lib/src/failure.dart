/// Defines the [Failure] value type returned by every failed [Result].
library;

<<<<<<< Updated upstream
/// Categorical tag describing *what kind of thing* went wrong, independent
/// of any HTTP status code or human-readable message.
///
/// Lets callers discriminate between failures that happen to share (or lack)
/// a `code` — e.g. distinguishing a network failure from a parsing failure,
/// both of which carry a `null` [Failure.code].
enum FailureKind {
  /// Connectivity problem: DNS lookup, no internet, socket reset.
  network,

  /// Operation exceeded its allotted time.
  timeout,

  /// Server responded but the response could not be interpreted.
  badResponse,

  /// Decoding the response body into the target type failed.
  parsing,

  /// HTTP 401 — missing or invalid credentials.
  unauthorized,

  /// HTTP 403 — authenticated but not allowed.
  forbidden,

  /// HTTP 404 — resource does not exist.
  notFound,

  /// HTTP 409 — conflict with current resource state.
  conflict,

  /// HTTP 429 — too many requests.
  rateLimit,

  /// HTTP 5xx — server-side problem.
  serverError,

  /// Operation cancelled before completion.
  cancelled,

  /// A circuit breaker is in the `open` state and rejected the call without
  /// invoking the underlying operation.
  circuitOpen,

  /// Catch-all for unclassified failures.
  unknown,
}
=======
import 'failure_type.dart';
>>>>>>> Stashed changes

/// An immutable, structured description of *why* an operation failed.
///
/// `resilify` never throws from its public API. Instead, recoverable problems
/// surface as a [Failure] wrapped inside an `Error` variant of `Result<T>`.
///
/// Use the named constructors ([Failure.network], [Failure.timeout], etc.) to
/// model the most common HTTP / IO failure modes with consistent semantics.
/// Every named constructor automatically sets [type] to the matching
/// [FailureType] value so callers can switch on category without inspecting
/// [code] or [message].
class Failure {
  /// Creates a generic failure. Prefer the named constructors when one of the
  /// well-known categories applies; supply [kind] explicitly when building a
  /// custom failure that should still participate in `kind`-based dispatch.
  const Failure({
    required this.message,
    this.type = FailureType.unknown,
    this.code,
    this.kind = FailureKind.unknown,
    this.stackTrace,
    this.cause,
  });

  /// A connectivity problem (DNS lookup failure, no internet, socket reset).
  const Failure.network({
    this.message = 'Network connection failed',
    this.code,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.network;
=======
    this.retryAfter,
  }) : type = FailureType.network;
>>>>>>> Stashed changes

  /// The operation did not complete within the configured timeout.
  const Failure.timeout({
    this.message = 'Operation timed out',
    this.code = 408,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.timeout;
=======
    this.retryAfter,
  }) : type = FailureType.timeout;
>>>>>>> Stashed changes

  /// The server returned a response that could not be interpreted as expected
  /// (e.g. unexpected status, malformed envelope).
  const Failure.badResponse({
    required this.message,
    this.code,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.badResponse;
=======
    this.retryAfter,
  }) : type = FailureType.badResponse;
>>>>>>> Stashed changes

  /// Decoding the response body into the target type failed.
  const Failure.parsing({
    this.message = 'Failed to parse response',
    this.code,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.parsing;
=======
  })  : retryAfter = null,
        type = FailureType.parsing;
>>>>>>> Stashed changes

  /// HTTP 401 — the request lacks valid authentication credentials.
  const Failure.unauthorized({
    this.message = 'Unauthorized',
    this.code = 401,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.unauthorized;
=======
  })  : retryAfter = null,
        type = FailureType.unauthorized;
>>>>>>> Stashed changes

  /// HTTP 403 — the server understood the request but refuses to authorize it.
  const Failure.forbidden({
    this.message = 'Forbidden',
    this.code = 403,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.forbidden;
=======
  })  : retryAfter = null,
        type = FailureType.forbidden;
>>>>>>> Stashed changes

  /// HTTP 404 — the target resource does not exist.
  const Failure.notFound({
    this.message = 'Resource not found',
    this.code = 404,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.notFound;
=======
  })  : retryAfter = null,
        type = FailureType.notFound;
>>>>>>> Stashed changes

  /// HTTP 409 — the request conflicts with the current state of the resource.
  const Failure.conflict({
    this.message = 'Conflict',
    this.code = 409,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.conflict;
=======
  })  : retryAfter = null,
        type = FailureType.conflict;

  /// HTTP 422 — the request was well-formed but failed server-side validation.
  ///
  /// Use [message] (or [cause]) to surface field-level validation detail to
  /// the caller.
  const Failure.validation({
    this.message = 'Validation failed',
    this.code = 422,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        type = FailureType.validation;
>>>>>>> Stashed changes

  /// HTTP 429 — too many requests; the client should back off.
  const Failure.rateLimit({
    this.message = 'Rate limit exceeded',
    this.code = 429,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.rateLimit;
=======
    this.retryAfter,
  }) : type = FailureType.rateLimit;
>>>>>>> Stashed changes

  /// Any 5xx response from the server.
  const Failure.serverError({
    this.message = 'Server error',
    this.code = 500,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.serverError;
=======
    this.retryAfter,
  }) : type = FailureType.serverError;
>>>>>>> Stashed changes

  /// The request was cancelled before it could complete.
  const Failure.cancelled({
    this.message = 'Operation was cancelled',
    this.code,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.cancelled;
=======
  })  : retryAfter = null,
        type = FailureType.cancelled;
>>>>>>> Stashed changes

  /// Catch-all for failures that do not fit any other category.
  const Failure.unknown({
    this.message = 'An unknown error occurred',
    this.code,
    this.stackTrace,
    this.cause,
<<<<<<< Updated upstream
  }) : kind = FailureKind.unknown;
=======
  })  : retryAfter = null,
        type = FailureType.unknown;
>>>>>>> Stashed changes

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
      case 422:
        return Failure.validation(
          message: message ?? 'Validation failed',
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

  /// Whether this failure looks transient and worth retrying. Decided
  /// primarily by [kind]: `network`, `timeout`, `serverError`, `rateLimit`
  /// are retryable; `parsing`, `unauthorized`, `forbidden`, `notFound`,
  /// `conflict`, `cancelled`, `badResponse` are not. For [FailureKind.unknown]
  /// the decision falls back to [code] (5xx, 408, 429 retryable).
  bool get isRetryable {
    switch (kind) {
      case FailureKind.network:
      case FailureKind.timeout:
      case FailureKind.serverError:
      case FailureKind.rateLimit:
        return true;
      case FailureKind.parsing:
      case FailureKind.unauthorized:
      case FailureKind.forbidden:
      case FailureKind.notFound:
      case FailureKind.conflict:
      case FailureKind.cancelled:
      case FailureKind.badResponse:
      case FailureKind.circuitOpen:
        return false;
      case FailureKind.unknown:
        return is5xx || code == 408 || code == 429;
    }
  }

<<<<<<< Updated upstream
  /// Categorical tag describing the failure independently of its [code] /
  /// [message]. Defaults to [FailureKind.unknown] for failures built with
  /// the unstructured generic constructor.
  final FailureKind kind;
=======
  /// Structural category of this failure, set automatically by the named
  /// constructor used to create it.
  final FailureType type;
>>>>>>> Stashed changes

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
<<<<<<< Updated upstream
    FailureKind? kind,
=======
    FailureType? type,
>>>>>>> Stashed changes
    int? code,
    String? message,
    StackTrace? stackTrace,
    Object? cause,
  }) {
    return Failure(
<<<<<<< Updated upstream
      kind: kind ?? this.kind,
=======
      type: type ?? this.type,
>>>>>>> Stashed changes
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
        other.type == type &&
        other.code == code &&
        other.message == message &&
        other.cause == cause;
  }

  @override
<<<<<<< Updated upstream
  int get hashCode => Object.hash(code, message, cause);
=======
  int get hashCode => Object.hash(type, code, message, cause, retryAfter);
>>>>>>> Stashed changes

  @override
  String toString() {
    final buffer = StringBuffer('Failure(');
<<<<<<< Updated upstream
    buffer.write('kind: ${kind.name}');
    if (code != null) buffer.write(', code: $code');
    buffer.write(', message: $message');
=======
    buffer.write('type: $type');
    if (code != null) buffer.write(', code: $code');
    buffer.write(', message: $message');
    if (retryAfter != null) buffer.write(', retryAfter: $retryAfter');
>>>>>>> Stashed changes
    if (cause != null) buffer.write(', cause: $cause');
    buffer.write(')');
    return buffer.toString();
  }
}
