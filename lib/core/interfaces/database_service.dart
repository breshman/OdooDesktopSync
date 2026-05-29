abstract class DatabaseService {
  /// Inicializa la conexión y crea esquemas de base de datos
  Future<void> init();

  /// Limpia registros de caché antiguos (mayores a 4 días)
  Future<void> cleanOldCache();

  /// Obtiene la configuración unificada completa
  Future<Map<String, dynamic>> getConfig();

  /// Agrega o actualiza un endpoint en la tabla de APIs
  Future<void> saveApiConfig(String name, String url);

  /// Agrega o actualiza una ruta en la tabla de rutas de lectura
  Future<void> savePathConfig(String path, bool isActive);

  /// Reemplaza la configuración completa del sistema bajo una transacción
  Future<Map<String, dynamic>> replaceConfig(Map<String, dynamic> newConfig);

  /// Guarda o actualiza mapeos de trazabilidad en el caché
  Future<void> saveCacheItems(List<dynamic> cacheItems);

  /// Obtiene un ID de trazabilidad del caché si existe
  Future<String?> getTraceabilityId(String uniqueKey);

  /// Normaliza una clave eliminando espacios extremos y pasándola a mayúsculas
  String normalizeKey(String key);
}
