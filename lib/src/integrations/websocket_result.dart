/// `package:web_socket_channel` integration for `resilify`.
library;

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../failure.dart';
import '../result.dart';

/// Decodes a raw WebSocket frame (`String` or `List<int>`) into a typed
/// message of type `T`.
typedef MessageParser<T> = T Function(dynamic raw);

/// Factory for opening a [WebSocketChannel]. Re-invoked on each reconnect.
typedef WebSocketChannelFactory = WebSocketChannel Function();

/// Configuration for [WebSocketResultHandler]'s exponential-backoff reconnect
/// loop.
class ReconnectConfig {
  /// Creates a reconnect config.
  const ReconnectConfig({
    this.enabled = true,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffFactor = 2.0,
    this.maxAttempts,
  });

  /// Disables reconnect entirely.
  const ReconnectConfig.disabled()
      : enabled = false,
        initialDelay = Duration.zero,
        maxDelay = Duration.zero,
        backoffFactor = 1,
        maxAttempts = 0;

  /// Whether to attempt reconnects after an unexpected close / error.
  final bool enabled;

  /// Delay before the *first* reconnect attempt.
  final Duration initialDelay;

  /// Upper bound on the delay between attempts.
  final Duration maxDelay;

  /// Multiplier applied after each failed attempt.
  final double backoffFactor;

  /// Maximum number of reconnect attempts. `null` means retry forever.
  final int? maxAttempts;
}

/// A reconnecting, [Result]-flavored wrapper around a [WebSocketChannel].
///
/// Each frame from the server is parsed by [MessageParser] and emitted on
/// [stream] as `Result<T>`. Connection / parsing errors surface on the same
/// stream as `Error<T>` events, so consumers don't need an `onError` handler.
class WebSocketResultHandler<T> {
  /// Creates a handler that opens its channel via [channelFactory].
  WebSocketResultHandler({
    required WebSocketChannelFactory channelFactory,
    required MessageParser<T> parser,
    ReconnectConfig reconnect = const ReconnectConfig(),
  })  : _factory = channelFactory,
        _parser = parser,
        _reconnect = reconnect {
    _connect();
  }

  final WebSocketChannelFactory _factory;
  final MessageParser<T> _parser;
  final ReconnectConfig _reconnect;

  final StreamController<Result<T>> _controller =
      StreamController<Result<T>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _closed = false;

  /// Stream of parsed messages and failures.
  Stream<Result<T>> get stream => _controller.stream;

  void _connect() {
    if (_closed) return;
    try {
      final channel = _factory();
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      _attempt = 0;
    } catch (e, st) {
      _emitFailure(
        Failure.network(message: e.toString(), cause: e, stackTrace: st),
      );
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      _controller.add(Success<T>(_parser(raw)));
    } catch (e, st) {
      _emitFailure(Failure.parsing(cause: e, stackTrace: st));
    }
  }

  void _onError(Object error, StackTrace st) {
    _emitFailure(
      Failure.network(message: error.toString(), cause: error, stackTrace: st),
    );
    _scheduleReconnect();
  }

  void _onDone() {
    if (_closed) return;
    final code = _channel?.closeCode;
    final reason = _channel?.closeReason;
    _emitFailure(
      Failure.network(
        message: 'WebSocket closed${reason == null ? '' : ': $reason'}',
        code: code,
      ),
    );
    _scheduleReconnect();
  }

  void _emitFailure(Failure failure) {
    if (_controller.isClosed) return;
    _controller.add(Error<T>(failure));
  }

  void _scheduleReconnect() {
    if (_closed || !_reconnect.enabled) return;
    final max = _reconnect.maxAttempts;
    if (max != null && _attempt >= max) return;

    final base = _reconnect.initialDelay.inMilliseconds;
    final mult = _powInt(_reconnect.backoffFactor, _attempt);
    final ms = (base * mult).clamp(0, _reconnect.maxDelay.inMilliseconds);
    _attempt++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: ms.toInt()), () {
      _sub?.cancel();
      _channel?.sink.close();
      _connect();
    });
  }

  /// Sends [data] to the server. Returns [Success] when the data was handed
  /// to the underlying sink, or an [Error] if the channel is not connected.
  Result<void> send(dynamic data) {
    final channel = _channel;
    if (channel == null || _closed) {
      return const Error<void>(
        Failure.network(message: 'WebSocket is not connected'),
      );
    }
    try {
      channel.sink.add(data);
      return const Success<void>(null);
    } catch (e, st) {
      return Error<void>(
        Failure.network(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }

  /// Closes the channel and stops reconnect attempts. Safe to call multiple
  /// times.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    await _controller.close();
  }

  static double _powInt(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}
