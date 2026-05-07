/// Collapses concurrent calls for the same key into a single in-flight future.
library;

import 'result.dart';

/// Ensures only one [Future<Result<V>>] is in flight per key at any time.
///
/// When [run] is called concurrently with the same key, all callers share the
/// same underlying future and receive the same result — no duplicate network
/// calls, no thundering herd:
///
/// ```dart
/// final dedup = ResultDeduplicator<String, User>();
///
/// // All three calls resolve from the single network request.
/// final results = await Future.wait([
///   dedup.run('u1', () => api.fetchUser('u1')),
///   dedup.run('u1', () => api.fetchUser('u1')),
///   dedup.run('u1', () => api.fetchUser('u1')),
/// ]);
/// ```
///
/// Once the in-flight future completes (success or error), the key is evicted
/// so subsequent calls trigger a fresh fetch.
class ResultDeduplicator<K, V> {
  final Map<K, Future<Result<V>>> _inFlight = {};

  /// Returns the in-flight future for [key] if one exists, otherwise calls
  /// [fetch] to start a new one, registers it, and returns it.
  ///
  /// The key is removed from the registry once the future completes,
  /// regardless of whether it succeeded or failed.
  Future<Result<V>> run(K key, Future<Result<V>> Function() fetch) {
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = fetch();
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  /// Whether a fetch for [key] is currently in progress.
  bool isInFlight(K key) => _inFlight.containsKey(key);

  /// The number of keys with in-flight fetches.
  int get inFlightCount => _inFlight.length;
}
