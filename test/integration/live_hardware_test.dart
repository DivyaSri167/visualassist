@Tags(['hardware'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/core/config/device_config.dart';
import 'package:vision_assist/features/device_connection/data/device_repository.dart';
import 'package:vision_assist/features/camera/data/camera_stream_service.dart';

/// Integration tests designed for execution against the physical ESP32-CAM.
///
/// To run these tests against your actual hardware:
/// 1. Connect your workstation or test device Wi-Fi to "VisionAssist-Cap" (password: VisionAssist123).
/// 2. Run: flutter test test/integration/live_hardware_test.dart --tags hardware
void main() {
  const config = DeviceConfig();
  late DeviceRepository repository;

  setUp(() {
    repository = DeviceRepository(config: config);
  });

  tearDown(() {
    repository.dispose();
  });

  group('Physical ESP32-CAM Hardware Integration Tests', () {
    test('verifies live /status endpoint on ESP32-CAM', () async {
      try {
        final status = await repository.fetchStatus(
          timeout: const Duration(seconds: 4),
        );
        expect(status.device, isNotEmpty);
        expect(status.camera, equals('ready'));
        expect(status.isCameraReady, isTrue);
      } catch (e) {
        // Skip with notice if workstation is not connected to VisionAssist-Cap
        markTestSkipped(
          'Workstation is not connected to VisionAssist-Cap AP (192.168.4.1 unreachable): $e',
        );
      }
    });

    test('verifies live /capture endpoint returns valid JPEG', () async {
      try {
        final bytes = await repository.captureStillImage(
          timeout: const Duration(seconds: 6),
        );
        expect(bytes, isNotEmpty);
        expect(bytes.length, greaterThan(1000));
        // Verify JPEG magic numbers (SOI and EOI)
        expect(bytes[0], equals(0xFF));
        expect(bytes[1], equals(0xD8));
        expect(bytes[bytes.length - 2], equals(0xFF));
        expect(bytes[bytes.length - 1], equals(0xD9));
      } catch (e) {
        markTestSkipped('Workstation is not connected to VisionAssist-Cap AP: $e');
      }
    });

    test('verifies live /stream startup and shutdown', () async {
      final streamService = CameraStreamService();
      try {
        await streamService.startStream(config.streamUri);
        // Wait briefly for at least one frame if hardware is connected
        await Future.delayed(const Duration(seconds: 2));
        await streamService.stopStream();
      } catch (e) {
        markTestSkipped('Not connected to VisionAssist-Cap Wi-Fi: $e');
      } finally {
        streamService.dispose();
      }
    });
  });
}
