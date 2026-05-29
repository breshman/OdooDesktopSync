abstract class SpreadsheetService {
  /// Valida una lista de rutas absolutas de archivos Excel
  void validatePaths(List<String> paths);

  /// Lee y parsea todos los archivos Excel en paralelo
  Future<List<Map<String, String>>> processAllExcelFiles(List<String> listPaths);

  /// Agrupa, consolida aritméticamente y cruza datos con la base de datos
  Future<List<Map<String, String>>> processAndGroupItems(List<Map<String, String>> allItems);
}
