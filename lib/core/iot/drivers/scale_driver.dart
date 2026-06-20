import 'dart:async';
import 'dart:math';
import '../iot_driver.dart';
import '../iot_manager.dart';

class ScaleDriver extends IoTDriver {
  double _currentWeight = 0.0;
  Timer? _pollingTimer;
  final _random = Random();

  ScaleDriver(String identifier, dynamic device)
      : super(
          identifier: identifier,
          device: device,
          connectionType: 'serial',
          priority: 1,
        ) {
    deviceName = 'Weight Scale ($identifier)';
    deviceConnection = 'serial';
    deviceType = 'scale';
    deviceManufacturer = 'Odoo Scale Simulator';
    data = {'value': 0.0, 'status': 'stable'};
  }

  static void register() {
    IoTManager.registerDriver(
      factory: (identifier, device) => ScaleDriver(identifier, device),
      connectionType: 'serial',
      priority: 1,
      supported: (device) => device is Map && device.containsKey('device'),
    );
  }

  /// Sets simulated weight from the UI.
  void setSimulatedWeight(double weight) {
    _currentWeight = weight;
    data = {'value': _currentWeight, 'status': 'stable'};
    // Notify Odoo server / long-polling client of weight change event
    IoTManager.instance.triggerDeviceEvent(identifier, {
      'status': 'success',
      'result': data,
    });
  }

  @override
  Future<void> run() async {
    IoTManager.instance.loggingService.info('Scale driver active on serial port: $identifier');
    
    // Simulate weight changes periodically for testing
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (isStopped) {
        timer.cancel();
        return;
      }
      
      // If weight is above zero, simulate small scale fluctuations (stable scale noise)
      if (_currentWeight > 0) {
        final double noise = (_random.nextDouble() - 0.5) * 0.010; // +/- 10g fluctuation
        final double finalWeight = max(0.0, double.parse((_currentWeight + noise).toStringAsFixed(3)));
        data = {'value': finalWeight, 'status': 'stable'};
        
        IoTManager.instance.triggerDeviceEvent(identifier, {
          'status': 'success',
          'result': data,
        });
      }
    });
  }

  @override
  Future<dynamic> executeAction(String actionName, Map<String, dynamic> actionData) async {
    IoTManager.instance.loggingService.info('Scale action: $actionName');
    
    switch (actionName) {
      case 'read_once':
        return data;
      case 'zero':
        setSimulatedWeight(0.0);
        return data;
      default:
        IoTManager.instance.loggingService.warning('Unsupported scale action: $actionName');
        throw UnimplementedError('Scale action $actionName not implemented');
    }
  }

  @override
  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    await super.disconnect();
  }
}
