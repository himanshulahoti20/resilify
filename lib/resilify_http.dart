/// Opt-in `package:http` integration for `resilify`.
///
/// Pulls in `package:http` as a transitive dependency. Import only if you
/// intend to use [HttpResultHandler]. For richer features (interceptors, file
/// transfers) prefer the Dio integration.
library;

export 'resilify.dart';
export 'src/integrations/http_result.dart';
