/// Core `resilify` API — `Result`, `Failure`, and dependency-free helpers.
///
/// Importing this barrel pulls in **zero networking dependencies**. Add one of
/// the integration barrels (`resilify_http.dart`, `resilify_dio.dart`,
/// `resilify_retrofit.dart`, `resilify_chopper.dart`,
/// `resilify_websocket.dart`) only for the transports you actually use.
///
/// **`dart:core.Error` collision:** the [Error] variant in this library
/// shadows `dart:core.Error`. If you need both in the same file, hide one at
/// the import site:
///
/// ```dart
/// import 'package:resilify/resilify.dart';
/// import 'dart:core' hide Error;
/// ```
library;

export 'src/failure.dart';
export 'src/list_extensions.dart';
export 'src/result.dart';
export 'src/result_extensions.dart';
export 'src/retry_helper.dart';
export 'src/stream_extensions.dart';
