import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../services/logging_service.dart';
import 'iot_manager.dart';

class WebSocketClient {
  final String serverUrl;
  final String channel;
  final LoggingService loggingService;
  final String identifier;

  WebSocket? _webSocket;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _lastMessageId = 0;
  Timer? _reconnectTimer;

  WebSocketClient({
    required this.serverUrl,
    required this.channel,
    required this.loggingService,
    required this.identifier,
  });

  /// Derives ws/wss URL from HTTP/HTTPS database URL
  String get _websocketUrl {
    final uri = Uri.parse(serverUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.authority}/websocket';
  }

  /// Starts the WebSocket client connection loop
  void start() {
    _shouldReconnect = true;
    _connect();
  }

  /// Stops and closes the WebSocket connection
  Future<void> stop() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_webSocket != null) {
      await _webSocket!.close();
      _webSocket = null;
    }
    loggingService.info('WebSocket client stopped.');
  }

  Future<void> _connect() async {
    if (_isConnecting || _webSocket != null) return;
    _isConnecting = true;

    final wsUrl = _websocketUrl;
    loggingService.info('Connecting to Odoo WebSocket at $wsUrl');

    try {
      _webSocket = await WebSocket.connect(
        wsUrl,
        headers: {
          'User-Agent': 'OdooIoTBox/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      loggingService.info('WebSocket connection established.');
      _isConnecting = false;

      // Subscribe to IoT Box channel
      _subscribe();

      _webSocket!.listen(
        (data) {
          _onMessage(data);
        },
        onError: (err) {
          loggingService.error('WebSocket encountered an error: $err');
          _handleDisconnection();
        },
        onDone: () {
          loggingService.info('WebSocket connection closed.');
          _handleDisconnection();
        },
        cancelOnError: true,
      );
    } catch (e) {
      loggingService.error('Failed to connect to WebSocket: $e');
      _isConnecting = false;
      _handleDisconnection();
    }
  }

  void _subscribe() {
    if (_webSocket == null) return;

    final subscriptionMessage = {
      'event_name': 'subscribe',
      'data': {
        'channels': [channel],
        'last': _lastMessageId,
        'identifier': identifier,
      }
    };

    _webSocket!.add(jsonEncode(subscriptionMessage));
    loggingService.info('Sent subscription payload for channel $channel');
  }

  void _onMessage(dynamic rawData) {
    try {
      final String text = rawData is String ? rawData : utf8.decode(rawData as List<int>);
      final messages = jsonDecode(text);

      if (messages is! List) return;

      for (var message in messages) {
        if (message is! Map) continue;

        _lastMessageId = message['id'] ?? _lastMessageId;
        final payload = message['message']?['payload'] ?? {};
        final messageType = message['message']?['type'];

        loggingService.info('WebSocket received message of type: $messageType');

        final iotIdentifiers = List<String>.from(payload['iot_identifiers'] ?? []);
        if (!iotIdentifiers.contains(identifier)) {
          continue;
        }

        switch (messageType) {
          case 'iot_action':
            final deviceIdentifiers = List<String>.from(payload['device_identifiers'] ?? []);
            for (final devId in deviceIdentifiers) {
              final device = IoTManager.instance.iotDevices[devId];
              if (device != null) {
                loggingService.info('Executing action on device: $devId');
                final actionPayload = Map<String, dynamic>.from(payload);
                device.action(actionPayload);
              } else {
                loggingService.warning('Device not found for action: $devId');
                // Notify controller that device is disconnected
                _sendToController({
                  'session_id': payload['session_id'] ?? '0',
                  'iot_box_identifier': identifier,
                  'device_identifier': devId,
                  'status': 'disconnected',
                });
              }
            }
            break;
          case 'restart_odoo':
            loggingService.info('Received restart command from Odoo database.');
            _sendToController({
              'session_id': payload['session_id'],
              'iot_box_identifier': identifier,
              'device_identifier': identifier,
              'status': 'success',
            });
            stop();
            break;
          default:
            loggingService.info('Unhandled WebSocket message type: $messageType');
            break;
        }
      }
    } catch (e) {
      loggingService.error('Error parsing WebSocket message payload: $e');
    }
  }

  void _handleDisconnection() {
    _webSocket = null;
    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 10), () {
        loggingService.info('Attempting to reconnect WebSocket...');
        _connect();
      });
    }
  }

  Future<void> _sendToController(Map<String, dynamic> params, {String method = 'send_websocket'}) async {
    final requestPath = '$serverUrl/iot/box/$method';
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(requestPath));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'params': params}));
      final response = await request.close();
      await response.drain();
    } catch (e) {
      loggingService.error('Could not send response to controller: $requestPath, error: $e');
    }
  }
}
