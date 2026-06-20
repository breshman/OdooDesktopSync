import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'core/providers/dependency_providers.dart';
import 'core/services/logging_service.dart';
import 'core/services/window_tray_service.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/widgets/logs_dialog.dart';
import 'core/iot/iot_manager.dart';
import 'core/iot/websocket_client.dart';
import 'core/iot/drivers/printer_driver.dart';
import 'core/iot/drivers/scale_driver.dart';
import 'core/iot/interfaces/printer_interface.dart';
import 'core/iot/interfaces/serial_interface.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Crear contenedor Riverpod para inyección y arranque seguro antes de runApp()
  final container = ProviderContainer();

  // Ejecutar la aplicación inmediatamente. La inicialización de base de datos
  // y del servidor HTTP se hará después, desde el propio widget.
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with TrayListener, WindowListener {
  late WindowTrayService _windowTrayService;
  bool _initializing = true;
  String? _initializationError;
  bool _initializationFailed = false;
  late LoggingService _loggingService;
  WebSocketClient? _wsClient;

  @override
  void initState() {
    super.initState();
    _windowTrayService = ref.read(windowTrayServiceProvider);
    _loggingService = ref.read(loggingServiceProvider);

    // Configurar System Tray y registrar a esta instancia como Listener de bandeja y ventana
    _windowTrayService.initTray(this);
    _windowTrayService.addWindowListener(this);

    // Inicializar ventana nativa después de que la UI esté lista,
    // para evitar interferencias con el lanzamiento en macOS.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _windowTrayService.initWindow();
      await _initializeServices();
    });
  }

  @override
  void dispose() {
    _wsClient?.stop();
    ref.read(iotManagerProvider).stopAll();
    _windowTrayService.removeTrayListener(this);
    _windowTrayService.removeWindowListener(this);
    super.dispose();
  }

  // --- Implementación de TrayListener ---
  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_panel') {
      await _windowTrayService.showAndFocus();
    } else if (menuItem.key == 'close_server') {
      final apiServer = ref.read(apiServerProvider);
      ref.read(serverStatusProvider.notifier).setStatus(ServerStatus.inactive);
      await apiServer.stop();
      await _windowTrayService.closeApp();
    }
  }

  // --- Implementación de WindowListener ---
  @override
  void onWindowMinimize() async {
    // Al minimizar la ventana, la ocultamos por completo para que no aparezca en la barra de tareas
    await _windowTrayService.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Odoo Desktop Sync',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1), // Indigo
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Dark Slate
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: _initializing
          ? _LoadingScreen(errorMessage: _initializationError)
          : (_initializationFailed
              ? _ErrorScreen(errorMessage: _initializationError)
              : const DashboardScreen()),
    );
  }

  Future<void> _initializeServices() async {
    final dbService = ref.read(databaseServiceProvider);
    final apiServer = ref.read(apiServerProvider);

    try {
      await dbService.init();
      await apiServer.start();

      // Initialize IoT drivers and interfaces
      PrinterDriver.register();
      ScaleDriver.register();

      final IoTManager iotManager = ref.read(iotManagerProvider);
      iotManager.addInterface(PrinterInterface(allowUnsupported: false));
      iotManager.addInterface(SerialInterface(allowUnsupported: true));
      await iotManager.startAll();

      // Check if Odoo database server is configured to start websocket client
      final config = await dbService.getConfig();
      final List apiConfigs = config['api'] ?? [];
      String? odooUrl;
      for (final api in apiConfigs) {
        final name = api['name']?.toString().toLowerCase() ?? '';
        if (name.contains('odoo') || name.contains('test') || name.contains('produc')) {
          odooUrl = api['url'];
          break;
        }
      }
      odooUrl ??= apiConfigs.isNotEmpty ? apiConfigs.first['url'] : null;

      if (odooUrl != null && odooUrl.isNotEmpty && odooUrl != 'https://api.miempresa.com') {
        _wsClient = WebSocketClient(
          serverUrl: odooUrl,
          channel: 'iot_channel_desktop_sync',
          loggingService: _loggingService,
          identifier: 'iot_box_desktop_sync',
        );
        _wsClient!.start();
      }

      ref.read(serverStatusProvider.notifier).setStatus(ServerStatus.active);
    } catch (e, stack) {
      _initializationError = e.toString();
      _initializationFailed = true;
      _loggingService.error('Error inicializando servicios: $e');
      _loggingService.error('Stack trace: $stack');

    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({this.errorMessage, super.key});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6366F1)),
              const SizedBox(height: 24),
              const Text(
                'Iniciando aplicación...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ??
                    'Por favor espera mientras se inicializan los servicios.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.errorMessage, super.key});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 72,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'No se pudo inicializar la aplicación',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage ?? 'Verifica permisos y vuelve a intentar.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reinicia la aplicación después de corregir el problema.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => showLogsDialog(context),
                icon: const Icon(Icons.terminal_rounded),
                label: const Text('Ver Logs de Error'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
