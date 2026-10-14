import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/device_connection/domain/device_status.dart';

void main() {
  group('DeviceStatus Model Tests', () {
    test('parses full standard ESP32-CAM status JSON correctly', () {
      final json = {
        'device': 'VisionAssist-Cap',
        'camera': 'ready',
        'ip': '192.168.4.1',
        'sosCount': 2,
      };

      final status = DeviceStatus.fromJson(json);
      expect(status.device, equals('VisionAssist-Cap'));
      expect(status.camera, equals('ready'));
      expect(status.ip, equals('192.168.4.1'));
      expect(status.sosCount, equals(2));
      expect(status.isCameraReady, isTrue);
    });

    test('handles missing or null JSON fields safely with defaults', () {
      final json = <String, dynamic>{};
      final status = DeviceStatus.fromJson(json);

      expect(status.device, equals('VisionAssist-Cap'));
      expect(status.camera, equals('unknown'));
      expect(status.ip, equals('192.168.4.1'));
      expect(status.sosCount, equals(0));
      expect(status.isCameraReady, isFalse);
    });

    test('parses string representations of sosCount', () {
      final json = {
        'device': 'VisionAssist-Cap',
        'camera': 'ready',
        'ip': '192.168.4.1',
        'sosCount': '5',
      };
      final status = DeviceStatus.fromJson(json);
      expect(status.sosCount, equals(5));
    });

    test('detects camera hardware not ready', () {
      final json = {
        'device': 'VisionAssist-Cap',
        'camera': 'init_failed',
        'ip': '192.168.4.1',
        'sosCount': 0,
      };
      final status = DeviceStatus.fromJson(json);
      expect(status.isCameraReady, isFalse);
    });

    test('trims whitespace and handles mixed-case camera status', () {
      final json = {'camera': ' READY '};
      final status = DeviceStatus.fromJson(json);
      expect(status.isCameraReady, isTrue);
    });

    test('equality and copyWith work as expected', () {
      final now = DateTime(2026, 10, 10, 12, 0);
      final s1 = DeviceStatus(
        device: 'Cap1',
        camera: 'ready',
        ip: '192.168.4.1',
        sosCount: 1,
        timestamp: now,
      );
      final s2 = s1.copyWith(sosCount: 2);
      expect(s2.sosCount, equals(2));
      expect(s2.device, equals('Cap1'));
      expect(s1 == s2, isFalse);
    });
  });
}
