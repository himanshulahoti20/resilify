/// A reusable, configured [TimeoutPolicy] for `Result`-returning operations.
library;

import 'result.dart';
import 'retry_helper.dart';

/// A [duration]-bound wrapper around a `Result`-returning operation,
/// packaged as a reusable object with the same `execute(() => ...)` shape as
/// [CircuitBreaker], [Bulkhead], and [RateLimiter] — so it composes by
/// nesting rather than being applied ad hoc at every call site.
///
/// Delegates to [RetryHelper.withTimeout]: if [operation] does not produce a
/// [Result] within [duration], returns `Error(Failure.timeout())` instead of
/// throwing.
///
/// ```dart
/// final timeout = TimeoutPolicy(const Duration(seconds: 5));
/// final breaker = CircuitBreaker();
///
/// final result = await breaker.execute(() => timeout.execute(() => api.fetchUser(id)));
/// ```
class TimeoutPolicy {
  /// Creates a policy that fails any operation exceeding [duration].
  const TimeoutPolicy(this.duration, {this.timeoutMessage});

  /// The maximum time an operation is allowed to take.
  final Duration duration;

  /// Custom message for the resulting `Failure.timeout()`. Defaults to
  /// `RetryHelper.withTimeout`'s message when omitted.
  final String? timeoutMessage;

  /// Runs [operation], returning `Error(Failure.timeout())` if it does not
  /// complete within [duration].
  Future<Result<T>> execute<T>(Future<Result<T>> Function() operation) =>
      RetryHelper.withTimeout(operation, duration,
          timeoutMessage: timeoutMessage);
}
