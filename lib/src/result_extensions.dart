/// Convenience extensions on [Result] and `Future<Result>`.
library;

import 'failure.dart';
import 'result.dart';

/// Synchronous helpers on [Result].
extension ResultX<T> on Result<T> {
  /// Whether this result is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Whether this result is an [Error].
  bool get isError => this is Error<T>;

  /// The wrapped data, or `null` if this is an [Error].
  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Error<T>() => null,
      };

  /// The wrapped failure, or `null` if this is a [Success].
  Failure? get errorOrNull => switch (this) {
        Success<T>() => null,
        Error<T>(:final failure) => failure,
      };

  /// Returns the data on success, or [defaultValue] on failure.
  T getOrElse(T defaultValue) => switch (this) {
        Success<T>(:final data) => data,
        Error<T>() => defaultValue,
      };

  /// Returns the data on success, or throws a [ResultUnwrapException] on
  /// failure.
  ///
  /// Use sparingly — the whole point of `Result` is that callers are forced to
  /// handle the failure path. Reach for [getOrElse] or [when] first.
  T getOrThrow() => switch (this) {
        Success<T>(:final data) => data,
        Error<T>(:final failure) => throw ResultUnwrapException(failure),
      };

  /// Returns the wrapped failure on error, or throws a [StateError] on
  /// success. Symmetric counterpart to [getOrThrow].
  Failure errorOrThrow() => switch (this) {
        Success<T>(:final data) => throw StateError(
            'Called errorOrThrow on a Success: $data',
          ),
        Error<T>(:final failure) => failure,
      };

  /// Invokes [action] with the data if this is a [Success]. Returns `this`
  /// for chaining.
  Result<T> onSuccess(void Function(T data) action) {
    if (this case Success<T>(:final data)) action(data);
    return this;
  }

  /// Invokes [action] with the failure if this is an [Error]. Returns `this`
  /// for chaining.
  Result<T> onError(void Function(Failure failure) action) {
    if (this case Error<T>(:final failure)) action(failure);
    return this;
  }

  /// Invokes [action] regardless of variant — a finally-style hook for
  /// cleanup like dismissing a spinner. Returns `this` for chaining.
  Result<T> onComplete(void Function() action) {
    action();
    return this;
  }

  /// Invokes [action] with the data on success, passing through the result
  /// unchanged. Useful for side effects like logging without transforming.
  Result<T> tap(void Function(T data) action) {
    if (this case Success<T>(:final data)) action(data);
    return this;
  }

  /// Synchronous counterpart to [FutureResultX.recover]. If this is an
  /// [Error], substitutes a default success value computed from the failure;
  /// otherwise propagates the [Success] unchanged.
  Result<T> recover(T Function(Failure failure) recovery) => switch (this) {
        Success<T>() => this,
        Error<T>(:final failure) => Success<T>(recovery(failure)),
      };

  /// Synchronous counterpart to [FutureResultX.recoverWith]. If this is an
  /// [Error], delegates to [recovery] for a replacement [Result]; otherwise
  /// propagates the [Success] unchanged.
  Result<T> recoverWith(Result<T> Function(Failure failure) recovery) =>
      switch (this) {
        Success<T>() => this,
        Error<T>(:final failure) => recovery(failure),
      };

  /// If this is a [Success] and [predicate] returns `false` for its data,
  /// converts it into an [Error] using [onUnmet]. Otherwise propagates the
  /// result unchanged. Handy for post-success domain validation, e.g. an HTTP
  /// 200 envelope whose body still indicates a logical failure.
  ///
  /// ```dart
  /// final r = await api.fetchOrder(id);
  /// final valid = r.ensure(
  ///   (o) => o.items.isNotEmpty,
  ///   (o) => const Failure.badResponse(message: 'Empty order'),
  /// );
  /// ```
  Result<T> ensure(
    bool Function(T data) predicate,
    Failure Function(T data) onUnmet,
  ) =>
      switch (this) {
        Success<T>(:final data) =>
          predicate(data) ? this : Error<T>(onUnmet(data)),
        Error<T>() => this,
      };
}

/// Async transformations applied directly to a [Result] (not a future).
///
/// Unlike [FutureResultX] which operates on `Future<Result<T>>`, these methods
/// start from a plain [Result<T>] and return a `Future<Result<R>>`, making
/// them useful at the start of an async pipeline or when you already hold a
/// resolved result.
extension ResultAsyncX<T> on Result<T> {
  /// If this is a [Success], awaits [transform] applied to the data and wraps
  /// the return value in a new [Success]. Otherwise resolves immediately with
  /// the existing [Error].
  Future<Result<R>> asyncMap<R>(Future<R> Function(T data) transform) =>
      switch (this) {
        Success<T>(:final data) => transform(data).then(Success<R>.new),
        Error<T>(:final failure) => Future.value(Error<R>(failure)),
      };

  /// Like [asyncMap] but [transform] returns its own [Result], allowing async
  /// failures to short-circuit without nesting `Future<Result<Result<R>>>`.
  Future<Result<R>> asyncFlatMap<R>(
    Future<Result<R>> Function(T data) transform,
  ) =>
      switch (this) {
        Success<T>(:final data) => transform(data),
        Error<T>(:final failure) => Future.value(Error<R>(failure)),
      };
}

/// Collapses a nested [Result] into a single layer. If the outer is an
/// [Error], it is returned unchanged; otherwise the inner [Result] is
/// returned.
extension FlattenResultX<T> on Result<Result<T>> {
  /// Removes one layer of nesting from `Result<Result<T>>` to `Result<T>`.
  Result<T> flatten() => switch (this) {
        Success<Result<T>>(:final data) => data,
        Error<Result<T>>(:final failure) => Error<T>(failure),
      };
}

/// Async helpers on `Future<Result<T>>`.
///
/// These let pipelines of asynchronous calls stay flat instead of nesting
/// `then`s and conditional branches.
extension FutureResultX<T> on Future<Result<T>> {
  /// Awaits this future, then applies [transform] to the data on success.
  Future<Result<R>> mapAsync<R>(Future<R> Function(T data) transform) async {
    final result = await this;
    return switch (result) {
      Success<T>(:final data) => Success<R>(await transform(data)),
      Error<T>(:final failure) => Error<R>(failure),
    };
  }

  /// Awaits this future, then chains another async [Result]-returning op.
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T data) transform,
  ) async {
    final result = await this;
    return switch (result) {
      Success<T>(:final data) => await transform(data),
      Error<T>(:final failure) => Error<R>(failure),
    };
  }

  /// Substitutes a default success value when the awaited result is an
  /// [Error]. The [recovery] callback receives the [Failure] so that you can
  /// inspect it before deciding what to return.
  Future<Result<T>> recover(
    Future<T> Function(Failure failure) recovery,
  ) async {
    final result = await this;
    return switch (result) {
      Success<T>() => result,
      Error<T>(:final failure) => Success<T>(await recovery(failure)),
    };
  }

  /// Like [recover], but the [recovery] callback may itself fail by returning
  /// another [Result]. Use this when the fallback is another network call or
  /// any operation that can return its own [Failure].
  Future<Result<T>> recoverWith(
    Future<Result<T>> Function(Failure failure) recovery,
  ) async {
    final result = await this;
    return switch (result) {
      Success<T>() => result,
      Error<T>(:final failure) => await recovery(failure),
    };
  }

  /// Async counterpart to the synchronous `Result.mapError`. Transforms the
  /// wrapped [Failure] using an async [transform], leaving [Success] alone.
  Future<Result<T>> mapErrorAsync(
    Future<Failure> Function(Failure failure) transform,
  ) async {
    final result = await this;
    return switch (result) {
      Success<T>() => result,
      Error<T>(:final failure) => Error<T>(await transform(failure)),
    };
  }

  /// Awaits this future, invokes [action] with the data if the result is a
  /// [Success], then returns the result unchanged. Useful for async side
  /// effects like analytics or cache writes without transforming the value.
  Future<Result<T>> onSuccessAsync(
    Future<void> Function(T data) action,
  ) async {
    final result = await this;
    if (result case Success<T>(:final data)) await action(data);
    return result;
  }

  /// Awaits this future, invokes [action] with the failure if the result is an
  /// [Error], then returns the result unchanged. Useful for async error
  /// reporting or logging without altering the failure.
  Future<Result<T>> onErrorAsync(
    Future<void> Function(Failure failure) action,
  ) async {
    final result = await this;
    if (result case Error<T>(:final failure)) await action(failure);
    return result;
  }
}

/// Bridges a regular `Future<T>` (which signals failure by throwing) into a
/// `Future<Result<T>>` without writing `Result.tryRunAsync(() => future)` at
/// every call site.
///
/// Named `asResult` (rather than `toResult`) to avoid colliding with the
/// transport-specific `.toResult()` methods provided by the retrofit /
/// chopper integration barrels.
extension FutureToResultX<T> on Future<T> {
  /// Awaits this future, returning [Success] on completion or [Error] if it
  /// throws. By default the caught object is wrapped in [Failure.unknown];
  /// pass [onError] to translate transport-specific exceptions into a more
  /// meaningful [Failure].
  Future<Result<T>> asResult({
    Failure Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      return Success<T>(await this);
    } catch (e, st) {
      final failure = onError?.call(e, st) ??
          Failure.unknown(message: e.toString(), stackTrace: st, cause: e);
      return Error<T>(failure);
    }
  }
}

/// Thrown by [ResultX.getOrThrow] when called on an [Error].
class ResultUnwrapException implements Exception {
  /// Creates an unwrap exception carrying the originating [failure].
  const ResultUnwrapException(this.failure);

  /// The failure that the caller chose to escalate to an exception.
  final Failure failure;

  @override
  String toString() => 'ResultUnwrapException: $failure';
}
