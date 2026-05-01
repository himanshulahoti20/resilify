// Quick tour of the core `resilify` API — no networking dependencies.
//
// Run with: `dart run example/resilify.dart`
//
// For framework-specific integrations, see the sibling examples:
//   - http_example.dart        (package:http)
//   - dio_example.dart         (package:dio)
//   - retrofit_example.dart    (package:retrofit)
//   - chopper_example.dart     (package:chopper)
//   - websocket_example.dart   (package:web_socket_channel)
//   - retry_example.dart       (RetryHelper with exponential backoff)

import 'package:resilify/resilify.dart';

Future<void> main() async {
  // 1. Build Results directly.
  const ok = Success<int>(42);
  const bad = Error<int>(Failure.notFound());

  // 2. Pattern-match exhaustively.
  print(ok.when(success: (v) => 'got $v', error: (f) => 'oops: ${f.message}'));
  print(bad.when(success: (v) => 'got $v', error: (f) => 'oops: ${f.message}'));

  // 3. Transform success values; failures short-circuit automatically.
  final doubled = ok.map((v) => v * 2);
  print(doubled); // Success<int>(84)

  // 4. Translate low-level failures into domain failures.
  final domain = bad.mapError(
    (f) => Failure.unknown(message: 'lookup failed: ${f.message}'),
  );
  print(domain.errorOrNull?.message);

  // 5. Bridge throwing code into a Result without writing try/catch.
  final parsed = Result.tryRun<int>(() => int.parse('not a number'));
  print(parsed.isError); // true

  // 6. Same idea, but async.
  final fetched = await Result.tryRunAsync<String>(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return 'hello';
  });
  print(fetched.getOrElse('fallback'));

  // 7. Recover from a failed future without throwing.
  final recovered = await Future.value(bad).recover((f) async => -1);
  print(recovered); // Success<int>(-1)
}
