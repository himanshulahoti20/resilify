import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('ResultX', () {
    test('isSuccess / isError', () {
      expect(const Success<int>(1).isSuccess, isTrue);
      expect(const Success<int>(1).isError, isFalse);
      expect(const Error<int>(Failure.notFound()).isError, isTrue);
      expect(const Error<int>(Failure.notFound()).isSuccess, isFalse);
    });

    test('dataOrNull / errorOrNull', () {
      expect(const Success<int>(1).dataOrNull, 1);
      expect(const Success<int>(1).errorOrNull, isNull);
      expect(const Error<int>(Failure.notFound()).dataOrNull, isNull);
      expect(const Error<int>(Failure.notFound()).errorOrNull, isNotNull);
    });

    test('getOrElse', () {
      expect(const Success<int>(7).getOrElse(0), 7);
      expect(const Error<int>(Failure.notFound()).getOrElse(0), 0);
    });

    test('getOrThrow throws on Error', () {
      expect(
        () => const Error<int>(Failure.notFound()).getOrThrow(),
        throwsA(isA<ResultUnwrapException>()),
      );
      expect(const Success<int>(7).getOrThrow(), 7);
    });

    test('onSuccess / onError side-effects', () {
      var seen = -1;
      const Success<int>(9).onSuccess((v) => seen = v);
      expect(seen, 9);

      Failure? captured;
      const Error<int>(Failure.notFound()).onError((f) => captured = f);
      expect(captured?.code, 404);
    });
  });

  group('ResultX.recover / recoverWith (sync)', () {
    test('recover converts Error into Success', () {
      final r = const Error<int>(Failure.serverError()).recover((_) => 0);
      expect(r, const Success<int>(0));
    });

    test('recover passes Success through unchanged', () {
      var called = false;
      final r = const Success<int>(7).recover((_) {
        called = true;
        return 0;
      });
      expect(r, const Success<int>(7));
      expect(called, isFalse);
    });

    test('recoverWith may return another Error', () {
      final r = const Error<int>(Failure.serverError()).recoverWith(
        (_) => const Error<int>(Failure.unauthorized()),
      );
      expect(r.errorOrNull?.code, 401);
    });

    test('recoverWith may return Success', () {
      final r = const Error<int>(Failure.serverError())
          .recoverWith((_) => const Success<int>(42));
      expect(r, const Success<int>(42));
    });
  });

  group('ResultX.ensure', () {
    test('Success passing predicate is preserved', () {
      final r = const Success<int>(5).ensure(
        (v) => v > 0,
        (_) => const Failure.badResponse(message: 'non-positive'),
      );
      expect(r, const Success<int>(5));
    });

    test('Success failing predicate becomes Error', () {
      final r = const Success<int>(-1).ensure(
        (v) => v > 0,
        (v) => Failure.badResponse(message: 'got $v'),
      );
      expect(r.isError, isTrue);
      expect(r.errorOrNull?.message, 'got -1');
    });

    test('Error passes through without invoking predicate', () {
      var called = false;
      final r = const Error<int>(Failure.notFound()).ensure(
        (v) {
          called = true;
          return true;
        },
        (_) => const Failure.badResponse(message: 'never'),
      );
      expect(r.isError, isTrue);
      expect(called, isFalse);
    });
  });

  group('Result.asyncMap / asyncFlatMap', () {
    test('asyncMap transforms Success asynchronously', () async {
      const r = Success<int>(3);
      final out = await r.asyncMap<int>((v) async => v * 10);
      expect(out, const Success<int>(30));
    });

    test('asyncMap propagates Error without calling transform', () async {
      var called = false;
      const r = Error<int>(Failure.notFound());
      final out = await r.asyncMap<int>((v) async {
        called = true;
        return v * 10;
      });
      expect(out.isError, isTrue);
      expect(called, isFalse);
    });

    test('asyncFlatMap chains Success', () async {
      const r = Success<int>(4);
      final out =
          await r.asyncFlatMap<String>((v) async => Success<String>('x$v'));
      expect(out, const Success<String>('x4'));
    });

    test('asyncFlatMap propagates Error without calling transform', () async {
      var called = false;
      const r = Error<int>(Failure.unauthorized());
      final out = await r.asyncFlatMap<String>((v) async {
        called = true;
        return Success<String>('x$v');
      });
      expect(out.isError, isTrue);
      expect(called, isFalse);
    });

    test('asyncFlatMap surfaces returned Error', () async {
      const r = Success<int>(5);
      final out = await r.asyncFlatMap<String>(
        (_) async => const Error<String>(Failure.serverError()),
      );
      expect(out.errorOrNull?.code, 500);
    });
  });

  group('FutureResultX', () {
    test('mapAsync transforms Success', () async {
      final out = await Future<Result<int>>.value(
        const Success<int>(2),
      ).mapAsync<int>((v) async => v * 10);
      expect(out, const Success<int>(20));
    });

    test('mapAsync propagates Error', () async {
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.notFound()),
      ).mapAsync<int>((v) async => v * 10);
      expect(out.isError, isTrue);
    });

    test('flatMapAsync chains', () async {
      final out = await Future<Result<int>>.value(
        const Success<int>(2),
      ).flatMapAsync<String>((v) async => Success<String>('v$v'));
      expect(out, const Success<String>('v2'));
    });

    test('recover replaces Error with Success', () async {
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.serverError()),
      ).recover((_) async => -1);
      expect(out, const Success<int>(-1));
    });

    test('recover leaves Success untouched', () async {
      final out = await Future<Result<int>>.value(
        const Success<int>(7),
      ).recover((_) async => -1);
      expect(out, const Success<int>(7));
    });

    test('recoverWith can return another Result that itself fails', () async {
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.serverError()),
      ).recoverWith((_) async => const Error<int>(Failure.notFound()));
      expect(out.errorOrNull?.code, 404);
    });

    test('recoverWith leaves Success untouched', () async {
      final out = await Future<Result<int>>.value(
        const Success<int>(5),
      ).recoverWith((_) async => const Error<int>(Failure.notFound()));
      expect(out, const Success<int>(5));
    });

    test('mapErrorAsync transforms failure asynchronously', () async {
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.network()),
      ).mapErrorAsync((f) async => const Failure.unauthorized());
      expect(out, const Error<int>(Failure.unauthorized()));
    });

    test('mapErrorAsync leaves Success untouched', () async {
      final out = await Future<Result<int>>.value(
        const Success<int>(2),
      ).mapErrorAsync((f) async => const Failure.unauthorized());
      expect(out, const Success<int>(2));
    });

    test('onSuccessAsync fires on Success and returns result', () async {
      var seen = -1;
      final out = await Future<Result<int>>.value(
        const Success<int>(7),
      ).onSuccessAsync((v) async => seen = v);
      expect(seen, 7);
      expect(out, const Success<int>(7));
    });

    test('onSuccessAsync skips on Error', () async {
      var called = false;
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.network()),
      ).onSuccessAsync((_) async => called = true);
      expect(called, isFalse);
      expect(out.isError, isTrue);
    });

    test('onErrorAsync fires on Error and returns result', () async {
      Failure? captured;
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.unauthorized()),
      ).onErrorAsync((f) async => captured = f);
      expect(captured?.code, 401);
      expect(out.isError, isTrue);
    });

    test('onErrorAsync skips on Success', () async {
      var called = false;
      final out = await Future<Result<int>>.value(
        const Success<int>(3),
      ).onErrorAsync((_) async => called = true);
      expect(called, isFalse);
      expect(out, const Success<int>(3));
    });
  });

  group('FutureToResultX (asResult)', () {
    test('non-throwing future becomes Success', () async {
      final out = await Future<int>.value(42).asResult();
      expect(out, const Success<int>(42));
    });

    test('throwing future becomes Error with Failure.unknown by default',
        () async {
      final out = await Future<int>.error(StateError('boom')).asResult();
      expect(out.isError, isTrue);
      expect(out.errorOrNull?.kind, FailureKind.unknown);
      expect(out.errorOrNull?.message, contains('boom'));
    });

    test('onError can translate the thrown object into a domain Failure',
        () async {
      final out = await Future<int>.error(StateError('boom')).asResult(
        onError: (_, __) => const Failure.unauthorized(),
      );
      expect(out, const Error<int>(Failure.unauthorized()));
    });
  });

  group('StreamResultX', () {
    test('dataStream emits only successful payloads', () async {
      final stream = Stream<Result<int>>.fromIterable(const [
        Success<int>(1),
        Error<int>(Failure.network()),
        Success<int>(2),
      ]);
      expect(await stream.dataStream.toList(), [1, 2]);
    });

    test('whereSuccess / whereError filter', () async {
      final source = Stream<Result<int>>.fromIterable(const [
        Success<int>(1),
        Error<int>(Failure.network()),
        Success<int>(2),
      ]);
      final successes = await source.whereSuccess().toList();
      expect(successes, hasLength(2));

      final errorsStream = Stream<Result<int>>.fromIterable(const [
        Success<int>(1),
        Error<int>(Failure.network()),
      ]);
      final errors = await errorsStream.whereError().toList();
      expect(errors, hasLength(1));
    });

    test('mapStream transforms successes only', () async {
      final stream = Stream<Result<int>>.fromIterable(const [
        Success<int>(1),
        Error<int>(Failure.network()),
        Success<int>(3),
      ]).mapStream<int>((v) => v * 100);
      final collected = await stream.toList();
      expect(collected[0], const Success<int>(100));
      expect(collected[1].isError, isTrue);
      expect(collected[2], const Success<int>(300));
    });
  });

  group('ResultListX', () {
    test('mapList transforms each element', () {
      const r = Success<List<int>>([1, 2, 3]);
      final mapped = r.mapList<int>((v) => v + 10);
      expect(mapped.isSuccess, isTrue);
      expect(mapped.dataOrNull, equals([11, 12, 13]));
    });

    test('filter keeps elements satisfying test', () {
      const r = Success<List<int>>([1, 2, 3, 4]);
      final filtered = r.filter((v) => v.isEven);
      expect(filtered.isSuccess, isTrue);
      expect(filtered.dataOrNull, equals([2, 4]));
    });

    test('firstOrError returns Success on non-empty', () {
      const r = Success<List<int>>([7, 8]);
      expect(r.firstOrError(), const Success<int>(7));
    });

    test('firstOrError returns notFound on empty', () {
      const r = Success<List<int>>([]);
      final out = r.firstOrError(emptyMessage: 'no rows');
      expect(out.isError, isTrue);
      expect(out.errorOrNull?.code, 404);
      expect(out.errorOrNull?.message, 'no rows');
    });

    test('firstOrError propagates upstream Error', () {
      const r = Error<List<int>>(Failure.network());
      expect(r.firstOrError().errorOrNull?.code, isNull);
    });
  });
}
