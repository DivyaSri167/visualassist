/// Application domain exceptions with accessible troubleshooting guidance.
abstract class AppException implements Exception {
  final String message;
  final String? troubleshootingGuide;
  final Object? cause;

  const AppException(this.message, {this.troubleshootingGuide, this.cause});

  @override
  String toString() => message;
}

/// Thrown when the phone cannot establish a network connection to the ESP32-CAM.
class DeviceUnreachableException extends AppException {
  const DeviceUnreachableException(
    super.message, {
    super.troubleshootingGuide = 'Ensure Wi-Fi is turned on and your phone is connected to the "VisionAssist-Cap" network. If Android warned that the network has no internet access, choose "Keep Wi-Fi Connection".',
    super.cause,
  });
}

/// Thrown when an HTTP request to the ESP32-CAM times out.
class ConnectionTimeoutException extends AppException {
  const ConnectionTimeoutException(
    super.message, {
    super.troubleshootingGuide = 'The ESP32-CAM did not respond in time. Make sure the cap is powered on and within range, or try restarting the ESP32-CAM.',
    super.cause,
  });
}

/// Thrown when the /status endpoint returns a non-200 code or malformed JSON.
class InvalidStatusResponseException extends AppException {
  final int? statusCode;

  const InvalidStatusResponseException(
    super.message, {
    this.statusCode,
    super.troubleshootingGuide = 'The ESP32-CAM responded with an unexpected status or malformed data. Verify the device firmware is running the VisionAssist API.',
    super.cause,
  });
}

/// Thrown when the device is reachable but reports the camera hardware is not ready.
class CameraHardwareException extends AppException {
  const CameraHardwareException(
    super.message, {
    super.troubleshootingGuide = 'The ESP32-CAM is online, but the OV2640 camera sensor failed to initialize or is busy. Check ribbon cable connection and power supply.',
    super.cause,
  });
}

/// Thrown when /capture does not return a valid JPEG payload.
class InvalidImageResponseException extends AppException {
  const InvalidImageResponseException(
    super.message, {
    super.troubleshootingGuide = 'Captured payload was empty or not a valid JPEG. Ensure the camera lens is clean and the sensor is operational.',
    super.cause,
  });
}

/// Thrown when the MJPEG stream fails or drops unexpectedly.
class StreamConnectionException extends AppException {
  const StreamConnectionException(
    super.message, {
    super.troubleshootingGuide = 'The video stream disconnected. If another stream session was open, close it. Remember that the ESP32-CAM supports only one active stream at a time.',
    super.cause,
  });
}

/// Thrown when a request collides with an active MJPEG stream on the synchronous server.
class StreamConcurrencyException extends AppException {
  const StreamConcurrencyException(
    super.message, {
    super.troubleshootingGuide = 'The ESP32-CAM synchronous web server cannot process status or capture while a live stream is active. Stop the video stream first.',
    super.cause,
  });
}

/// Thrown when a generic device command (e.g. SOS trigger) fails.
class DeviceOperationException extends AppException {
  const DeviceOperationException(
    super.message, {
    super.troubleshootingGuide,
    super.cause,
  });
}
