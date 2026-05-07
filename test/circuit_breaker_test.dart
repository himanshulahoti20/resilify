import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

class _Clock {
  DateTime now = DateTime(2026);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  group('CircuitBreaker', () {
    test('passes calls through while closed', () async {
      final breaker = CircuitBreaker();
      final result =
          await breaker.execute<int>(() async => const Success<int>(7));
      expect(result, const Success<int>(7));
      expect(breaker.state, CircuitBreakerState.closed);
      expect(breaker.consecutiveFailures, 0);
    });

    test('trips after consecutive trip-eligible failures', () async {
      final transitions = <CircuitBreakerState>[];
      final breaker = CircuitBreaker(
        failureThreshold: 3,
        onStateChange: (_, to) => transitions.add(to),
      );

      for (var i = 0; i < 3; i++) {
        await breaker.execute<int>(
          () async => const Error<int>(Failure.serverError()),
        );
      }
      expect(breaker.state, CircuitBreakerState.open);
      expect(transitions, contains(CircuitBreakerState.open));
    });

    test('non-tripping failures do not advance the counter', () async {
      // Default `shouldTrip` is `failure.isRetryable`, so a 404 should not
      // count toward tripping the breaker.
      final breaker = CircuitBreaker(failureThreshold: 2);
      for (var i = 0; i < 5; i++) {
        await breaker.execute<int>(
          () async => const Error<int>(Failure.notFound()),
        );
      }
      expect(breaker.state, CircuitBreakerState.closed);
      expect(breaker.consecutiveFailures, 0);
    });

    test('open breaker fast-fails without invoking the operation', () async {
      var calls = 0;
      final breaker = CircuitBreaker(failureThreshold: 1);
      // Trip it with one server error.
      await breaker.execute<int>(
        () async => const Error<int>(Failure.serverError()),
      );
      expect(breaker.state, CircuitBreakerState.open);

      final result = await breaker.execute<int>(() async {
        calls++;
        return const Success<int>(1);
      });
      expect(calls, 0);
      expect(result.isError, isTrue);
      expect(result.errorOrNull?.kind, FailureKind.circuitOpen);
    });

    test(
        'after resetTimeout, half-open admits one probe; success closes the '
        'breaker', () async {
      final clock = _Clock();
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(seconds: 30),
        clock: () => clock.now,
      );
      await breaker.execute<int>(
        () async => const Error<int>(Failure.serverError()),
      );
      expect(breaker.state, CircuitBreakerState.open);

      clock.advance(const Duration(seconds: 31));

      final result =
          await breaker.execute<int>(() async => const Success<int>(42));
      expect(result, const Success<int>(42));
      expect(breaker.state, CircuitBreakerState.closed);
    });

    test('half-open probe failure reopens the breaker', () async {
      final clock = _Clock();
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(seconds: 30),
        clock: () => clock.now,
      );
      await breaker.execute<int>(
        () async => const Error<int>(Failure.serverError()),
      );
      clock.advance(const Duration(seconds: 31));
      // First call after timeout transitions to halfOpen and runs the probe.
      // Probe fails => back to open.
      final result = await breaker.execute<int>(
        () async => const Error<int>(Failure.serverError()),
      );
      expect(result.errorOrNull?.kind, FailureKind.serverError);
      expect(breaker.state, CircuitBreakerState.open);
    });

    test('reset() clears state and counters', () async {
      final breaker = CircuitBreaker(failureThreshold: 1);
      await breaker.execute<int>(
        () async => const Error<int>(Failure.serverError()),
      );
      expect(breaker.state, CircuitBreakerState.open);

      breaker.reset();
      expect(breaker.state, CircuitBreakerState.closed);
      expect(breaker.consecutiveFailures, 0);

      final result =
          await breaker.execute<int>(() async => const Success<int>(1));
      expect(result, const Success<int>(1));
    });

    test('custom shouldTrip overrides the default predicate', () async {
      // Trip on EVERY failure, including 404.
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        shouldTrip: (_) => true,
      );
      await breaker.execute<int>(
        () async => const Error<int>(Failure.notFound()),
      );
      await breaker.execute<int>(
        () async => const Error<int>(Failure.notFound()),
      );
      expect(breaker.state, CircuitBreakerState.open);
    });
  });
}
