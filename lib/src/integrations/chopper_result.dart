/// `package:chopper` integration for `resilify`.
///
/// Chopper services return `Future<Response<T>>`. The [.toResult] extension in
/// this file inspects [Response.isSuccessful], unwraps `body` on success, and
/// builds an appropriate [Failure] from `error` / `statusCode` on failure.
///
/// ```dart
/// part 'pets_api.chopper.dart';
///
/// @ChopperApi(baseUrl: '/pets')
/// abstract class PetsApi extends ChopperService {
///   static PetsApi create([ChopperClient? client]) => _$PetsApi(client);
///
///   @Get(path: '/{id}')
///   Future<Response<Pet>> getPet(@Path() String id);
/// }
///
/// final api = PetsApi.create();
/// final result = await api.getPet('42').toResult();
/// ```
library;

import 'package:chopper/chopper.dart';

import '../failure.dart';
import '../result.dart';

/// Builds a [Failure] from a non-successful Chopper [Response].
///
/// Default implementation classifies by status code; supply a custom mapper to
/// extract a typed error envelope from `response.error`.
typedef ChopperFailureMapper<BodyType> = Failure Function(
  Response<BodyType> response,
);

/// Default [ChopperFailureMapper] used when none is provided to [.toResult].
Failure defaultChopperFailureMapper<BodyType>(Response<BodyType> response) {
  final code = response.statusCode;
  final body = response.error ?? response.bodyString;
  return switch (code) {
    401 => Failure.unauthorized(cause: body),
    404 => Failure.notFound(cause: body),
    >= 500 && < 600 => Failure.serverError(code: code, cause: body),
    _ => Failure.badResponse(
        code: code,
        message: 'HTTP $code',
        cause: body,
      ),
  };
}

/// Converts a Chopper `Future<Response<BodyType>>` into a
/// `Future<Result<BodyType>>`.
extension ChopperResponseResultX<BodyType> on Future<Response<BodyType>> {
  /// Awaits the response and folds it into a [Result].
  ///
  /// On `response.isSuccessful` and a non-null `body`, returns [Success].
  /// Otherwise builds a [Failure] via [failureMapper] (defaults to
  /// [defaultChopperFailureMapper]).
  Future<Result<BodyType>> toResult({
    ChopperFailureMapper<BodyType>? failureMapper,
  }) async {
    try {
      final response = await this;
      if (response.isSuccessful) {
        final body = response.body;
        if (body == null) {
          return Error<BodyType>(
            const Failure.parsing(message: 'Empty response body'),
          );
        }
        return Success<BodyType>(body);
      }
      final mapper = failureMapper ?? defaultChopperFailureMapper<BodyType>;
      return Error<BodyType>(mapper(response));
    } catch (e, st) {
      return Error<BodyType>(
        Failure.unknown(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }
}
