import 'dart:typed_data';

/// Represents a single JPEG frame decoded from the MJPEG stream or still capture.
class CameraFrame {
  final Uint8List bytes;
  final DateTime timestamp;
  final int frameIndex;

  const CameraFrame({
    required this.bytes,
    required this.timestamp,
    this.frameIndex = 0,
  });

  int get byteLength => bytes.length;

  /// Approximate size formatted for UI display
  String get sizeFormatted {
    if (byteLength < 1024) return '$byteLength B';
    final kb = (byteLength / 1024).toStringAsFixed(1);
    return '$kb KB';
  }
}
