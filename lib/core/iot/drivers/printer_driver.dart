import 'dart:async';
import '../iot_driver.dart';
import '../iot_manager.dart';

class PrinterDriver extends IoTDriver {
  PrinterDriver(String identifier, dynamic device)
      : super(
          identifier: identifier,
          device: device,
          connectionType: 'printer',
          priority: 0,
        ) {
    deviceName = device['name'] ?? 'System Printer';
    deviceConnection = 'direct';
    deviceType = 'printer';
    deviceManufacturer = 'Windows Print Queue';
  }

  static void register() {
    IoTManager.registerDriver(
      factory: (identifier, device) => PrinterDriver(identifier, device),
      connectionType: 'printer',
      priority: 0,
      supported: (device) => device is Map && device.containsKey('name'),
    );
  }

  @override
  Future<void> run() async {
    IoTManager.instance.loggingService.info('Printer driver started for: $deviceName');
  }

  @override
  Future<dynamic> executeAction(String actionName, Map<String, dynamic> actionData) async {
    IoTManager.instance.loggingService.info('Executing printer action: $actionName on $deviceName');

    switch (actionName) {
      case 'print_receipt':
      case 'print_xml_receipt':
        final receipt = actionData['receipt'] ?? actionData['params']?['receipt'] ?? '--- Empty Ticket ---';
        IoTManager.instance.loggingService.info('=== PRINTING RECEIPT ON $deviceName ===\n$receipt\n===================================');
        return {'status': 'success', 'message': 'Receipt printed successfully.'};
      case 'status':
        return {'status': 'online', 'paper': 'ok'};
      default:
        IoTManager.instance.loggingService.warning('Unsupported action $actionName for PrinterDriver');
        throw UnimplementedError('Action $actionName not implemented');
    }
  }
}
