// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'logging_service.dart';

class WindowTrayService {
  /// Inicializa la ventana principal para arranque oculto
  final LoggingService _loggingService = LoggingService();
  Future<void> initWindow() async {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 800),
      minimumSize: Size(700, 450),
      center: true,
      backgroundColor: Color(0xFF0B0F19),
      titleBarStyle: TitleBarStyle.normal,
      title: 'Odoo Desktop Sync',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  /// Inicializa el System Tray y el menú contextual
  Future<void> initTray(TrayListener listener) async {
    trayManager.addListener(listener);

    String iconPath = Platform.isWindows
        ? 'assets/images/app_icon.ico'
        : 'assets/images/app_icon.png';

    try {
      await trayManager.setIcon(iconPath);
    } catch (e) {
      _loggingService.error('Error al cargar el icono del System Tray: $e');
      
    }

    final List<MenuItem> menuItems = [
      MenuItem(key: 'show_panel', label: 'Mostrar Panel'),
      MenuItem.separator(),
      MenuItem(key: 'close_server', label: 'Cerrar Servidor'),
    ];

    await trayManager.setContextMenu(Menu(items: menuItems));
  }

  /// Añade un listener para eventos de ventana
  void addWindowListener(WindowListener listener) {
    windowManager.addListener(listener);
  }

  /// Remueve un listener de ventana
  void removeWindowListener(WindowListener listener) {
    windowManager.removeListener(listener);
  }

  /// Remueve un listener del System Tray
  void removeTrayListener(TrayListener listener) {
    trayManager.removeListener(listener);
  }

  /// Muestra y enfoca la ventana principal
  Future<void> showAndFocus() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Oculta la ventana principal
  Future<void> hide() async {
    await windowManager.hide();
  }

  /// Finaliza el proceso y cierra la aplicación
  Future<void> closeApp() async {
    exit(0);
  }
}
