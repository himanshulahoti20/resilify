// Example: a reconnecting WebSocket emitting parsed `Result<T>` events.
//
// Run with: `dart run example/websocket_example.dart`

import 'dart:convert';

import 'package:resilify/resilify_websocket.dart';

class Tick {
  const Tick({required this.symbol, required this.price});

  factory Tick.fromJson(Map<String, dynamic> json) => Tick(
        symbol: json['symbol'] as String,
        price: (json['price'] as num).toDouble(),
      );

  final String symbol;
  final double price;
}

Future<void> main() async {
  final ws = WebSocketResultHandler<Tick>(
    channelFactory: () =>
        WebSocketChannel.connect(Uri.parse('wss://example.com/ticks')),
    parser: (raw) =>
        Tick.fromJson(jsonDecode(raw as String) as Map<String, dynamic>),
    reconnect: const ReconnectConfig(
      initialDelay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 30),
      backoffFactor: 2,
    ),
  );

  final sub = ws.stream.listen((result) {
    result.when(
      success: (tick) => print('${tick.symbol}: \$${tick.price}'),
      error: (failure) => print('ws error: ${failure.message}'),
    );
  });

  // Subscribe to a symbol.
  final sendResult = ws.send(jsonEncode({'subscribe': 'AAPL'}));
  sendResult.onError((f) => print('send failed: ${f.message}'));

  // Run for 30 seconds in this demo.
  await Future<void>.delayed(const Duration(seconds: 30));
  await sub.cancel();
  await ws.close();
}
