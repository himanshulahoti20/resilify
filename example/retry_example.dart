// Example: retrying a flaky operation with exponential backoff.
//
// Run with: `dart run example/retry_example.dart`

import 'package:resilify/resilify.dart';

Future<void> main() async {
  var attempts = 0;

  final result = await RetryHelper.retry<String>(
    () async {
      attempts++;
      if (attempts < 3) {
        return Error<String>(
          Failure.serverError(message: 'pretend 503 #$attempts'),
        );
      }
      return Success<String>('payload after $attempts attempts');
    },
    maxAttempts: 5,
    delay: const Duration(milliseconds: 200),
    backoffFactor: 2,
    retryIf: (failure) => failure.code == 500 || failure.code == 503,
    onRetry: (attempt, failure) =>
        print('retry $attempt because: ${failure.message}'),
  );

  result.when(success: print, error: (f) => print('gave up: ${f.message}'));
}
