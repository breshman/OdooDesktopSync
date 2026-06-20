import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../iot_interface.dart';
import '../iot_manager.dart';

class PrinterInterface extends IoTInterface {
  PrinterInterface({bool allowUnsupported = false})
      : super(
          connectionType: 'printer',
          loopDelay: 20, // Scan every 20 seconds
          allowUnsupported: allowUnsupported,
        );

  @override
  Future<Map<String, dynamic>> getDevices() async {
    final Map<String, dynamic> devices = {};

    if (!Platform.isWindows) {
      // Fallback fallback mock printer for non-Windows platforms (e.g. development)
      devices['System_Virtual_Printer'] = {
        'name': 'System Virtual Printer',
        'port': 'USB001',
      };
      return devices;
    }

    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-Printer | Select-Object Name, PortName | ConvertTo-Json'
      ]);

      if (result.exitCode == 0) {
        final String output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final decoded = jsonDecode(output);
          if (decoded is List) {
            for (var p in decoded) {
              final String? name = p['Name']?.toString();
              final String? port = p['PortName']?.toString();
              if (name != null && name.isNotEmpty) {
                // Filter out virtual printers that trigger dialog prompt boxes
                if (port == 'PORTPROMPT:') continue;
                devices[name] = {
                  'name': name,
                  'port': port ?? 'IOT_DUMMY_PORT',
                };
              }
            }
          } else if (decoded is Map) {
            final String? name = decoded['Name']?.toString();
            final String? port = decoded['PortName']?.toString();
            if (name != null && name.isNotEmpty) {
              if (port != 'PORTPROMPT:') {
                devices[name] = {
                  'name': name,
                  'port': port ?? 'IOT_DUMMY_PORT',
                };
              }
            }
          }
        }
      } else {
        IoTManager.instance.loggingService.error('PowerShell Get-Printer exited with code ${result.exitCode}: ${result.stderr}');
      }
    } catch (e) {
      IoTManager.instance.loggingService.error('Failed to retrieve system printers: $e');
    }

    return devices;
  }
}
