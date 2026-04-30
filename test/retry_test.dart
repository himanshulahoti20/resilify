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
  });
}
