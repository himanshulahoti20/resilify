/// Defines the sealed [Result] type and its [Success] / [Error] variants.
library;

import 'failure.dart';

/// A type-safe representation of an operation that either produced a value of
/// type [T] ([Success]) or failed with a [Failure] ([Error]).
///
/// `Result` is sealed, so exhaustive `switch` expressions over it are
/// statically verified by the compiler:
///
/// ```dart
/// final message = switch (result) {
///   Success(:final data) => 'Got $data',
///   Error(:final failure) => 'Oops: ${failure.message}',
/// };
/// ```
///
/// > **Naming collision:** the [Error] variant shadows `dart:core.Error`. If
/// > you need both in the same file, hide one of them at the import site:
/// >
/// > ```dart
/// > import 'package:resilify/resilify.dart';
/// > import 'dart:core' hide Error;
/// > ```
sealed class Result<T> {
  const Result();

  /// Wraps [data] in a successful result.
  const factory Result.success(T data) = Success<T>;

  /// Wraps [failure] in an error result.
  const factory Result.error(Failure failure) = Error<T>;

  /// Pattern-matches on the variant, calling [success] or [error] and
  /// returning the produced value.
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  });

  /// Alias for [when] with positional callbacks, matching the Either/Result
  /// convention used in functional libraries.
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(Failure failure) onError,
  );

  /// If this is a [Success], applies [transform] to the data and wraps the
  /// outcome in a new [Success]. Otherwise propagates the [Error] unchanged.
  Result<R> map<R>(R Function(T data) transform);

  /// Like [map] but the [transform] returns its own [Result], allowing
  /// failures to short-circuit without nesting `Result<Result<R>>`.
  Result<R> flatMap<R>(Result<R> Function(T data) transform);
}

/// The successful variant of a [Result].
final class Success<T> extends Result<T> {
  /// Creates a [Success] holding [data].
  const Success(this.data);

  /// The value produced by the operation.
  final T data;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  }) =>
      success(data);

  @override
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(Failure failure) onError,
  ) =>
      onSuccess(data);

  @override
  Result<R> map<R>(R Function(T data) transform) => Success<R>(transform(data));

  @override
  Result<R> flatMap<R>(Result<R> Function(T data) transform) => transform(data);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<T> && other.data == data;
  }

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success<$T>($data)';
}

/// The failed variant of a [Result].
///
/// Note: this class shadows `dart:core.Error`. See the [Result] doc for the
/// `hide Error` workaround.
final class Error<T> extends Result<T> {
  /// Creates an [Error] holding [failure].
  const Error(this.failure);

  /// The structured description of why the operation failed.
  final Failure failure;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) error,
  }) =>
      error(failure);

  @override
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(Failure failure) onError,
  ) =>
      onError(failure);

  @override
  Result<R> map<R>(R Function(T data) transform) => Error<R>(failure);

  @override
  Result<R> flatMap<R>(Result<R> Function(T data) transform) =>
      Error<R>(failure);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Error<T> && other.failure == failure;
  }

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Error<$T>($failure)';
}
