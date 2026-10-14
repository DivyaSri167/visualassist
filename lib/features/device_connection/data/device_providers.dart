import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/device_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/connection_state.dart';
import 'device_repository.dart';

const String _prefKeyHost = 'esp32_cam_host';

/// Provider for managing and persisting ESP32-CAM host configuration.
class DeviceConfigNotifier extends Notifier<DeviceConfig> {
  @override
  DeviceConfig build() {
    _loadPersistedHost();
    return const DeviceConfig();
  }

  Future<void> _loadPersistedHost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHost = prefs.getString(_prefKeyHost);
      if (savedHost != null && savedHost.isNotEmpty) {
        state = DeviceConfig(host: DeviceConfig.sanitizeHost(savedHost));
      }
    } catch (_) {
      // Fallback silently to default config if SharedPreferences unavailable
    }
  }

  Future<void> updateHost(String newHost) async {
    final sanitized = DeviceConfig.sanitizeHost(newHost);
    state = state.copyWith(host: sanitized);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyHost, sanitized);
    } catch (_) {}
  }

  Future<void> resetToDefault() async {
    state = const DeviceConfig();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyHost);
    } catch (_) {}
  }
}

final deviceConfigProvider =
    NotifierProvider<DeviceConfigNotifier, DeviceConfig>(() {
      return DeviceConfigNotifier();
    });

/// Device repository provider reacting to config changes.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final config = ref.watch(deviceConfigProvider);
  final repo = DeviceRepository(config: config);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// State management for device connection lifecycle.
class DeviceConnectionNotifier extends Notifier<DeviceConnectionState> {
  @override
  DeviceConnectionState build() {
    return const DeviceConnectionState();
  }

  /// Proactively connects to ESP32-CAM and queries /status.
  Future<bool> checkConnection({bool isReconnect = false}) async {
    state = state.copyWith(
      status: isReconnect
          ? ConnectionStatus.reconnecting
          : ConnectionStatus.connecting,
      clearError: true,
    );

    final repository = ref.read(deviceRepositoryProvider);

    try {
      final status = await repository.fetchStatus();

      state = state.copyWith(
        status: status.isCameraReady
            ? ConnectionStatus.connected
            : ConnectionStatus.cameraUnavailable,
        deviceStatus: status,
        lastSuccessfulResponse: DateTime.now(),
        clearError: true,
      );
      return status.isCameraReady;
    } on CameraHardwareException catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.cameraUnavailable,
        errorMessage: e.message,
        troubleshootingGuide: e.troubleshootingGuide,
      );
      return false;
    } on AppException catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.message,
        troubleshootingGuide: e.troubleshootingGuide,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Connection failed: $e',
        troubleshootingGuide:
            'Verify phone is connected to "VisionAssist-Cap" Wi-Fi.',
      );
      return false;
    }
  }

  void setStreaming(bool isStreaming) {
    if (isStreaming) {
      if (state.status == ConnectionStatus.connected) {
        state = state.copyWith(status: ConnectionStatus.streaming);
      }
    } else {
      if (state.status == ConnectionStatus.streaming) {
        state = state.copyWith(status: ConnectionStatus.connected);
      }
    }
  }

  void disconnect() {
    state = const DeviceConnectionState(status: ConnectionStatus.disconnected);
  }

  Future<bool> triggerSosTest() async {
    final repository = ref.read(deviceRepositoryProvider);
    try {
      await repository.sendTestSos();
      // Re-fetch status to update sosCount if device is reachable
      await checkConnection();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final deviceConnectionProvider =
    NotifierProvider<DeviceConnectionNotifier, DeviceConnectionState>(() {
      return DeviceConnectionNotifier();
    });
