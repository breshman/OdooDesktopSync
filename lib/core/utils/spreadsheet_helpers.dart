import 'dart:collection';
import 'package:decimal/decimal.dart';
import '../interfaces/database_service.dart';

mixin SpreadsheetHelperMixin {
  DatabaseService get databaseService;

  final String colEmpresa = "EMPRESA";
  final String colSerie = "SERIE";
  final String colNumero = "NUMERO";
  final String colImporteMe = "IMPORTE ME";
  final String colPesoTotal = "PESO TOTAL";
  final String colClave = "unique_key";
  final String colTraceabilityId = "doc_traceability_id";

  Future<List<Map<String, String>>> processAndGroupItems(
    List<Map<String, String>> allItems,
  ) async {
    final Map<String, Map<String, String>> grouped = {};

    for (final row in allItems) {
      final key = _buildKey(row);

      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;

        existing[colImporteMe] =
            (_parseDecimal(existing[colImporteMe]) +
                    _parseDecimal(row[colImporteMe]))
                .toString();

        existing[colPesoTotal] =
            (_parseDecimal(existing[colPesoTotal]) +
                    _parseDecimal(row[colPesoTotal]))
                .toString();
      } else {
        final newRow = LinkedHashMap<String, String>.from(row);
        newRow[colClave] = key;
        newRow[colImporteMe] = row[colImporteMe] ?? '0';
        newRow[colPesoTotal] = row[colPesoTotal] ?? '0';

        // Inyectar doc_traceability_id si existe en el caché
        final traceabilityId = await databaseService.getTraceabilityId(key);
        if (traceabilityId != null && traceabilityId.isNotEmpty) {
          newRow[colTraceabilityId] = traceabilityId;
        }

        grouped[key] = newRow;
      }
    }

    return grouped.values.toList();
  }

  String _buildKey(Map<String, String> row) {
    final empresa = (row[colEmpresa] ?? "").trim();
    final serie = (row[colSerie] ?? "").trim();
    final numero = (row[colNumero] ?? "").trim();
    return "$empresa - $serie - $numero";
  }

  Decimal _parseDecimal(String? value) {
    try {
      if (value == null || value.trim().isEmpty) return Decimal.zero;
      return Decimal.parse(value.trim());
    } catch (_) {
      // ignore: avoid_print
      print("Valor numérico inválido: '$value'");
      return Decimal.zero;
    }
  }
}
