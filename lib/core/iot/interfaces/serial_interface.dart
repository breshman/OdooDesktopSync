import 'dart:async';
import 'dart:io';
import '../iot_interface.dart';
import '../iot_manager.dart';

class SerialInterface extends IoTInterface {
  SerialInterface({bool allowUnsupported = true})
      : super(
          connectionType: 'serial',
          loopDelay: 15, // Scan every 15 seconds
          allowUnsupported: allowUnsupported,
        );

  @override
  Future<Map<String, dynamic>> getDevices() async {
    final Map<String, dynamic> devices = {};

    if (!Platform.isWindows) {
      // Fallback mock serial ports for non-Windows platforms
      devices['COM_MOCK_1'] = {
        'device': 'COM_MOCK_1',
      };
      return devices;
    }

    try {
      final result = await Process.run('powershell', [
        '-Command',
        '[System.IO.Ports.SerialPort]::GetPortNames()'
      ]);

      if (result.exitCode == 0) {
        final String output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final lines = output.split(RegExp(r'\r?\n'));
          for (final line in lines) {
            final port = line.trim();
            if (port.isNotEmpty) {
              devices[port] = {
                'device': port,
              };
            }
          }
        }
      } else {
        IoTManager.instance.loggingService.error('PowerShell GetPortNames exited with code ${result.exitCode}: ${result.stderr}');
      }
    } catch (e) {
      IoTManager.instance.loggingService.error('Failed to retrieve system serial ports: $e');
    }

    return devices;
  }
}
