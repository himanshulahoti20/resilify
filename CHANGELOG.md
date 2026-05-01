# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
