// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import '../interfaces/database_service.dart';
import '../interfaces/spreadsheet_service.dart';
import '../utils/spreadsheet_helpers.dart';

class FlatFileSpreadsheetService
    with SpreadsheetHelperMixin
    implements SpreadsheetService {
  @override
  final DatabaseService databaseService;

  static const List<String> _textHeaders = [
    'EMPRESA',
    'TIPO DOC.',
    'SERIE',
    'NUMERO',
    'SITUACION',
    'FECHA',
    'CODIGO CLIENTE',
    'NOMBRE CLIENTE',
    'DIRECCION CLIENTE',
    'TIP.INV',
    'COD. ARTICULO',
    'NOMBRE ARTICULO',
    'UND',
    'CANTIDAD',
    'PESO',
    'PESO TOTAL',
    'DESCUENTO',
    'DSCTO 1',
    'DSCTO 2',
    'DSCTO 3',
    'DSCTO 4',
    'TIPCAM',
    'P.U. MN',
    'SUBTOTAL MN',
    'IGV MN',
    'IMPORTE MN',
    'P.U. ME',
    'SUBTOTAL ME',
    'IGV ME',
    'IMPORTE ME',
    'COD. F.PAGO',
    'FORMA DE PAGO',
    'MONEDA',
    'COD. VEN CARTERA',
    'VENDEDOR CARTERA',
    'COD. VEN',
    'VENDEDOR',
    'COD. FAM',
    'FAMILIA',
    'COD. SUBFAM',
    'SUBFAMILIA',
    'COD. MARCA',
    'MARCA',
    'DOC. REF',
    'DEPARTAMENTO',
    'PROVINCIA',
    'DISTRITO',
    'ZONA 1',
    'COD. SUBFAM2',
    'SUBFAMILIA2',
    'DIRECCION ENVIO',
    'DEPARTAMENTO ENVIO',
    'PROVINCIA ENVIO',
    'DISTRITO ENVIO',
    'TRANSPORTISTA',
    'DIRECCION TRANSPORTISTA',
    'GUIA REMISION',
    'OBSERVACION',
    'GUIA_FECHA',
    'GUIA_FECHA_PROGAMADO',
    'RUC TRANSPORTISTA',
  ];

  FlatFileSpreadsheetService(this.databaseService);

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
      final nameLower = fileName.toLowerCase();

      if (!nameLower.endsWith('.csv') && !nameLower.endsWith('.txt')) {
        throw ArgumentError(
          'El archivo "$fileName" no es un archivo plano válido. Debe tener extensión .csv o .txt.',
        );
      }

      if (fileName.startsWith('~')) {
        throw ArgumentError(
          'El archivo "$fileName" es un archivo temporal y no puede ser procesado.',
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
          (name.endsWith('.csv') || name.endsWith('.txt')) &&
          !name.startsWith('~');

      if (!valid) {
        final error = "Archivo plano inválido o no encontrado: $path";
        print('Aviso: $error');
        throw ArgumentError(error);
      }
      validFiles.add(file);
    }

    print('Procesando ${validFiles.length} archivos planos en paralelo...');

    // Procesar archivos planos en paralelo usando Future.wait
    final List<List<Map<String, String>>> allFilesRows = await Future.wait(
      validFiles.map((file) async {
        try {
          return await _readTextOrCsvFile(file, separator: separator);
        } catch (e) {
          print('Error procesando archivo plano ${file.path}: $e');
          throw FlatFileRuntimeException(e.toString());
        }
      }),
    );

    return allFilesRows.expand((rows) => rows).toList();
  }

  /// Lee un archivo de texto o CSV de manera asíncrona y le asigna la cabecera correspondiente
  Future<List<Map<String, String>>> _readTextOrCsvFile(
    File file, {
    String? separator,
  }) async {
    final activeSeparator = separator ?? '|';

    try {
      final lines = await file.readAsLines(encoding: utf8);
      if (lines.isEmpty) return [];
      return _processLinesWithBuffer(lines, activeSeparator);
    } catch (e) {
      // Intentar leer con encoding latin1 si utf8 falla
      try {
        final lines = await file.readAsLines(encoding: latin1);
        if (lines.isEmpty) return [];
        return _processLinesWithBuffer(lines, activeSeparator);
      } catch (e2) {
        final errorMsg =
            "Error al leer el archivo de texto/csv ${file.uri.pathSegments.last} => $e2";
        print(errorMsg);
        throw Exception(errorMsg);
      }
    }
  }

  /// Procesa la lista de líneas reconstruyendo aquellas que tengan saltos de línea erróneos
  List<Map<String, String>> _processLinesWithBuffer(
    List<String> lines,
    String activeSeparator,
  ) {
    final List<Map<String, String>> allRows = [];
    String buffer = '';

    // Si tenemos 61 columnas en _textHeaders, una fila completa debe tener 60 separadores.
    final int separadoresEsperados = _textHeaders.length - 1;

    for (final line in lines) {
      // Ignorar líneas vacías a menos que estemos a mitad de reconstruir una línea rota
      if (line.trim().isEmpty && buffer.isEmpty) continue;

      if (buffer.isEmpty) {
        buffer = line;
      } else {
        // Unimos el texto cortado con un espacio para no perder el formato natural
        buffer += ' ${line.trim()}';
      }

      final int cantidadSeparadores = buffer.split(activeSeparator).length - 1;

      // Si alcanzamos o superamos los separadores de una fila válida, procesamos el buffer
      if (cantidadSeparadores >= separadoresEsperados) {
        final fields = _splitCsvLine(buffer, activeSeparator);
        final Map<String, String> rowMap = {};

        for (int i = 0; i < _textHeaders.length; i++) {
          final headerName = _textHeaders[i];
          final value = i < fields.length ? fields[i] : '';
          rowMap[headerName] = value;
        }

        final hasData = rowMap.values.any((val) => val.isNotEmpty);
        if (hasData) {
          allRows.add(rowMap);
        }

        // Limpiamos el buffer para la siguiente fila
        buffer = '';
      }
    }

    // Por seguridad, si el archivo termina repentinamente y queda algo en el buffer,
    // intentamos procesarlo como la última fila.
    if (buffer.isNotEmpty) {
      final fields = _splitCsvLine(buffer, activeSeparator);
      final Map<String, String> rowMap = {};
      for (int i = 0; i < _textHeaders.length; i++) {
        rowMap[_textHeaders[i]] = i < fields.length ? fields[i] : '';
      }
      if (rowMap.values.any((val) => val.isNotEmpty)) {
        allRows.add(rowMap);
      }
    }

    return allRows;
  }

  List<String> _splitCsvLine(String line, String separator) {
    final rawParts = line.split(separator);
    return rawParts.map((part) {
      var trimmed = part.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
        trimmed = trimmed.substring(1, trimmed.length - 1);
      } else if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
        trimmed = trimmed.substring(1, trimmed.length - 1);
      }
      return trimmed.trim();
    }).toList();
  }
}

class FlatFileRuntimeException implements Exception {
  final String message;
  FlatFileRuntimeException(this.message);
  @override
  String toString() => "FlatFileRuntimeException: $message";
}
