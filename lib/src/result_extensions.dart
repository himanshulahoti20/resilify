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
}

/// Async helpers on `Future<Result<T>>`.
///
/// These let pipelines of asynchronous calls stay flat instead of nesting
/// `then`s and conditional branches.
extension FutureResultX<T> on Future<Result<T>> {
  /// Awaits this future, then applies [transform] to the data on success.
  Future<Result<R>> mapAsync<R>(
    Future<R> Function(T data) transform,
  ) async {
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
