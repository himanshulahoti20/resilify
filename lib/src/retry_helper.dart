/// Re-tries an asynchronous [Result]-returning operation with backoff.
library;

import 'dart:async';
import 'dart:math';

import 'failure.dart';
import 'result.dart';

/// Static helpers for retrying [Result]-returning async operations.
///
/// Stops on the first [Success]; on each [Error] consults the optional
/// [retryIf] predicate to decide whether to retry, then waits
/// `delay * (backoffFactor ^ attempt)` before the next attempt.
abstract final class RetryHelper {
  /// Re-runs [operation] up to [maxAttempts] times.
  ///
  /// Returns the first [Success] produced. If every attempt fails, returns the
  /// final [Error]. If [retryIf] returns `false` for a failure, retries stop
  /// immediately and that failure is returned.
  ///
  /// [onRetry] is invoked *after* a failure that will be retried, with the
  /// 1-based attempt number that failed and the failure itself. It is *not*
  /// invoked for the final failure or for a [Success].
  ///
  /// [maxDelay] caps the wait between attempts after exponential backoff is
  /// applied. Use this to bound the worst-case wait when [maxAttempts] and
  /// [backoffFactor] are both large.
  ///
  /// [jitter] adds randomness in the range `[0, jitter]` as a multiplier on
  /// the computed wait — e.g. `jitter: 0.3` produces waits between 100% and
  /// 130% of the backed-off delay. Defaults to `0.0` (no jitter). Useful for
  /// preventing many clients from retrying in lockstep after a shared
  /// outage. Pass [random] to make the jitter deterministic in tests.
  static Future<Result<T>> retry<T>(
    Future<Result<T>> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(milliseconds: 500),
    double backoffFactor = 2.0,
    Duration? maxDelay,
    double jitter = 0.0,
    Random? random,
    bool Function(Failure failure)? retryIf,
    void Function(int attempt, Failure failure)? onRetry,
  }) async {
    assert(maxAttempts > 0, 'maxAttempts must be > 0');
    assert(backoffFactor > 0, 'backoffFactor must be > 0');
    assert(jitter >= 0, 'jitter must be >= 0');

    final rng = random ?? Random();

    Result<T>? last;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final result = await operation();
      last = result;

      if (result is Success<T>) return result;

      final failure = (result as Error<T>).failure;
      final isLastAttempt = attempt == maxAttempts;
      final shouldRetry = retryIf?.call(failure) ?? true;

      if (isLastAttempt || !shouldRetry) return result;

      onRetry?.call(attempt, failure);

      var waitMicros =
          (delay.inMicroseconds * _pow(backoffFactor, attempt - 1)).round();
      if (maxDelay != null && waitMicros > maxDelay.inMicroseconds) {
        waitMicros = maxDelay.inMicroseconds;
      }
      if (jitter > 0) {
        waitMicros = (waitMicros * (1 + rng.nextDouble() * jitter)).round();
      }
      await Future<void>.delayed(Duration(microseconds: waitMicros));
    }
    // Unreachable: the loop above always returns once it exits.
    return last!;
  }

  static double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}
