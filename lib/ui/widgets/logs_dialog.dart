import 'package:flutter/material.dart';
import '../../core/services/logging_service.dart';

void showLogsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LogsDialog(),
  );
}

class LogsDialog extends StatefulWidget {
  const LogsDialog({super.key});

  @override
  State<LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends State<LogsDialog> {
  List<String> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
    });
    final fetched = await LoggingService().readLastLogs(limit: 250);
    if (mounted) {
      setState(() {
        _logs = fetched;
        _loading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Limpiar logs?'),
        content: const Text('Esto vaciará el historial de logs de sincronización en el disco de manera permanente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Limpiar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LoggingService().clearLogs();
      await LoggingService().info('Historial de logs limpiado por el usuario.');
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A), // Slate-900
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.terminal_rounded,
                        color: Color(0xFF818CF8),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Logs de Sincronización',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Console Terminal View
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617), // Rich dark slate-950
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                      )
                    : (_logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay registros de logs de actividad.',
                              style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                          )
                        : ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final logLine = _logs[index];

                              // Asignar colores según la severidad del log
                              Color textColor = const Color(0xFFE2E8F0); // Slate-200 (Default)
                              if (logLine.contains('[ERROR]')) {
                                textColor = const Color(0xFFF87171); // Soft red
                              } else if (logLine.contains('[WARNING]')) {
                                textColor = const Color(0xFFFBBF24); // Soft amber
                              } else if (logLine.contains('[INFO]')) {
                                textColor = const Color(0xFF34D399); // Soft emerald
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  logLine,
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'Courier', // Monospace terminal style
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          )),
              ),
            ),
            const SizedBox(height: 20),

            // Footer Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _clearLogs,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Limpiar Historial'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.12),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _loadLogs,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refrescar'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF818CF8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
