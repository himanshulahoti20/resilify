# resilify

[![pub version](https://img.shields.io/pub/v/resilify.svg)](https://pub.dev/packages/resilify)
[![pub points](https://img.shields.io/pub/points/resilify)](https://pub.dev/packages/resilify/score)
[![pub likes](https://img.shields.io/pub/likes/resilify)](https://pub.dev/packages/resilify/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![CI](https://github.com/himanshulahoti20/resilify/actions/workflows/dart_ci.yml/badge.svg?branch=main&cache_bust=1)

> **No exceptions. Just results.**

`resilify` gives you a single, exception-free, `Result<T>`-based API across
the most popular Dart networking libraries — `http`, `Dio`, `Retrofit`,
`Chopper`, and `web_socket_channel`. The core is dependency-free; integrations
are layered on top so you only pay for what you use.

---

## Why resilify?

Try-catch hell:

```dart
Future<User> fetchUser(String id) async {
  try {
    final response = await dio.get('/users/$id');
    return User.fromJson(response.data);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      throw TimeoutException();
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException();
    } else {
      throw NetworkException();
    }
  } on FormatException {
    throw ParsingException();
  }
}
```

…vs. one `Result`:

```dart
Future<Result<User>> fetchUser(String id) {
  return api.get<User>(
    '/users/$id',
    parser: (json) => User.fromJson(json! as Map<String, dynamic>),
  );
}

// Caller:
final result = await fetchUser('42');
result.when(
  success: (user) => print('Hello ${user.name}'),
  error:   (failure) => print('Failed: ${failure.message}'),
);
```

No exceptions thrown from the public API. Failures are **values** the type
system forces you to handle.

---

## Feature matrix

| Use case                 | Use                       |
| ------------------------ | ------------------------- |
| Quick prototypes         | `http`                    |
| Enterprise apps          | `Dio`                     |
| File uploads / downloads | `Dio`                     |
| Type-safe clean code     | `Retrofit` or `Chopper`   |
| Real-time updates        | `web_socket_channel`      |

---

## Installation

```yaml
dependencies:
  resilify: ^1.2.0
```

Then add the transports you need (already pulled in transitively by the
matching integration barrel):

```yaml
  dio: ^5.4.0
  http: ^1.2.0
  retrofit: ^4.1.0
  chopper: ^8.0.0
  web_socket_channel: ^3.0.0
```

Import only the integrations you actually use:

```dart
import 'package:resilify/resilify.dart';            // core (no networking deps)
import 'package:resilify/resilify_dio.dart';        // Dio + logger
import 'package:resilify/resilify_http.dart';       // package:http
import 'package:resilify/resilify_retrofit.dart';   // Retrofit
import 'package:resilify/resilify_chopper.dart';    // Chopper
import 'package:resilify/resilify_websocket.dart';  // WebSocket
```

---

## Quick start (5 lines)

```dart
final api = HttpResultHandler(baseUrl: 'https://api.example.com');
final result = await api.get<User>(
  '/users/me',
  parser: (json) => User.fromJson(json! as Map<String, dynamic>),
);
result.when(success: print, error: (f) => print(f.message));
```

---

## `http` — quick prototypes

```dart
import 'package:resilify/resilify_http.dart';

final api = HttpResultHandler(
  baseUrl: 'https://api.example.com',
  defaultHeaders: const {'Accept': 'application/json'},
  timeout: const Duration(seconds: 15),
);

final result = await api.get<List<Post>>(
  '/posts',
  parser: (json) => (json! as List)
      .cast<Map<String, dynamic>>()
      .map(Post.fromJson)
      .toList(),
);
```

---

## `Dio` — enterprise apps + file transfers

```dart
import 'package:resilify/resilify_dio.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
  ..interceptors.add(ResultLoggerInterceptor(logHeaders: true));
final api = DioResultHandler(dio);

final user = await api.get<User>(
  '/users/me',
  parser: (data) => User.fromJson(data! as Map<String, dynamic>),
);
```

### Upload with progress

```dart
final form = FormData.fromMap({
  'file': await MultipartFile.fromFile('/tmp/photo.jpg'),
});

final result = await api.upload<Map<String, dynamic>>(
  '/uploads',
  formData: form,
  onSendProgress: (sent, total) =>
      print('${(sent / total * 100).toStringAsFixed(1)}%'),
  parser: (json) => json! as Map<String, dynamic>,
);
```

### Download with progress

```dart
final result = await api.download(
  '/files/manual.pdf',
  '/tmp/manual.pdf',
  onReceiveProgress: (received, total) =>
      print('$received / $total bytes'),
);
```

---

## `Retrofit` — type-safe clean code

```dart
@RestApi(baseUrl: 'https://api.example.com')
abstract class UserApi {
  factory UserApi(Dio dio) = _UserApi;

  @GET('/users/{id}')
  Future<User> getUser(@Path('id') String id);
}

import 'package:resilify/resilify_retrofit.dart';

final api = UserApi(Dio());
final result = await api.getUser('42').toResult();
```

---

## `Chopper` — type-safe clean code

```dart
import 'package:resilify/resilify_chopper.dart';

final api = PetsApi.create();
final result = await api.getPet('42').toResult(
  failureMapper: (response) => Failure.badResponse(
    code: response.statusCode,
    message: 'Pet API failed',
    cause: response.error,
  ),
);
```

---

## WebSocket — real-time updates

```dart
import 'package:resilify/resilify_websocket.dart';

final ws = WebSocketResultHandler<Map<String, dynamic>>(
  channelFactory: () => WebSocketChannel.connect(
    Uri.parse('wss://api.example.com/feed'),
  ),
  parser: (raw) => jsonDecode(raw as String) as Map<String, dynamic>,
  reconnect: const ReconnectConfig(
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
    backoffFactor: 2.0,
  ),
);

ws.stream.listen((result) {
  result.when(
    success: (msg) => print('event: $msg'),
    error:   (f)   => print('ws error: ${f.message}'),
  );
});
ws.send(jsonEncode({'subscribe': 'ticker'}));
```

---

## Bulkhead — bound in-flight concurrency

Cap the number of simultaneously in-flight calls so one slow dependency
cannot exhaust client-side resources. Overflow callers queue up to
`maxQueueSize` (FIFO); past that, they fast-fail with
`Failure.bulkheadRejected()` instead of being kept waiting:

```dart
final bulkhead = Bulkhead(maxConcurrent: 8, maxQueueSize: 16);

final result = await bulkhead.execute(() => api.fetchUser(id));
// If the bulkhead is full, `result` is an Error with
// FailureKind.bulkheadRejected — the underlying call was not made.
```

Composes naturally with `CircuitBreaker`, `RetryHelper`, and
`ResultCache` — wrap the bulkhead around the call to bound resource use,
then layer retries / caching outside it as needed.

---

## Rate limiter — bound throughput over time

Unlike `Bulkhead` (which limits concurrency), `RateLimiter` limits
*throughput* using a token bucket — the right tool for staying under an
upstream API quota such as "100 requests per minute". Calls made with an
empty bucket fast-fail with `Failure.rateLimiterRejected()`:

```dart
final limiter = RateLimiter(
  maxTokens: 100,
  refillInterval: const Duration(minutes: 1),
);

final result = await limiter.execute(() => api.fetchUser(id));
// If the bucket is empty, `result` is an Error with
// FailureKind.rateLimiterRejected — the underlying call was not made.
```

---

## Circuit breaker — fail fast on a sick dependency

```dart
final breaker = CircuitBreaker(
  failureThreshold: 5,
  resetTimeout: const Duration(seconds: 30),
);

final result = await breaker.execute(() => api.fetchUser(id));
// While open, calls fast-fail with FailureKind.circuitOpen without
// invoking the underlying operation.
```

---

## Timeout policy — a reusable, composable deadline

Same `execute(() => ...)` shape as `CircuitBreaker`, `Bulkhead`, and
`RateLimiter`, so it nests instead of being reapplied at every call site:

```dart
final timeout = TimeoutPolicy(const Duration(seconds: 5));
final breaker = CircuitBreaker();

final result = await breaker.execute(
  () => timeout.execute(() => api.fetchUser(id)),
);
```

---

## Partition a batch — successes and failures side by side

`Result.collect` short-circuits on the first failure. When you instead
want partial progress alongside everything that failed, use
`Result.partition`:

```dart
final (saved, errors) = Result.partition(
  await Future.wait(orders.map(api.save)),
);
log.info('saved ${saved.length}, failed ${errors.length}');
```

---

## Recover, ensure, and finally

```dart
// Synchronously substitute a fallback for an Error.
final user = cachedResult.recover((f) => User.guest());

// Validate a Success post-hoc; convert to Error if a domain check fails.
final order = orderResult.ensure(
  (o) => o.items.isNotEmpty,
  (o) => const Failure.badResponse(message: 'Empty order'),
);

// Run async cleanup regardless of variant — even if the future throws.
await api.fetchUser(id).onFinallyAsync(() => spinner.dismiss());
```

---

## Result cache

```dart
final cache = ResultCache<String, User>(ttl: const Duration(minutes: 5));

// Async fetch-on-miss; only Successes are memoized.
final user = await cache.getOrFetch(id, () => api.fetchUser(id));

// Synchronous insert-only-if-missing; caches Errors too.
final cfg = cache.putIfAbsent('cfg', () => Result.success(loadConfig()));

// Tag-style bulk eviction.
cache.invalidateWhere((k) => k.startsWith('user:'));
```

---

## Retry with exponential backoff

```dart
final result = await RetryHelper.retry<User>(
  () => api.get<User>('/users/me', parser: User.fromJsonRaw),
  maxAttempts: 3,
  delay: const Duration(milliseconds: 500),
  backoffFactor: 2.0,
  retryIf: (failure) => failure.code == 503 || failure is Failure,
  onRetry: (attempt, failure) =>
      print('attempt $attempt failed: ${failure.message}'),
);
```

---

## Logger usage

```dart
final dio = Dio()
  ..interceptors.add(ResultLoggerInterceptor(
    logRequest: true,
    logResponse: true,
    logError: true,
    logHeaders: false,
    logBody: true,
    logger: (line) => myLogger.fine(line), // plug into Sentry, logger, etc.
  ));
```

---

## API reference

| Symbol                            | Purpose                                          |
| --------------------------------- | ------------------------------------------------ |
| `Result<T>` / `Success` / `Error` | Sealed result type and its variants              |
| `Failure`                         | Structured error value with named constructors   |
| `Result.when` / `fold`            | Pattern-match on success / error                 |
| `Result.map` / `flatMap`          | Transform / chain successful results             |
| `Result.recover` / `recoverWith`  | Sync fallback from `Error` to `Success`          |
| `Result.ensure`                   | Post-success validation: `Success` → `Error`     |
| `Result.collect` / `partition`    | Combine many results (short-circuit vs split)    |
| `Result.getOrElse` / `getOrThrow` | Unwrap with default or escalate to exception     |
| `Future<Result>.mapAsync` etc.    | Async transformations without nesting            |
| `Future<Result>.onFinallyAsync`   | Async finally hook, runs even on throw           |
| `Stream<Result>.dataStream` etc.  | Stream-friendly helpers                          |
| `Result<List>.mapList` / `filter` | Operate on the underlying collection             |
| `RetryHelper.retry`               | Backoff-driven retries with predicates           |
| `CircuitBreaker`                  | Fast-fail when a dependency keeps failing        |
| `Bulkhead`                        | Cap concurrent in-flight calls with FIFO queue   |
| `RateLimiter`                     | Token-bucket cap on throughput over time         |
| `TimeoutPolicy`                   | Reusable, composable per-call deadline           |
| `ResultCache`                     | TTL cache: `getOrFetch`, `putIfAbsent`, `keys`   |
| `ResultDeduplicator`              | Collapse concurrent calls per key                |
| `HttpResultHandler`               | `package:http` adapter                           |
| `DioResultHandler`                | `Dio` adapter incl. upload/download              |
| `ResultLoggerInterceptor`         | Pretty Dio interceptor                           |
| `WebSocketResultHandler`          | Reconnecting WebSocket with `Result` events      |
| `Future<T>.toResult()`            | Retrofit / Chopper bridge                        |

---

## `dart:core.Error` collision

The `Error` variant of `Result<T>` shadows `dart:core.Error`. If you need both
in the same file, hide one at the import site:

```dart
import 'package:resilify/resilify.dart';
import 'dart:core' hide Error;
```

…or import `dart:core` with a prefix:

```dart
import 'dart:core' as core;
core.Error someStdError;
```

---

## Contributing

PRs and issues are welcome at
<https://github.com/himanshulahoti20/resilify>. Please run `dart analyze` and
`dart test` before submitting.

## ❤️ Support

If you find this package helpful, consider supporting:

👉 https://github.com/sponsors/himanshulahoti20

## License

[MIT](LICENSE) © 2026 resilify contributors
No exceptions. Just results. A resilient networking toolkit for Dart &amp; Flutter with Dio, HTTP, WebSocket, and clean error handling.
