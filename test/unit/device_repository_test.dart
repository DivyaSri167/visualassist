import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vision_assist/core/config/device_config.dart';
import 'package:vision_assist/core/errors/app_exception.dart';
import 'package:vision_assist/features/device_connection/data/device_repository.dart';

/// Test HTTP client that redirects requests to customizable response handlers.
class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  group('DeviceRepository HTTP Tests', () {
    const config = DeviceConfig();

    test('fetchStatus succeeds with valid 200 JSON and ready camera', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url, equals(config.statusUri));
        final body = json.encode({
          'device': 'VisionAssist-Cap',
          'camera': 'ready',
          'ip': '192.168.4.1',
          'sosCount': 3,
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = DeviceRepository(client: mockClient, config: config);
      final status = await repo.fetchStatus();

      expect(status.device, equals('VisionAssist-Cap'));
      expect(status.camera, equals('ready'));
      expect(status.sosCount, equals(3));
      expect(status.isCameraReady, isTrue);
    });

    test(
      'fetchStatus throws CameraHardwareException if camera is not ready',
      () async {
        final mockClient = MockHttpClient((request) async {
          final body = json.encode({
            'device': 'VisionAssist-Cap',
            'camera': 'init_error',
            'ip': '192.168.4.1',
            'sosCount': 0,
          });
          return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
        });

        final repo = DeviceRepository(client: mockClient, config: config);
        expect(
          () => repo.fetchStatus(),
          throwsA(isA<CameraHardwareException>()),
        );
      },
    );

    test(
      'fetchStatus throws InvalidStatusResponseException on HTTP 500 error',
      () async {
        final mockClient = MockHttpClient((request) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode('Internal Server Error')),
            500,
          );
        });

        final repo = DeviceRepository(client: mockClient, config: config);
        expect(
          () => repo.fetchStatus(),
          throwsA(isA<InvalidStatusResponseException>()),
        );
      },
    );

    test(
      'fetchStatus throws InvalidStatusResponseException on invalid JSON',
      () async {
        final mockClient = MockHttpClient((request) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode('NOT_JSON_BODY')),
            200,
          );
        });

        final repo = DeviceRepository(client: mockClient, config: config);
        expect(
          () => repo.fetchStatus(),
          throwsA(isA<InvalidStatusResponseException>()),
        );
      },
    );

    test(
      'fetchStatus translates SocketException to DeviceUnreachableException',
      () async {
        final mockClient = MockHttpClient((request) async {
          throw const SocketException('Host unreachable');
        });

        final repo = DeviceRepository(client: mockClient, config: config);
        expect(
          () => repo.fetchStatus(),
          throwsA(isA<DeviceUnreachableException>()),
        );
      },
    );

    test('captureStillImage returns bytes for valid JPEG payload', () async {
      final validJpeg = [0xFF, 0xD8, 0x12, 0x34, 0xFF, 0xD9];
      final mockClient = MockHttpClient((request) async {
        expect(request.url, equals(config.captureUri));
        return http.StreamedResponse(
          Stream.value(validJpeg),
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      final repo = DeviceRepository(client: mockClient, config: config);
      final bytes = await repo.captureStillImage();

      expect(bytes, equals(validJpeg));
    });

    test(
      'captureStillImage throws InvalidImageResponseException on invalid JPEG',
      () async {
        final invalidBytes = [0x00, 0x11, 0x22, 0x33]; // Missing SOI/EOI
        final mockClient = MockHttpClient((request) async {
          return http.StreamedResponse(Stream.value(invalidBytes), 200);
        });

        final repo = DeviceRepository(client: mockClient, config: config);
        expect(
          () => repo.captureStillImage(),
          throwsA(isA<InvalidImageResponseException>()),
        );
      },
    );

    test('sendTestSos succeeds on 200 response', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url, equals(config.sosUri));
        expect(request.method, equals('POST'));
        return http.StreamedResponse(Stream.value([]), 200);
      });

      final repo = DeviceRepository(client: mockClient, config: config);
      await expectLater(repo.sendTestSos(), completes);
    });

    test('sendTestSos throws DeviceOperationException on failure', () async {
      final mockClient = MockHttpClient((request) async {
        return http.StreamedResponse(Stream.value([]), 503);
      });

      final repo = DeviceRepository(client: mockClient, config: config);
      expect(
        () => repo.sendTestSos(),
        throwsA(isA<DeviceOperationException>()),
      );
    });
  });
}
