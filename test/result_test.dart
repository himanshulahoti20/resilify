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
}
