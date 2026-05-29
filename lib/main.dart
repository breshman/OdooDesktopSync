import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'core/providers/dependency_providers.dart';
import 'core/services/window_tray_service.dart';
import 'ui/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crear contenedor Riverpod para inyección y arranque seguro antes de runApp()
  final container = ProviderContainer();

  // 1. Obtener instancias concretas a través del contenedor de proveedores
  final dbService = container.read(databaseServiceProvider);
  final windowTrayService = container.read(windowTrayServiceProvider);
  final apiServer = container.read(apiServerProvider);

  // 2. Inicializar base de datos SQLite y limpieza de caché
  await dbService.init();

  // 3. Iniciar servidor REST local
  await apiServer.start();

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with TrayListener, WindowListener {
  late WindowTrayService _windowTrayService;

  @override
  void initState() {
    super.initState();
    _windowTrayService = ref.read(windowTrayServiceProvider);

    // Configurar System Tray y registrar a esta instancia como Listener de bandeja y ventana
    _windowTrayService.initTray(this);
    _windowTrayService.addWindowListener(this);

    // Inicializar ventana nativa después de que la UI esté lista,
    // para evitar interferencias con el lanzamiento en macOS.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _windowTrayService.initWindow();
    });
  }

  @override
  void dispose() {
    _windowTrayService.removeTrayListener(this);
    _windowTrayService.removeWindowListener(this);
    super.dispose();
  }

  // --- Implementación de WindowListener ---
  @override
  void onWindowClose() async {
    // Intercepta botón 'X' de la ventana para ocultar de forma invisible al Tray
    await _windowTrayService.hide();
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
      home: const DashboardScreen(),
    );
  }
}
