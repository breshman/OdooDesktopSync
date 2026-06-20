import 'dart:async';
import 'iot_manager.dart';

abstract class IoTInterface {
  final int loopDelay; // seconds between scans (0 to scan only once)
  final String connectionType;
  final bool allowUnsupported;

  final Set<String> _detectedDevices = {};
  bool _isRunning = false;
  Timer? _loopTimer;

  IoTInterface({
    required this.connectionType,
    this.loopDelay = 3,
    this.allowUnsupported = false,
  });

  /// Abstract method to scan and list currently connected devices.
  /// Returns a map of { identifier: device_object }
  Future<Map<String, dynamic>> getDevices();

  /// Starts the scanning loop.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    if (loopDelay == 0) {
      await _scanOnce();
    } else {
      _loopTimer = Timer.periodic(Duration(seconds: loopDelay), (timer) async {
        if (!_isRunning) {
          timer.cancel();
          return;
        }
        await _scanOnce();
      });
      // Initial scan
      scheduleMicrotask(() => _scanOnce());
    }
  }

  Future<void> _scanOnce() async {
    try {
      final devices = await getDevices();
      await updateIoTDevices(devices);
    } catch (e) {
      IoTManager.instance.loggingService.error('Error during IoT scan on interface $connectionType: $e');
    }
  }

  /// Stops the interface and disconnects its scanned devices.
  Future<void> stop() async {
    _isRunning = false;
    _loopTimer?.cancel();
    _loopTimer = null;

    final toRemove = List<String>.from(_detectedDevices);
    for (final id in toRemove) {
      await removeDevice(id);
    }
    _detectedDevices.clear();
  }

  Future<void> addDevice(String identifier, dynamic device) async {
    if (IoTManager.instance.iotDevices.containsKey(identifier)) {
      return;
    }

    final entry = IoTManager.instance.findCompatibleDriver(connectionType, device);
    if (entry != null) {
      IoTManager.instance.loggingService.info('Device $identifier is now connected (Driver connection: ${entry.connectionType})');

      final driver = entry.factory(identifier, device);
      IoTManager.instance.iotDevices[identifier] = driver;

      if (IoTManager.instance.unsupportedDevices.containsKey(identifier)) {
        IoTManager.instance.unsupportedDevices.remove(identifier);
      }

      await driver.start();
      IoTManager.instance.notifyStateChanged();
    } else if (allowUnsupported && !IoTManager.instance.unsupportedDevices.containsKey(identifier)) {
      IoTManager.instance.loggingService.info('Unsupported device $identifier is now connected');
      IoTManager.instance.unsupportedDevices[identifier] = {
        'name': 'Unknown device ($connectionType)',
        'identifier': identifier,
        'type': 'unsupported',
        'connection': connectionType == 'usb' ? 'direct' : connectionType,
      };
      IoTManager.instance.notifyStateChanged();
    }
  }

  Future<void> removeDevice(String identifier) async {
    if (IoTManager.instance.iotDevices.containsKey(identifier)) {
      final driver = IoTManager.instance.iotDevices.remove(identifier);
      if (driver != null) {
        await driver.disconnect();
        IoTManager.instance.loggingService.info('Device $identifier is now disconnected');
      }
      IoTManager.instance.notifyStateChanged();
    } else if (allowUnsupported && IoTManager.instance.unsupportedDevices.containsKey(identifier)) {
      IoTManager.instance.unsupportedDevices.remove(identifier);
      IoTManager.instance.loggingService.info('Unsupported device $identifier is now disconnected');
      IoTManager.instance.notifyStateChanged();
    }
  }

  Future<void> updateIoTDevices(Map<String, dynamic> devices) async {
    final currentKeys = devices.keys.toSet();

    final added = currentKeys.difference(_detectedDevices);
    final removed = _detectedDevices.difference(currentKeys);

    final unsupportedKeys = IoTManager.instance.unsupportedDevices.keys.toSet();
    final unsupported = unsupportedKeys.intersection(currentKeys);

    _detectedDevices.clear();
    _detectedDevices.addAll(currentKeys);

    for (final identifier in removed) {
      await removeDevice(identifier);
    }

    for (final identifier in added.union(unsupported)) {
      await addDevice(identifier, devices[identifier]);
    }
  }
}
