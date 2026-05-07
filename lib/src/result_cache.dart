/// In-memory cache keyed by arbitrary keys, storing [Result] values.
library;

import 'result.dart';

/// An in-memory cache for [Result] values with optional TTL expiry.
///
/// Useful for caching successful API responses and serving them instantly on
/// repeat calls without hitting the network:
///
/// ```dart
/// final cache = ResultCache<String, User>(ttl: const Duration(minutes: 5));
///
/// Future<Result<User>> getUser(String id) =>
///     cache.getOrFetch(id, () => api.fetchUser(id));
/// ```
///
/// Only [Success] results are cached by [getOrFetch]; errors are always
/// forwarded to the caller so they can retry immediately.
class ResultCache<K, V> {
  /// Creates a cache. Supply [ttl] to evict entries automatically after that
  /// duration; omit it for a cache that never expires.
  ResultCache({this.ttl});

  /// Maximum age of a cache entry. `null` means entries never expire.
  final Duration? ttl;

  final Map<K, _CacheEntry<V>> _store = {};

  /// Returns the cached [Result] for [key], or `null` if the entry is absent
  /// or has expired. Expired entries are removed eagerly on read.
  Result<V>? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (ttl != null && DateTime.now().isAfter(entry.expiresAt!)) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Stores [value] under [key], overwriting any existing entry.
  void put(K key, Result<V> value) {
    _store[key] = _CacheEntry(
      value: value,
      expiresAt: ttl != null ? DateTime.now().add(ttl!) : null,
    );
  }

  /// Returns the cached value for [key] if present and live; otherwise calls
  /// [fetch], caches the result if it is a [Success], and returns it.
  Future<Result<V>> getOrFetch(K key, Future<Result<V>> Function() fetch) async {
    final cached = get(key);
    if (cached != null) return cached;
    final result = await fetch();
    if (result is Success<V>) put(key, result);
    return result;
  }

  /// Removes the entry for [key], if any.
  void invalidate(K key) => _store.remove(key);

  /// Removes all entries from the cache.
  void clear() => _store.clear();

  /// Whether the cache contains a live (non-expired) entry for [key].
  bool containsKey(K key) => get(key) != null;

  /// The number of entries currently held. Includes entries that may have
  /// expired but have not yet been read (and thus not yet evicted).
  int get size => _store.length;
}

class _CacheEntry<V> {
  _CacheEntry({required this.value, this.expiresAt});

  final Result<V> value;
  final DateTime? expiresAt;
}
