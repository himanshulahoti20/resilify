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

  /// Runs [action] and wraps its return value in a [Success], catching any
  /// thrown object and converting it via [onError] (defaulting to
  /// [Failure.unknown]) into an [Error].
  static Result<T> tryRun<T>(
    T Function() action, {
    Failure Function(Object error, StackTrace stackTrace)? onError,
  }) {
    try {
      return Success<T>(action());
    } catch (e, st) {
      final failure = onError?.call(e, st) ??
          Failure.unknown(message: e.toString(), stackTrace: st, cause: e);
      return Error<T>(failure);
    }
  }

  /// Async counterpart to [tryRun]. Awaits [action] and converts thrown
  /// objects into an [Error] via [onError] (defaulting to [Failure.unknown]).
  static Future<Result<T>> tryRunAsync<T>(
    Future<T> Function() action, {
    Failure Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      return Success<T>(await action());
    } catch (e, st) {
      final failure = onError?.call(e, st) ??
          Failure.unknown(message: e.toString(), stackTrace: st, cause: e);
      return Error<T>(failure);
    }
  }

  /// Wraps a nullable [value] in a [Success] if non-null, otherwise produces
  /// an [Error] with the failure returned by [onNull] (defaulting to a
  /// generic `Failure(message: 'Value was null')`). Handy for bridging APIs
  /// that signal absence with `null` (cache lookups, `firstWhereOrNull`).
  static Result<T> fromNullable<T>(
    T? value, {
    Failure Function()? onNull,
  }) {
    if (value != null) return Success<T>(value);
    return Error<T>(
      onNull?.call() ?? const Failure(message: 'Value was null'),
    );
  }

  /// Combines two [Result]s into a `Result<(A, B)>`. Returns the first
  /// [Error] encountered (left-to-right), or a [Success] containing both
  /// values as a record.
  static Result<(A, B)> zip2<A, B>(Result<A> a, Result<B> b) {
    if (a is Error<A>) return Error<(A, B)>(a.failure);
    if (b is Error<B>) return Error<(A, B)>(b.failure);
    return Success<(A, B)>(((a as Success<A>).data, (b as Success<B>).data));
  }

  /// Combines three [Result]s into a `Result<(A, B, C)>`. Returns the first
  /// [Error] encountered (left-to-right).
  static Result<(A, B, C)> zip3<A, B, C>(
    Result<A> a,
    Result<B> b,
    Result<C> c,
  ) {
    if (a is Error<A>) return Error<(A, B, C)>(a.failure);
    if (b is Error<B>) return Error<(A, B, C)>(b.failure);
    if (c is Error<C>) return Error<(A, B, C)>(c.failure);
    return Success<(A, B, C)>(
      (
        (a as Success<A>).data,
        (b as Success<B>).data,
        (c as Success<C>).data,
      ),
    );
  }

  /// Collapses an iterable of [Result]s into a single `Result<List<T>>`.
  /// Short-circuits on the first [Error]; otherwise returns a list of all
  /// successful values in iteration order.
  static Result<List<T>> collect<T>(Iterable<Result<T>> results) {
    final out = <T>[];
    for (final r in results) {
      switch (r) {
        case Success<T>(:final data):
          out.add(data);
        case Error<T>(:final failure):
          return Error<List<T>>(failure);
      }
    }
    return Success<List<T>>(List.unmodifiable(out));
  }

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

  /// If this is an [Error], applies [transform] to the failure and wraps the
  /// outcome in a new [Error]. Otherwise propagates the [Success] unchanged.
  ///
  /// Useful for translating low-level failures (e.g. a transport-level
  /// `Failure.network`) into a domain-specific failure before it bubbles up.
  Result<T> mapError(Failure Function(Failure failure) transform);
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
  Result<T> mapError(Failure Function(Failure failure) transform) => this;

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
  Result<T> mapError(Failure Function(Failure failure) transform) =>
      Error<T>(transform(failure));

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
