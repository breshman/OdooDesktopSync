// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel/excel.dart';
import 'package:decimal/decimal.dart';
import '../interfaces/database_service.dart';
import '../interfaces/spreadsheet_service.dart';
import '../utils/spreadsheet_helpers.dart';
import 'logging_service.dart';

class ExcelSpreadsheetService with SpreadsheetHelperMixin implements SpreadsheetService {
  @override
  final DatabaseService databaseService;

  final LoggingService _loggingService = LoggingService();

  ExcelSpreadsheetService(this.databaseService);

  @override
  void validatePaths(List<String> paths) {
    for (var path in paths) {
      final file = File(path);
      if (!file.existsSync()) {
        _loggingService.error('El archivo no existe en la ruta especificada: $path');
        throw ArgumentError(
          'El archivo no existe en la ruta especificada: $path',
        );
      }

      final fileName = file.uri.pathSegments.last;

      if (!path.toLowerCase().endsWith('.xlsx')) {
        _loggingService.error('El archivo "$fileName" no es un archivo Excel válido. Debe tener extensión .xlsx.');
        throw ArgumentError(
          'El archivo "$fileName" no es un archivo Excel válido. Debe tener extensión .xlsx.',
        );
      }

      if (fileName.startsWith('~')) {
        _loggingService.error('El archivo "$fileName" es un archivo temporal de Excel y no puede ser procesado.');
        throw ArgumentError(
          'El archivo "$fileName" es un archivo temporal de Excel y no puede ser procesado.',
        );
      }
    }
  }

  @override
  Future<List<Map<String, String>>> processAllFiles(
    List<String> listPaths, {
    String? separator,
  }) async {
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
        _loggingService.error(error);
        throw ArgumentError(error);
      }
      validFiles.add(file);
    }

    _loggingService.info('Procesando ${validFiles.length} archivos Excel en paralelo...');

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

  /// Pre-procesa los bytes del archivo Excel para resolver el error:
  /// "Exception: custom numFmtId starts at 164 but found a value of X"
  /// provocado por la librería 'excel' cuando encuentra formatos personalizados con IDs menores a 164.
  Uint8List _fixExcelStyles(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      int? targetIndex;
      for (int i = 0; i < archive.length; i++) {
        if (archive[i].name == 'xl/styles.xml') {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex != null) {
        final stylesFile = archive[targetIndex];
        final xmlContent = utf8.decode(stylesFile.content as List<int>);
        final document = XmlDocument.parse(xmlContent);
        
        final numFmtsElements = document.findAllElements('numFmts');
        if (numFmtsElements.isNotEmpty) {
          final numFmts = numFmtsElements.first;
          final numFmtList = numFmts.findElements('numFmt').toList();
          
          int removedCount = 0;
          for (final numFmt in numFmtList) {
            final idAttr = numFmt.getAttribute('numFmtId');
            if (idAttr != null) {
              final id = int.tryParse(idAttr);
              if (id != null && id < 164) {
                numFmt.parent?.children.remove(numFmt);
                removedCount++;
              }
            }
          }
          
          if (removedCount > 0) {
            final remainingNumFmts = numFmts.findElements('numFmt').toList();
            if (remainingNumFmts.isEmpty) {
              numFmts.parent?.children.remove(numFmts);
            } else {
              numFmts.setAttribute('count', remainingNumFmts.length.toString());
            }
            
            final newXmlContent = document.toXmlString();
            final newStylesBytes = utf8.encode(newXmlContent);
            final newStylesFile = ArchiveFile(
              'xl/styles.xml',
              newStylesBytes.length,
              newStylesBytes,
            );
            archive[targetIndex] = newStylesFile;
            
            // Re-codificar el zip con la modificación
            final encoder = ZipEncoder();
            final encodedBytes = encoder.encode(archive);
            if (encodedBytes != null) {
              return Uint8List.fromList(encodedBytes);
            }
          }
        }
      }
    } catch (e) {
      _loggingService.error('Advertencia: No se pudo pre-procesar los estilos del archivo Excel: $e');
    }
    return bytes;
  }

  /// Lee un archivo Excel en streaming de manera asíncrona
  Future<List<Map<String, String>>> _readExcelFile(File file) async {
    final List<Map<String, String>> allRows = [];

    try {
      final fileBytes = await file.readAsBytes();
      final bytes = _fixExcelStyles(fileBytes);
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
        _loggingService.error('No se encontró la fila de cabeceras en el archivo ${file.uri.pathSegments.last}.');
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
      // print(headers);
      // [EMPRESA, TIPO DOC., SERIE, NUMERO, SITUACION, FECHA, CODIGO CLIENTE, NOMBRE CLIENTE, DIRECCION CLIENTE, TIP.INV, COD. ARTICULO, NOMBRE ARTICULO, UND, CANTIDAD, PESO, PESO TOTAL, DESCUENTO, DSCTO 1, DSCTO 2, DSCTO 3, DSCTO 4, TIPCAM, P.U. MN, SUBTOTAL MN, IGV MN, IMPORTE MN, P.U. ME, SUBTOTAL ME, IGV ME, IMPORTE ME, COD. F.PAGO, FORMA DE PAGO, MONEDA, COD. VEN CARTERA, VENDEDOR CARTERA, COD. VEN, VENDEDOR, COD. FAM, FAMILIA, COD. SUBFAM, SUBFAMILIA, COD. MARCA, MARCA, DOC. REF, DEPARTAMENTO, PROVINCIA, DISTRITO, ZONA 1, COD. SUBFAM2, SUBFAMILIA2, DIRECCION ENVIO, DEPARTAMENTO ENVIO, PROVINCIA ENVIO, DISTRITO ENVIO, TRANSPORTISTA, DIRECCION TRANSPORTISTA, GUIA REMISION, OBSERVACION, GUIA_FECHA, GUIA_FECHA_PROGAMADO, RUC TRANSPORTISTA]
    } catch (e) {
      final errorMsg =
          "Error al leer el archivo ${file.uri.pathSegments.last} => $e";
      _loggingService.error(errorMsg);
      throw Exception(errorMsg);
    }

    return allRows;
  }



  bool _isHeaderRow(List<String> rowValues) {
    final normalized = rowValues.map((value) => value.toUpperCase()).toList();
    return normalized.contains(colEmpresa.toUpperCase()) &&
        normalized.contains(colNumero.toUpperCase());
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
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
}

class RuntimeException implements Exception {
  final String message;
  RuntimeException(this.message);
  @override
  String toString() => "RuntimeException: $message";
}
