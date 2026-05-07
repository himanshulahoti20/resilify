# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.0
<<<<<<< Updated upstream

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
- **`RetryHelper.withTimeout`** — standalone helper that wraps a single
  attempt in a timeout, returning `Error(Failure.timeout())` instead of
  throwing.
- **`Future<T>.asResult()` extension** — terser bridge from a throwing
  `Future<T>` into a `Future<Result<T>>` (vs the longer
  `Result.tryRunAsync(() => future)`). Named `asResult` rather than
  `toResult` to avoid colliding with the retrofit / chopper integrations'
  transport-specific `.toResult()` methods.
=======

### Added

- **`FailureType` enum** — every `Failure` now carries a `type` field set
  automatically by its named constructor. Switch on `failure.type` instead of
  inspecting `failure.code` to route failures to the right UI state or analytics
  bucket without fragile integer comparisons:

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

- **`Failure.type`** field — `FailureType` set by each named constructor. The
  primary `Failure()` constructor accepts an optional `type` parameter that
  defaults to `FailureType.unknown`. `copyWith` preserves `type` unless
  explicitly overridden. `type` is included in equality, `hashCode`, and
  `toString`.

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
>>>>>>> Stashed changes

### Changed

- `Failure.isRetryable` is now decided primarily by `FailureKind`, so
  `Failure.network()` and similar code-less transient failures are now
  reported as retryable. Failures built with the unstructured generic
  constructor still fall back to `code`-based heuristics. Existing
  `code`-based retry decisions are unchanged.
- `Failure.toString()` now includes `kind:` for easier diagnostics. The
  `==` / `hashCode` contract is unchanged (still `code` + `message` +
  `cause`) so existing equality-based assertions keep working.

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
