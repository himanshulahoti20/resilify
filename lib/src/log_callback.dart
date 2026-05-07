/// Defines the [LogCallback] typedef used by resilify logging integrations.
library;

/// Sink for log lines emitted by resilify interceptors and handlers.
///
/// Defaults to `print` in most integrations; swap for your preferred logger:
///
/// ```dart
/// ResultLoggerInterceptor(logger: (line) => logger.d(line))
/// ```
typedef LogCallback = void Function(String line);
