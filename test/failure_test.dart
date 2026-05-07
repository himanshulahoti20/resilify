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

    test('validation has 422 and default message', () {
      expect(const Failure.validation().code, 422);
      expect(const Failure.validation().message, 'Validation failed');
    });
  });

  group('Failure.type', () {
    test('named constructors carry the matching FailureType', () {
      expect(const Failure.network().type, FailureType.network);
      expect(const Failure.timeout().type, FailureType.timeout);
      expect(
        const Failure.badResponse(message: 'x').type,
        FailureType.badResponse,
      );
      expect(const Failure.parsing().type, FailureType.parsing);
      expect(const Failure.unauthorized().type, FailureType.unauthorized);
      expect(const Failure.forbidden().type, FailureType.forbidden);
      expect(const Failure.notFound().type, FailureType.notFound);
      expect(const Failure.conflict().type, FailureType.conflict);
      expect(const Failure.rateLimit().type, FailureType.rateLimit);
      expect(const Failure.serverError().type, FailureType.serverError);
      expect(const Failure.cancelled().type, FailureType.cancelled);
      expect(const Failure.validation().type, FailureType.validation);
      expect(const Failure.unknown().type, FailureType.unknown);
    });

    test('primary constructor defaults to FailureType.unknown', () {
      expect(const Failure(message: 'x').type, FailureType.unknown);
    });

    test('primary constructor accepts an explicit type', () {
      expect(
        const Failure(message: 'x', type: FailureType.network).type,
        FailureType.network,
      );
    });

    test('copyWith preserves type when not supplied', () {
      const original = Failure.serverError();
      final copy = original.copyWith(message: 'custom');
      expect(copy.type, FailureType.serverError);
    });

    test('copyWith overrides type when supplied', () {
      const original = Failure.serverError();
      final copy = original.copyWith(type: FailureType.unknown);
      expect(copy.type, FailureType.unknown);
    });

    test('type appears in toString', () {
      expect(
        const Failure.notFound().toString(),
        contains('FailureType.notFound'),
      );
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

    test('maps 422 to validation', () {
      expect(Failure.fromStatusCode(422).code, 422);
      expect(Failure.fromStatusCode(422).type, FailureType.validation);
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

    test('isRetryable is true for network and timeout (kind-driven)', () {
      // 1.1.0: kind-based dispatch makes code-less network/timeout retryable.
      expect(const Failure.network().isRetryable, isTrue);
      expect(const Failure.timeout().isRetryable, isTrue);
    });

    test('isRetryable is false for parsing/cancelled (terminal)', () {
      expect(const Failure.parsing().isRetryable, isFalse);
      expect(const Failure.cancelled().isRetryable, isFalse);
    });

    test('isRetryable for unknown falls back to code heuristics', () {
      expect(
        const Failure(message: 'mystery 503', code: 503).isRetryable,
        isTrue,
      );
      expect(const Failure(message: 'mystery').isRetryable, isFalse);
    });
  });

  group('FailureKind', () {
    test('named constructors carry the matching kind', () {
      expect(const Failure.network().kind, FailureKind.network);
      expect(const Failure.timeout().kind, FailureKind.timeout);
      expect(
        const Failure.badResponse(message: 'x').kind,
        FailureKind.badResponse,
      );
      expect(const Failure.parsing().kind, FailureKind.parsing);
      expect(const Failure.unauthorized().kind, FailureKind.unauthorized);
      expect(const Failure.forbidden().kind, FailureKind.forbidden);
      expect(const Failure.notFound().kind, FailureKind.notFound);
      expect(const Failure.conflict().kind, FailureKind.conflict);
      expect(const Failure.rateLimit().kind, FailureKind.rateLimit);
      expect(const Failure.serverError().kind, FailureKind.serverError);
      expect(const Failure.cancelled().kind, FailureKind.cancelled);
      expect(const Failure.unknown().kind, FailureKind.unknown);
    });

    test('generic Failure() defaults kind to unknown', () {
      expect(const Failure(message: 'x').kind, FailureKind.unknown);
    });

    test('copyWith carries kind forward and lets it be overridden', () {
      const original = Failure.network();
      final copy = original.copyWith(message: 'reworded');
      expect(copy.kind, FailureKind.network);

      final overridden = original.copyWith(kind: FailureKind.unknown);
      expect(overridden.kind, FailureKind.unknown);
    });

    test('toString surfaces the kind for diagnostics', () {
      expect(const Failure.network().toString(), contains('kind: network'));
    });

    test('equality still ignores kind (unchanged contract)', () {
      const a = Failure(message: 'boom', code: 1);
      const b = Failure(message: 'boom', code: 1, kind: FailureKind.network);
      // Same message+code+cause => equal even though kind differs.
      expect(a == b, isTrue);
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

    test(
      'rateLimit constructor carries retryAfter into equality and toString',
      () {
        const f = Failure.rateLimit(retryAfter: Duration(seconds: 30));
        expect(f.retryAfter, const Duration(seconds: 30));
        expect(f, const Failure.rateLimit(retryAfter: Duration(seconds: 30)));
        expect(f.toString(), contains('retryAfter'));
      },
    );
  });
}
