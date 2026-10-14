/// Configuration for ESP32-CAM communication and endpoints.
class DeviceConfig {
  static const String defaultHost = '192.168.4.1';
  static const int defaultPort = 80;
  static const String defaultSsid = 'VisionAssist-Cap';
  static const String defaultPassword = 'VisionAssist123';

  final String host;
  final int port;

  const DeviceConfig({this.host = defaultHost, this.port = defaultPort});

  /// Sanitized host without leading protocol or trailing slashes
  static String sanitizeHost(String input) {
    var cleaned = input.trim();
    if (cleaned.startsWith('http://')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('https://')) {
      cleaned = cleaned.substring(8);
    }
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned.isEmpty ? defaultHost : cleaned;
  }

  /// Base URL e.g. http://192.168.4.1
  String get baseUrl => port == 80 ? 'http://$host' : 'http://$host:$port';

  /// GET /status
  Uri get statusUri => Uri.parse('$baseUrl/status');

  /// GET /capture
  Uri get captureUri => Uri.parse('$baseUrl/capture');

  /// GET /stream
  Uri get streamUri => Uri.parse('$baseUrl/stream');

  /// POST /sos
  Uri get sosUri => Uri.parse('$baseUrl/sos');

  DeviceConfig copyWith({String? host, int? port}) {
    return DeviceConfig(host: host ?? this.host, port: port ?? this.port);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;

  @override
  String toString() => 'DeviceConfig(baseUrl: $baseUrl)';
}
