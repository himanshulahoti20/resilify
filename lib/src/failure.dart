/// Defines the [Failure] value type returned by every failed [Result].
library;

import 'failure_type.dart';

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

  /// A bulkhead concurrency limiter rejected the call because both the
  /// in-flight slots and the queue were full.
  bulkheadRejected,

  /// Catch-all for unclassified failures.
  unknown,
}

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
    this.retryAfter,
  });

  /// A connectivity problem (DNS lookup failure, no internet, socket reset).
  const Failure.network({
    this.message = 'Network connection failed',
    this.code,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  })  : kind = FailureKind.network,
        type = FailureType.network;

  /// The operation did not complete within the configured timeout.
  const Failure.timeout({
    this.message = 'Operation timed out',
    this.code = 408,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  })  : kind = FailureKind.timeout,
        type = FailureType.timeout;

  /// The server returned a response that could not be interpreted as expected
  /// (e.g. unexpected status, malformed envelope).
  const Failure.badResponse({
    required this.message,
    this.code,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  })  : kind = FailureKind.badResponse,
        type = FailureType.badResponse;

  /// Decoding the response body into the target type failed.
  const Failure.parsing({
    this.message = 'Failed to parse response',
    this.code,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        kind = FailureKind.parsing,
        type = FailureType.parsing;

  /// HTTP 401 — the request lacks valid authentication credentials.
  const Failure.unauthorized({
    this.message = 'Unauthorized',
    this.code = 401,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        kind = FailureKind.unauthorized,
        type = FailureType.unauthorized;

  /// HTTP 403 — the server understood the request but refuses to authorize it.
  const Failure.forbidden({
    this.message = 'Forbidden',
    this.code = 403,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        kind = FailureKind.forbidden,
        type = FailureType.forbidden;

  /// HTTP 404 — the target resource does not exist.
  const Failure.notFound({
    this.message = 'Resource not found',
    this.code = 404,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        kind = FailureKind.notFound,
        type = FailureType.notFound;

  /// HTTP 409 — the request conflicts with the current state of the resource.
  const Failure.conflict({
    this.message = 'Conflict',
    this.code = 409,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        kind = FailureKind.conflict,
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
        kind = FailureKind.unknown,
        type = FailureType.validation;

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
  })  : kind = FailureKind.rateLimit,
        type = FailureType.rateLimit;

  /// Any 5xx response from the server.
  const Failure.serverError({
    this.message = 'Server error',
    this.code = 500,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  })  : kind = FailureKind.serverError,
        type = FailureType.serverError;

  /// The request was cancelled before it could complete.
  const Failure.cancelled({
    this.message = 'Operation was cancelled',
    this.code,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        kind = FailureKind.cancelled,
        type = FailureType.cancelled;

  /// Catch-all for failures that do not fit any other category.
  const Failure.unknown({
    this.message = 'An unknown error occurred',
    this.code,
    this.stackTrace,
    this.cause,
  })  : retryAfter = null,
        kind = FailureKind.unknown,
        type = FailureType.unknown;

  /// A bulkhead concurrency limiter rejected the call because both the
  /// in-flight slots and the queue were full. Treated as a transient failure
  /// by [isRetryable]; callers may want to back off using [retryAfter] before
  /// trying again.
  const Failure.bulkheadRejected({
    this.message = 'Bulkhead rejected the call: at capacity',
    this.code,
    this.stackTrace,
    this.cause,
    this.retryAfter,
  })  : kind = FailureKind.bulkheadRejected,
        type = FailureType.bulkheadRejected;

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
      case FailureKind.bulkheadRejected:
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

  /// Categorical tag describing the failure independently of its [code] /
  /// [message]. Defaults to [FailureKind.unknown] for failures built with
  /// the unstructured generic constructor.
  final FailureKind kind;

  /// Structural category of this failure, set automatically by the named
  /// constructor used to create it.
  final FailureType type;

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
    FailureKind? kind,
    FailureType? type,
    int? code,
    String? message,
    StackTrace? stackTrace,
    Object? cause,
    Duration? retryAfter,
  }) {
    return Failure(
      kind: kind ?? this.kind,
      type: type ?? this.type,
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
        other.type == type &&
        other.code == code &&
        other.message == message &&
        other.cause == cause &&
        other.retryAfter == retryAfter;
  }

  @override
  int get hashCode => Object.hash(type, code, message, cause, retryAfter);

  @override
  String toString() {
    final buffer = StringBuffer('Failure(');
    buffer.write('kind: ${kind.name}');
    buffer.write(', type: $type');
    if (code != null) buffer.write(', code: $code');
    buffer.write(', message: $message');
    if (retryAfter != null) buffer.write(', retryAfter: $retryAfter');
    if (cause != null) buffer.write(', cause: $cause');
    buffer.write(')');
    return buffer.toString();
  }
}
