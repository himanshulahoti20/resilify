/// A concurrency limiter ([Bulkhead]) for `Result`-returning operations.
library;

import 'dart:async';
import 'dart:collection';

import 'failure.dart';
import 'result.dart';

/// Caps the number of concurrently in-flight `Result`-returning operations,
/// optionally queueing the overflow.
///
/// The bulkhead pattern isolates a slow or failing downstream so it cannot
/// exhaust client-side resources (threads, sockets, memory). Callers above
/// the configured concurrency wait in a FIFO queue; once the queue is also
/// full, additional callers receive
/// `Error(Failure.bulkheadRejected())` instead of being kept waiting.
///
/// ```dart
/// final bulkhead = Bulkhead(maxConcurrent: 8, maxQueueSize: 16);
///
/// final result = await bulkhead.execute(() => api.fetchUser(id));
/// // If the bulkhead is full, `result` is an Error with
/// // FailureKind.bulkheadRejected — the underlying call was not made.
/// ```
///
/// Composes naturally with [CircuitBreaker], [RetryHelper], and
/// [ResultCache]: wrap the bulkhead around the call to bound resource use,
/// then layer retries / caching outside it as needed.
class Bulkhead {
  /// Creates a bulkhead permitting at most [maxConcurrent] in-flight
  /// operations.
  ///
  /// When the in-flight slots are full, additional callers wait in a FIFO
  /// queue of up to [maxQueueSize] entries. The default `0` means no
  /// queueing — overflow callers fail fast with
  /// [Failure.bulkheadRejected].
  Bulkhead({
    required this.maxConcurrent,
    this.maxQueueSize = 0,
  })  : assert(maxConcurrent > 0, 'maxConcurrent must be > 0'),
        assert(maxQueueSize >= 0, 'maxQueueSize must be >= 0');

  /// Maximum number of operations allowed to run at the same time.
  final int maxConcurrent;

  /// Maximum number of callers that may wait when [maxConcurrent] is reached.
  /// `0` disables queueing, causing overflow callers to be rejected.
  final int maxQueueSize;

  int _inFlight = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// The number of operations currently executing.
  int get inFlight => _inFlight;

  /// The number of callers currently waiting for a slot to open.
  int get queueLength => _waiters.length;

  /// Whether a new call would be admitted right now without queueing or
  /// rejection.
  bool get hasCapacity => _inFlight < maxConcurrent;

  /// Runs [operation] subject to the bulkhead's concurrency cap.
  ///
  /// - If a slot is free, runs immediately.
  /// - If the slots are full but the queue has room, waits until a slot
  ///   opens and then runs.
  /// - If both slots and queue are full, returns
  ///   `Error(Failure.bulkheadRejected())` without invoking [operation].
  Future<Result<T>> execute<T>(
    Future<Result<T>> Function() operation,
  ) async {
    if (_inFlight >= maxConcurrent) {
      if (_waiters.length >= maxQueueSize) {
        return Error<T>(
          Failure.bulkheadRejected(
            message: 'Bulkhead rejected: '
                '$maxConcurrent in-flight, $maxQueueSize queued',
          ),
        );
      }
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }

    _inFlight++;
    try {
      return await operation();
    } finally {
      _inFlight--;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }
}
