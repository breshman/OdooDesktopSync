// ignore_for_file: avoid_print
import 'dart:collection';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:decimal/decimal.dart';
import '../interfaces/database_service.dart';
import '../interfaces/spreadsheet_service.dart';

class ExcelSpreadsheetService implements SpreadsheetService {
  final DatabaseService databaseService;

  static const String _colEmpresa = "EMPRESA";
  static const String _colSerie = "SERIE";
  static const String _colNumero = "NUMERO";
  static const String _colImporteMe = "IMPORTE ME";
  static const String _colPesoTotal = "PESO TOTAL";
  static const String _colClave = "unique_key";
  static const String _trazabilidadId = "doc_traceability_id";

  ExcelSpreadsheetService(this.databaseService);

  @override
  void validatePaths(List<String> paths) {
    for (var path in paths) {
      final file = File(path);
      if (!file.existsSync()) {
        throw ArgumentError(
          'El archivo no existe en la ruta especificada: $path',
        );
      }

      final fileName = file.uri.pathSegments.last;

      if (!path.toLowerCase().endsWith('.xlsx')) {
        throw ArgumentError(
          'El archivo "$fileName" no es un archivo Excel válido. Debe tener extensión .xlsx.',
        );
      }

      if (fileName.startsWith('~')) {
        throw ArgumentError(
          'El archivo "$fileName" es un archivo temporal de Excel y no puede ser procesado.',
        );
      }
    }
  }

  @override
  Future<List<Map<String, String>>> processAllExcelFiles(
    List<String> listPaths,
  ) async {
    final List<File> validFiles = [];

    for (var path in listPaths) {
      final file = File(path);
      final name = file.uri.pathSegments.last.toLowerCase();
      final valid =
          file.existsSync() &&
          FileSystemEntity.isFileSync(path) &&
          name.endsWith('.xlsx') &&
          !name.startsWith('~');

      if (!valid) {
        final error = "Archivo inválido o no encontrado: $path";
        print('Aviso: $error');
        throw ArgumentError(error);
      }
      validFiles.add(file);
    }

    print('Procesando ${validFiles.length} archivos Excel en paralelo...');

    // Procesar archivos en paralelo usando Future.wait
    final List<List<Map<String, String>>> allFilesRows = await Future.wait(
      validFiles.map((file) async {
        try {
          return await _readExcelFile(file);
        } catch (e) {
          print('Error procesando archivo ${file.path}: $e');
          throw RuntimeException(e.toString());
        }
      }),
    );

    return allFilesRows.expand((rows) => rows).toList();
  }

  /// Lee un archivo Excel en streaming de manera asíncrona
  Future<List<Map<String, String>>> _readExcelFile(File file) async {
    final List<Map<String, String>> allRows = [];

    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) return allRows;

      final sheetName = excel.tables.keys.first;
      final table = excel.tables[sheetName]!;

      final List<String> headers = [];
      int headerRowIndex = -1;

      for (var i = 0; i < table.rows.length; i++) {
        final row = table.rows[i];
        final rowValues = row
            .map((cell) => _getCellValueAsString(cell?.value).trim())
            .toList();

        if (_isHeaderRow(rowValues)) {
          headers.addAll(rowValues);
          headerRowIndex = i;
          break;
        }
      }

      if (headers.isEmpty) {
        throw Exception(
          'No se encontró la fila de cabeceras en el archivo ${file.uri.pathSegments.last}.',
        );
      }

      for (var i = headerRowIndex + 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        final Map<String, String> rowMap = <String, String>{};
        bool hasData = false;

        for (int j = 0; j < headers.length; j++) {
          final cellValue = j < row.length ? row[j]?.value : null;
          final value = cellValue != null
              ? _getCellValueAsString(cellValue).trim()
              : '';
          if (value.isNotEmpty) hasData = true;
          rowMap[headers[j]] = value;
        }

        if (hasData) {
          allRows.add(rowMap);
        }
      }
    } catch (e) {
      final errorMsg =
          "Error al leer el archivo ${file.uri.pathSegments.last} => $e";
      print(errorMsg);
      throw Exception(errorMsg);
    }

    return allRows;
  }

  bool _isHeaderRow(List<String> rowValues) {
    final normalized = rowValues.map((value) => value.toUpperCase()).toList();
    return normalized.contains(_colEmpresa.toUpperCase()) &&
        normalized.contains(_colNumero.toUpperCase());
  }

  @override
  Future<List<Map<String, String>>> processAndGroupItems(
    List<Map<String, String>> allItems,
  ) async {
    final Map<String, Map<String, String>> grouped = {};

    for (final row in allItems) {
      final key = _buildKey(row);

      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;

        existing[_colImporteMe] =
            (_parseDecimal(existing[_colImporteMe]) +
                    _parseDecimal(row[_colImporteMe]))
                .toString();

        existing[_colPesoTotal] =
            (_parseDecimal(existing[_colPesoTotal]) +
                    _parseDecimal(row[_colPesoTotal]))
                .toString();
      } else {
        final newRow = LinkedHashMap<String, String>.from(row);
        newRow[_colClave] = key;
        newRow[_colImporteMe] = row[_colImporteMe] ?? '0';
        newRow[_colPesoTotal] = row[_colPesoTotal] ?? '0';

        // Inyectar doc_traceability_id si existe en el caché
        final trazabilidadId = await databaseService.getTraceabilityId(key);
        if (trazabilidadId != null && trazabilidadId.isNotEmpty) {
          newRow[_trazabilidadId] = trazabilidadId;
        }

        grouped[key] = newRow;
      }
    }

    return grouped.values.toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _buildKey(Map<String, String> row) {
    final empresa = (row[_colEmpresa] ?? "").trim();
    final serie = (row[_colSerie] ?? "").trim();
    final numero = (row[_colNumero] ?? "").trim();
    return "$empresa - $serie - $numero";
  }

  String _getCellValueAsString(CellValue? cellValue) {
    if (cellValue == null) return '';

    if (cellValue is TextCellValue) {
      return cellValue.value.toString().trim();
    } else if (cellValue is IntCellValue) {
      return cellValue.value.toString();
    } else if (cellValue is DoubleCellValue) {
      try {
        final dec = Decimal.parse(cellValue.value.toString());
        return dec.toString();
      } catch (_) {
        return cellValue.value.toString();
      }
    } else if (cellValue is BoolCellValue) {
      return cellValue.value.toString();
    } else if (cellValue is DateTimeCellValue) {
      return "${cellValue.year.toString().padLeft(4, '0')}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}T${cellValue.hour.toString().padLeft(2, '0')}:${cellValue.minute.toString().padLeft(2, '0')}:${cellValue.second.toString().padLeft(2, '0')}";
    } else if (cellValue is DateCellValue) {
      return "${cellValue.year.toString().padLeft(4, '0')}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}";
    } else if (cellValue is TimeCellValue) {
      return cellValue.toString();
    } else if (cellValue is FormulaCellValue) {
      return cellValue.formula;
    }

    final str = cellValue.toString().trim();
    if (str.endsWith('.0')) {
      return str.substring(0, str.length - 2);
    }
    return str;
  }

  Decimal _parseDecimal(String? value) {
    try {
      if (value == null || value.trim().isEmpty) return Decimal.zero;
      return Decimal.parse(value.trim());
    } catch (_) {
      print("Valor numérico inválido: '$value'");
      return Decimal.zero;
    }
  }
}

class RuntimeException implements Exception {
  final String message;
  RuntimeException(this.message);
  @override
  String toString() => "RuntimeException: $message";
}
