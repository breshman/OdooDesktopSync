import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../../core/services/logging_service.dart';

void showLogsDialog(BuildContext context) {
  showFDialog(
    context: context,
    builder: (context, style, animation) => const LogsDialog(),
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
    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('¿Limpiar logs?'),
        body: const Text('Esto vaciará el historial de logs de sincronización en el disco de manera permanente.'),
        actions: [
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FButton(
            variant: FButtonVariant.destructive,
            onPress: () => Navigator.of(context).pop(true),
            child: const Text('Limpiar'),
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
    final theme = FTheme.of(context);

    return FDialog(
      title: Row(
        children: [
          Icon(
            FLucideIcons.terminal,
            color: theme.colors.primary,
          ),
          const SizedBox(width: 12),
          const Text('Logs de Sincronización'),
        ],
      ),
      body: SizedBox(
        width: 600,
        height: 400,
        child: _loading
            ? const Center(
                child: FCircularProgress(),
              )
            : (_logs.isEmpty
                ? const Center(
                    child: Text(
                      'No hay registros de logs de actividad.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colors.muted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final logLine = _logs[index];

                        Color textColor = theme.colors.foreground;
                        if (logLine.contains('[ERROR]')) {
                          textColor = theme.colors.destructive;
                        } else if (logLine.contains('[WARNING]')) {
                          textColor = Colors.amber; // Fallback or warning color if needed
                        } else if (logLine.contains('[INFO]')) {
                          textColor = Colors.green; // Fallback positive color
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            logLine,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'Courier',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  )),
      ),
      actions: [
        FButton(
          variant: FButtonVariant.destructive,
          onPress: _clearLogs,
          prefix: const Icon(FLucideIcons.trash2),
          child: const Text('Limpiar Historial'),
        ),
        FButton(
          variant: FButtonVariant.outline,
          onPress: _loadLogs,
          prefix: const Icon(FLucideIcons.refreshCw),
          child: const Text('Refrescar'),
        ),
        FButton(
          onPress: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

