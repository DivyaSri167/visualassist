import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/device_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/networking/mjpeg_stream_parser.dart';
import '../domain/device_status.dart';

/// Repository handling HTTP network operations with the ESP32-CAM.
class DeviceRepository {
  final http.Client _client;
  final DeviceConfig config;

  DeviceRepository({http.Client? client, required this.config})
    : _client = client ?? http.Client();

  /// Queries the ESP32-CAM `/status` endpoint.
  Future<DeviceStatus> fetchStatus({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final response = await _client.get(config.statusUri).timeout(timeout);

      if (response.statusCode != 200) {
        throw InvalidStatusResponseException(
          'ESP32-CAM responded with HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final Map<String, dynamic> jsonBody;
      try {
        jsonBody = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw InvalidStatusResponseException(
          'Failed to parse JSON response from ESP32-CAM: ${response.body}',
          statusCode: response.statusCode,
          cause: e,
        );
      }

      final status = DeviceStatus.fromJson(jsonBody);

      if (!status.isCameraReady) {
        throw CameraHardwareException(
          'Camera sensor is not ready (status reported: "${status.camera}")',
        );
      }

      return status;
    } on TimeoutException catch (e) {
      throw ConnectionTimeoutException(
        'Request to ${config.statusUri} timed out after ${timeout.inSeconds}s.',
        cause: e,
      );
    } on SocketException catch (e) {
      throw DeviceUnreachableException(
        'Cannot reach ESP32-CAM at ${config.host}. Please verify Wi-Fi connection.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw DeviceUnreachableException(
        'Network error contacting ${config.host}: ${e.message}',
        cause: e,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw DeviceUnreachableException(
        'Unexpected connection error: $e',
        cause: e,
      );
    }
  }

  /// Downloads a single JPEG frame from the `/capture` endpoint.
  Future<Uint8List> captureStillImage({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final response = await _client.get(config.captureUri).timeout(timeout);

      if (response.statusCode != 200) {
        throw InvalidImageResponseException(
          'ESP32-CAM capture failed with HTTP ${response.statusCode}',
        );
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty || !MjpegStreamParser.isValidJpeg(bytes)) {
        throw const InvalidImageResponseException(
          'Captured payload was empty or missing valid JPEG markers (SOI/EOI).',
        );
      }

      return bytes;
    } on TimeoutException catch (e) {
      throw ConnectionTimeoutException(
        'Still image capture from ${config.captureUri} timed out after ${timeout.inSeconds}s.',
        cause: e,
      );
    } on SocketException catch (e) {
      throw DeviceUnreachableException(
        'Cannot reach ESP32-CAM at ${config.host}. Check Wi-Fi connection.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw DeviceUnreachableException(
        'HTTP error during still capture: ${e.message}',
        cause: e,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw InvalidImageResponseException(
        'Error fetching still image: $e',
        cause: e,
      );
    }
  }

  /// Triggers a test SOS event on the ESP32-CAM via POST `/sos`.
  Future<void> sendTestSos({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final response = await _client.post(config.sosUri).timeout(timeout);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw DeviceOperationException(
          'ESP32-CAM SOS endpoint responded with HTTP ${response.statusCode}',
          troubleshootingGuide: 'Note: If a live video stream is running, the ESP32-CAM synchronous web server may reject or block SOS requests.',
        );
      }
    } on TimeoutException catch (e) {
      throw ConnectionTimeoutException(
        'POST ${config.sosUri} timed out.',
        troubleshootingGuide: 'If an MJPEG stream is active, stop it before sending SOS due to synchronous server limitations.',
        cause: e,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DeviceOperationException('Failed to send test SOS: $e', cause: e);
    }
  }

  void dispose() {
    _client.close();
  }
}
