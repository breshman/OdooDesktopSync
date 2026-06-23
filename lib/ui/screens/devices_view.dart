import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../../core/iot/iot_manager.dart';
import '../../core/iot/drivers/scale_driver.dart';
import '../../core/iot/drivers/printer_driver.dart';
 

class DevicesView extends ConsumerStatefulWidget {
  final IoTState iotState;
  final IoTManager iotManager;
  
  const DevicesView({super.key, required this.iotState, required this.iotManager});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DevicesViewState();
}

class _DevicesViewState extends ConsumerState<DevicesView> {

  @override
  Widget build(BuildContext context) {

     final theme = FTheme.of(context);
    final devicesList = widget.iotState.iotDevices.values.toList();
    final unsupportedList = widget.iotState.unsupportedDevices.values.toList();

    return FScaffold(child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administración de Dispositivos',
            style: theme.typography.body.xl2.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const FDivider(),
          const SizedBox(height: 16),

          if (devicesList.isEmpty && unsupportedList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No hay dispositivos conectados.'),
              ),
            ),

          if (devicesList.isNotEmpty) ...[
            Text('Controladores de Sistema Activos', style: theme.typography.body.lg.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...devicesList.map((device) {
              final isScale = device is ScaleDriver;
              final isPrinter = device is PrinterDriver;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: FCard(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(device.deviceName)),
                      FBadge(
                        child: Text(device.deviceType.toUpperCase()),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Identificador: ${device.identifier}'),
                      Text('Conexión: ${device.deviceConnection}'),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isScale) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Peso Simulado: ${device.data['value']} kg',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                FButton(
                                  variant: FButtonVariant.outline,
                                  onPress: () {
                                    setState(() {
                                      device.setSimulatedWeight(0.0);
                                    });
                                  },
                                  child: const Text('Cero'),
                                ),
                                const SizedBox(width: 8),
                                FButton(
                                  variant: FButtonVariant.outline,
                                  onPress: () {
                                    setState(() {
                                      final current = (device.data['value'] as num).toDouble();
                                      device.setSimulatedWeight(double.parse((current + 0.500).toStringAsFixed(3)));
                                    });
                                  },
                                  child: const Text('+0.5kg'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      if (isPrinter) ...[
                        const SizedBox(height: 12),
                        FButton(
                          onPress: () {
                            device.action({
                              'action': 'print_receipt',
                              'receipt': '================================\n'
                                  '        ODOO DESKTOP SYNC       \n'
                                  '        TEST TICKET SUCCESS      \n'
                                  '================================\n'
                                  'System device prints successfully.\n'
                                  'Date: ${DateTime.now().toLocal()}\n'
                                  '================================\n'
                            });
                            showFToast(
                              context: context,
                              title: const Text('Se ha enviado la tarea de impresión de prueba.'),
                            );
                          },
                          prefix: const Icon(FLucideIcons.printer),
                          child: const Text('Imprimir Ticket de Prueba'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],

          if (unsupportedList.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Dispositivos no Soportados', style: theme.typography.body.lg.copyWith(color: theme.colors.destructive, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...unsupportedList.map((device) {
              return FTile(
                prefix: Icon(FLucideIcons.alertTriangle, color: theme.colors.destructive),
                title: Text(device['name'] ?? 'Dispositivo desconocido'),
                subtitle: Text('Puerto: ${device['connection']} | Identificador: ${device['identifier']}'),
              );
            }),
          ],
        ],
      ),
    ));
  }
}