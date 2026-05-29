// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'core/interfaces/database_service.dart';
import 'core/interfaces/spreadsheet_service.dart';

class ApiServer {
  final DatabaseService dbService;
  final SpreadsheetService excelService;
  HttpServer? _server;

  ApiServer({required this.dbService, required this.excelService});

  /// Inicia el servidor HTTP en el puerto 8089 con rutas definidas y middleware de logs y CORS
  Future<void> start() async {
    final router = Router();

    // GET /status - Health Check
    router.get('/status', (Request request) {
      final responseBody = {
        'status': 'OK',
        'version': '26.05.16',
        'message': 'Everything is working fine',
      };
      return Response.ok(
        jsonEncode(responseBody),
        headers: {'content-type': 'application/json'},
      );
    });

    // GET /api/config - Obtener configuración unificada
    router.get('/api/config', (Request request) async {
      try {
        final config = await dbService.getConfig();
        return Response.ok(
          jsonEncode(config),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        return _buildErrorResponse(
          500,
          'Internal Server Error',
          e.toString(),
          '/api/config',
        );
      }
    });

    // POST /api/config/api - Upsert endpoint externo
    router.post('/api/config/api', (Request request) async {
      try {
        final bodyStr = await request.readAsString();
        final payload = jsonDecode(bodyStr);

        final name = payload['name']?.toString();
        final url = payload['url']?.toString();

        if (name == null || name.isEmpty || url == null || url.isEmpty) {
          return _buildErrorResponse(
            400,
            'Bad Request',
            'Los campos "name" y "url" son obligatorios.',
            '/api/config/api',
          );
        }

        await dbService.saveApiConfig(name, url);
        final updatedConfig = await dbService.getConfig();

        return Response.ok(
          jsonEncode(updatedConfig),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        return _buildErrorResponse(
          400,
          'Bad Request',
          e.toString(),
          '/api/config/api',
        );
      }
    });

    // POST /api/config/paths - Upsert ruta de lectura
    router.post('/api/config/paths', (Request request) async {
      try {
        final bodyStr = await request.readAsString();
        final payload = jsonDecode(bodyStr);

        final path = payload['path']?.toString();
        final isActive = payload['is_active'];

        if (path == null || path.isEmpty || isActive == null) {
          return _buildErrorResponse(
            400,
            'Bad Request',
            'Los campos "path" y "is_active" son obligatorios.',
            '/api/config/paths',
          );
        }

        await dbService.savePathConfig(path, isActive == true);
        final updatedConfig = await dbService.getConfig();

        return Response.ok(
          jsonEncode(updatedConfig),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        return _buildErrorResponse(
          400,
          'Bad Request',
          e.toString(),
          '/api/config/paths',
        );
      }
    });

    // PUT /api/config - Reemplazar toda la configuración en transacción
    router.put('/api/config', (Request request) async {
      try {
        final bodyStr = await request.readAsString();
        final payload = jsonDecode(bodyStr);

        if (payload is! Map<String, dynamic>) {
          return _buildErrorResponse(
            400,
            'Bad Request',
            'El cuerpo de la petición debe ser un objeto JSON de configuración.',
            '/api/config',
          );
        }

        final updatedConfig = await dbService.replaceConfig(payload);
        return Response.ok(
          jsonEncode(updatedConfig),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        return _buildErrorResponse(
          400,
          'Bad Request',
          e.toString(),
          '/api/config',
        );
      }
    });

    // POST /api/excel/cache - Guardar/actualizar caché de trazabilidad en SQLite
    router.post('/api/excel/cache', (Request request) async {
      try {
        final bodyStr = await request.readAsString();
        final payload = jsonDecode(bodyStr);

        if (payload is! List) {
          return _buildErrorResponse(
            400,
            'Bad Request',
            'El cuerpo debe ser un arreglo de objetos de mapeo de trazabilidad.',
            '/api/excel/cache',
          );
        }

        await dbService.saveCacheItems(payload);
        return Response.ok(
          'Datos guardados en memoria',
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      } catch (e) {
        return _buildErrorResponse(
          400,
          'Bad Request',
          e.toString(),
          '/api/excel/cache',
        );
      }
    });

    // POST /api/excel/items - Procesar y consolidar archivos Excel
    router.post('/api/excel/items', (Request request) async {
      try {
        final bodyStr = await request.readAsString();
        final payload = jsonDecode(bodyStr);

        if (payload is! List) {
          return _buildErrorResponse(
            400,
            'Bad Request',
            'El cuerpo debe ser un arreglo JSON con rutas absolutas de archivos Excel.',
            '/api/excel/items',
          );
        }

        final List<String> paths = payload.map((p) => p.toString()).toList();
        final allItems = await excelService.processAllExcelFiles(paths);
        final consolidatedItems = await excelService.processAndGroupItems(
          allItems,
        );
        print('consolidatedItems.length: ${consolidatedItems}');
        print('consolidatedItems: $consolidatedItems');
        return Response.ok(
          jsonEncode(consolidatedItems),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } catch (e) {
        final status = (e is ArgumentError) ? 400 : 500;
        final errorType = (e is ArgumentError)
            ? 'Bad Request'
            : 'Internal Server Error';
        final message = e.toString().replaceFirst('Invalid argument(s): ', '');
        return _buildErrorResponse(
          status,
          errorType,
          message,
          '/api/excel/items',
        );
      }
    });

    // Pipeline de Middleware: logs y CORS habilitado
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders())
        .addHandler(router.call);

    // Escuchar en todas las interfaces en el puerto 8089
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8089);
    print(
      'Servidor API corriendo en http://${_server!.address.address}:${_server!.port}',
    );
  }

  /// Detiene el servidor HTTP
  Future<void> stop() async {
    await _server?.close(force: true);
    print('Servidor API detenido.');
  }

  /// Helper para formatear errores estandarizados según especificación
  Response _buildErrorResponse(
    int status,
    String error,
    String message,
    String path,
  ) {
    // Formato ISO-8601 YYYY-MM-DDTHH:mm:ss
    final timestamp = DateTime.now().toIso8601String().substring(0, 19);
    final errorBody = {
      'timestamp': timestamp,
      'status': status,
      'error': error,
      'message': message,
      'path': path,
    };
    return Response(
      status,
      body: jsonEncode(errorBody),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// Middleware para configurar CORS
Middleware corsHeaders() {
  final allowedOrigins = [
    'http://localhost:8019',
    'http://localhost:8018',
    'http://10.2.2.142:8019',
    'http://10.2.2.142:8018',
    'https://odoo18.cmp-operaciones.com',
    'https://odoo19.cmp-operaciones.com',
  ];

  return (Handler innerHandler) {
    return (Request request) async {
      final origin = request.headers['origin'];

      if (request.method == 'OPTIONS') {
        final headers = {
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': '*',
          'Access-Control-Allow-Credentials': 'true',
        };

        if (origin != null && allowedOrigins.contains(origin)) {
          headers['Access-Control-Allow-Origin'] = origin;
        } else if (origin != null) {
          headers['Access-Control-Allow-Origin'] = origin;
        } else {
          headers['Access-Control-Allow-Origin'] = '*';
        }

        return Response.ok('', headers: headers);
      }

      final response = await innerHandler(request);
      final headers = Map<String, String>.from(response.headers);

      if (origin != null && allowedOrigins.contains(origin)) {
        headers['Access-Control-Allow-Origin'] = origin;
      } else if (origin != null) {
        headers['Access-Control-Allow-Origin'] = origin;
      } else {
        headers['Access-Control-Allow-Origin'] = '*';
      }
      headers['Access-Control-Allow-Credentials'] = 'true';

      return response.change(headers: headers);
    };
  };
}
