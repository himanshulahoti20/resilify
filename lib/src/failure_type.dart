/// Defines the [FailureType] enum — a structural category for every [Failure].
library;

/// Structural category of a [Failure].
///
/// Every [Failure] carries a [FailureType] set automatically by the named
/// constructor used to create it. Useful for routing failures to different
/// UI states or analytics buckets without pattern-matching on [Failure.code]:
///
/// ```dart
/// switch (failure.type) {
///   FailureType.network      => showOfflineBanner(),
///   FailureType.unauthorized => pushLoginScreen(),
///   _                        => showGenericError(failure.message),
/// }
/// ```
enum FailureType {
  /// A connectivity problem (DNS lookup failure, no internet, socket reset).
  network,

  /// The operation did not complete within the configured timeout.
  timeout,

  /// The server returned a response that could not be interpreted as expected.
  badResponse,

  /// Decoding the response body into the target type failed.
  parsing,

  /// HTTP 401 — missing or invalid authentication credentials.
  unauthorized,

  /// HTTP 403 — the server refuses to authorise the request.
  forbidden,

  /// HTTP 404 — the target resource does not exist.
  notFound,

  /// HTTP 409 — the request conflicts with the current state of the resource.
  conflict,

  /// HTTP 429 — too many requests; the client should back off.
  rateLimit,

  /// Any 5xx response from the server.
  serverError,

  /// The request was cancelled before it could complete.
  cancelled,

  /// HTTP 422 — input failed server-side validation rules.
  validation,

  /// A bulkhead concurrency limiter rejected the call because both the
  /// in-flight slots and the queue were full.
  bulkheadRejected,

  /// Catch-all for failures that do not fit any other category.
  unknown,
}
