import 'dart:io';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/dependency_providers.dart';
import '../../core/iot/iot_manager.dart';
import '../../core/services/logging_service.dart';
import '../widgets/status_badge.dart';
import 'devices_view.dart';
import 'server_printer_view.dart';

enum DashboardTab { overview, devices, wifi, odoo, logs }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardTab _currentTab = DashboardTab.overview;
  bool _showAdvanced = false;

  // Log viewer state
  List<String> _logs = [];
  bool _logsLoading = true;

  // Controllers for WiFi and Odoo
  late TextEditingController _wifiSsidController;
  late TextEditingController _wifiPasswordController;


  @override
  void initState() {
    super.initState();
    _wifiSsidController = TextEditingController();
    _wifiPasswordController = TextEditingController();
  
    _loadLogs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  Future<void> _loadConfig() async {
    final dbService = ref.read(databaseServiceProvider);
    try {
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

      final wifiSsid = config['wifi_ssid']?.toString();
      final wifiPassword = config['wifi_password']?.toString();

      if (mounted) {
        setState(() {
          // if (odooUrl != null && odooUrl.isNotEmpty) {
          //   _odooUrlController.text = odooUrl;
          // }
          if (wifiSsid != null && wifiSsid.isNotEmpty) {
            _wifiSsidController.text = wifiSsid;
          }
          if (wifiPassword != null && wifiPassword.isNotEmpty) {
            _wifiPasswordController.text = wifiPassword;
          }
        });
      }
    } catch (e) {
      ref.read(loggingServiceProvider).error('Error al cargar la configuración de base de datos: $e');
    }
  }

  @override
  void dispose() {
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
  
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _logsLoading = true;
    });
    final fetched = await LoggingService().readLastLogs(limit: 250);
    if (mounted) {
      setState(() {
        _logs = fetched;
        _logsLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showFDialog<bool>(
      context: context,
      builder: (context, s, a) => FDialog(
        title: const Text('¿Limpiar logs?'),
        body: const Text(
          'Esto vaciará el historial de logs de sincronización en el disco de manera permanente.',
        ),
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
    final iotState = ref.watch(iotStateProvider);
    final iotManager = ref.read(iotManagerProvider);
    final apiServer = ref.read(apiServerProvider);
    final windowTrayService = ref.read(windowTrayServiceProvider);
    final theme = FTheme.of(context);

    return FScaffold(
      sidebar: FSidebar(
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IoT Box',
                style: theme.typography.body.xl.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Desktop Sync',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        footer: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: StatusBadge()),
              const SizedBox(height: 12),
              FButton(
                variant: FButtonVariant.destructive,
                onPress: () async {
                  ref
                      .read(serverStatusProvider.notifier)
                      .setStatus(ServerStatus.inactive);
                  await apiServer.stop();
                  await windowTrayService.closeApp();
                },
                prefix: const Icon(FLucideIcons.power),
                child: const Text('Apagar Servidor'),
              ),
            ],
          ),
        ),
        children: [
          FSidebarGroup(
            label: const Text('Información'),
            children: [
              FSidebarItem(
                icon: const Icon(FLucideIcons.layoutDashboard),
                label: const Text('Resumen'),
                selected: _currentTab == DashboardTab.overview,
                onPress: () =>
                    setState(() => _currentTab = DashboardTab.overview),
              ),
              FSidebarItem(
                icon: const Icon(FLucideIcons.terminal),
                label: const Text('Logs de Actividad'),
                selected: _currentTab == DashboardTab.logs,
                onPress: () {
                  setState(() => _currentTab = DashboardTab.logs);
                  _loadLogs();
                },
              ),
            ],
          ),
          FSidebarGroup(
            label: const Text('Configuración'),
            children: [
              FSidebarItem(
                icon: const Icon(FLucideIcons.cpu),
                label: const Text('Dispositivos'),
                selected: _currentTab == DashboardTab.devices,
                onPress: () =>
                    setState(() => _currentTab = DashboardTab.devices),
              ),
              FSidebarItem(
                icon: const Icon(FLucideIcons.wifi),
                label: const Text('Red Wi-Fi'),
                selected: _currentTab == DashboardTab.wifi,
                onPress: () => setState(() => _currentTab = DashboardTab.wifi),
              ),
              FSidebarItem(
                icon: const Icon(FLucideIcons.database),
                label: const Text('Servidor de impresión'),
                selected: _currentTab == DashboardTab.odoo,
                onPress: () => setState(() => _currentTab = DashboardTab.odoo),
              ),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _buildBody(context, iotState, iotManager),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    IoTState iotState,
    IoTManager iotManager,
  ) {
    switch (_currentTab) {
      case DashboardTab.overview:
        return _buildOverviewTab(context, iotState);
      case DashboardTab.devices:
        return DevicesView(iotState: iotState, iotManager: iotManager);
      case DashboardTab.wifi:
        return _buildWifiTab(context);
      case DashboardTab.odoo:
        return ServerPrinterView();
      case DashboardTab.logs:
        return _buildLogsTab(context);
    }
  }

  Widget _buildOverviewTab(BuildContext context, IoTState iotState) {
    final theme = FTheme.of(context);

    final numDevices =
        iotState.iotDevices.length + iotState.unsupportedDevices.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumen del Sistema',
                style: theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              FButton(
                variant: FButtonVariant.outline,
                onPress: () => setState(() => _showAdvanced = !_showAdvanced),
                prefix: Icon(
                  _showAdvanced ? FLucideIcons.settings : FLucideIcons.sliders,
                ),
                child: Text(
                  _showAdvanced ? 'Ocultar Avanzado' : 'Mostrar Avanzado',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FDivider(),
          const SizedBox(height: 16),

          // Certificate warning
          FAlert(
            icon: const Icon(FLucideIcons.triangleAlert),
            title: const Text("Este IoT Box no tiene un certificado válido."),
            subtitle: const Text(
              "El IoT Box debería obtener un certificado automáticamente al emparejarse con una base de datos. Si no lo hace, intenta reiniciarlo.",
            ),
            variant: FAlertVariant.destructive,
          ),
          const SizedBox(height: 16),

          FCard(
            title: const Text('Información del Dispositivo'),
            child: Column(
              children: [
                FTile(
                  prefix: const Icon(FLucideIcons.idCard),
                  title: const Text('Identificador'),
                  subtitle: const Text('iot_box_desktop_sync'),
                ),
                if (_showAdvanced) ...[
                  FTile(
                    prefix: const Icon(FLucideIcons.network),
                    title: const Text('Dirección MAC'),
                    subtitle: const Text('00:1A:2B:3C:4D:5E'),
                  ),
                  FTile(
                    prefix: const Icon(FLucideIcons.cpu),
                    title: const Text('Versión'),
                    subtitle: const Text('v26.05.30'),
                    suffix: FButton(
                      variant: FButtonVariant.outline,
                      onPress: () {
                        showFToast(
                          context: context,
                          title: const Text(
                            'Verificando actualizaciones... Todos los paquetes están actualizados.',
                          ),
                        );
                      },
                      child: const Text('Actualizar'),
                    ),
                  ),
                  FTile(
                    prefix: const Icon(FLucideIcons.globe),
                    title: const Text('Dirección IP'),
                    subtitle: const Text('197.168.1.104'),
                  ),
                ],
                FTile(
                  prefix: const Icon(FLucideIcons.wifi),
                  title: const Text('Estado de Internet'),
                  subtitle: Text(
                    Platform.isWindows
                        ? 'Conexión Ethernet'
                        : 'Wi-Fi: Local_Network',
                  ),
                  suffix: FButton(
                    variant: FButtonVariant.outline,
                    onPress: () =>
                        setState(() => _currentTab = DashboardTab.wifi),
                    child: const Text('Configurar'),
                  ),
                ),
                FTile(
                  prefix: const Icon(FLucideIcons.database),
                  title: const Text('Base de Datos Odoo'),
                  subtitle: Text(
                    ref.watch(serverStatusProvider) == ServerStatus.active
                        ? 'Conectado'
                        : 'No Conectado',
                  ),
                  suffix: FButton(
                    variant: FButtonVariant.outline,
                    onPress: () =>
                        setState(() => _currentTab = DashboardTab.odoo),
                    child: const Text('Configurar'),
                  ),
                ),
                FTile(
                  prefix: const Icon(FLucideIcons.power),
                  title: const Text('Dispositivos'),
                  subtitle: Text('$numDevices dispositivos conectados'),
                  suffix: FButton(
                    variant: FButtonVariant.outline,
                    onPress: () =>
                        setState(() => _currentTab = DashboardTab.devices),
                    child: const Text('Administrar'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          FCard(
            title: const Text('Acciones Rápidas'),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FButton(
                  onPress: () {
                    showFToast(
                      context: context,
                      title: const Text(
                        'Se ha abierto el panel de visualización de estado.',
                      ),
                    );
                  },
                  child: const Text('Pantalla de Estado'),
                ),
                FButton(
                  onPress: () {
                    showFToast(
                      context: context,
                      title: const Text('Servidor de impresión abierto.'),
                    );
                  },
                  child: const Text('Servidor de Impresión'),
                ),
                if (_showAdvanced) ...[
                  FButton(
                    onPress: () {
                      showFToast(
                        context: context,
                        title: const Text(
                          'Activando/desactivando el túnel de depuración remota...',
                        ),
                      );
                    },
                    child: const Text('Depuración Remota'),
                  ),
                  FButton(
                    onPress: () {
                      showFToast(
                        context: context,
                        title: const Text(
                          'Descargando nuevamente los controladores de cajas IoT.',
                        ),
                      );
                    },
                    child: const Text('Descargar Handlers'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiTab(BuildContext context) {
    final theme = FTheme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración Wi-Fi',
            style: theme.typography.body.xl2.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const FDivider(),
          const SizedBox(height: 16),

          FCard(
            title: const Text('Establecer Conexión Inalámbrica'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FTextField(
                  control: FTextFieldControl.managed(
                    controller: _wifiSsidController,
                  ),

                  label: const Text('Nombre de Red (SSID)'),
                  description: const Text(
                    'Introduce el nombre de tu red Wi-Fi.',
                  ),
                ),
                const SizedBox(height: 16),
                FTextField(
                  control: FTextFieldControl.managed(
                    controller: _wifiPasswordController,
                  ),

                  label: const Text('Contraseña'),
                  description: const Text('Introduce la clave de seguridad.'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                FButton(
                  onPress: () async {
                    showFToast(
                      context: context,
                      title: Text(
                        'Conectando a ${_wifiSsidController.text}...',
                      ),
                    );

                    final dbService = ref.read(databaseServiceProvider);
                    try {
                      await dbService.replaceConfig({
                        'wifi_ssid': _wifiSsidController.text,
                        'wifi_password': _wifiPasswordController.text,
                      });
                    } catch (e) {
                      ref.read(loggingServiceProvider).error('Error al guardar config Wi-Fi: $e');
                    }
                  },
                  prefix: const Icon(FLucideIcons.wifi),
                  child: const Text('Conectar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 
  Widget _buildLogsTab(BuildContext context) {
    final theme = FTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logs de Actividad',
          style: theme.typography.body.xl2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const FDivider(),
        const SizedBox(height: 16),

        Expanded(
          child: _logsLoading
              ? const Center(child: FCircularProgress())
              : (_logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay registros de logs de actividad.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      )
                    : Container(
                        width: double.infinity,
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
                              textColor = Colors.amber;
                            } else if (logLine.contains('[INFO]')) {
                              textColor = Colors.green;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
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
        const SizedBox(height: 16),

        Row(
          children: [
            FButton(
              variant: FButtonVariant.destructive,
              onPress: _clearLogs,
              prefix: const Icon(FLucideIcons.trash2),
              child: const Text('Limpiar Historial'),
            ),
            const SizedBox(width: 12),
            FButton(
              variant: FButtonVariant.outline,
              onPress: _loadLogs,
              prefix: const Icon(FLucideIcons.refreshCw),
              child: const Text('Refrescar'),
            ),
          ],
        ),
      ],
    );
  }
}
