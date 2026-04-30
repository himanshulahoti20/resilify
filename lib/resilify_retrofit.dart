/// Opt-in `package:retrofit` integration for `resilify`.
///
/// Adds `.toResult()` extensions on the `Future<T>` and `Future<HttpResponse<T>>`
/// returned by Retrofit-generated clients. Pulls in both `dio` and
/// `retrofit` as transitive dependencies.
library;

export 'resilify.dart';
export 'src/integrations/retrofit_result.dart';
