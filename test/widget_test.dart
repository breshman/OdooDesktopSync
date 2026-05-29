import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_async/core/interfaces/database_service.dart';
import 'package:odoo_async/core/interfaces/spreadsheet_service.dart';
import 'package:odoo_async/core/providers/dependency_providers.dart';
import 'package:odoo_async/core/services/excel_spreadsheet_service.dart';
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
  Future<List<Map<String, String>>> processAllExcelFiles(
    List<String> listPaths,
  ) async => [];
  @override
  Future<List<Map<String, String>>> processAndGroupItems(
    List<Map<String, String>> allItems,
  ) async => [];
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
        ],
        child: const MyApp(),
      ),
    );

    // Confirmar que el título principal de cabecera existe en pantalla
    expect(find.text('Odoo Desktop Sync'), findsOneWidget);
  });

  test('Procesar archivos de demo de Excel', () async {
    final spreadsheetService = ExcelSpreadsheetService(MockDatabaseService());
    final paths = [
      '/Users/macbook/Documents/Proyectos/Flutter/odoo_async/data_demo/148_FIA-FT.xlsx',
      '/Users/macbook/Documents/Proyectos/Flutter/odoo_async/data_demo/157_INF-FT.xlsx',
    ];

    spreadsheetService.validatePaths(paths);
    final rows = await spreadsheetService.processAllExcelFiles(paths);

    expect(rows, isNotEmpty);
    expect(rows.first, containsPair('EMPRESA', isNotNull));
  });
}
