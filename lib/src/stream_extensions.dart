/// Stream-oriented helpers on `Stream<Result<T>>`.
library;

import 'dart:async';

import 'failure.dart';
import 'result.dart';
import 'result_extensions.dart';

/// Extensions for working with streams of [Result] values without unwrapping
/// each event manually.
extension StreamResultX<T> on Stream<Result<T>> {
  /// Maps each successful event with [transform], leaving errors untouched.
  Stream<Result<R>> mapStream<R>(R Function(T data) transform) {
    return map((result) => result.map(transform));
  }

  /// Emits only the [Success] events, unwrapped to their data.
  Stream<T> get dataStream {
    return where((r) => r.isSuccess).map((r) => (r as Success<T>).data);
  }

  /// Emits only the [Success] events as full [Result]s. Useful when you want
  /// to keep the result wrapper for downstream chaining.
  Stream<Result<T>> whereSuccess() => where((r) => r.isSuccess);

  /// Emits only the [Error] events as full [Result]s.
  Stream<Result<T>> whereError() => where((r) => r.isError);

  /// Convenience for subscribing with separate success and error callbacks.
  StreamSubscription<Result<T>> listenResult({
    required void Function(T data) onData,
    required void Function(Failure failure) onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return listen(
      (result) => result.when(success: onData, error: onError),
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
