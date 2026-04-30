/// Opt-in `package:chopper` integration for `resilify`.
///
/// Adds `.toResult()` on `Future<Response<T>>` returned by Chopper services.
library;

export 'resilify.dart';
export 'src/integrations/chopper_result.dart';
