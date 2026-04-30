/// Helpers for working with `Result<List<T>>`.
library;

import 'failure.dart';
import 'result.dart';

/// Extensions that operate on the elements *inside* a successful list result.
///
/// Lets you transform / filter the underlying collection without explicitly
/// pattern-matching on the [Result] wrapper:
///
/// ```dart
/// final names = users.mapList((u) => u.name);     // Result<List<String>>
/// final adults = users.filter((u) => u.age >= 18); // Result<List<User>>
/// ```
extension ResultListX<T> on Result<List<T>> {
  /// Transforms each element of the wrapped list with [transform].
  Result<List<R>> mapList<R>(R Function(T item) transform) {
    return map((list) => list.map(transform).toList(growable: false));
  }

  /// Keeps only the elements satisfying [test]. Errors pass through unchanged.
  Result<List<T>> filter(bool Function(T item) test) {
    return map((list) => list.where(test).toList(growable: false));
  }

  /// Alias for [filter] that reads more naturally next to [mapList].
  Result<List<T>> whereResult(bool Function(T item) test) => filter(test);

  /// Returns the first element of the wrapped list as a `Result<T>`. If the
  /// list is empty, the result becomes an [Error] carrying [Failure.notFound]
  /// with [emptyMessage].
  Result<T> firstOrError({
    String emptyMessage = 'List is empty',
  }) {
    return switch (this) {
      Success<List<T>>(:final data) => data.isEmpty
          ? Error<T>(Failure.notFound(message: emptyMessage))
          : Success<T>(data.first),
      Error<List<T>>(:final failure) => Error<T>(failure),
    };
  }
}
