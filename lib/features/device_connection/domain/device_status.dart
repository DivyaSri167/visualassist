/// Domain model representing the response from the ESP32-CAM `/status` endpoint.
class DeviceStatus {
  final String device;
  final String camera;
  final String ip;
  final int sosCount;
  final DateTime timestamp;

  const DeviceStatus({
    required this.device,
    required this.camera,
    required this.ip,
    required this.sosCount,
    required this.timestamp,
  });

  /// Whether the OV2640 camera hardware is reported as ready.
  bool get isCameraReady => camera.trim().toLowerCase() == 'ready';

  /// Safe JSON deserialization with fallbacks and type conversion.
  factory DeviceStatus.fromJson(
    Map<String, dynamic> json, {
    DateTime? timestamp,
  }) {
    final deviceVal = json['device']?.toString() ?? 'VisionAssist-Cap';
    final cameraVal = json['camera']?.toString() ?? 'unknown';
    final ipVal = json['ip']?.toString() ?? '192.168.4.1';

    int parsedSos = 0;
    final rawSos = json['sosCount'];
    if (rawSos is int) {
      parsedSos = rawSos;
    } else if (rawSos is String) {
      parsedSos = int.tryParse(rawSos) ?? 0;
    } else if (rawSos is num) {
      parsedSos = rawSos.toInt();
    }

    return DeviceStatus(
      device: deviceVal,
      camera: cameraVal,
      ip: ipVal,
      sosCount: parsedSos,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'device': device,
    'camera': camera,
    'ip': ip,
    'sosCount': sosCount,
    'timestamp': timestamp.toIso8601String(),
  };

  DeviceStatus copyWith({
    String? device,
    String? camera,
    String? ip,
    int? sosCount,
    DateTime? timestamp,
  }) {
    return DeviceStatus(
      device: device ?? this.device,
      camera: camera ?? this.camera,
      ip: ip ?? this.ip,
      sosCount: sosCount ?? this.sosCount,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceStatus &&
          runtimeType == other.runtimeType &&
          device == other.device &&
          camera == other.camera &&
          ip == other.ip &&
          sosCount == other.sosCount;

  @override
  int get hashCode =>
      device.hashCode ^ camera.hashCode ^ ip.hashCode ^ sosCount.hashCode;

  @override
  String toString() =>
      'DeviceStatus(device: $device, camera: $camera, ip: $ip, sos: $sosCount, ready: $isCameraReady)';
}
