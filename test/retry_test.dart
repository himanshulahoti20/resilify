import 'dart:math';

import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('RetryHelper.retry', () {
    test('returns first Success without retrying', () async {
      var calls = 0;
      final result = await RetryHelper.retry<int>(
        () async {
          calls++;
          return const Success<int>(42);
        },
      );
      expect(result, const Success<int>(42));
      expect(calls, 1);
    });

    test('retries up to maxAttempts then returns last Error', () async {
      var calls = 0;
      final result = await RetryHelper.retry<int>(
        () async {
          calls++;
          return const Error<int>(Failure.serverError());
        },
        maxAttempts: 3,
        delay: const Duration(milliseconds: 1),
      );
      expect(result.isError, isTrue);
      expect(calls, 3);
    });

    test('stops as soon as Success is observed', () async {
      var calls = 0;
      final result = await RetryHelper.retry<int>(
        () async {
          calls++;
          if (calls < 3) {
            return const Error<int>(Failure.serverError());
          }
          return const Success<int>(99);
        },
        maxAttempts: 5,
        delay: const Duration(milliseconds: 1),
      );
      expect(result, const Success<int>(99));
      expect(calls, 3);
    });

    test('retryIf=false short-circuits to that Error', () async {
      var calls = 0;
      final result = await RetryHelper.retry<int>(
        () async {
          calls++;
          return const Error<int>(Failure.unauthorized());
        },
        maxAttempts: 5,
        delay: const Duration(milliseconds: 1),
        retryIf: (f) => f.code != 401,
      );
      expect(calls, 1);
      expect(result.errorOrNull?.code, 401);
    });

    test('onRetry fires for every retried failure but not the last', () async {
      final retries = <int>[];
      await RetryHelper.retry<int>(
        () async => const Error<int>(Failure.serverError()),
        maxAttempts: 3,
        delay: const Duration(milliseconds: 1),
        onRetry: (attempt, _) => retries.add(attempt),
      );
      expect(retries, [1, 2]);
    });

    test('exponential backoff increases wait each attempt', () async {
      final stopwatch = Stopwatch()..start();
      await RetryHelper.retry<int>(
        () async => const Error<int>(Failure.serverError()),
        maxAttempts: 3,
        delay: const Duration(milliseconds: 20),
        backoffFactor: 2,
      );
      stopwatch.stop();
      // attempt 1 fails, wait 20ms, attempt 2 fails, wait 40ms, attempt 3 fails
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
    });

    test('maxDelay caps the wait between attempts', () async {
      final stopwatch = Stopwatch()..start();
      await RetryHelper.retry<int>(
        () async => const Error<int>(Failure.serverError()),
        maxAttempts: 4,
        // Without a cap, waits would be 100, 1000, 10_000 ms.
        delay: const Duration(milliseconds: 100),
        backoffFactor: 10,
        maxDelay: const Duration(milliseconds: 30),
      );
      stopwatch.stop();
      // 3 backoff waits, each capped at 30ms => well under 200ms total.
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('jitter only ever adds time', () async {
      // Seeded RNG => deterministic jitter, but we only assert "at least the
      // base delay was waited" because the jitter multiplier is in [1, 1+j].
      final stopwatch = Stopwatch()..start();
      await RetryHelper.retry<int>(
        () async => const Error<int>(Failure.serverError()),
        maxAttempts: 2,
        delay: const Duration(milliseconds: 30),
        jitter: 1.0,
        random: Random(42),
      );
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(30));
    });

    test('isRetryable composes naturally with retryIf', () async {
      var calls = 0;
      final result = await RetryHelper.retry<int>(
        () async {
          calls++;
          return const Error<int>(Failure.notFound());
        },
        maxAttempts: 5,
        delay: const Duration(milliseconds: 1),
        retryIf: (f) => f.isRetryable,
      );
      // 404 is not retryable => first error returned, no extra calls.
      expect(calls, 1);
      expect(result.errorOrNull?.code, 404);
    });

    test('attemptTimeout converts a slow attempt into Failure.timeout',
        () async {
      var calls = 0;
      final result = await RetryHelper.retry<int>(
        () async {
          calls++;
          // First attempt hangs longer than the per-attempt timeout.
          if (calls == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return const Success<int>(1);
          }
          return const Success<int>(2);
        },
        maxAttempts: 2,
        delay: const Duration(milliseconds: 1),
        attemptTimeout: const Duration(milliseconds: 20),
      );
      // First attempt times out, second succeeds.
      expect(result, const Success<int>(2));
      expect(calls, 2);
    });

    test('attemptTimeout returns Failure.timeout when all attempts time out',
        () async {
      final result = await RetryHelper.retry<int>(
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return const Success<int>(1);
        },
        maxAttempts: 2,
        delay: const Duration(milliseconds: 1),
        attemptTimeout: const Duration(milliseconds: 10),
      );
      expect(result.isError, isTrue);
      expect(result.errorOrNull?.code, 408);
    });
  });
}
