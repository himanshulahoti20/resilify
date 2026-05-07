import 'dart:async';

import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('ResultDeduplicator.run', () {
    test('deduplicates two concurrent calls for the same key', () async {
      final dedup = ResultDeduplicator<String, int>();
      var calls = 0;

      final completer = Completer<Result<int>>();
      Future<Result<int>> fetch() {
        calls++;
        return completer.future;
      }

      final future1 = dedup.run('k', fetch);
      final future2 = dedup.run('k', fetch);

      expect(calls, 1);
      expect(identical(future1, future2), isTrue);

      completer.complete(const Success<int>(42));
      final out1 = await future1;
      final out2 = await future2;
      expect(out1, const Success<int>(42));
      expect(out2, const Success<int>(42));
    });

    test('different keys do not share the same future', () async {
      final dedup = ResultDeduplicator<String, int>();
      var calls = 0;

      final completerA = Completer<Result<int>>();
      final completerB = Completer<Result<int>>();

      Future<Result<int>> fetchA() {
        calls++;
        return completerA.future;
      }

      Future<Result<int>> fetchB() {
        calls++;
        return completerB.future;
      }

      final futureA = dedup.run('a', fetchA);
      final futureB = dedup.run('b', fetchB);

      expect(calls, 2);
      expect(identical(futureA, futureB), isFalse);

      completerA.complete(const Success<int>(1));
      completerB.complete(const Success<int>(2));

      expect(await futureA, const Success<int>(1));
      expect(await futureB, const Success<int>(2));
    });

    test('completed key is evicted so next call fetches again', () async {
      final dedup = ResultDeduplicator<String, int>();
      var calls = 0;

      final completer1 = Completer<Result<int>>();
      final completer2 = Completer<Result<int>>();

      Future<Result<int>> makeCompleter(Completer<Result<int>> c) {
        calls++;
        return c.future;
      }

      final future1 = dedup.run('k', () => makeCompleter(completer1));
      expect(dedup.isInFlight('k'), isTrue);

      completer1.complete(const Success<int>(1));
      await future1;

      expect(dedup.isInFlight('k'), isFalse);

      final future2 = dedup.run('k', () => makeCompleter(completer2));
      expect(dedup.isInFlight('k'), isTrue);
      expect(calls, 2);

      completer2.complete(const Success<int>(2));
      await future2;
    });

    test('error result is forwarded and key is evicted', () async {
      final dedup = ResultDeduplicator<String, int>();
      final completer = Completer<Result<int>>();

      final future = dedup.run('k', () => completer.future);
      expect(dedup.isInFlight('k'), isTrue);

      completer.complete(const Error<int>(Failure.serverError()));
      final out = await future;

      expect(out.isError, isTrue);
      expect(dedup.isInFlight('k'), isFalse);
    });
  });

  group('ResultDeduplicator.isInFlight / inFlightCount', () {
    test('isInFlight is true while a fetch is in progress', () async {
      final dedup = ResultDeduplicator<String, int>();
      final completer = Completer<Result<int>>();
      final future = dedup.run('k', () => completer.future);

      expect(dedup.isInFlight('k'), isTrue);
      expect(dedup.inFlightCount, 1);

      completer.complete(const Success<int>(1));
      await future;

      expect(dedup.isInFlight('k'), isFalse);
      expect(dedup.inFlightCount, 0);
    });

    test('isInFlight is false for an unknown key', () {
      expect(ResultDeduplicator<String, int>().isInFlight('x'), isFalse);
    });
  });
}
