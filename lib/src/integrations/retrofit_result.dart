/// `package:retrofit` integration for `resilify`.
///
/// Retrofit-generated clients return `Future<T>` (or `Future<HttpResponse<T>>`)
/// and raise [DioException] on HTTP errors because Retrofit runs on top of
/// Dio. This file adds `.toResult()` extensions that convert those raw
/// futures to `Future<Result<T>>` while reusing [mapDioException] for
/// failure classification.
///
/// ### Example
///
/// ```dart
/// // user_api.dart
/// @RestApi(baseUrl: 'https://api.example.com')
/// abstract class UserApi {
///   factory UserApi(Dio dio) = _UserApi;
///
///   @GET('/users/{id}')
///   Future<User> getUser(@Path('id') String id);
/// }
///
/// // usage
/// final api = UserApi(Dio());
/// final result = await api.getUser('42').toResult();
/// result.when(
///   success: (u) => print(u),
///   error: (f) => print('failed: ${f.message}'),
/// );
/// ```
library;

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../failure.dart';
import '../result.dart';
import 'dio_result.dart';

/// Converts a Retrofit `Future<T>` (the typical generated return type) into a
/// `Future<Result<T>>`.
extension RetrofitFutureResultX<T> on Future<T> {
  /// Awaits this future and wraps its outcome in a [Result].
  ///
  /// On success, the value is wrapped in [Success]. On [DioException], the
  /// error is mapped via [mapDioException]. Any other exception becomes a
  /// [Failure.unknown].
  Future<Result<T>> toResult() async {
    try {
      final value = await this;
      return Success<T>(value);
    } on DioException catch (e, st) {
      return Error<T>(mapDioException(e, st));
    } catch (e, st) {
      return Error<T>(
        Failure.unknown(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }
}

/// Converts a Retrofit `Future<HttpResponse<T>>` (returned when you opt-in to
/// the full response object) into a `Future<Result<T>>`.
extension RetrofitHttpResponseResultX<T> on Future<HttpResponse<T>> {
  /// Awaits the future, then unwraps the `data` field of the [HttpResponse].
  Future<Result<T>> toResult() async {
    try {
      final response = await this;
      return Success<T>(response.data);
    } on DioException catch (e, st) {
      return Error<T>(mapDioException(e, st));
    } catch (e, st) {
      return Error<T>(
        Failure.unknown(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }
}
