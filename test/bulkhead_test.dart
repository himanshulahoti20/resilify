import 'dart:async';

import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('Bulkhead', () {
    test('runs operations under the concurrency cap immediately', () async {
      final bulkhead = Bulkhead(maxConcurrent: 2);
      final r1 = await bulkhead.execute<int>(() async => const Success<int>(1));
      final r2 = await bulkhead.execute<int>(() async => const Success<int>(2));
      expect(r1, const Success<int>(1));
      expect(r2, const Success<int>(2));
      expect(bulkhead.inFlight, 0);
      expect(bulkhead.queueLength, 0);
    });

    test('queues callers when at capacity and admits them as slots open',
        () async {
      final bulkhead = Bulkhead(maxConcurrent: 1, maxQueueSize: 2);
      final gate1 = Completer<void>();
      final gate2 = Completer<void>();

      final f1 = bulkhead.execute<int>(() async {
        await gate1.future;
        return const Success<int>(1);
      });
      // Let f1 start.
      await Future<void>.delayed(Duration.zero);
      expect(bulkhead.inFlight, 1);

      final f2 = bulkhead.execute<int>(() async {
        await gate2.future;
        return const Success<int>(2);
      });
      await Future<void>.delayed(Duration.zero);
      expect(bulkhead.inFlight, 1);
      expect(bulkhead.queueLength, 1);

      gate1.complete();
      await Future<void>.delayed(Duration.zero);
      // f2 should now be in flight.
      expect(bulkhead.inFlight, 1);
      expect(bulkhead.queueLength, 0);

      gate2.complete();
      expect(await f1, const Success<int>(1));
      expect(await f2, const Success<int>(2));
      expect(bulkhead.inFlight, 0);
    });

    test('rejects overflow with Failure.bulkheadRejected when queue is full',
        () async {
      final bulkhead = Bulkhead(maxConcurrent: 1);
      final gate = Completer<void>();

      final running = bulkhead.execute<int>(() async {
        await gate.future;
        return const Success<int>(1);
      });
      await Future<void>.delayed(Duration.zero);

      final rejected =
          await bulkhead.execute<int>(() async => const Success<int>(2));
      expect(rejected.isError, isTrue);
      expect(rejected.errorOrNull?.kind, FailureKind.bulkheadRejected);
      expect(rejected.errorOrNull?.type, FailureType.bulkheadRejected);
      expect(rejected.errorOrNull?.isRetryable, isTrue);

      gate.complete();
      await running;
    });

    test('inFlight counter is decremented even when the operation fails',
        () async {
      final bulkhead = Bulkhead(maxConcurrent: 1);
      final r = await bulkhead.execute<int>(
        () async => const Error<int>(Failure.serverError()),
      );
      expect(r.isError, isTrue);
      expect(bulkhead.inFlight, 0);
      expect(bulkhead.hasCapacity, isTrue);
    });

    test('inFlight counter is decremented when the operation throws', () async {
      final bulkhead = Bulkhead(maxConcurrent: 1);
      await expectLater(
        bulkhead.execute<int>(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(bulkhead.inFlight, 0);
      expect(bulkhead.hasCapacity, isTrue);
    });

    test('asserts on invalid constructor args', () {
      expect(() => Bulkhead(maxConcurrent: 0), throwsA(isA<AssertionError>()));
      expect(
        () => Bulkhead(maxConcurrent: 1, maxQueueSize: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
