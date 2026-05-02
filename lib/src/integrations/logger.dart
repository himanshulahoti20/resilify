/// Pretty-printing Dio interceptor that plugs into `resilify`-based clients.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

/// Sink for log lines. Defaults to `print`; swap for `logger`, Sentry, etc.
typedef LogCallback = void Function(String line);

/// A Dio [Interceptor] that emits structured, human-readable log output for
/// requests, responses, and errors.
///
/// Wire it up by adding the interceptor to the Dio instance you pass to
/// `DioResultHandler`:
///
/// ```dart
/// final dio = Dio()..interceptors.add(ResultLoggerInterceptor());
/// final api = DioResultHandler(dio);
/// ```
class ResultLoggerInterceptor extends Interceptor {
  /// Creates a logger interceptor.
  ResultLoggerInterceptor({
    this.logRequest = true,
    this.logResponse = true,
    this.logError = true,
    this.logHeaders = false,
    this.logBody = true,
    LogCallback? logger,
  }) : _log = logger ?? _defaultLogger;

  /// Whether outgoing requests are logged.
  final bool logRequest;

  /// Whether successful responses are logged.
  final bool logResponse;

  /// Whether errors / non-2xx responses are logged.
  final bool logError;

  /// Whether headers are included in the log output.
  final bool logHeaders;

  /// Whether request / response bodies are included in the log output.
  final bool logBody;

  final LogCallback _log;

  static void _defaultLogger(String line) {
    // ignore: avoid_print
    print(line);
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (logRequest) {
      final box = _Box('REQUEST')..line('${options.method} ${options.uri}');
      if (logHeaders) box.section('Headers', options.headers);
      if (logBody && options.data != null) {
        box.section('Body', options.data);
      }
      _log(box.toString());
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (logResponse) {
      final box = _Box('RESPONSE')
        ..line(
          '${response.statusCode} '
          '${response.requestOptions.method} '
          '${response.requestOptions.uri}',
        );
      if (logHeaders) box.section('Headers', response.headers.map);
      if (logBody && response.data != null) {
        box.section('Body', response.data);
      }
      _log(box.toString());
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (logError) {
      final box = _Box('ERROR')
        ..line(
          '${err.type} ${err.requestOptions.method} ${err.requestOptions.uri}',
        )
        ..line('Message: ${err.message ?? '<none>'}');
      final response = err.response;
      if (response != null) {
        box.line('Status: ${response.statusCode}');
        if (logBody && response.data != null) {
          box.section('Body', response.data);
        }
      }
      _log(box.toString());
    }
    handler.next(err);
  }
}

class _Box {
  _Box(String title) {
    _buffer
      ..writeln('┌─ $title ${'─' * (60 - title.length).clamp(0, 60)}')
      ..writeln('│');
  }

  final StringBuffer _buffer = StringBuffer();

  void line(String text) {
    for (final part in text.split('\n')) {
      _buffer.writeln('│ $part');
    }
  }

  void section(String name, Object? value) {
    _buffer.writeln('│ $name:');
    final encoded = _stringify(value);
    for (final part in encoded.split('\n')) {
      _buffer.writeln('│   $part');
    }
  }

  String _stringify(Object? value) {
    if (value == null) return '<null>';
    if (value is String) return value;
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  String toString() {
    _buffer.writeln('└${'─' * 70}');
    return _buffer.toString();
  }
}
