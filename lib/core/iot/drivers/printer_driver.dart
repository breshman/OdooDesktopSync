import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../iot_driver.dart';
import '../iot_manager.dart';

class PrinterDriver extends IoTDriver {
  late final String receiptProtocol;
  @override
  late final String deviceSubtype;

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

    final idUpper = identifier.toUpperCase();
    final nameUpper = deviceName.toUpperCase();

    // Protocol detection
    if (idUpper.contains('STAR') || nameUpper.contains('STAR') || idUpper.contains('STR_T')) {
      receiptProtocol = 'star';
    } else {
      receiptProtocol = 'escpos';
    }

    // Subtype detection
    if (idUpper.contains('STAR') || nameUpper.contains('STAR') ||
        idUpper.contains('RECEIPT') || nameUpper.contains('RECEIPT') ||
        idUpper.contains('ESCPOS') || nameUpper.contains('ESCPOS') ||
        idUpper.contains('EPSON') || nameUpper.contains('EPSON') ||
        idUpper.contains('TM-') || nameUpper.contains('TM-')) {
      deviceSubtype = 'receipt_printer';
    } else if (idUpper.contains('ZPL') || nameUpper.contains('ZPL') ||
        idUpper.contains('LABEL') || nameUpper.contains('LABEL')) {
      deviceSubtype = 'label_printer';
    } else {
      deviceSubtype = 'office_printer';
    }
  }

  static void register() {
    IoTManager.registerDriver(
      factory: (identifier, device) => PrinterDriver(identifier, device),
      connectionType: 'printer',
      priority: 0,
      supported: (device) => device is Map && device.containsKey('name'),
    );
  }

  /// Ensures that the PowerShell printing helper script exists in the system temporary directory.
  /// 
  /// ### Rationale & Platform Channels comparison:
  /// This script utilizes PowerShell and dynamically compiled C# code via .NET reflection
  /// to access low-level Windows Spooler APIs (`winspool.drv` like `OpenPrinter`, `WritePrinter`).
  /// 
  /// **Why not use Flutter Platform Channels?**
  /// 1. **Decoupled Architecture**: It keeps the IoT Box printer driver self-contained inside
  ///    the Dart library `lib/core/iot/drivers/`, without coupling it to the native C++ code
  ///    in the `windows/` directory of the Flutter runner project.
  /// 2. **Dynamic .NET Compilation**: C# compiles on the fly and offers simple access to
  ///    `System.Drawing.Bitmap` (pre-installed on Windows), which allows easy grayscale,
  ///    pixel thresholding, and bitmap formatting for receipt printers. Doing this in C++ via
  ///    WIC (Windows Imaging Component) or GDI+ would require complex, verbose code and external linking.
  /// 
  /// Yes, this can be migrated to a Flutter Platform/Method Channel (using C++ on the runner)
  /// if a fully native C++ compiler flow without shell invocations is preferred.
  static Future<String> _ensureHelperScript() async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/windows_printer_helper.ps1');
    
    // Read the helper script from the asset bundle instead of keeping it in a Dart string.
    final scriptContent = await rootBundle.loadString('lib/core/iot/drivers/windows_printer_helper.ps1');
    await file.writeAsString(scriptContent);
    return file.path;
  }

  /// Platform-agnostic helper to execute a print job.
  /// Uses PowerShell on Windows (RAW spooling and image rasterization helper),
  /// and standard CUPS command-line 'lp' on macOS/Linux.
  static Future<bool> _printHelper({
    required String printerName,
    required String filePath,
    required String action, // 'raw', 'image', or 'pdf'
    required String protocol,
  }) async {
    if (Platform.isWindows) {
      try {
        final scriptPath = await _ensureHelperScript();
        final result = await Process.run('powershell', [
          '-ExecutionPolicy', 'Bypass',
          '-File', scriptPath,
          '-Action', action,
          '-PrinterName', printerName,
          '-FilePath', filePath,
          '-Protocol', protocol,
        ]);
        return result.stdout.toString().trim().toLowerCase() == 'true';
      } catch (e) {
        IoTManager.instance.loggingService.error('Error running Windows printer helper: $e');
        return false;
      }
    } else {
      // macOS / Linux integration using CUPS CLI tool 'lp'
      try {
        final List<String> args = [];
        if (action == 'raw') {
          // Send raw bytes directly bypassing CUPS filter translation (comparable to Python print_raw)
          args.addAll(['-d', printerName, '-o', 'raw', filePath]);
        } else {
          // Standard printing for image/PDF using local CUPS drivers
          args.addAll(['-d', printerName, filePath]);
        }
        final result = await Process.run('lp', args);
        return result.exitCode == 0;
      } catch (e) {
        IoTManager.instance.loggingService.error('Error running lp Unix printer command: $e');
        return false;
      }
    }
  }

  @override
  Future<void> run() async {
    IoTManager.instance.loggingService.info('Printer driver started for: $deviceName (Protocol: $receiptProtocol, Subtype: $deviceSubtype)');
  }

  @override
  Future<dynamic> executeAction(String actionName, Map<String, dynamic> actionData) async {
    IoTManager.instance.loggingService.info('Executing printer action: $actionName on $deviceName');

    switch (actionName) {
      case 'print_receipt':
        final receiptBase64 = actionData['receipt'] ?? actionData['params']?['receipt'];
        if (receiptBase64 == null) {
          return {'status': 'error', 'message': 'No receipt data provided.'};
        }
        
        try {
          List<int> receiptBytes;
          bool isImage = true;
          
          try {
            var cleaned = receiptBase64.trim();
            if (cleaned.startsWith('data:image')) {
              cleaned = cleaned.substring(cleaned.indexOf(',') + 1);
            }
            receiptBytes = base64Decode(cleaned);
          } catch (_) {
            isImage = false;
            receiptBytes = utf8.encode(receiptBase64);
          }

          final tempDir = Directory.systemTemp;
          final fileExtension = isImage ? 'png' : 'txt';
          final tempFile = File('${tempDir.path}/temp_receipt_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
          await tempFile.writeAsBytes(receiptBytes);

          final success = await _printHelper(
            printerName: deviceName,
            filePath: tempFile.path,
            action: isImage ? 'image' : 'raw',
            protocol: receiptProtocol,
          );

          try {
            await tempFile.delete();
          } catch (_) {}

          if (success) {
            return {'status': 'success', 'message': 'Receipt printed successfully.'};
          } else {
            return {'status': 'error', 'message': 'Failed to print receipt.'};
          }
        } catch (e) {
          IoTManager.instance.loggingService.error('Error printing receipt: $e');
          return {'status': 'error', 'message': e.toString()};
        }

      case 'print_xml_receipt':
        final receipt = actionData['receipt'] ?? actionData['params']?['receipt'] ?? '';
        if (receipt.isEmpty) {
          return {'status': 'error', 'message': 'Empty receipt.'};
        }
        try {
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/temp_xml_receipt_${DateTime.now().millisecondsSinceEpoch}.txt');
          await tempFile.writeAsString(receipt);

          final success = await _printHelper(
            printerName: deviceName,
            filePath: tempFile.path,
            action: 'raw',
            protocol: receiptProtocol,
          );

          try {
            await tempFile.delete();
          } catch (_) {}

          if (success) {
            return {'status': 'success', 'message': 'XML/Text receipt printed.'};
          } else {
            return {'status': 'error', 'message': 'Failed to print XML/Text receipt.'};
          }
        } catch (e) {
          IoTManager.instance.loggingService.error('Error printing XML/Text receipt: $e');
          return {'status': 'error', 'message': e.toString()};
        }

      case 'cashbox':
        try {
          final List<int> drawerCmds = [];
          if (receiptProtocol == 'star') {
            drawerCmds.addAll([0x07, 0x1A]);
          } else {
            drawerCmds.addAll([0x1B, 0x3D, 0x01, 0x1B, 0x70, 0x00, 0x19, 0x19, 0x1B, 0x70, 0x01, 0x19, 0x19]);
          }

          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/temp_cashbox_${DateTime.now().millisecondsSinceEpoch}.bin');
          await tempFile.writeAsBytes(drawerCmds);

          final success = await _printHelper(
            printerName: deviceName,
            filePath: tempFile.path,
            action: 'raw',
            protocol: receiptProtocol,
          );

          try {
            await tempFile.delete();
          } catch (_) {}

          if (success) {
            return {'status': 'success', 'message': 'Cashbox triggered successfully.'};
          } else {
            return {'status': 'error', 'message': 'Failed to send cashbox open command.'};
          }
        } catch (e) {
          IoTManager.instance.loggingService.error('Error opening cashbox: $e');
          return {'status': 'error', 'message': e.toString()};
        }

      case 'status':
        try {
          final List<int> statusCmds = [];
          if (deviceSubtype == 'receipt_printer') {
            if (receiptProtocol == 'star') {
              statusCmds.addAll([0x1B, 0x1D, 0x61, 0x01]); // center
              statusCmds.addAll([0x1B, 0x69, 0x01, 0x01]); // title size
              statusCmds.addAll('IoT Box Test Receipt\n'.codeUnits);
              statusCmds.addAll([0x1B, 0x69, 0x00, 0x00]); // normal size
              statusCmds.addAll([0x1B, 0x64, 0x02]); // cut
            } else {
              statusCmds.addAll([0x1B, 0x61, 0x01]); // center
              statusCmds.addAll([0x1B, 0x21, 0x30]); // title size
              statusCmds.addAll('IoT Box Test Receipt\n'.codeUnits);
              statusCmds.addAll([0x1B, 0x21, 0x00]); // normal size
              statusCmds.addAll([0x1D, 0x56, 0x41, 0x0A]); // cut
            }
          } else if (deviceSubtype == 'label_printer') {
            statusCmds.addAll('^XA^CI28 ^FT35,40 ^A0N,30 ^FDIoT Box Test Label^FS^XZ'.codeUnits);
          } else {
            statusCmds.addAll('IoT Box Test Page\r\n'.codeUnits);
          }

          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/temp_status_${DateTime.now().millisecondsSinceEpoch}.bin');
          await tempFile.writeAsBytes(statusCmds);

          final success = await _printHelper(
            printerName: deviceName,
            filePath: tempFile.path,
            action: 'raw',
            protocol: receiptProtocol,
          );

          try {
            await tempFile.delete();
          } catch (_) {}

          if (success) {
            return {'status': 'success', 'message': 'Status ticket printed.'};
          } else {
            return {'status': 'error', 'message': 'Failed to print status ticket.'};
          }
        } catch (e) {
          IoTManager.instance.loggingService.error('Error printing status ticket: $e');
          return {'status': 'error', 'message': e.toString()};
        }

      case '':
      default:
        // Default action handler (e.g. printing a PDF document or raw report)
        final documentBase64 = actionData['document'] ?? actionData['params']?['document'];
        if (documentBase64 != null) {
          try {
            final documentBytes = base64Decode(documentBase64);
            final isPdf = documentBytes.length >= 4 &&
                documentBytes[0] == 0x25 && // %
                documentBytes[1] == 0x50 && // P
                documentBytes[2] == 0x44 && // D
                documentBytes[3] == 0x46;   // F

            final tempDir = Directory.systemTemp;
            final fileExtension = isPdf ? 'pdf' : 'bin';
            final tempFile = File('${tempDir.path}/temp_doc_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
            await tempFile.writeAsBytes(documentBytes);

            final success = await _printHelper(
              printerName: deviceName,
              filePath: tempFile.path,
              action: isPdf ? 'pdf' : 'raw',
              protocol: receiptProtocol,
            );

            try {
              await tempFile.delete();
            } catch (_) {}

            final printId = actionData['print_id'] ?? actionData['params']?['print_id'];
            if (success) {
              return {
                'status': 'success',
                // ignore: use_null_aware_elements
                if (printId != null) 'print_id': printId,
              };
            } else {
              return {
                'status': 'error',
                'message': 'Failed to spool document.',
                // ignore: use_null_aware_elements
                if (printId != null) 'print_id': printId,
              };
            }
          } catch (e) {
            IoTManager.instance.loggingService.error('Error handling default print action: $e');
            return {'status': 'error', 'message': e.toString()};
          }
        }

        IoTManager.instance.loggingService.warning('Unsupported action $actionName for PrinterDriver');
        throw UnimplementedError('Action $actionName not implemented');
    }
  }
}

