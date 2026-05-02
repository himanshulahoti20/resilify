import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resilify/resilify_http.dart';
import 'package:test/test.dart';

void main() {
  group('HttpResultHandler', () {
    test('GET 200 decodes body via parser into Success', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.example.com/users/42');
        return http.Response(
          jsonEncode({'id': '42', 'name': 'Ada'}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      final api = HttpResultHandler(
        baseUrl: 'https://api.example.com',
        client: client,
      );

      final result = await api.get<Map<String, dynamic>>(
        '/users/42',
        parser: (json) => json! as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, {'id': '42', 'name': 'Ada'});
    });

    test('POST sends JSON-encoded body and Content-Type header', () async {
      Object? capturedBody;
      String? capturedContentType;

      final client = MockClient((request) async {
        capturedBody = request.body;
        capturedContentType = request.headers['content-type'];
        return http.Response('{"ok":true}', 201);
      });

      final api = HttpResultHandler(
        baseUrl: 'https://api.example.com',
        client: client,
      );

      final result = await api.post<bool>(
        '/things',
        body: {'name': 'foo'},
        parser: (json) => (json! as Map<String, dynamic>)['ok'] as bool,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isTrue);
      expect(capturedBody, jsonEncode({'name': 'foo'}));
      expect(capturedContentType, 'application/json');
    });

    test('404 maps to Failure.notFound', () async {
      final client = MockClient(
        (_) async => http.Response('not found', 404),
      );
      final api = HttpResultHandler(client: client);

      final result = await api.get<Object?>(
        'https://api.example.com/missing',
        parser: (json) => json,
      );

      expect(result.isError, isTrue);
      final failure = result.errorOrNull!;
      expect(failure.code, 404);
    });

    test('5xx maps to Failure.serverError with status code', () async {
      final client = MockClient(
        (_) async => http.Response('boom', 503),
      );
      final api = HttpResultHandler(client: client);

      final result = await api.get<Object?>(
        'https://api.example.com/x',
        parser: (json) => json,
      );

      expect(result.isError, isTrue);
      expect(result.errorOrNull!.code, 503);
    });

    test('invalid JSON in 200 response yields Failure.parsing', () async {
      final client = MockClient(
        (_) async => http.Response('not-json', 200),
      );
      final api = HttpResultHandler(client: client);

      final result = await api.get<Object?>(
        'https://api.example.com/x',
        parser: (json) => json,
      );

      expect(result.isError, isTrue);
      expect(result.errorOrNull, isA<Failure>());
    });

    test('query parameters are appended to the URL', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{}', 200);
      });

      final api = HttpResultHandler(
        baseUrl: 'https://api.example.com',
        client: client,
      );

      await api.get<Object?>(
        '/search',
        queryParameters: const {'q': 'flutter', 'page': 2},
        parser: (json) => json,
      );

      expect(capturedUri!.queryParameters, {'q': 'flutter', 'page': '2'});
    });

    test('429 response carries Retry-After as a Duration', () async {
      final client = MockClient(
        (_) async => http.Response(
          'slow down',
          429,
          headers: const {'retry-after': '42'},
        ),
      );
      final api = HttpResultHandler(client: client);

      final result = await api.get<Object?>(
        'https://api.example.com/x',
        parser: (json) => json,
      );

      expect(result.isError, isTrue);
      final failure = result.errorOrNull!;
      expect(failure.code, 429);
      expect(failure.retryAfter, const Duration(seconds: 42));
    });

    test('503 response surfaces Retry-After when present', () async {
      final client = MockClient(
        (_) async => http.Response(
          'maintenance',
          503,
          headers: const {'retry-after': '5'},
        ),
      );
      final api = HttpResultHandler(client: client);

      final result = await api.get<Object?>(
        'https://api.example.com/x',
        parser: (json) => json,
      );

      expect(result.errorOrNull!.retryAfter, const Duration(seconds: 5));
    });

    test('default headers merge with per-call headers', () async {
      Map<String, String>? captured;
      final client = MockClient((request) async {
        captured = request.headers;
        return http.Response('{}', 200);
      });

      final api = HttpResultHandler(
        baseUrl: 'https://api.example.com',
        defaultHeaders: const {'x-app': 'resilify-test'},
        client: client,
      );

      await api.get<Object?>(
        '/x',
        headers: const {'authorization': 'Bearer token'},
        parser: (json) => json,
      );

      expect(captured!['x-app'], 'resilify-test');
      expect(captured!['authorization'], 'Bearer token');
    });
  });
}
