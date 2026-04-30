/// Opt-in `package:web_socket_channel` integration for `resilify`.
///
/// Re-exports [WebSocketChannel] so callers don't need a second import for
/// the channel factory.
library;

export 'package:web_socket_channel/web_socket_channel.dart'
    show WebSocketChannel;

export 'resilify.dart';
export 'src/integrations/websocket_result.dart';
