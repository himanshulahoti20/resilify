/// `package:dio` integration for `resilify`.
library;

import 'dart:async';

import 'package:dio/dio.dart';

import '../failure.dart';
import '../result.dart';

/// Decodes a Dio response payload (already JSON-decoded by Dio's default
/// `Transformer`) into a typed model `T`.
typedef DioJsonParser<T> = T Function(Object? data);

/// A [Result]-returning wrapper around a [Dio] instance — the recommended
/// integration for production apps.
///
/// Beyond the standard verbs it adds:
///
/// * [upload] for `multipart/form-data` requests with progress callbacks.
/// * [download] for streaming a response body to disk with progress callbacks.
/// * Granular failure mapping for every [DioExceptionType].
class DioResultHandler {
  /// Wraps an existing [Dio] instance. Pass your own client so that
  /// interceptors, base URLs, and adapter configuration remain in one place.
  const DioResultHandler(this._dio);

  final Dio _dio;

  /// The underlying Dio client. Exposed so callers can attach interceptors
  /// (e.g. `ResultLoggerInterceptor`).
  Dio get dio => _dio;

  /// Performs a `GET` and decodes via [parser].
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required DioJsonParser<T> parser,
  }) =>
      _request(
        () => _dio.get<dynamic>(
          path,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),
        parser,
      );

  /// Performs a `POST`.
  Future<Result<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required DioJsonParser<T> parser,
  }) =>
      _request(
        () => _dio.post<dynamic>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),
        parser,
      );

  /// Performs a `PUT`.
  Future<Result<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required DioJsonParser<T> parser,
  }) =>
      _request(
        () => _dio.put<dynamic>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),
        parser,
      );

  /// Performs a `PATCH`.
  Future<Result<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required DioJsonParser<T> parser,
  }) =>
      _request(
        () => _dio.patch<dynamic>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),
        parser,
      );

  /// Performs a `DELETE`.
  Future<Result<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required DioJsonParser<T> parser,
  }) =>
      _request(
        () => _dio.delete<dynamic>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),
        parser,
      );

  /// Uploads [formData] to [path] using `multipart/form-data`.
  ///
  /// `onSendProgress` reports `(sent, total)` byte counts; `total` may be
  /// `-1` while it is still being computed.
  Future<Result<T>> upload<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
    required DioJsonParser<T> parser,
  }) =>
      _request(
        () => _dio.post<dynamic>(
          path,
          data: formData,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
        ),
        parser,
      );

  /// Downloads the response body for [path] to [savePath].
  ///
  /// `onReceiveProgress` reports `(received, total)` byte counts; `total` may
  /// be `-1` if the server doesn't send `Content-Length`.
  Future<Result<void>> download(
    String path,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    try {
      await _dio.download(
        path,
        savePath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return const Success<void>(null);
    } on DioException catch (e, st) {
      return Error<void>(mapDioException(e, st));
    } catch (e, st) {
      return Error<void>(
        Failure.unknown(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }

  Future<Result<T>> _request<T>(
    Future<Response<dynamic>> Function() send,
    DioJsonParser<T> parser,
  ) async {
    try {
      final response = await send();
      try {
        return Success<T>(parser(response.data));
      } catch (e, st) {
        return Error<T>(Failure.parsing(cause: e, stackTrace: st));
      }
    } on DioException catch (e, st) {
      return Error<T>(mapDioException(e, st));
    } catch (e, st) {
      return Error<T>(
        Failure.unknown(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }
}

/// Maps a [DioException] to the appropriate [Failure] variant.
///
/// Exposed at top level so other integrations (e.g. Retrofit, which throws
/// `DioException` from generated clients) can reuse it.
Failure mapDioException(DioException e, [StackTrace? stackTrace]) {
  final st = stackTrace ?? e.stackTrace;
  final status = e.response?.statusCode;
  final retryAfterHeader =
      e.response?.headers.value('retry-after') ??
          e.response?.headers.value('Retry-After');
  final retryAfter = Failure.parseRetryAfter(retryAfterHeader);

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      Failure.timeout(cause: e, stackTrace: st),
    DioExceptionType.cancel => Failure.cancelled(cause: e, stackTrace: st),
    DioExceptionType.connectionError => Failure.network(
        message: e.message ?? 'Connection error',
        cause: e,
        stackTrace: st,
      ),
    DioExceptionType.badCertificate =>
      Failure.network(message: 'Bad certificate', cause: e, stackTrace: st),
    DioExceptionType.badResponse => switch (status) {
        401 => Failure.unauthorized(cause: e, stackTrace: st),
        404 => Failure.notFound(cause: e, stackTrace: st),
        429 => Failure.rateLimit(
            cause: e,
            stackTrace: st,
            retryAfter: retryAfter,
          ),
        final s when s != null && s >= 500 && s < 600 => Failure.serverError(
            code: s,
            cause: e,
            stackTrace: st,
            retryAfter: retryAfter,
          ),
        _ => Failure.badResponse(
            code: status,
            message: e.message ?? 'Bad response',
            cause: e,
            stackTrace: st,
          ),
      },
    DioExceptionType.unknown => Failure.unknown(
        message: e.message ?? 'Unknown error',
        cause: e,
        stackTrace: st,
      ),
  };
}
