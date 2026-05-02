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

    test('forbidden has 403', () {
      expect(const Failure.forbidden().code, 403);
    });

    test('conflict has 409', () {
      expect(const Failure.conflict().code, 409);
    });

    test('rateLimit has 429', () {
      expect(const Failure.rateLimit().code, 429);
    });
  });

  group('Failure.fromStatusCode', () {
    test('maps 401 to unauthorized', () {
      expect(Failure.fromStatusCode(401).code, 401);
      expect(Failure.fromStatusCode(401).message, 'Unauthorized');
    });

    test('maps 403 to forbidden', () {
      expect(Failure.fromStatusCode(403).code, 403);
    });

    test('maps 404 to notFound', () {
      expect(Failure.fromStatusCode(404).code, 404);
    });

    test('maps 408 to timeout', () {
      expect(Failure.fromStatusCode(408).code, 408);
    });

    test('maps 409 to conflict', () {
      expect(Failure.fromStatusCode(409).code, 409);
    });

    test('maps 429 to rateLimit', () {
      expect(Failure.fromStatusCode(429).code, 429);
    });

    test('preserves the actual 5xx code', () {
      expect(Failure.fromStatusCode(503).code, 503);
      expect(Failure.fromStatusCode(503).is5xx, isTrue);
    });

    test('preserves an unmapped 4xx code as badResponse', () {
      final f = Failure.fromStatusCode(418);
      expect(f.code, 418);
      expect(f.is4xx, isTrue);
    });

    test('uses caller-supplied message when provided', () {
      expect(Failure.fromStatusCode(404, message: 'gone').message, 'gone');
    });

    test('non-HTTP code falls back to generic Failure', () {
      final f = Failure.fromStatusCode(200);
      expect(f.is4xx, isFalse);
      expect(f.is5xx, isFalse);
      expect(f.code, 200);
    });
  });

  group('Failure.is4xx / is5xx / isRetryable', () {
    test('is4xx covers the 4xx range', () {
      expect(const Failure.notFound().is4xx, isTrue);
      expect(const Failure.serverError().is4xx, isFalse);
      expect(const Failure.network().is4xx, isFalse);
    });

    test('is5xx covers the 5xx range', () {
      expect(const Failure.serverError().is5xx, isTrue);
      expect(const Failure.notFound().is5xx, isFalse);
    });

    test('isRetryable is true for 5xx, 408, 429', () {
      expect(const Failure.serverError().isRetryable, isTrue);
      expect(const Failure.timeout().isRetryable, isTrue);
      expect(const Failure.rateLimit().isRetryable, isTrue);
    });

    test('isRetryable is false for 4xx (except 408 / 429)', () {
      expect(const Failure.unauthorized().isRetryable, isFalse);
      expect(const Failure.forbidden().isRetryable, isFalse);
      expect(const Failure.notFound().isRetryable, isFalse);
      expect(const Failure.conflict().isRetryable, isFalse);
    });

    test('isRetryable is false for code-less failures by default', () {
      expect(const Failure.network().isRetryable, isFalse);
      expect(const Failure.parsing().isRetryable, isFalse);
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

  group('Failure.parseRetryAfter', () {
    test('parses seconds form', () {
      expect(Failure.parseRetryAfter('120'), const Duration(seconds: 120));
    });

    test('clamps negative values to zero', () {
      expect(Failure.parseRetryAfter('-5'), Duration.zero);
    });

    test('returns null for null, blank, or non-numeric input', () {
      expect(Failure.parseRetryAfter(null), isNull);
      expect(Failure.parseRetryAfter(''), isNull);
      expect(Failure.parseRetryAfter('   '), isNull);
      expect(Failure.parseRetryAfter('Wed, 21 Oct 2026 07:28:00 GMT'), isNull);
    });

    test('rateLimit constructor carries retryAfter into equality and toString',
        () {
      const f = Failure.rateLimit(retryAfter: Duration(seconds: 30));
      expect(f.retryAfter, const Duration(seconds: 30));
      expect(
        f,
        const Failure.rateLimit(retryAfter: Duration(seconds: 30)),
      );
      expect(f.toString(), contains('retryAfter'));
    });
  });
}
