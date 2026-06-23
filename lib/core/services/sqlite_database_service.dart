// ignore_for_file: avoid_print
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import '../interfaces/database_service.dart';
import 'logging_service.dart';

class SqliteDatabaseService implements DatabaseService {
  Database? _db;
  final LoggingService _loggingService = LoggingService();
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
        _loggingService.info('Directorio de datos creado en: ${dataDir.absolute.path}');
      }
    } catch (e) {
      _loggingService.error('Error al crear directorio de datos: $e');
      throw FileSystemException(
        'No se pudo crear el directorio de datos. Verifica permisos de escritura en: ${dataDir.path}',
        e.toString(),
      );
    }

    final dbPath = p.join(dataDir.path, 'data.db');
    _loggingService.info('Abriendo base de datos SQLite en: $dbPath');

    // 3. Abrir la base de datos
    try {
      _db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (Database db, int version) async {
          print('Creando tablas SQLite...');

          // Tabla app_config (almacenamiento de claves y valores)
          await db.execute('''
          CREATE TABLE app_config (
            clave TEXT PRIMARY KEY,
            valor TEXT
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
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          print('Actualizando base de datos SQLite de versión $oldVersion a $newVersion...');
          if (oldVersion < 2) {
            await db.execute('DROP TABLE IF EXISTS api_config');
            await db.execute('DROP TABLE IF EXISTS path_config');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS app_config (
                clave TEXT PRIMARY KEY,
                valor TEXT
              )
            ''');
          }
        },
      );
    } catch (e) {
      _loggingService.error('Error al abrir base de datos: $e');
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
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM app_config'),
    );
    if (count == 0) {
      // await db.insert('app_config', {
      //   'clave': 'odoo_url',
      //   'valor': 'https://miempresa.odoo.com',
      // });
      // await db.insert('app_config', {
      //   'clave': 'wifi_ssid',
      //   'valor': '',
      // });
      // await db.insert('app_config', {
      //   'clave': 'wifi_password',
      //   'valor': '',
      // });
      _loggingService.info('Configuraciones de app_config por defecto inicializadas.');
    }
  }

  @override
  Future<void> cleanOldCache() async {
    final now = DateTime.now();
    _loggingService.info(
      'Iniciando hook de limpieza de caché de trazabilidad... Hora local: $now',
    );

    // SQLite almacena en UTC para CURRENT_TIMESTAMP. Restamos 4 días de la fecha actual de SQLite
    final rowsDeleted = await db.delete(
      'data_send_cache',
      where: "create_at < datetime('now', '-6 days')",
    );
    _loggingService.info(
      'Limpieza de caché completada, registros antiguos eliminados: $rowsDeleted',
    );
  }

  @override
  String normalizeKey(String key) {
    return key.trim().toUpperCase();
  }

  @override
  Future<Map<String, dynamic>> getConfig() async {
    final rows = await db.query('app_config');
    String odooUrl = 'https://miempresa.odoo.com';
    String wifiSsid = '';
    String wifiPassword = '';

    for (final row in rows) {
      final clave = row['clave']?.toString();
      final valor = row['valor']?.toString() ?? '';
      if (clave == 'odoo_url') {
        odooUrl = valor;
      } else if (clave == 'wifi_ssid') {
        wifiSsid = valor;
      } else if (clave == 'wifi_password') {
        wifiPassword = valor;
      }
    }

    return {
      'api': [
        {'name': 'odoo', 'url': odooUrl}
      ],
      'wifi_ssid': wifiSsid,
      'wifi_password': wifiPassword,
      'config_paths': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> saveApiConfig(String name, String url) async {
    await db.insert('app_config', {
      'clave': 'odoo_url',
      'valor': url,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> savePathConfig(String path, bool isActive) async {
    // No-op or we can save it to app_config if needed.
  }

  @override
  Future<Map<String, dynamic>> replaceConfig(
    Map<String, dynamic> newConfig,
  ) async {
    await db.transaction((txn) async {
      if (newConfig['api'] != null && newConfig['api'] is List) {
        for (var item in newConfig['api']) {
          if (item is Map) {
            await txn.insert('app_config', {
              'clave': 'odoo_url',
              'valor': item['url']?.toString() ?? '',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            break;
          }
        }
      }
      if (newConfig['wifi_ssid'] != null) {
        await txn.insert('app_config', {
          'clave': 'wifi_ssid',
          'valor': newConfig['wifi_ssid'].toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (newConfig['wifi_password'] != null) {
        await txn.insert('app_config', {
          'clave': 'wifi_password',
          'valor': newConfig['wifi_password'].toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
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
