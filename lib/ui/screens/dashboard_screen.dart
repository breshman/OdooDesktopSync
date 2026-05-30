// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/dependency_providers.dart';
import '../widgets/status_badge.dart';
import '../widgets/info_card.dart';
import '../widgets/logs_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider);
    final isActive = status == ServerStatus.active;

    final apiServer = ref.read(apiServerProvider);
    final windowTrayService = ref.read(windowTrayServiceProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B0F19), // Dark slate
              Color(0xFF1E1B4B), // Indigo dark
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior / Cabecera
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.sync_alt_rounded,
                            color: Color(0xFF818CF8),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Odoo Desktop Sync',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Servidor Local de Sincronización',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8), // Slate 400
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const StatusBadge(),
                  ],
                ),
                const SizedBox(height: 32),

                // Grid de información del servidor
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                    children: [
                      InfoCard(
                        icon: Icons.lan_rounded,
                        title: 'Dirección Local',
                        value: isActive
                            ? 'http://localhost:8089'
                            : 'Desconectado',
                        color: Colors.cyanAccent,
                      ),
                      InfoCard(
                        icon: Icons.health_and_safety_rounded,
                        title: 'Estado del Servidor',
                        value: isActive ? 'Saludable (200 OK)' : 'Detenido',
                        color: isActive
                            ? const Color(0xFF10B981)
                            : Colors.redAccent,
                      ),
                      InfoCard(
                        icon: Icons.code_rounded,
                        title: 'Ruta GET de Estado',
                        value: '/status',
                        color: Colors.orangeAccent,
                      ),
                      InfoCard(
                        icon: Icons.layers_rounded,
                        title: 'Versión del Sistema',
                        value: 'v26.05.16',
                        color: Colors.purpleAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tarjeta informativa sobre el comportamiento en segundo plano
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF818CF8),
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Modo de Ejecución en Segundo Plano',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Si cierras esta ventana presionando la "X", la aplicación seguirá ejecutándose de forma invisible en la bandeja de sistema.',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1), // Slate 300
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Fila de botones de acción
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => showLogsDialog(context),
                      icon: const Icon(Icons.terminal_rounded),
                      label: const Text('Ver Logs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await windowTrayService.hide();
                      },
                      icon: const Icon(Icons.visibility_off_rounded),
                      label: const Text('Ocultar al Tray'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        ref
                            .read(serverStatusProvider.notifier)
                            .setStatus(ServerStatus.inactive);
                        await apiServer.stop();
                        await windowTrayService.closeApp();
                      },
                      icon: const Icon(Icons.power_settings_new_rounded),
                      label: const Text('Cerrar Servidor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.15),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
