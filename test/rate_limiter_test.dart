import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

class _Clock {
  DateTime now = DateTime(2026);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  group('RateLimiter', () {
    test('admits calls up to maxTokens immediately', () async {
      final limiter = RateLimiter(
        maxTokens: 2,
        refillInterval: const Duration(seconds: 1),
      );
      final r1 = await limiter.execute<int>(() async => const Success<int>(1));
      final r2 = await limiter.execute<int>(() async => const Success<int>(2));
      expect(r1, const Success<int>(1));
      expect(r2, const Success<int>(2));
    });

    test('rejects overflow with Failure.rateLimiterRejected', () async {
      final limiter = RateLimiter(
        maxTokens: 1,
        refillInterval: const Duration(seconds: 1),
      );
      await limiter.execute<int>(() async => const Success<int>(1));
      final rejected =
          await limiter.execute<int>(() async => const Success<int>(2));
      expect(rejected.isError, isTrue);
      expect(rejected.errorOrNull?.kind, FailureKind.rateLimiterRejected);
      expect(rejected.errorOrNull?.type, FailureType.rateLimiterRejected);
      expect(rejected.errorOrNull?.isRetryable, isTrue);
    });

    test('refills tokens continuously over time', () async {
      final clock = _Clock();
      final limiter = RateLimiter(
        maxTokens: 10,
        refillInterval: const Duration(seconds: 10),
        clock: () => clock.now,
      );
      for (var i = 0; i < 10; i++) {
        expect(limiter.tryAcquire(), isTrue);
      }
      expect(limiter.tryAcquire(), isFalse);

      // Half the refill interval elapses -> half the tokens back.
      clock.advance(const Duration(seconds: 5));
      expect(limiter.availableTokens, 5);
    });

    test('never exceeds maxTokens after a long idle period', () async {
      final clock = _Clock();
      final limiter = RateLimiter(
        maxTokens: 5,
        refillInterval: const Duration(seconds: 1),
        clock: () => clock.now,
      );
      limiter.tryAcquire();
      clock.advance(const Duration(hours: 1));
      expect(limiter.availableTokens, 5);
    });

    test('reset() restores the bucket to full', () async {
      final limiter = RateLimiter(
        maxTokens: 1,
        refillInterval: const Duration(seconds: 1),
      );
      limiter.tryAcquire();
      expect(limiter.availableTokens, 0);
      limiter.reset();
      expect(limiter.availableTokens, 1);
    });

    test('asserts on invalid constructor args', () {
      expect(
        () => RateLimiter(maxTokens: 0, refillInterval: const Duration(seconds: 1)),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RateLimiter(maxTokens: 1, refillInterval: Duration.zero),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
