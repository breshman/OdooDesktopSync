import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/database_service.dart';
import '../interfaces/spreadsheet_service.dart';
import '../services/sqlite_database_service.dart';
import '../services/excel_spreadsheet_service.dart';
import '../services/window_tray_service.dart';
import '../../api_server.dart';

/// Proveedor para la abstracción DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return SqliteDatabaseService();
});

/// Proveedor para la abstracción SpreadsheetService
final spreadsheetServiceProvider = Provider<SpreadsheetService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return ExcelSpreadsheetService(dbService);
});

/// Proveedor para el gestor de ventanas nativas y tray
final windowTrayServiceProvider = Provider<WindowTrayService>((ref) {
  return WindowTrayService();
});

/// Proveedor para el servidor HTTP API
final apiServerProvider = Provider<ApiServer>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final excelService = ref.watch(spreadsheetServiceProvider);
  return ApiServer(dbService: dbService, excelService: excelService);
});

/// Estado reactivo para el estado del Servidor (Activo / Inactivo)
enum ServerStatus { active, inactive }

class ServerStatusNotifier extends Notifier<ServerStatus> {
  @override
  ServerStatus build() => ServerStatus.active;

  void setStatus(ServerStatus status) {
    state = status;
  }
}

final serverStatusProvider = NotifierProvider<ServerStatusNotifier, ServerStatus>(() {
  return ServerStatusNotifier();
});
