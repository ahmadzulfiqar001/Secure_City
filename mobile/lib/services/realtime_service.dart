import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'secure_storage_service.dart';

/// One event off the gateway — mirrors the envelope documented in
/// backend/docs/websocket_protocol.md: `{"event": ..., "data": ..., "ts": ...}`.
class RealtimeEvent {
  final String event;
  final Map<String, dynamic> data;
  const RealtimeEvent(this.event, this.data);
}

const _maxBackoffSeconds = 30;

/// The single WebSocket gateway client (`/ws?token=`), implementing
/// backend/docs/websocket_protocol.md exactly: JSON envelope, ping/pong
/// heartbeat reply, and exponential-backoff reconnect (1s base, doubling,
/// capped at 30s, reset on a successful connect). A `4401` close means the
/// access token was rejected — refresh it once before the next attempt
/// rather than backing off on a token that will never work.
class RealtimeService {
  final _eventController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventController.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _disposed = false;
  bool _wantsConnection = false;

  void connect() {
    _wantsConnection = true;
    _open();
  }

  void disconnect() {
    _wantsConnection = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _eventController.close();
  }

  Future<void> _open() async {
    if (_disposed || !_wantsConnection) return;

    final token = await SecureStorageService.getAccessToken();
    if (token == null) {
      // No session yet — nothing to connect with. A caller reconnects once
      // one exists (RealtimeService is only started post-login anyway).
      return;
    }

    final wsBase = backendBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws?token=$token'));
    _channel = channel;

    try {
      await channel.ready;
    } catch (_) {
      await _handleClose(channel);
      return;
    }

    if (!_wantsConnection || _disposed) {
      channel.sink.close();
      return;
    }

    _attempt = 0; // reset backoff on a successful connect, per the protocol doc
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (_) => _handleClose(channel),
      onDone: () => _handleClose(channel),
      cancelOnError: true,
    );
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = json['event'] as String?;
      if (event == null) return;

      if (event == 'ping') {
        _channel?.sink.add(jsonEncode({'event': 'pong'}));
        return;
      }

      final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      _eventController.add(RealtimeEvent(event, data));
    } catch (_) {
      // malformed frame; ignore rather than crash the feed
    }
  }

  Future<void> _handleClose(WebSocketChannel channel) async {
    if (_channel != channel) return; // a newer connection already replaced this one
    _subscription?.cancel();
    if (!_wantsConnection || _disposed) return;

    final closeCode = channel.closeCode;
    if (closeCode == 4401) {
      // The access token was rejected outright — refresh before retrying
      // rather than backing off on a token that will never work.
      await ApiClient.instance.refreshAccessToken();
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final delaySeconds = _attempt >= 5 ? _maxBackoffSeconds : (1 << _attempt);
    _attempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _open);
  }
}
