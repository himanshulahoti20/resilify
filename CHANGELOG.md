# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.3.0

### Added

- **`RateLimiter`** — token-bucket throughput limiter for `Result`-returning
  operations. Admits up to `maxTokens` calls in a burst, then refills
  continuously at a rate of `maxTokens` every `refillInterval`. Complements
  [Bulkhead] (which limits concurrency, not throughput) — the right tool for
  staying under an upstream API quota like "100 requests per minute". Calls
  made with an empty bucket fast-fail with
  `Error(Failure.rateLimiterRejected())` instead of the underlying operation
  being invoked.

  ```dart
  final limiter = RateLimiter(
    maxTokens: 100,
    refillInterval: const Duration(minutes: 1),
  );
  final result = await limiter.execute(() => api.fetchUser(id));
  ```

  Also exposes `tryAcquire()` for gating non-`Result` work off the same
  bucket, and `reset()` to refill immediately.

- **`TimeoutPolicy`** — a `duration`-bound operation wrapper packaged as a
  reusable object with the same `execute(() => ...)` shape as
  `CircuitBreaker`, `Bulkhead`, and `RateLimiter`, so it composes by nesting
  instead of being reapplied at every call site:

  ```dart
  final timeout = TimeoutPolicy(const Duration(seconds: 5));
  final breaker = CircuitBreaker();

  final result = await breaker.execute(
    () => timeout.execute(() => api.fetchUser(id)),
  );
  ```

- **`FailureKind.rateLimiterRejected` + `FailureType.rateLimiterRejected` +
  `Failure.rateLimiterRejected()`** — categorical tag and named constructor
  for rate-limiter overflow. Treated as transient by `Failure.isRetryable`.

### Fixed

- **`mapDioException`** no longer switches on `DioExceptionType` by
  exhaustively naming every member. Dio has added new enum values within
  our `dio: ^5.3.0` constraint (e.g. `transformTimeout` in 5.10.0), which
  broke compilation for anyone resolving a newer dio than this package was
  last built against. The catch-all case now falls back to
  `Failure.unknown()` for any type outside the categories we explicitly
  handle, matching the previous behavior for `DioExceptionType.unknown`
  while staying forward-compatible.

### Changed

- **`Failure.validation()`** now sets `kind: FailureKind.validation` instead
  of falling back to `FailureKind.unknown`. Adds the missing
  `FailureKind.validation` enum value so kind-based dispatch (retry
  policies, analytics buckets, `CircuitBreaker.shouldTrip`) can distinguish
  a 422 validation failure from a genuinely unclassified one.
  `Failure.validation().isRetryable` remains `false` — this only affects
  code that inspects `kind` directly, not the existing code-based fallback
  behavior it previously relied on.

## 1.2.0

### Added

- **`Bulkhead`** — concurrency limiter for `Result`-returning operations.
  Caps the number of simultaneously in-flight calls at `maxConcurrent`
  and queues the overflow up to `maxQueueSize` (FIFO). When both the
  in-flight slots and the queue are full, additional callers fast-fail
  with `Error(Failure.bulkheadRejected())` instead of being kept
  waiting. Composes naturally with `CircuitBreaker`, `RetryHelper`, and
  `ResultCache`.

  ```dart
  final bulkhead = Bulkhead(maxConcurrent: 8, maxQueueSize: 16);
  final result = await bulkhead.execute(() => api.fetchUser(id));
  ```

- **`FailureKind.bulkheadRejected` + `FailureType.bulkheadRejected` +
  `Failure.bulkheadRejected()`** — categorical tag and named
  constructor for bulkhead overflow. Treated as transient by
  `Failure.isRetryable`, so retry helpers will back off and try again
  rather than surfacing it as a permanent failure.

- **`Result.partition()`** — splits an `Iterable<Result<T>>` into two
  parallel unmodifiable lists `(List<T> successes, List<Failure>
  failures)`, preserving order. Non-short-circuiting counterpart to
  `Result.collect()` — useful for batch operations where you want to
  surface partial progress alongside the failures.

  ```dart
  final (saved, errors) = Result.partition(
    await Future.wait(orders.map(api.save)),
  );
  ```

- **`ResultCache.putIfAbsent()`** — synchronous, atomic insert-only-if-
  missing. Mirrors `Map.putIfAbsent` semantics: also caches `Error`
  results (unlike `getOrFetch`, which only memoizes successes), making
  it useful for memoizing pure computations or pre-resolved
  `Result`s.

- **`FutureResultX.onFinallyAsync()`** — async finally-style hook that
  runs an `async` callback regardless of variant (and even if the
  underlying future throws), then returns the original result. Useful
  for releasing tokens, closing transient resources, or dismissing UI
  state without coupling to success/error handling.

## 1.1.1

### Added

- **`ResultX.recover()` / `ResultX.recoverWith()` (sync)** — synchronous
  counterparts to the existing `FutureResultX.recover` /
  `recoverWith`. `recover` substitutes a fallback success value computed
  from the [Failure]; `recoverWith` delegates to a callback that returns
  its own [Result] (which may itself be an [Error]).

  ```dart
  final user = cachedResult.recover((f) => User.guest());
  ```

- **`ResultX.ensure()`** — post-success validation that turns a [Success]
  into an [Error] when a predicate fails, leaving an existing [Error]
  untouched. Useful when an HTTP 200 envelope still encodes a logical
  failure (empty payload, server-side flag, etc.).

  ```dart
  final valid = orderResult.ensure(
    (o) => o.items.isNotEmpty,
    (o) => const Failure.badResponse(message: 'Empty order'),
  );
  ```

- **`ResultCache.keys`** — unmodifiable snapshot of the cache key set for
  diagnostics and ad-hoc inspection.

- **`ResultCache.invalidateWhere()`** — bulk invalidation by predicate,
  returning the number of entries removed. Enables tag-style eviction
  when keys encode resource type or user scope:

  ```dart
  cache.invalidateWhere((k) => k.startsWith('user:'));
  ```

## 1.1.0

### Added

- **Circuit breaker** (`CircuitBreaker`) — a closed/open/half-open state
  machine for `Result`-returning operations. After
  `failureThreshold` consecutive trip-eligible failures the breaker opens
  and fast-fails calls for `resetTimeout`, then admits a single probe.
  Configurable `shouldTrip` predicate (defaults to `failure.isRetryable`)
  and `onStateChange` observer. Pluggable clock for tests.

- **`FailureKind` enum + `Failure.kind` field** — categorical tag that
  discriminates failures independently of `code` / `message`. Enables
  accurate retry decisions for code-less failures (a `network` failure is
  retryable; a `parsing` failure is not). New `FailureKind.circuitOpen`
  marks fast-fail responses from `CircuitBreaker.execute`.

- **`FailureType` enum** — every `Failure` now carries a `type` field set
  automatically by its named constructor. Switch on `failure.type` instead of
  inspecting `failure.code` to route failures to the right UI state or
  analytics bucket without fragile integer comparisons:

  ```dart
  switch (failure.type) {
    FailureType.network      => showOfflineBanner(),
    FailureType.unauthorized => pushLoginScreen(),
    _                        => showGenericError(failure.message),
  }
  ```

- **`Failure.validation()`** — new named constructor for HTTP 422 (Unprocessable
  Entity) with `type = FailureType.validation`. Also handled by
  `Failure.fromStatusCode(422)`.

- **`RetryHelper.withTimeout`** — standalone helper that wraps a single
  attempt in a timeout, returning `Error(Failure.timeout())` instead of
  throwing.

- **`Future<T>.asResult()` extension** — terser bridge from a throwing
  `Future<T>` into a `Future<Result<T>>` (vs the longer
  `Result.tryRunAsync(() => future)`). Named `asResult` rather than
  `toResult` to avoid colliding with the retrofit / chopper integrations'
  transport-specific `.toResult()` methods.

- **`Result.collectAsync()`** — async counterpart to `Result.collect()`.
  Awaits an `Iterable<Future<Result<T>>>` in order and short-circuits on the
  first error, returning a `Result<List<T>>`:

  ```dart
  final r = await Result.collectAsync([
    api.fetchUser('u1'),
    api.fetchUser('u2'),
  ]);
  ```

- **`Result.asyncMap()` / `Result.asyncFlatMap()`** — async transform methods
  on plain `Result<T>` (not a future). Complement `FutureResultX.mapAsync` /
  `flatMapAsync` for cases where you already hold a resolved result and want
  to start an async pipeline:

  ```dart
  final result = await cachedResult.asyncMap((user) => enrichUser(user));
  ```

- **`FutureResultX.onSuccessAsync()` / `onErrorAsync()`** — async side-effect
  hooks on `Future<Result<T>>`. Mirror the synchronous `onSuccess` / `onError`
  but accept `async` callbacks, useful for async logging, cache writes, or
  analytics calls:

  ```dart
  await api.fetchUser(id)
      .onSuccessAsync((u) => cache.put(id, u))
      .onErrorAsync((f) => analytics.logError(f));
  ```

- **`ResultCache<K, V>`** — in-memory cache for `Result` values with optional
  TTL. `getOrFetch` serves cached successes instantly and fetches on miss;
  errors are never cached so callers can retry immediately:

  ```dart
  final cache = ResultCache<String, User>(ttl: const Duration(minutes: 5));
  final user = await cache.getOrFetch('u1', () => api.fetchUser('u1'));
  ```

- **`ResultDeduplicator<K, V>`** — collapses concurrent calls for the same key
  into a single in-flight future. All concurrent callers receive the same
  result; once the future completes the key is evicted so the next call
  triggers a fresh fetch:

  ```dart
  final dedup = ResultDeduplicator<String, User>();
  // Three concurrent callers → one network request.
  final results = await Future.wait([
    dedup.run('u1', () => api.fetchUser('u1')),
    dedup.run('u1', () => api.fetchUser('u1')),
    dedup.run('u1', () => api.fetchUser('u1')),
  ]);
  ```

- **`LogCallback`** — the `typedef LogCallback = void Function(String line)`
  is now exported from the core `resilify.dart` barrel so you can type
  callback parameters without importing the Dio barrel.

### Changed

- `Failure.isRetryable` is now decided primarily by `FailureKind`, so
  `Failure.network()` and similar code-less transient failures are now
  reported as retryable. Failures built with the unstructured generic
  constructor still fall back to `code`-based heuristics. Existing
  `code`-based retry decisions are unchanged.
- `Failure.toString()` now includes both `kind:` and `type:` for easier
  diagnostics. The `==` / `hashCode` contract is unchanged (still `type` +
  `code` + `message` + `cause` + `retryAfter`) so existing equality-based
  assertions keep working.

## 1.0.6

### Fixed

- Resolved pub.dev analysis failure caused by `dart pub outdated --json`
  crashing during dependency advisory parsing.
- Stabilized dependency resolution to ensure compatibility with pub.dev's pana
  analysis pipeline.
- Fixed documentation generation issues that prevented dartdoc from running
  successfully.
- Corrected `documentation` URL in `pubspec.yaml` to point to a valid and
  accessible resource.

### Changed

- Adjusted dependency constraints (notably `dio`) to avoid triggering advisory
  parsing issues on pub.dev.
- Simplified dev dependency graph to improve analysis reliability and prevent
  toolchain conflicts.
- Improved overall package compatibility with pub.dev scoring system and
  analysis environment.

### Documentation

- Added missing dartdoc comments across public APIs to improve documentation
  coverage and pub score.

## 1.0.5

### Added

- **`Result.tap()`** — execute side effects (logging, debugging) on successful
  results without transforming the value. Great for inspecting data in the
  middle of a result chain:

  ```dart
  result.tap(print).tap(logToAnalytics).map(transformData);
  ```

- Enhanced code quality standards with stricter linting rules (upgraded `lints`
  to ^6.1.0) — the package now adheres to the latest Dart conventions and best
  practices for code style and correctness.

### Fixed

- Trailing-comma lint warnings in `lib/src/integrations/chopper_result.dart`
  and `lib/src/result.dart` — package now passes `dart analyze --fatal-warnings`
  with zero issues.
- Removed deprecated transitive dependencies (`build_resolvers`,
  `build_runner_core`) that were flagged by pub.dev.

### Changed

- Updated dev dependencies to latest versions:
  - `lints`: ^4.0.0 → ^6.1.0 for stricter code quality checks
  - `retrofit_generator`: ^8.0.0 → ^10.2.5
  - `build_runner`: ^2.4.0 → ^2.15.0
  - `chopper_generator`: ^8.0.0 → ^8.6.1
  - `json_serializable`: ^6.7.0 → ^6.13.2
  - `test`: ^1.25.0 → ^1.31.1
  - All transitive dependencies updated to latest compatible versions.

## 1.0.4

### Added

- **`Failure.retryAfter`** — a `Duration?` field on `Failure` that surfaces
  the server's back-off hint from a `Retry-After` HTTP header. Populated
  automatically for 429 / 5xx responses by both `HttpResultHandler` and the
  Dio integration's `mapDioException`. Pair with `RetryHelper.retry`'s
  `delay` parameter to honor the server's wait time exactly:

  ```dart
  result.errorOrNull?.retryAfter // Duration(seconds: 30) when present
  ```

- **`Failure.parseRetryAfter(String?)`** — static helper that converts the
  seconds form of an HTTP `Retry-After` header into a `Duration`. Returns
  `null` for null / blank / non-numeric input; clamps negatives to zero. The
  HTTP-date form is intentionally left to callers so the core library stays
  free of `dart:io`.
- `platforms:` declaration in `pubspec.yaml` (Android, iOS, Linux, macOS,
  Windows) so pub.dev surfaces verified platform support on the package page.
- `documentation:` link in `pubspec.yaml` pointing at the published dartdoc.
- Smoke tests for `HttpResultHandler` covering JSON GET/POST round-trips,
  query parameter merging, default-header propagation, 404 / 429 / 5xx
  mapping, `Retry-After` extraction, and parsing failures — closing the
  integration test gap flagged in the 1.0.3 audit.

### Fixed

- Trailing-comma lint warnings in `dio_result.dart` and `logger.dart` so the
  package now ships with a clean `dart analyze`.

## 1.0.3

### Added

- `Result.fromNullable<T>(T?, {Failure Function()? onNull})` — bridge
  nullable APIs (cache lookups, `firstWhereOrNull`, etc.) into a `Result<T>`
  in one call.
- `Result.zip2` and `Result.zip3` — combine multiple results into a record
  (`Result<(A, B)>` / `Result<(A, B, C)>`), short-circuiting on the first
  failure left-to-right. Handy for parallel fetches with `Future.wait`.
- `Result.collect<T>(Iterable<Result<T>>)` — fold a list of results into a
  single `Result<List<T>>`, returning the first failure encountered.
- `recoverWith` extension on `Future<Result<T>>` — like `recover`, but the
  fallback callback may itself return a `Result` (so a fallback network
  call that also fails is surfaced as the final error).
- `mapErrorAsync` extension on `Future<Result<T>>` — async counterpart to
  the synchronous `Result.mapError`.

### Changed

- `RetryHelper.retry` now accepts `attemptTimeout`. When set, each attempt
  is wrapped in `Future.timeout`; an exceeded timeout is converted into an
  `Error(Failure.timeout())` and goes through the normal `retryIf` /
  `maxAttempts` machinery.

## 1.0.2

### Added

- New `Failure` named constructors: `Failure.forbidden` (403),
  `Failure.conflict` (409), and `Failure.rateLimit` (429).
- `Failure.fromStatusCode(int)` — picks the most specific named constructor
  for a given HTTP status, falling back to `badResponse` for other 4xx and
  `serverError` for other 5xx.
- `Failure.is4xx`, `Failure.is5xx`, and `Failure.isRetryable` getters —
  drop-in predicates for `RetryHelper.retryIf`.
- `onComplete` extension on `Result<T>` — finally-style hook that fires for
  both `Success` and `Error`.
- `flatten()` extension on `Result<Result<T>>` — collapses one layer of
  nesting that `flatMap` chains often produce.

### Changed

- `RetryHelper.retry` now accepts `maxDelay` to cap the wait between
  attempts and `jitter` (with an optional `Random`) to spread retries and
  prevent thundering-herd retry storms. Both default to no-op behavior, so
  existing call sites are unaffected.

## 1.0.1

### Added

- `Result.tryRun` and `Result.tryRunAsync` — bridge throwing code into a
  `Result<T>` without writing try/catch at call sites. Both accept an
  optional `onError` to translate the caught object into a domain-specific
  `Failure`.
- `mapError` on `Result<T>` — transform the wrapped `Failure` without
  touching the success path. Useful for translating low-level transport
  failures into domain failures.
- `errorOrThrow` extension — symmetric counterpart to `getOrThrow`,
  returning the wrapped `Failure` or throwing a `StateError` on `Success`.

## 1.0.0 — Initial release

### Added

- **Core**
  - Sealed `Result<T>` with `Success<T>` and `Error<T>` variants (Dart 3).
  - Structured `Failure` value type with named constructors: `network`,
    `timeout`, `badResponse`, `parsing`, `unauthorized`, `notFound`,
    `serverError`, `cancelled`, `unknown`.
  - Synchronous extensions: `isSuccess`, `isError`, `dataOrNull`,
    `errorOrNull`, `getOrElse`, `getOrThrow`, `onSuccess`, `onError`.
  - `when`, `fold`, `map`, `flatMap` on `Result<T>`.
  - Async helpers on `Future<Result<T>>`: `mapAsync`, `flatMapAsync`,
    `recover`.
  - Stream helpers on `Stream<Result<T>>`: `mapStream`, `whereSuccess`,
    `whereError`, `dataStream`, `listenResult`.
  - List helpers on `Result<List<T>>`: `mapList`, `filter`, `whereResult`,
    `firstOrError`.
  - `RetryHelper.retry` with exponential backoff, predicate-based retry,
    and per-attempt observer.

- **Integrations** (each opt-in via its own barrel file)
  - `resilify_http.dart` — `HttpResultHandler` for `package:http`.
  - `resilify_dio.dart` — `DioResultHandler` (incl. `upload` /
    `download` with progress) and `ResultLoggerInterceptor`.
  - `resilify_retrofit.dart` — `.toResult()` on Retrofit-generated futures.
  - `resilify_chopper.dart` — `.toResult()` on Chopper `Response<T>`
    futures with pluggable failure mappers.
  - `resilify_websocket.dart` — `WebSocketResultHandler<T>` with
    auto-reconnect and exponential backoff.
