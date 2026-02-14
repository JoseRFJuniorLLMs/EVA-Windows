import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'backend_selector_windows.dart';

class WebSocketService {
  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String? _lastUrl;
  
  final _textController = StreamController<String>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();

  Stream<String> get textStream => _textController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect([String? url]) async {
    final targetUrl = url ?? BackendSelectorWindows.wsBaseUrl;
    _lastUrl = targetUrl;
    
    try {
      _logger.i('🔌 Connecting to WebSocket: $targetUrl');
      _channel = WebSocketChannel.connect(Uri.parse(targetUrl));

      _channel!.stream.listen(
        (message) {
          _reconnectTimer?.cancel();
          if (message is String) {
            _textController.add(message);
          } else if (message is List<int>) {
            _audioController.add(Uint8List.fromList(message));
          }
        },
        onError: (error) {
          _logger.e('WS Error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          _logger.w('WS Disconnected');
          _channel = null;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _logger.e('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!isConnected && _lastUrl != null) {
        _logger.i('♻️ Attempting to reconnect...');
        connect(_lastUrl);
      }
    });
  }

  void sendText(String text) {
    if (isConnected) {
      _channel!.sink.add(text);
    }
  }

  void sendBinary(Uint8List data) {
    if (isConnected) {
      _channel!.sink.add(data);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
