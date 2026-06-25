import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class SocketService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static final Map<String, StreamController<Map<String, dynamic>>> _listeners = {};
  static bool _shouldReconnect = true;
  static bool _isConnecting = false;
  static int _reconnectDelay = 1;
  static Timer? _reconnectTimer;
  static StreamSubscription? _connectivitySub;
  static bool _lastConnected = false;

  static void connect() {
    if (_channel != null || _isConnecting) return;

    final token = ApiService.token;
    if (token == null) return;

    _isConnecting = true;
    final wsUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsUrl/ws?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _shouldReconnect = true;

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data.toString());
            if (decoded is Map<String, dynamic>) {
              final event = decoded['event'] as String?;
              final eventData = decoded['data'];
              if (event != null) {
                _emit(event, eventData);
              }
            }
          } catch (_) {}
        },
        onDone: () {
          _isConnecting = false;
          _cleanup();
          _scheduleReconnect();
        },
        onError: (err) {
          _isConnecting = false;
          _cleanup();
          _scheduleReconnect();
        },
      );
      _isConnecting = false;
      _reconnectDelay = 1;
    } catch (_) {
      _isConnecting = false;
      _cleanup();
      _scheduleReconnect();
    }
  }

  static void _cleanup() {
    try { _subscription?.cancel(); } catch (_) {}
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _subscription = null;
  }

  static void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    final delay = Duration(seconds: _reconnectDelay.clamp(1, 10));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect) {
        _reconnectDelay = (_reconnectDelay * 2).clamp(1, 10);
        connect();
      }
    });
  }

  static void startConnectivityMonitor() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_lastConnected && _channel == null) {
        _reconnectDelay = 1;
        connect();
      }
      _lastConnected = hasConnection;
    });
  }

  static void stopConnectivityMonitor() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  static void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    stopConnectivityMonitor();
    for (final controller in _listeners.values) {
      controller.close();
    }
    _listeners.clear();
  }

  static void joinGroup(String groupId) {
    _send({'type': 'join_group', 'data': {'groupId': groupId}});
  }

  static void leaveGroup(String groupId) {
    _send({'type': 'leave_group', 'data': {'groupId': groupId}});
  }

  static void _send(Map<String, dynamic> message) {
    if (_channel == null) return;
    try { _channel!.sink.add(jsonEncode(message)); } catch (_) {
      _cleanup();
      _scheduleReconnect();
    }
  }

  static Stream<Map<String, dynamic>> on(String event) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _listeners[event]!.stream;
  }

  static void _emit(String event, dynamic data) {
    final controller = _listeners[event];
    if (controller != null && !controller.isClosed) {
      final mapData = data is Map<String, dynamic> ? data : <String, dynamic>{};
      controller.add(mapData);
    }
  }

  static bool get isConnected => _channel != null;
}
