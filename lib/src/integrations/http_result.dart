/// `package:http` integration for `resilify`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../failure.dart';
import '../result.dart';

/// Decodes an already-decoded JSON value (typically `Map<String, dynamic>` or
/// `List<dynamic>`) into a typed model `T`.
typedef JsonParser<T> = T Function(Object? json);

/// A thin, opt-in adapter that wraps `package:http` calls in [Result] values.
///
/// Built for **quick prototypes and small apps**: zero ceremony, no
/// interceptors, no transformers. For production HTTP clients, prefer the Dio
/// integration ([DioResultHandler]) which exposes interceptors, file
/// transfers, and richer error mapping.
///
/// ```dart
/// final api = HttpResultHandler(
///   baseUrl: 'https://api.example.com',
///   defaultHeaders: const {'Accept': 'application/json'},
/// );
///
/// final user = await api.get<User>(
///   '/users/me',
///   parser: (json) => User.fromJson(json! as Map<String, dynamic>),
/// );
/// user.when(
///   success: print,
///   error: (f) => print('failed: ${f.message}'),
/// );
/// ```
class HttpResultHandler {
  /// Creates a new handler.
  ///
  /// [client] lets tests inject a `MockClient`. If omitted, a fresh
  /// `http.Client` is created and owned by this handler — call [close] when
  /// you're done.
  HttpResultHandler({
    this.baseUrl = '',
    this.defaultHeaders = const <String, String>{},
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Prefix prepended to every relative path passed to the verb methods.
  final String baseUrl;

  /// Headers applied to every request, merged with per-call headers.
  final Map<String, String> defaultHeaders;

  /// Per-request timeout. A timeout produces [Failure.timeout].
  final Duration timeout;

  final http.Client _client;
  final bool _ownsClient;

  /// Closes the underlying HTTP client if this handler created it.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Performs a `GET` and decodes the response body via [parser].
  Future<Result<T>> get<T>(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    required JsonParser<T> parser,
  }) {
    return _send(
      method: 'GET',
      path: path,
      headers: headers,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  /// Performs a `POST` with a JSON-encoded [body].
  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    required JsonParser<T> parser,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      headers: headers,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  /// Performs a `PUT` with a JSON-encoded [body].
  Future<Result<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    required JsonParser<T> parser,
  }) {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      headers: headers,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  /// Performs a `PATCH` with a JSON-encoded [body].
  Future<Result<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    required JsonParser<T> parser,
  }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      headers: headers,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  /// Performs a `DELETE`.
  Future<Result<T>> delete<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    required JsonParser<T> parser,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      body: body,
      headers: headers,
      queryParameters: queryParameters,
      parser: parser,
    );
  }

  Future<Result<T>> _send<T>({
    required String method,
    required String path,
    required JsonParser<T> parser,
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final mergedHeaders = <String, String>{
        ...defaultHeaders,
        if (body != null) 'Content-Type': 'application/json',
        ...?headers,
      };
      final encodedBody = body == null ? null : jsonEncode(body);

      final request = http.Request(method, uri)..headers.addAll(mergedHeaders);
      if (encodedBody != null) request.body = encodedBody;

      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final decoded =
              response.body.isEmpty ? null : jsonDecode(response.body);
          return Success<T>(parser(decoded));
        } catch (e, st) {
          return Error<T>(Failure.parsing(cause: e, stackTrace: st));
        }
      }

      return Error<T>(_failureForStatus(response));
    } on TimeoutException catch (e, st) {
      return Error<T>(Failure.timeout(cause: e, stackTrace: st));
    } on SocketException catch (e, st) {
      return Error<T>(
        Failure.network(message: e.message, cause: e, stackTrace: st),
      );
    } on http.ClientException catch (e, st) {
      return Error<T>(
        Failure.network(message: e.message, cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return Error<T>(
        Failure.unknown(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final raw = path.startsWith('http') ? path : '$baseUrl$path';
    final uri = Uri.parse(raw);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        ...query.map((k, v) => MapEntry(k, '$v')),
      },
    );
  }

  Failure _failureForStatus(http.Response response) {
    final code = response.statusCode;
    final message = response.reasonPhrase ?? 'HTTP $code';
    final retryAfter = Failure.parseRetryAfter(response.headers['retry-after']);
    return switch (code) {
      401 => Failure.unauthorized(cause: response.body),
      404 => Failure.notFound(cause: response.body),
      429 => Failure.rateLimit(cause: response.body, retryAfter: retryAfter),
      >= 500 && < 600 => Failure.serverError(
          code: code,
          message: message,
          cause: response.body,
          retryAfter: retryAfter,
        ),
      _ => Failure.badResponse(
          code: code,
          message: message,
          cause: response.body,
        ),
    };
  }
}
