import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_async/core/iot/iot_driver.dart';
import 'package:odoo_async/core/iot/iot_interface.dart';
import 'package:odoo_async/core/iot/iot_manager.dart';
import 'package:odoo_async/core/services/logging_service.dart';

final testRefProvider = Provider<Ref>((ref) => ref);

class FakeIoTDriver extends IoTDriver {
  bool started = false;

  FakeIoTDriver({
    required super.identifier,
    required super.device,
    required super.connectionType,
    required super.priority,
  });

  @override
  Future<void> run() async {}

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<dynamic> executeAction(
    String actionName,
    Map<String, dynamic> actionData,
  ) async {
    return null;
  }
}

class FakeIoTInterface extends IoTInterface {
  final List<Map<String, dynamic>> _responses;
  int callCount = 0;

  FakeIoTInterface(this._responses, {int loopDelay = 3})
    : super(
        connectionType: 'usb',
        allowUnsupported: true,
        loopDelay: loopDelay,
      );

  @override
  Future<Map<String, dynamic>> getDevices() async {
    callCount++;
    return _responses.isEmpty ? {} : _responses.first;
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    final ref = container.read(testRefProvider);
    IoTManager.instance.init(LoggingService(), ref);
    IoTManager.instance.iotDevices.clear();
    IoTManager.instance.unsupportedDevices.clear();
    IoTManager.instance.interfaces.clear();
    IoTManager.driverRegistry.clear();
  });

  tearDown(() {
    container.dispose();
    IoTManager.instance.iotDevices.clear();
    IoTManager.instance.unsupportedDevices.clear();
    IoTManager.instance.interfaces.clear();
    IoTManager.driverRegistry.clear();
  });

  test(
    'updateIoTDevices adds supported devices and removes stale ones',
    () async {
      IoTManager.registerDriver(
        factory: (identifier, device) => FakeIoTDriver(
          identifier: identifier,
          device: device,
          connectionType: 'usb',
          priority: 1,
        ),
        connectionType: 'usb',
        priority: 1,
        supported: (device) => device is Map && device['kind'] == 'supported',
      );

      final interface = FakeIoTInterface([
        {
          'device-1': {'kind': 'supported'},
          'device-2': {'kind': 'unsupported'},
        },
      ]);

      await interface.updateIoTDevices({
        'device-1': {'kind': 'supported'},
        'device-2': {'kind': 'unsupported'},
      });

      expect(IoTManager.instance.iotDevices.containsKey('device-1'), isTrue);
      expect(
        IoTManager.instance.unsupportedDevices.containsKey('device-2'),
        isTrue,
      );
      expect(
        IoTManager.instance.iotDevices['device-1'] is FakeIoTDriver,
        isTrue,
      );

      await interface.updateIoTDevices({
        'device-1': {'kind': 'supported'},
      });

      expect(
        IoTManager.instance.unsupportedDevices.containsKey('device-2'),
        isFalse,
      );
      expect(IoTManager.instance.iotDevices.containsKey('device-1'), isTrue);
    },
  );

  test('start scans once when loopDelay is 0', () async {
    final interface = FakeIoTInterface([
      {
        'device-1': {'kind': 'supported'},
      },
    ], loopDelay: 0);

    IoTManager.registerDriver(
      factory: (identifier, device) => FakeIoTDriver(
        identifier: identifier,
        device: device,
        connectionType: 'usb',
        priority: 1,
      ),
      connectionType: 'usb',
      priority: 1,
      supported: (device) => device is Map && device['kind'] == 'supported',
    );

    await interface.start();

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(interface.callCount, equals(1));
    expect(IoTManager.instance.iotDevices.containsKey('device-1'), isTrue);
  });
}
