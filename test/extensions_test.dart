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
      expect(
        const Error<int>(Failure.notFound()).errorOrNull,
        isNotNull,
      );
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

  group('FutureResultX', () {
    test('mapAsync transforms Success', () async {
      final out = await Future<Result<int>>.value(const Success<int>(2))
          .mapAsync<int>((v) async => v * 10);
      expect(out, const Success<int>(20));
    });

    test('mapAsync propagates Error', () async {
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.notFound()),
      ).mapAsync<int>((v) async => v * 10);
      expect(out.isError, isTrue);
    });

    test('flatMapAsync chains', () async {
      final out = await Future<Result<int>>.value(const Success<int>(2))
          .flatMapAsync<String>((v) async => Success<String>('v$v'));
      expect(out, const Success<String>('v2'));
    });

    test('recover replaces Error with Success', () async {
      final out = await Future<Result<int>>.value(
        const Error<int>(Failure.serverError()),
      ).recover((_) async => -1);
      expect(out, const Success<int>(-1));
    });

    test('recover leaves Success untouched', () async {
      final out = await Future<Result<int>>.value(const Success<int>(7))
          .recover((_) async => -1);
      expect(out, const Success<int>(7));
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
