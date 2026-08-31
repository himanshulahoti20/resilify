import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('TimeoutPolicy', () {
    test('returns the result when within budget', () async {
      const policy = TimeoutPolicy(Duration(seconds: 1));
      final result =
          await policy.execute<int>(() async => const Success<int>(1));
      expect(result, const Success<int>(1));
    });

    test('returns Failure.timeout when budget is exceeded', () async {
      const policy = TimeoutPolicy(Duration(milliseconds: 10));
      final result = await policy.execute<int>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Success<int>(1);
      });
      expect(result.isError, isTrue);
      expect(result.errorOrNull?.kind, FailureKind.timeout);
    });

    test('honors a custom timeoutMessage', () async {
      const policy = TimeoutPolicy(
        Duration(milliseconds: 10),
        timeoutMessage: 'too slow',
      );
      final result = await policy.execute<int>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Success<int>(1);
      });
      expect(result.errorOrNull?.message, 'too slow');
    });

    test('composes with other policies via nesting', () async {
      const timeout = TimeoutPolicy(Duration(milliseconds: 100));
      final breaker = CircuitBreaker(failureThreshold: 1);

      final result = await breaker.execute<int>(
        () => timeout.execute<int>(() async => const Success<int>(1)),
      );
      expect(result, const Success<int>(1));
      expect(breaker.state, CircuitBreakerState.closed);
    });
  });
}
