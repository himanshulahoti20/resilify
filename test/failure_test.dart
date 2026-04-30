import 'package:resilify/resilify.dart';
import 'package:test/test.dart';

void main() {
  group('Failure named constructors', () {
    test('timeout has 408', () {
      expect(const Failure.timeout().code, 408);
    });

    test('unauthorized has 401', () {
      expect(const Failure.unauthorized().code, 401);
    });

    test('notFound has 404', () {
      expect(const Failure.notFound().code, 404);
    });

    test('serverError has 500 by default', () {
      expect(const Failure.serverError().code, 500);
    });

    test('cancelled carries default message', () {
      expect(const Failure.cancelled().message, 'Operation was cancelled');
    });

    test('parsing carries default message', () {
      expect(const Failure.parsing().message, 'Failed to parse response');
    });
  });

  group('copyWith', () {
    test('overrides only the supplied fields', () {
      const original = Failure.serverError();
      final copy = original.copyWith(code: 503, message: 'Unavailable');
      expect(copy.code, 503);
      expect(copy.message, 'Unavailable');
      expect(copy.cause, original.cause);
    });
  });

  group('equality', () {
    test('equal when code + message + cause match', () {
      const a = Failure(message: 'boom', code: 1);
      const b = Failure(message: 'boom', code: 1);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when message differs', () {
      const a = Failure(message: 'boom', code: 1);
      const b = Failure(message: 'fizz', code: 1);
      expect(a == b, isFalse);
    });
  });

  group('toString', () {
    test('includes code and message when both present', () {
      const f = Failure(message: 'boom', code: 42);
      final s = f.toString();
      expect(s, contains('code: 42'));
      expect(s, contains('boom'));
    });

    test('omits code when null', () {
      const f = Failure(message: 'boom');
      expect(f.toString(), isNot(contains('code:')));
    });
  });
}
