// ignore_for_file: avoid_print
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import '../interfaces/database_service.dart';

class SqliteDatabaseService implements DatabaseService {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError(
        'La base de datos no ha sido inicializada. Llama a init() primero.',
      );
    }
    return _db!;
  }

  @override
  Future<void> init() async {
    // 1. Inicializar FFI si es una plataforma de escritorio (macOS o Windows)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 2. Asegurar que el directorio de datos exista en una ruta de usuario segura
    final dataDir = await _getDataDirectory();
    try {
      if (!dataDir.existsSync()) {
        dataDir.createSync(recursive: true);
        print('Directorio de datos creado en: ${dataDir.absolute.path}');
      }
    } catch (e) {
      throw FileSystemException(
        'No se pudo crear el directorio de datos. Verifica permisos de escritura en: ${dataDir.path}',
        e.toString(),
      );
    }

    final dbPath = p.join(dataDir.path, 'data.db');
    print('Abriendo base de datos SQLite en: $dbPath');

    // 3. Abrir la base de datos
    try {
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (Database db, int version) async {
          print('Creando tablas SQLite...');

          // Tabla api_config
          await db.execute('''
          CREATE TABLE api_config (
            name TEXT PRIMARY KEY,
            url TEXT
          )
        ''');

          // Tabla path_config
          await db.execute('''
          CREATE TABLE path_config (
            path TEXT PRIMARY KEY,
            is_active INTEGER
          )
        ''');

          // Tabla data_send_cache
          await db.execute('''
          CREATE TABLE data_send_cache (
            clave TEXT PRIMARY KEY,
            valor TEXT,
            create_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        },
      );
    } catch (e) {
      throw FileSystemException(
        'No se pudo abrir o crear la base de datos SQLite en: $dbPath',
        e.toString(),
      );
    }

    // 4. Poblar valores por defecto si las tablas están vacías
    await _initDefaultValues();

    // 5. Ejecutar la rutina de limpieza de caché (antigüedad mayor a 4 días)
    await cleanOldCache();
  }

  /// Inicializa los datos por defecto en las tablas de configuración
  Future<Directory> _getDataDirectory() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(
          p.join(home, 'Library', 'Application Support', 'odoo_async'),
        );
      }
    } else if (Platform.isWindows) {
      final appData =
          Platform.environment['APPDATA'] ??
          Platform.environment['USERPROFILE'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(p.join(appData, 'odoo_async'));
      }
    } else if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        return Directory(p.join(xdg, 'odoo_async'));
      }
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(p.join(home, '.local', 'share', 'odoo_async'));
      }
    }

    return Directory('./data');
  }

  Future<void> _initDefaultValues() async {
    final apiCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM api_config'),
    );
    if (apiCount == 0) {
      await db.insert('api_config', {
        'name': 'url producion',
        'url': 'https://api.miempresa.com',
      });
      await db.insert('api_config', {
        'name': 'url test',
        'url': 'https://api.miempresa.com',
      });
      print('Configuraciones de API por defecto inicializadas.');
    }

    final pathCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM path_config'),
    );
    if (pathCount == 0) {
      await db.insert('path_config', {'path': 'C:/excel', 'is_active': 1});
      await db.insert('path_config', {'path': 'C:/excel_2', 'is_active': 0});
      print('Configuraciones de rutas de lectura por defecto inicializadas.');
    }
  }

  @override
  Future<void> cleanOldCache() async {
    final now = DateTime.now();
    print(
      'Iniciando hook de limpieza de caché de trazabilidad... Hora local: $now',
    );

    // SQLite almacena en UTC para CURRENT_TIMESTAMP. Restamos 4 días de la fecha actual de SQLite
    final rowsDeleted = await db.delete(
      'data_send_cache',
      where: "create_at < datetime('now', '-6 days')",
    );
    print(
      'Limpieza de caché completada. Registros antiguos eliminados: $rowsDeleted',
    );
  }

  @override
  String normalizeKey(String key) {
    return key.trim().toUpperCase();
  }

  @override
  Future<Map<String, dynamic>> getConfig() async {
    final apiRows = await db.query('api_config');
    final pathRows = await db.query('path_config');

    final apiList = apiRows
        .map((row) => {'url': row['url'], 'name': row['name']})
        .toList();

    final pathList = pathRows
        .map((row) => {'path': row['path'], 'is_active': row['is_active'] == 1})
        .toList();

    return {'api': apiList, 'config_paths': pathList};
  }

  @override
  Future<void> saveApiConfig(String name, String url) async {
    await db.insert('api_config', {
      'name': name,
      'url': url,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> savePathConfig(String path, bool isActive) async {
    await db.insert('path_config', {
      'path': path,
      'is_active': isActive ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>> replaceConfig(
    Map<String, dynamic> newConfig,
  ) async {
    await db.transaction((txn) async {
      // 1. Vaciar ambas tablas por completo
      await txn.delete('api_config');
      await txn.delete('path_config');

      // 2. Insertar nuevos registros en api_config
      if (newConfig['api'] != null && newConfig['api'] is List) {
        for (var item in newConfig['api']) {
          if (item is Map) {
            await txn.insert('api_config', {
              'name': item['name']?.toString() ?? '',
              'url': item['url']?.toString() ?? '',
            });
          }
        }
      }

      // 3. Insertar nuevos registros en path_config
      if (newConfig['config_paths'] != null &&
          newConfig['config_paths'] is List) {
        for (var item in newConfig['config_paths']) {
          if (item is Map) {
            await txn.insert('path_config', {
              'path': item['path']?.toString() ?? '',
              'is_active': (item['is_active'] == true) ? 1 : 0,
            });
          }
        }
      }
    });

    return getConfig();
  }

  @override
  Future<void> saveCacheItems(List<dynamic> cacheItems) async {
    final batch = db.batch();
    for (var item in cacheItems) {
      if (item is Map) {
        final uniqueKey = item['unique_key']?.toString();
        final docTraceabilityId = item['doc_traceability_id']?.toString();
        if (uniqueKey != null && docTraceabilityId != null) {
          final normalizedClave = normalizeKey(uniqueKey);
          batch.insert('data_send_cache', {
            'clave': normalizedClave,
            'valor': docTraceabilityId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<String?> getTraceabilityId(String uniqueKey) async {
    final normalizedClave = normalizeKey(uniqueKey);
    final results = await db.query(
      'data_send_cache',
      columns: ['valor'],
      where: 'clave = ?',
      whereArgs: [normalizedClave],
    );

    if (results.isNotEmpty) {
      return results.first['valor']?.toString();
    }
    return null;
  }
}
