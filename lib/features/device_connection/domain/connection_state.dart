import 'device_status.dart';

/// Connection states matching the hardware lifecycle of the ESP32-CAM.
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  cameraUnavailable,
  streaming,
  reconnecting,
  error,
}

/// Immutable state holder for ESP32-CAM connectivity.
class DeviceConnectionState {
  final ConnectionStatus status;
  final DeviceStatus? deviceStatus;
  final DateTime? lastSuccessfulResponse;
  final String? errorMessage;
  final String? troubleshootingGuide;

  const DeviceConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.deviceStatus,
    this.lastSuccessfulResponse,
    this.errorMessage,
    this.troubleshootingGuide,
  });

  bool get isConnected =>
      status == ConnectionStatus.connected ||
      status == ConnectionStatus.streaming;

  bool get isConnecting =>
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.reconnecting;

  bool get isCameraReady =>
      (deviceStatus?.isCameraReady ?? false) &&
      status != ConnectionStatus.cameraUnavailable;

  DeviceConnectionState copyWith({
    ConnectionStatus? status,
    DeviceStatus? deviceStatus,
    DateTime? lastSuccessfulResponse,
    String? errorMessage,
    String? troubleshootingGuide,
    bool clearError = false,
  }) {
    return DeviceConnectionState(
      status: status ?? this.status,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      lastSuccessfulResponse:
          lastSuccessfulResponse ?? this.lastSuccessfulResponse,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      troubleshootingGuide: clearError
          ? null
          : (troubleshootingGuide ?? this.troubleshootingGuide),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceConnectionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          deviceStatus == other.deviceStatus &&
          lastSuccessfulResponse == other.lastSuccessfulResponse &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      deviceStatus.hashCode ^
      lastSuccessfulResponse.hashCode ^
      errorMessage.hashCode;

  @override
  String toString() =>
      'DeviceConnectionState(status: $status, device: ${deviceStatus?.device}, err: $errorMessage)';
}
