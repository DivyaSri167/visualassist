import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/core/config/device_config.dart';

void main() {
  group('DeviceConfig Tests', () {
    test('default configuration values match ESP32-CAM defaults', () {
      const config = DeviceConfig();
      expect(config.host, equals('192.168.4.1'));
      expect(config.port, equals(80));
      expect(config.baseUrl, equals('http://192.168.4.1'));
      expect(config.statusUri.toString(), equals('http://192.168.4.1/status'));
      expect(
        config.captureUri.toString(),
        equals('http://192.168.4.1/capture'),
      );
      expect(config.streamUri.toString(), equals('http://192.168.4.1/stream'));
      expect(config.sosUri.toString(), equals('http://192.168.4.1/sos'));
    });

    test('custom host and port derive correct URIs', () {
      const config = DeviceConfig(host: '192.168.1.100', port: 8080);
      expect(config.baseUrl, equals('http://192.168.1.100:8080'));
      expect(
        config.statusUri.toString(),
        equals('http://192.168.1.100:8080/status'),
      );
      expect(
        config.captureUri.toString(),
        equals('http://192.168.1.100:8080/capture'),
      );
      expect(
        config.streamUri.toString(),
        equals('http://192.168.1.100:8080/stream'),
      );
      expect(config.sosUri.toString(), equals('http://192.168.1.100:8080/sos'));
    });

    test('sanitizeHost cleans protocol prefixes and trailing slashes', () {
      expect(
        DeviceConfig.sanitizeHost('http://192.168.4.1/'),
        equals('192.168.4.1'),
      );
      expect(
        DeviceConfig.sanitizeHost('https://192.168.4.1/'),
        equals('192.168.4.1'),
      );
      expect(
        DeviceConfig.sanitizeHost('  192.168.4.5  '),
        equals('192.168.4.5'),
      );
      expect(DeviceConfig.sanitizeHost(''), equals(DeviceConfig.defaultHost));
    });

    test('copyWith updates host while preserving other properties', () {
      const config = DeviceConfig();
      final updated = config.copyWith(host: '10.0.0.5');
      expect(updated.host, equals('10.0.0.5'));
      expect(updated.port, equals(80));
    });

    test('value equality holds for identical configurations', () {
      const c1 = DeviceConfig(host: '192.168.4.1', port: 80);
      const c2 = DeviceConfig(host: '192.168.4.1', port: 80);
      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
    });
  });
}
