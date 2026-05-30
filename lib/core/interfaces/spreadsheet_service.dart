abstract class SpreadsheetService {
  /// Valida una lista de rutas absolutas de archivos Excel, CSV o Texto
  void validatePaths(List<String> paths);

  /// Lee y parsea todos los archivos (.xlsx, .csv, .txt) en paralelo
  Future<List<Map<String, String>>> processAllFiles(List<String> listPaths, {String? separator});

  /// Agrupa, consolida aritméticamente y cruza datos con la base de datos
  Future<List<Map<String, String>>> processAndGroupItems(List<Map<String, String>> allItems);
}
