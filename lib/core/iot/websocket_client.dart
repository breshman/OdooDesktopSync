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
  String? _activeChannel;

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

    // Retrieve channel dynamically from /iot/setup endpoint
    final dynamicChannel = await _getWebSocketChannel();
    if (dynamicChannel != null) {
      _activeChannel = dynamicChannel;
    } else {
      loggingService.warning('Could not retrieve dynamic channel from server, falling back to constructor channel.');
    }

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

  Future<String?> _getWebSocketChannel() async {
    final requestPath = '$serverUrl/iot/setup';
    try {
      // 1. Get local IP from network interfaces
      String localIp = '127.0.0.1';
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
          localIp = interfaces.first.addresses.first.address;
        }
      } catch (_) {}

      // 2. Build devices list from IoTManager
      final devicesList = <String, Map<String, dynamic>>{};
      
      final activeDevices = IoTManager.instance.iotDevices;
      activeDevices.forEach((key, device) {
        devicesList[key] = {
          'name': device.deviceName,
          'type': device.deviceType,
          'manufacturer': device.deviceManufacturer,
          'connection': device.deviceConnection,
          'subtype': device.deviceSubtype,
        };
      });

      final unsupportedDevices = IoTManager.instance.unsupportedDevices;
      unsupportedDevices.forEach((key, val) {
        devicesList[key] = val;
      });

      final iotBox = {
        'identifier': identifier,
        'mac': '00:1A:2B:3C:4D:5E', // Use same stable MAC as on the dashboard screen
        'ip': localIp,
        'token': '',
        'version': 'v26.05.30',
        'l10n_eg_proxy_token': '',
      };

      final payload = {
        'params': {
          'iot_box': iotBox,
          'devices': devicesList,
        }
      };

      loggingService.info('Registering IoT box and devices at $requestPath');
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(requestPath)).timeout(const Duration(seconds: 5));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(responseBody);
        if (data.containsKey('result')) {
          final resultChannel = data['result']?.toString();
          if (resultChannel != null && resultChannel.isNotEmpty) {
            loggingService.info('Obtained WebSocket channel from server: $resultChannel');
            return resultChannel;
          }
        }
      } else {
        loggingService.warning('Failed to register IoT Box: HTTP ${response.statusCode}');
      }
    } catch (e) {
      loggingService.error('Error fetching WebSocket channel from /iot/setup: $e');
    }
    return null;
  }

  void _subscribe() {
    if (_webSocket == null) return;

    final activeChannel = _activeChannel ?? channel;
    final subscriptionMessage = {
      'event_name': 'subscribe',
      'data': {
        'channels': [activeChannel],
        'last': _lastMessageId,
        'identifier': identifier,
      }
    };

    _webSocket!.add(jsonEncode(subscriptionMessage));
    loggingService.info('Sent subscription payload for channel $activeChannel');
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
