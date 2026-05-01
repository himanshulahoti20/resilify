import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('Result.when / fold', () {
    test('Success returns success branch', () {
      const r = Success<int>(42);
      expect(r.when(success: (v) => v + 1, error: (_) => -1), 43);
      expect(r.fold((v) => v + 1, (_) => -1), 43);
    });

    test('Error returns error branch', () {
      const r = Error<int>(Failure.notFound());
      expect(r.when(success: (v) => v + 1, error: (_) => -1), -1);
      expect(r.fold((v) => v + 1, (_) => -1), -1);
    });
  });

  group('map / flatMap', () {
    test('map transforms Success', () {
      const r = Success<int>(2);
      expect(r.map((v) => v * 10), const Success<int>(20));
    });

    test('map propagates Error', () {
      const f = Failure.network();
      const r = Error<int>(f);
      expect(r.map((v) => v * 10), const Error<int>(f));
    });

    test('flatMap chains Success', () {
      const r = Success<int>(2);
      expect(
        r.flatMap<String>((v) => Success<String>('x$v')),
        const Success<String>('x2'),
      );
    });

    test('flatMap short-circuits on Error', () {
      const f = Failure.unauthorized();
      const r = Error<int>(f);
      expect(
        r.flatMap<String>((v) => Success<String>('x$v')),
        const Error<String>(f),
      );
    });
  });

  group('equality / hashCode', () {
    test('Success equality is by data', () {
      expect(const Success<int>(1) == const Success<int>(1), isTrue);
      expect(const Success<int>(1) == const Success<int>(2), isFalse);
      expect(
        const Success<int>(1).hashCode,
        const Success<int>(1).hashCode,
      );
    });

    test('Error equality is by failure', () {
      const f = Failure.notFound();
      expect(const Error<int>(f) == const Error<int>(f), isTrue);
      expect(
        const Error<int>(f) == const Error<int>(Failure.unauthorized()),
        isFalse,
      );
    });

    test('toString includes payload', () {
      expect(const Success<int>(1).toString(), contains('1'));
      expect(
        const Error<int>(Failure.notFound()).toString(),
        contains('Failure'),
      );
    });
  });

  group('exhaustive switch', () {
    test('compiles and dispatches', () {
      const Result<int> r = Success<int>(1);
      final out = switch (r) {
        Success<int>(:final data) => 'ok:$data',
        Error<int>(:final failure) => 'err:${failure.message}',
      };
      expect(out, 'ok:1');
    });
  });

  group('Result.tryRun', () {
    test('wraps return value in Success', () {
      expect(Result.tryRun<int>(() => 7), const Success<int>(7));
    });

    test('catches throw and wraps in Error', () {
      final r = Result.tryRun<int>(() => throw StateError('boom'));
      expect(r.isError, isTrue);
      expect(r.errorOrNull!.message, contains('boom'));
    });

    test('honors onError to translate failure', () {
      final r = Result.tryRun<int>(
        () => throw StateError('boom'),
        onError: (_, __) => const Failure.notFound(),
      );
      expect(r, const Error<int>(Failure.notFound()));
    });
  });

  group('Result.tryRunAsync', () {
    test('wraps awaited value in Success', () async {
      expect(
        await Result.tryRunAsync<int>(() async => 9),
        const Success<int>(9),
      );
    });

    test('catches async throw and wraps in Error', () async {
      final r = await Result.tryRunAsync<int>(
        () async => throw StateError('async boom'),
      );
      expect(r.isError, isTrue);
      expect(r.errorOrNull!.message, contains('async boom'));
    });
  });

  group('mapError', () {
    test('transforms failure on Error', () {
      const r = Error<int>(Failure.network());
      final mapped = r.mapError((_) => const Failure.unauthorized());
      expect(mapped, const Error<int>(Failure.unauthorized()));
    });

    test('passes through Success unchanged', () {
      const r = Success<int>(3);
      expect(r.mapError((_) => const Failure.unauthorized()), r);
    });
  });

  group('errorOrThrow', () {
    test('returns the failure on Error', () {
      const f = Failure.notFound();
      expect(const Error<int>(f).errorOrThrow(), f);
    });

    test('throws StateError on Success', () {
      expect(
        () => const Success<int>(1).errorOrThrow(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('onComplete', () {
    test('fires on Success and returns the same result', () {
      var fired = 0;
      const r = Success<int>(1);
      final out = r.onComplete(() => fired++);
      expect(fired, 1);
      expect(identical(out, r), isTrue);
    });

    test('fires on Error and returns the same result', () {
      var fired = 0;
      const r = Error<int>(Failure.notFound());
      final out = r.onComplete(() => fired++);
      expect(fired, 1);
      expect(identical(out, r), isTrue);
    });
  });

  group('flatten', () {
    test('collapses nested Success', () {
      const Result<Result<int>> r = Success<Result<int>>(Success<int>(7));
      expect(r.flatten(), const Success<int>(7));
    });

    test('preserves inner Error when outer is Success', () {
      const Result<Result<int>> r =
          Success<Result<int>>(Error<int>(Failure.notFound()));
      expect(r.flatten(), const Error<int>(Failure.notFound()));
    });

    test('propagates outer Error', () {
      const Result<Result<int>> r =
          Error<Result<int>>(Failure.unauthorized());
      expect(r.flatten(), const Error<int>(Failure.unauthorized()));
    });
  });

  group('Result.fromNullable', () {
    test('non-null becomes Success', () {
      expect(Result.fromNullable<int>(7), const Success<int>(7));
    });

    test('null becomes Error with default failure', () {
      final r = Result.fromNullable<int>(null);
      expect(r.isError, isTrue);
      expect(r.errorOrNull!.message, 'Value was null');
    });

    test('null honors caller-supplied onNull', () {
      final r = Result.fromNullable<int>(
        null,
        onNull: () => const Failure.notFound(message: 'no user'),
      );
      expect(r.errorOrNull!.code, 404);
      expect(r.errorOrNull!.message, 'no user');
    });
  });

  group('Result.zip2 / zip3', () {
    test('zip2 combines two Successes into a record', () {
      final r = Result.zip2<int, String>(
        const Success<int>(1),
        const Success<String>('a'),
      );
      expect(r, const Success<(int, String)>((1, 'a')));
    });

    test('zip2 short-circuits on first Error', () {
      const f = Failure.notFound();
      final r = Result.zip2<int, String>(
        const Error<int>(f),
        const Success<String>('a'),
      );
      expect(r, const Error<(int, String)>(f));
    });

    test('zip2 returns the second Error when first is Success', () {
      const f = Failure.unauthorized();
      final r = Result.zip2<int, String>(
        const Success<int>(1),
        const Error<String>(f),
      );
      expect(r.errorOrNull, f);
    });

    test('zip3 combines three Successes', () {
      final r = Result.zip3<int, String, bool>(
        const Success<int>(1),
        const Success<String>('a'),
        const Success<bool>(true),
      );
      expect(r, const Success<(int, String, bool)>((1, 'a', true)));
    });

    test('zip3 returns first Error left-to-right', () {
      const f = Failure.notFound();
      final r = Result.zip3<int, String, bool>(
        const Success<int>(1),
        const Error<String>(f),
        const Error<bool>(Failure.unauthorized()),
      );
      expect(r.errorOrNull, f);
    });
  });

  group('Result.collect', () {
    test('all Successes => Success<List>', () {
      final r = Result.collect<int>([
        const Success<int>(1),
        const Success<int>(2),
        const Success<int>(3),
      ]);
      expect(r.isSuccess, isTrue);
      expect(r.dataOrNull, equals([1, 2, 3]));
    });

    test('first Error short-circuits the list', () {
      const f = Failure.notFound();
      final r = Result.collect<int>([
        const Success<int>(1),
        const Error<int>(f),
        const Success<int>(3),
      ]);
      expect(r, const Error<List<int>>(f));
    });

    test('empty input becomes empty Success', () {
      final r = Result.collect<int>(const <Result<int>>[]);
      expect(r.dataOrNull, isEmpty);
    });
  });
}
