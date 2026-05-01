# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
