import 'dart:async';
import 'iot_manager.dart';

abstract class IoTDriver {
  final String identifier;
  final dynamic device;
  final String connectionType;
  final int priority;

  String deviceName = '';
  String deviceConnection = '';
  String deviceType = '';
  String deviceManufacturer = '';

  /// Device subtype, mainly used for printers ('receipt_printer', 'label_printer', 'office_printer').
  String get deviceSubtype => '';

  Map<String, dynamic> data = {'value': '', 'result': ''};
  bool isStopped = false;

  IoTDriver({
    required this.identifier,
    required this.device,
    required this.connectionType,
    required this.priority,
  });

  /// Abstract method to be implemented by subclass to perform driver loops or polling.
  Future<void> run();

  /// Starts driver execution asynchronously.
  Future<void> start() async {
    isStopped = false;
    scheduleMicrotask(() async {
      try {
        await run();
      } catch (e, stack) {
        print('Error running driver $identifier ($deviceType): $e');
        print(stack);
      }
    });
  }

  /// Handles incoming actions/commands sent from Odoo.
  Future<Map<String, dynamic>> action(Map<String, dynamic> actionData) async {
    final String actionName = actionData['action'] ?? '';
    final String? sessionId = actionData['session_id'];

    if (sessionId != null) {
      data['owner'] = sessionId;
      data['session_id'] = sessionId;
    }

    final baseResponse = {
      'action_args': actionData,
      'session_id': sessionId,
    };

    try {
      final result = await executeAction(actionName, actionData);
      final response = {
        'status': 'success',
        'result': result,
        ...baseResponse,
      };

      // Printers and payment terminals handle their own events. Other device types broadcast.
      if (deviceType != 'printer' && deviceType != 'payment') {
        IoTManager.instance.triggerDeviceEvent(identifier, response);
      }
      return response;
    } catch (e) {
      final response = {
        'status': 'error',
        'result': e.toString(),
        ...baseResponse,
      };
      return response;
    }
  }

  /// Abstract helper for subclasses to implement specific hardware commands.
  Future<dynamic> executeAction(String actionName, Map<String, dynamic> actionData);

  /// Disconnects the driver and releases hardware resources.
  Future<void> disconnect() async {
    isStopped = true;
  }
}
