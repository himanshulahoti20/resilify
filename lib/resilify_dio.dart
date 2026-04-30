/// Opt-in `package:dio` integration for `resilify`.
///
/// Includes [DioResultHandler] (with file upload/download) and
/// [ResultLoggerInterceptor].
library;

export 'package:dio/dio.dart'
    show
        BaseOptions,
        CancelToken,
        Dio,
        DioException,
        DioExceptionType,
        FormData,
        Interceptor,
        MultipartFile,
        Options,
        Response;

export 'resilify.dart';
export 'src/integrations/dio_result.dart';
export 'src/integrations/logger.dart';
