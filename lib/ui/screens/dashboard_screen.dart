import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/dependency_providers.dart';
import '../../core/iot/iot_manager.dart';
import '../../core/iot/drivers/scale_driver.dart';
import '../../core/iot/drivers/printer_driver.dart';
import '../widgets/logs_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the IoT manager registry
    final iotState = ref.watch(iotStateProvider);
    final iotManager = ref.read(iotManagerProvider);
    final status = ref.watch(serverStatusProvider);
    final isActive = status == ServerStatus.active;
    final apiServer = ref.read(apiServerProvider);
    final windowTrayService = ref.read(windowTrayServiceProvider);

    final numDevices = iotState.iotDevices.length + iotState.unsupportedDevices.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Odoo background gray (#F1F1F1 / #F3F4F6)
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 80), // spacer to center the title
                          const Expanded(
                            child: Text(
                              'IoT Box',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827), // Dark Gray
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Advanced Cog Button
                              IconButton(
                                icon: Icon(
                                  _showAdvanced ? Icons.settings : Icons.settings_suggest,
                                  color: const Color(0xFF714B67), // Odoo Purple
                                ),
                                tooltip: 'Toggle Advanced Settings',
                                onPressed: () {
                                  setState(() {
                                    _showAdvanced = !_showAdvanced;
                                  });
                                },
                              ),
                              // Shutdown Power Button
                              IconButton(
                                icon: const Icon(
                                  Icons.power_settings_new,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Shutdown Server',
                                onPressed: () async {
                                  ref
                                      .read(serverStatusProvider.notifier)
                                      .setStatus(ServerStatus.inactive);
                                  await apiServer.stop();
                                  await windowTrayService.closeApp();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Missing Certificate Warning (Yellow Alert)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7), // Amber 100
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "This IoT Box doesn't have a valid certificate.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E), // Amber 800
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "The IoT Box should get a certificate automatically when paired with a database. If it doesn't, try to restart it.",
                              style: TextStyle(
                                color: Color(0xFFB45309), // Amber 700
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List Rows (SingleData equivalents)
                      SingleDataRow(
                        name: 'Identifier',
                        value: 'iot_box_desktop_sync',
                        icon: Icons.badge_outlined,
                      ),

                      if (_showAdvanced) ...[
                        SingleDataRow(
                          name: 'Mac Address',
                          value: '00:1A:2B:3C:4D:5E',
                          icon: Icons.dns_outlined,
                        ),
                        SingleDataRow(
                          name: 'Version',
                          value: 'v26.05.30',
                          icon: Icons.memory_outlined,
                          trailingButton: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Checking for updates... All packages up to date.')),
                              );
                            },
                            child: const Text('Update', style: TextStyle(color: Color(0xFF714B67))),
                          ),
                        ),
                        SingleDataRow(
                          name: 'IP Address',
                          value: '197.168.1.104',
                          icon: Icons.public_outlined,
                        ),
                      ],

                      SingleDataRow(
                        name: 'Internet Status',
                        value: Platform.isWindows ? 'Ethernet Connection' : 'Wi-Fi: Local_Network',
                        icon: Icons.wifi_outlined,
                        trailingButton: TextButton(
                          onPressed: () => _showWiFiConfigDialog(context),
                          child: const Text('Configure', style: TextStyle(color: Color(0xFF714B67))),
                        ),
                      ),

                      SingleDataRow(
                        name: 'Odoo Database Connected',
                        value: isActive ? 'Connected (http://localhost:8089)' : 'Not Connected',
                        icon: Icons.link_outlined,
                        trailingButton: TextButton(
                          onPressed: () => _showServerConfigDialog(context),
                          child: const Text('Configure', style: TextStyle(color: Color(0xFF714B67))),
                        ),
                      ),

                      SingleDataRow(
                        name: 'Devices',
                        value: '$numDevices connected devices',
                        icon: Icons.power_outlined,
                        trailingButton: TextButton(
                          onPressed: () => _showDevicesDialog(context, iotState, iotManager),
                          child: const Text('Configure', style: TextStyle(color: Color(0xFF714B67))),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 16),

                      // Footer Action Buttons (styled in Odoo Purple and Gray)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildOdooButton(
                            label: 'Status Display',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Status Display dashboard opened.')),
                              );
                            },
                          ),
                          _buildOdooButton(
                            label: 'Printer Server',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Printer CUPS interface opened.')),
                              );
                            },
                          ),
                          if (_showAdvanced) ...[
                            _buildOdooButton(
                              label: 'Remote Debug',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Toggling remote debug tunnel...')),
                                );
                              },
                            ),
                            _buildOdooButton(
                              label: 'Configure Handlers',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Re-downloading IoT box handlers.')),
                                );
                              },
                            ),
                          ],
                          _buildOdooButton(
                            label: 'View Logs',
                            onPressed: () => showLogsDialog(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Help', style: TextStyle(color: Color(0xFF714B67), fontSize: 13)),
                          ),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Documentation', style: TextStyle(color: Color(0xFF714B67), fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOdooButton({required String label, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF714B67), // Odoo Purple
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showDevicesDialog(BuildContext context, IoTState iotState, IoTManager iotManager) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final devicesList = iotState.iotDevices.values.toList();
            final unsupportedList = iotState.unsupportedDevices.values.toList();

            return AlertDialog(
              title: const Text('Devices Connected'),
              content: SizedBox(
                width: double.maxFinite,
                child: devicesList.isEmpty && unsupportedList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No devices connected.', textAlign: TextAlign.center),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          if (devicesList.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Active System Drivers', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ...devicesList.map((device) {
                              final isScale = device is ScaleDriver;
                              final isPrinter = device is PrinterDriver;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            device.deviceName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF714B67).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              device.deviceType.toUpperCase(),
                                              style: const TextStyle(
                                                color: Color(0xFF714B67),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Identifier: ${device.identifier}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text('Connection: ${device.deviceConnection}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      
                                      if (isScale) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Simulated Weight: ${device.data['value']} kg',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () {
                                                    setDialogState(() {
                                                      device.setSimulatedWeight(0.0);
                                                    });
                                                  },
                                                  child: const Text('Zero'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    setDialogState(() {
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
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
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
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Test print task dispatched.')),
                                            );
                                          },
                                          icon: const Icon(Icons.print, size: 16),
                                          label: const Text('Print Test Receipt', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF714B67),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                          if (unsupportedList.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Unsupported System Devices', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            ),
                            ...unsupportedList.map((device) {
                              return ListTile(
                                leading: const Icon(Icons.warning, color: Colors.amber),
                                title: Text(device['name'] ?? 'Unknown device'),
                                subtitle: Text('Identifier: ${device['identifier']} (Port: ${device['connection']})'),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF714B67))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWiFiConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wi-Fi Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              TextField(
                decoration: InputDecoration(
                  labelText: 'SSID / Network Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF714B67), foregroundColor: Colors.white),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  void _showServerConfigDialog(BuildContext context) {
    final serverController = TextEditingController(text: 'https://miempresa.odoo.com');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configure Odoo Database'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serverController,
                decoration: const InputDecoration(
                  labelText: 'Database / Server URL',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                // In production, we would save this to SQLite config
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Database URL updated to: ${serverController.text}')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF714B67), foregroundColor: Colors.white),
              child: const Text('Save & Pair'),
            ),
          ],
        );
      },
    );
  }
}

class SingleDataRow extends StatelessWidget {
  final String name;
  final String value;
  final IconData icon;
  final Widget? trailingButton;

  const SingleDataRow({
    required this.name,
    required this.value,
    required this.icon,
    this.trailingButton,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF714B67), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF6B7280), // Gray 500
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF111827), // Gray 900
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingButton != null) trailingButton!,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
        ],
      ),
    );
  }
}
