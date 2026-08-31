/// A token-bucket [RateLimiter] for `Result`-returning operations.
library;

import 'dart:math';

import 'failure.dart';
import 'result.dart';

/// Caps the throughput of `Result`-returning operations using a token-bucket
/// algorithm: up to [maxTokens] calls are admitted immediately, and the
/// bucket continuously refills at a rate of [maxTokens] every
/// [refillInterval]. Callers that arrive with an empty bucket fail fast with
/// `Error(Failure.rateLimiterRejected())` instead of being queued.
///
/// Unlike [Bulkhead], which limits *concurrency*, [RateLimiter] limits
/// *throughput over time* — the right tool for staying under an upstream API
/// quota (e.g. "100 requests per minute").
///
/// ```dart
/// final limiter = RateLimiter(maxTokens: 100, refillInterval: Duration(minutes: 1));
///
/// final result = await limiter.execute(() => api.fetchUser(id));
/// // If the bucket is empty, `result` is an Error with
/// // FailureKind.rateLimiterRejected — the underlying call was not made.
/// ```
///
/// Composes naturally with [CircuitBreaker], [Bulkhead], and [RetryHelper].
class RateLimiter {
  /// Creates a limiter holding at most [maxTokens], refilling to full over
  /// [refillInterval] at a steady continuous rate.
  RateLimiter({
    required this.maxTokens,
    required this.refillInterval,
    DateTime Function()? clock,
  })  : assert(maxTokens > 0, 'maxTokens must be > 0'),
        assert(refillInterval > Duration.zero, 'refillInterval must be > 0'),
        _clock = clock ?? DateTime.now,
        _tokens = maxTokens.toDouble() {
    _lastRefill = _clock();
  }

  /// Maximum number of tokens the bucket can hold, and the number of calls
  /// admitted in a fully-refilled burst.
  final int maxTokens;

  /// Time for the bucket to refill from empty to [maxTokens] at a steady
  /// rate.
  final Duration refillInterval;

  final DateTime Function() _clock;
  double _tokens;
  late DateTime _lastRefill;

  /// The number of whole tokens currently available. Triggers a refill
  /// calculation as a side effect of reading.
  int get availableTokens {
    _refill();
    return _tokens.floor();
  }

  /// Runs [operation] if a token is available, consuming one. Returns
  /// `Error(Failure.rateLimiterRejected())` without invoking [operation] if
  /// the bucket is empty.
  Future<Result<T>> execute<T>(
    Future<Result<T>> Function() operation,
  ) async {
    if (!tryAcquire()) {
      return Error<T>(
        Failure.rateLimiterRejected(
          message: 'Rate limiter rejected: $maxTokens per $refillInterval',
        ),
      );
    }
    return operation();
  }

  /// Attempts to consume one token without running an operation. Returns
  /// `true` and decrements the bucket if a token was available, `false`
  /// otherwise. Useful for gating non-`Result` work (e.g. UI actions) with
  /// the same bucket.
  bool tryAcquire() {
    _refill();
    if (_tokens < 1) return false;
    _tokens -= 1;
    return true;
  }

  /// Resets the bucket to full immediately.
  void reset() {
    _tokens = maxTokens.toDouble();
    _lastRefill = _clock();
  }

  void _refill() {
    final now = _clock();
    final elapsed = now.difference(_lastRefill);
    if (elapsed <= Duration.zero) return;
    _lastRefill = now;
    final refilled =
        elapsed.inMicroseconds * maxTokens / refillInterval.inMicroseconds;
    _tokens = min(maxTokens.toDouble(), _tokens + refilled);
  }
}
