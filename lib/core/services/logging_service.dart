// ignore_for_file: avoid_print
import 'dart:io';
import 'package:path/path.dart' as p;

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  File? _logFile;
  bool _cleanedOldLogs = false;

  Future<File> _getLogFile() async {
    if (_logFile != null) {
      if (!_cleanedOldLogs) {
        _cleanedOldLogs = true;
        cleanOldLogs();
      }
      return _logFile!;
    }

    Directory dataDir;
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        dataDir = Directory(p.join(home, 'Library', 'Application Support', 'odoo_async'));
      } else {
        dataDir = Directory('./data');
      }
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'];
      if (appData != null && appData.isNotEmpty) {
        dataDir = Directory(p.join(appData, 'odoo_async'));
      } else {
        dataDir = Directory('./data');
      }
    } else if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        dataDir = Directory(p.join(xdg, 'odoo_async'));
      } else {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          dataDir = Directory(p.join(home, '.local', 'share', 'odoo_async'));
        } else {
          dataDir = Directory('./data');
        }
      }
    } else {
      dataDir = Directory('./data');
    }

    try {
      if (!dataDir.existsSync()) {
        dataDir.createSync(recursive: true);
      }
    } catch (e) {
      print('Warning: Failed to create log directory: $e');
    }

    _logFile = File(p.join(dataDir.path, 'sync_activity.log'));
    
    if (!_cleanedOldLogs) {
      _cleanedOldLogs = true;
      cleanOldLogs();
    }
    
    return _logFile!;
  }

  /// Escribe un registro de log con marca de tiempo local y nivel de severidad.
  Future<void> log(String message, {String level = 'INFO'}) async {
    try {
      final file = await _getLogFile();

      // Rotar archivo si supera los 2 MB para evitar consumo excesivo de disco
      if (file.existsSync() && file.lengthSync() > 2 * 1024 * 1024) {
        await _rotateLogs(file);
      }

      final timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
      final logLine = '[$timestamp] [$level] $message\n';

      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
      
      // Mantener salida en consola para monitoreo en vivo en desarrollo
      print(logLine.trim());
    } catch (e) {
      print('Error al escribir log en archivo: $e');
    }
  }

  Future<void> info(String message) => log(message, level: 'INFO');
  Future<void> warning(String message) => log(message, level: 'WARNING');
  Future<void> error(String message) => log(message, level: 'ERROR');

  /// Gestiona la rotación de logs manteniendo un historial máximo de 2 respaldos (.log.1 y .log.2)
  Future<void> _rotateLogs(File currentFile) async {
    try {
      final dataDirPath = currentFile.parent.path;

      final backup2 = File(p.join(dataDirPath, 'sync_activity.log.2'));
      if (backup2.existsSync()) {
        await backup2.delete();
      }

      final backup1 = File(p.join(dataDirPath, 'sync_activity.log.1'));
      if (backup1.existsSync()) {
        await backup1.rename(backup2.path);
      }

      await currentFile.rename(backup1.path);
    } catch (e) {
      print('Error al rotar archivos de log: $e');
    }
  }

  /// Recupera los últimos logs en orden cronológico inverso (el más reciente primero)
  Future<List<String>> readLastLogs({int limit = 150}) async {
    try {
      final file = await _getLogFile();
      if (!file.existsSync()) return [];

      final lines = await file.readAsLines();
      if (lines.length <= limit) {
        return lines.reversed.toList();
      }
      return lines.sublist(lines.length - limit).reversed.toList();
    } catch (e) {
      print('Error al leer logs: $e');
      return ['[$DateTime.now()] [ERROR] Error al recuperar logs: $e'];
    }
  }

  /// Limpia/vacía el archivo de logs
  Future<void> clearLogs() async {
    try {
      final file = await _getLogFile();
      if (file.existsSync()) {
        await file.writeAsString('');
      }
    } catch (e) {
      print('Error al limpiar logs: $e');
    }
  }

  /// Elimina automáticamente los archivos de respaldo de log antiguos (más de 5 días de inactividad)
  Future<void> cleanOldLogs() async {
    try {
      if (_logFile == null) return;
      final directory = _logFile!.parent;
      if (!directory.existsSync()) return;

      final now = DateTime.now();
      final files = directory.listSync();

      for (final entity in files) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          // Filtrar por archivos de respaldo de logs (ej. sync_activity.log.1, sync_activity.log.2)
          if (fileName.startsWith('sync_activity.log.') || fileName == 'sync_activity.log') {
            final lastModified = entity.lastModifiedSync();
            final difference = now.difference(lastModified).inDays;
            
            // Si el archivo tiene más de 5 días de antigüedad, eliminarlo
            if (difference >= 5) {
              await entity.delete();
              print('Log antiguo eliminado automáticamente por antigüedad (>= 5 días): $fileName');
            }
          }
        }
      }
    } catch (e) {
      print('Error al limpiar de forma automática los logs antiguos: $e');
    }
  }
}
