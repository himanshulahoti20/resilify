/// A simple state-machine [CircuitBreaker] for `Result`-returning operations.
library;

import 'failure.dart';
import 'result.dart';

/// State of a [CircuitBreaker].
enum CircuitBreakerState {
  /// Calls flow through. Consecutive failures are counted.
  closed,

  /// Calls fast-fail without invoking the underlying operation.
  open,

  /// One probe call is allowed through; its outcome decides whether to
  /// transition back to [closed] (on success) or [open] (on failure).
  halfOpen,
}

/// Wraps an unreliable operation with the circuit-breaker resilience
/// pattern: after [failureThreshold] consecutive failures the breaker
/// "opens" and fast-fails calls for [resetTimeout]; one probe call is then
/// admitted, and its outcome decides whether the breaker closes or reopens.
///
/// ```dart
/// final breaker = CircuitBreaker(failureThreshold: 3);
///
/// final result = await breaker.execute(() => api.fetchUser(id));
/// // If the breaker is open, `result` is an Error with
/// // FailureKind.circuitOpen — the underlying call was not made.
/// ```
class CircuitBreaker {
  /// Creates a breaker.
  ///
  /// - [failureThreshold] — number of *consecutive* qualifying failures that
  ///   trip the breaker open. Defaults to `5`.
  /// - [resetTimeout] — how long to stay open before admitting a probe.
  ///   Defaults to 30 seconds.
  /// - [shouldTrip] — predicate deciding whether a given [Failure] counts
  ///   toward tripping the breaker. Defaults to `failure.isRetryable`, so
  ///   only transient faults (network, timeout, 5xx, rate limit) count;
  ///   client errors like 401/404 leave the breaker closed.
  /// - [onStateChange] — observer for state transitions, useful for logs
  ///   and metrics.
  /// - [clock] — overridable time source for tests.
  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    bool Function(Failure failure)? shouldTrip,
    void Function(CircuitBreakerState from, CircuitBreakerState to)?
        onStateChange,
    DateTime Function()? clock,
  })  : assert(failureThreshold > 0, 'failureThreshold must be > 0'),
        _shouldTrip = shouldTrip,
        _onStateChange = onStateChange,
        _clock = clock ?? DateTime.now;

  /// Number of consecutive trip-eligible failures that move the breaker to
  /// [CircuitBreakerState.open].
  final int failureThreshold;

  /// How long the breaker stays in [CircuitBreakerState.open] before
  /// admitting a single probe call.
  final Duration resetTimeout;

  final bool Function(Failure failure)? _shouldTrip;
  final void Function(CircuitBreakerState from, CircuitBreakerState to)?
      _onStateChange;
  final DateTime Function() _clock;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _consecutiveFailures = 0;
  DateTime? _openedAt;
  bool _halfOpenProbeInFlight = false;

  /// The current state of the breaker.
  CircuitBreakerState get state => _state;

  /// Number of consecutive failures observed in the current closed window.
  /// Resets on every [Success] and on a successful probe in half-open.
  int get consecutiveFailures => _consecutiveFailures;

  /// Runs [operation] subject to the breaker's state machine. Returns
  /// `Error(Failure(kind: FailureKind.circuitOpen))` if the breaker is open
  /// (or if a half-open probe is already in flight) without calling
  /// [operation].
  Future<Result<T>> execute<T>(
    Future<Result<T>> Function() operation,
  ) async {
    // open -> halfOpen if reset elapsed.
    if (_state == CircuitBreakerState.open) {
      final openedAt = _openedAt;
      if (openedAt != null && _clock().difference(openedAt) >= resetTimeout) {
        _transition(CircuitBreakerState.halfOpen);
      } else {
        return Error<T>(_openFailure());
      }
    }

    if (_state == CircuitBreakerState.halfOpen) {
      if (_halfOpenProbeInFlight) {
        return Error<T>(_openFailure());
      }
      _halfOpenProbeInFlight = true;
      try {
        final result = await operation();
        if (result is Success<T>) {
          _consecutiveFailures = 0;
          _transition(CircuitBreakerState.closed);
        } else {
          _openedAt = _clock();
          _transition(CircuitBreakerState.open);
        }
        return result;
      } finally {
        _halfOpenProbeInFlight = false;
      }
    }

    // closed
    final result = await operation();
    if (result is Success<T>) {
      _consecutiveFailures = 0;
      return result;
    }
    final failure = (result as Error<T>).failure;
    final shouldTrip = _shouldTrip?.call(failure) ?? failure.isRetryable;
    if (shouldTrip) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= failureThreshold) {
        _openedAt = _clock();
        _transition(CircuitBreakerState.open);
      }
    }
    return result;
  }

  /// Force the breaker back to [CircuitBreakerState.closed], clearing
  /// failure counters. Useful after an out-of-band recovery (e.g. operator
  /// resets the dependency manually).
  void reset() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _halfOpenProbeInFlight = false;
    _transition(CircuitBreakerState.closed);
  }

  void _transition(CircuitBreakerState to) {
    if (_state == to) return;
    final from = _state;
    _state = to;
    _onStateChange?.call(from, to);
  }

  static const Failure _openFailureSingleton = Failure(
    message: 'Circuit breaker is open',
    kind: FailureKind.circuitOpen,
  );

  Failure _openFailure() => _openFailureSingleton;
}
