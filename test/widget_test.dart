import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_async/core/services/flat_file_spreadsheet_service.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:odoo_async/core/interfaces/database_service.dart';
import 'package:odoo_async/core/interfaces/spreadsheet_service.dart';
import 'package:odoo_async/core/providers/dependency_providers.dart';
import 'package:odoo_async/core/services/excel_spreadsheet_service.dart';
import 'package:odoo_async/core/services/window_tray_service.dart';
import 'package:odoo_async/core/services/logging_service.dart';
import 'package:odoo_async/api_server.dart';
import 'package:odoo_async/main.dart';

// Mocks livianos para evitar el acceso a archivos de sistema y FFI en ambiente de pruebas
class MockDatabaseService implements DatabaseService {
  @override
  Future<void> init() async {}
  @override
  Future<void> cleanOldCache() async {}
  @override
  Future<Map<String, dynamic>> getConfig() async => {};
  @override
  Future<void> saveApiConfig(String name, String url) async {}
  @override
  Future<void> savePathConfig(String path, bool isActive) async {}
  @override
  Future<Map<String, dynamic>> replaceConfig(
    Map<String, dynamic> newConfig,
  ) async => {};
  @override
  Future<void> saveCacheItems(List<dynamic> cacheItems) async {}
  @override
  Future<String?> getTraceabilityId(String uniqueKey) async => null;
  @override
  String normalizeKey(String key) => key.trim().toUpperCase();
}

class MockSpreadsheetService implements SpreadsheetService {
  @override
  void validatePaths(List<String> paths) {}
  @override
  Future<List<Map<String, String>>> processAllFiles(
    List<String> listPaths, {
    String? separator,
  }) async => [];
  @override
  Future<List<Map<String, String>>> processAndGroupItems(
    List<Map<String, String>> allItems,
  ) async => [];
}

class MockApiServer implements ApiServer {
  @override
  final DatabaseService dbService = MockDatabaseService();
  @override
  final SpreadsheetService excelService = MockSpreadsheetService();
  @override
  final SpreadsheetService flatFileService = MockSpreadsheetService();
  @override
  final LoggingService loggingService = LoggingService();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class MockWindowTrayService implements WindowTrayService {
  @override
  Future<void> initWindow() async {}

  @override
  Future<void> initTray(TrayListener listener) async {}

  @override
  void addWindowListener(WindowListener listener) {}

  @override
  void removeWindowListener(WindowListener listener) {}

  @override
  void removeTrayListener(TrayListener listener) {}

  @override
  Future<void> showAndFocus() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> closeApp() async {}
}

Future<void> saveRowsToJsonFile(
  List<Map<String, String>> rows,
  String fileName,
) async {
  final outputDir = Directory(
    p.join(Directory.current.path, 'data_demo', 'test_output'),
  );
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final outputFile = File(p.join(outputDir.path, fileName));
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(rows),
    flush: true,
  );
}

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    // Montar el widget de la aplicación dentro de un ProviderScope
    // Sobrescribimos los proveedores reales con los mocks para aislamiento absoluto
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseServiceProvider.overrideWithValue(MockDatabaseService()),
          spreadsheetServiceProvider.overrideWithValue(
            MockSpreadsheetService(),
          ),
          flatFileServiceProvider.overrideWithValue(MockSpreadsheetService()),
          apiServerProvider.overrideWithValue(MockApiServer()),
          windowTrayServiceProvider.overrideWithValue(MockWindowTrayService()),
        ],
        child: const MyApp(),
      ),
    );

    // Permitir la inicialización asíncrona en addPostFrameCallback
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    // Confirmar que el título principal de cabecera existe en pantalla
    expect(find.text('Odoo Desktop Sync'), findsOneWidget);
  });

  test('Procesar archivos de demo de Excel', () async {
    final spreadsheetService = ExcelSpreadsheetService(MockDatabaseService());
    final paths = [
      p.join(Directory.current.path, 'data_demo', '148_FIA-FT.xlsx'),
      p.join(Directory.current.path, 'data_demo', '157_INF-FT.xlsx'),
    ];

    spreadsheetService.validatePaths(paths);
    final rows = await spreadsheetService.processAllFiles(paths);

    await saveRowsToJsonFile(rows, 'excel_demo_rows.json');

    expect(rows, isNotEmpty);
    expect(rows.first, containsPair('EMPRESA', isNotNull));
  });
  test('Procesar archivos de demo de csv o txt', () async {
    final spreadsheetService = FlatFileSpreadsheetService(
      MockDatabaseService(),
    );
    final paths = [
      p.join(Directory.current.path, 'data_demo', '148_FIA-FT.txt'),
    ];

    spreadsheetService.validatePaths(paths);
    final rows = await spreadsheetService.processAllFiles(
      paths,
      separator: '|',
    );
    final rowsGrupo = await spreadsheetService.processAndGroupItems(rows);

    await saveRowsToJsonFile(rows, 'flatfile_demo_rows.json');
    await saveRowsToJsonFile(rowsGrupo, 'flatfile_demo_rows_grouped.json');

    expect(rows, isNotEmpty);
    expect(rows.first, containsPair('EMPRESA', isNotNull));
  });
}
