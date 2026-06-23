import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../../core/providers/dependency_providers.dart';
 

class ServerPrinterView extends ConsumerStatefulWidget {
 
  
  const ServerPrinterView({super.key, });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ServerPrinterViewState();
}

class _ServerPrinterViewState extends ConsumerState<ServerPrinterView> {
    late TextEditingController _odooUrlController;
    @override
  void initState() {
    super.initState();

      _odooUrlController = TextEditingController();
  }

    @override
  void dispose() {
    _odooUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

     final theme = FTheme.of(context);
 

    return FScaffold(child:  SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Servidor de impresión',
            style: theme.typography.body.xl2.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const FDivider(),
          const SizedBox(height: 16),

          FCard(
            title: const Text('Emparejar Base de Datos'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FTextField(
                  control: FTextFieldControl.managed(
                    controller: _odooUrlController,
                  ),

                  label: const Text('URL del Servidor'),
                  description: const Text(
                    'Ingresa la dirección web de tu base de datos de Odoo.',
                  ),
                ),
                const SizedBox(height: 24),
                FButton(
                  onPress: () async {
                    showFToast(
                      context: context,
                      title: Text(
                        'Base de datos guardada: ${_odooUrlController.text}',
                      ),
                    );

                    final dbService = ref.read(databaseServiceProvider);
                    try {
                      await dbService.saveApiConfig('odoo', _odooUrlController.text);
                    } catch (e) {
                      ref.read(loggingServiceProvider).error('Error al guardar URL del servidor: $e');
                    }
                  },
                  prefix: const Icon(FLucideIcons.database),
                  child: const Text('Guardar y Vincular'),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}