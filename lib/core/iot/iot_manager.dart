import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logging_service.dart';
import 'iot_driver.dart';
import 'iot_interface.dart';

typedef DriverFactory = IoTDriver Function(String identifier, dynamic device);

/// Represents a registered driver factory and its matching criteria.
class DriverRegistryEntry {
  final DriverFactory factory;
  final String connectionType;
  final int priority;
  final bool Function(dynamic device) supported;

  DriverRegistryEntry({
    required this.factory,
    required this.connectionType,
    required this.priority,
    required this.supported,
  });
}

/// Holds the current snapshot of connected and unsupported IoT devices.
class IoTState {
  final Map<String, IoTDriver> iotDevices;
  final Map<String, Map<String, dynamic>> unsupportedDevices;

  const IoTState({required this.iotDevices, required this.unsupportedDevices});
}

/// Coordinates IoT interfaces, drivers, and device state updates.
class IoTManager {
  static final IoTManager _instance = IoTManager._internal();
  static IoTManager get instance => _instance;

  late LoggingService loggingService;
  late Ref ref;

  final Map<String, IoTDriver> iotDevices = {};
  final Map<String, Map<String, dynamic>> unsupportedDevices = {};
  final List<IoTInterface> interfaces = [];

  static final List<DriverRegistryEntry> driverRegistry = [];

  // Active event stream for /iot_drivers/event (long polling)
  final List<Map<String, dynamic>> events = [];
  final List<Completer<Map<String, dynamic>>> _pendingEventRequests = [];

  IoTManager._internal();

  /// Initializes the manager with logging and Riverpod references.
  void init(LoggingService logs, Ref refInstance) {
    loggingService = logs;
    ref = refInstance;
  }

  /// Publishes the latest device state to the Riverpod notifier.
  void notifyStateChanged() {
    ref
        .read(iotStateProvider.notifier)
        .updateState(iotDevices, unsupportedDevices);
  }

  /// Registers a new driver implementation for a specific connection type.
  static void registerDriver({
    required DriverFactory factory,
    required String connectionType,
    required int priority,
    required bool Function(dynamic device) supported,
  }) {
    driverRegistry.add(
      DriverRegistryEntry(
        factory: factory,
        connectionType: connectionType,
        priority: priority,
        supported: supported,
      ),
    );
    // Sort by priority descending
    driverRegistry.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Returns the first compatible driver entry for the given device.
  DriverRegistryEntry? findCompatibleDriver(
    String connectionType,
    dynamic device,
  ) {
    for (final entry in driverRegistry) {
      if (entry.connectionType == connectionType && entry.supported(device)) {
        return entry;
      }
    }
    return null;
  }

  /// Broadcasts a device event to all pending listeners.
  void triggerDeviceEvent(
    String deviceIdentifier,
    Map<String, dynamic> response,
  ) {
    final event = {
      'time': DateTime.now().millisecondsSinceEpoch / 1000.0,
      'device_identifier': deviceIdentifier,
      ...response,
    };
    events.add(event);

    // Keep events from the last 5 seconds only to prevent memory bloat
    final oldestTime = (DateTime.now().millisecondsSinceEpoch / 1000.0) - 5;
    events.removeWhere((e) => (e['time'] as double) < oldestTime);

    // Resolve any pending long polling requests
    final pendingToResolve = List<Completer<Map<String, dynamic>>>.from(
      _pendingEventRequests,
    );
    _pendingEventRequests.clear();
    for (final completer in pendingToResolve) {
      completer.complete(event);
    }
  }

  /// Waits for the next matching device event within the timeout window.
  Future<Map<String, dynamic>?> waitForEvent(
    Map<String, dynamic> listener,
  ) async {
    final devices = List<String>.from(listener['devices'] ?? []);
    final double lastEventTime =
        (listener['last_event'] as num?)?.toDouble() ?? 0.0;

    // Check if we already have a newer event matching criteria
    for (final event in events) {
      if (devices.contains(event['device_identifier']) &&
          (event['time'] as double) > lastEventTime) {
        return event;
      }
    }

    // Otherwise register a completer and wait for next event with a timeout
    final completer = Completer<Map<String, dynamic>>();
    _pendingEventRequests.add(completer);

    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 40),
      );
      if (devices.contains(result['device_identifier'])) {
        return result;
      }
      return null;
    } on TimeoutException {
      _pendingEventRequests.remove(completer);
      return null;
    }
  }

  /// Registers an IoT interface to be managed by this instance.
  void addInterface(IoTInterface interface) {
    interfaces.add(interface);
  }

  /// Starts all registered interfaces and refreshes the UI state.
  Future<void> startAll() async {
    loggingService.info(
      'Starting IoT Manager with ${interfaces.length} active interfaces.',
    );
    for (final interface in interfaces) {
      await interface.start();
    }
    notifyStateChanged();
  }

  /// Stops all interfaces and clears the current device lists.
  Future<void> stopAll() async {
    loggingService.info('Stopping all IoT interfaces.');
    for (final interface in interfaces) {
      await interface.stop();
    }
    iotDevices.clear();
    unsupportedDevices.clear();
    notifyStateChanged();
  }
}

/// Riverpod notifier that keeps the IoT state snapshot up to date.
class IoTStateNotifier extends Notifier<IoTState> {
  @override
  IoTState build() {
    return const IoTState(iotDevices: {}, unsupportedDevices: {});
  }

  /// Replaces the state with a copy of the current device maps.
  void updateState(
    Map<String, IoTDriver> iotDevices,
    Map<String, Map<String, dynamic>> unsupportedDevices,
  ) {
    state = IoTState(
      iotDevices: Map.from(iotDevices),
      unsupportedDevices: Map.from(unsupportedDevices),
    );
  }
}

final iotStateProvider = NotifierProvider<IoTStateNotifier, IoTState>(
  IoTStateNotifier.new,
);
