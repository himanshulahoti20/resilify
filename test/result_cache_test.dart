import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('ResultCache.get / put', () {
    test('returns null for unknown key', () {
      final cache = ResultCache<String, int>();
      expect(cache.get('x'), isNull);
    });

    test('returns value after put', () {
      final cache = ResultCache<String, int>();
      cache.put('a', const Success<int>(1));
      expect(cache.get('a'), const Success<int>(1));
    });

    test('put overwrites existing entry', () {
      final cache = ResultCache<String, int>();
      cache.put('a', const Success<int>(1));
      cache.put('a', const Success<int>(2));
      expect(cache.get('a'), const Success<int>(2));
    });

    test('can store an Error result', () {
      final cache = ResultCache<String, int>();
      cache.put('e', const Error<int>(Failure.notFound()));
      expect(cache.get('e')?.isError, isTrue);
    });
  });

  group('ResultCache TTL', () {
    test('entry is available before TTL expires', () {
      final cache = ResultCache<String, int>(
        ttl: const Duration(seconds: 10),
      );
      cache.put('k', const Success<int>(42));
      expect(cache.get('k'), const Success<int>(42));
    });

    test('entry is evicted after TTL expires', () async {
      final cache = ResultCache<String, int>(
        ttl: const Duration(milliseconds: 10),
      );
      cache.put('k', const Success<int>(42));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cache.get('k'), isNull);
    });
  });

  group('ResultCache.invalidate / clear', () {
    test('invalidate removes the entry', () {
      final cache = ResultCache<String, int>();
      cache.put('a', const Success<int>(1));
      cache.invalidate('a');
      expect(cache.get('a'), isNull);
    });

    test('clear empties the cache', () {
      final cache = ResultCache<String, int>();
      cache.put('a', const Success<int>(1));
      cache.put('b', const Success<int>(2));
      cache.clear();
      expect(cache.size, 0);
    });
  });

  group('ResultCache.containsKey / size', () {
    test('containsKey is true for a live entry', () {
      final cache = ResultCache<String, int>();
      cache.put('x', const Success<int>(9));
      expect(cache.containsKey('x'), isTrue);
    });

    test('containsKey is false for a missing key', () {
      expect(ResultCache<String, int>().containsKey('missing'), isFalse);
    });

    test('size reflects the number of entries', () {
      final cache = ResultCache<String, int>();
      expect(cache.size, 0);
      cache.put('a', const Success<int>(1));
      cache.put('b', const Success<int>(2));
      expect(cache.size, 2);
    });
  });

  group('ResultCache.getOrFetch', () {
    test('fetches and caches on miss', () async {
      final cache = ResultCache<String, int>();
      var calls = 0;
      final out = await cache.getOrFetch('k', () async {
        calls++;
        return const Success<int>(99);
      });
      expect(out, const Success<int>(99));
      expect(calls, 1);
      expect(cache.containsKey('k'), isTrue);
    });

    test('returns cached value without calling fetch again', () async {
      final cache = ResultCache<String, int>();
      var calls = 0;
      await cache.getOrFetch('k', () async {
        calls++;
        return const Success<int>(1);
      });
      await cache.getOrFetch('k', () async {
        calls++;
        return const Success<int>(2);
      });
      expect(calls, 1);
    });

    test('does not cache an Error result', () async {
      final cache = ResultCache<String, int>();
      var calls = 0;
      for (var i = 0; i < 2; i++) {
        await cache.getOrFetch('k', () async {
          calls++;
          return const Error<int>(Failure.serverError());
        });
      }
      expect(calls, 2);
      expect(cache.containsKey('k'), isFalse);
    });
  });
}
