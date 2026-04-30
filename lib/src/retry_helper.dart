/// Re-tries an asynchronous [Result]-returning operation with backoff.
library;

import 'dart:async';

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
  static Future<Result<T>> retry<T>(
    Future<Result<T>> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(milliseconds: 500),
    double backoffFactor = 2.0,
    bool Function(Failure failure)? retryIf,
    void Function(int attempt, Failure failure)? onRetry,
  }) async {
    assert(maxAttempts > 0, 'maxAttempts must be > 0');
    assert(backoffFactor > 0, 'backoffFactor must be > 0');

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

      final waitMicros = (delay.inMicroseconds *
              _pow(backoffFactor, attempt - 1))
          .round();
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
