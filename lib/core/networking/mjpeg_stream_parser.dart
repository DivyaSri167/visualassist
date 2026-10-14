import 'dart:async';
import 'dart:typed_data';

/// Parses continuous multipart MJPEG HTTP streams into discrete JPEG frames.
///
/// Handles custom boundaries (e.g., the ESP32-CAM default `frame`), arbitrary
/// chunking, missing Content-Length headers, and bounded memory consumption.
class MjpegStreamParser {
  static const int jpegSoi0 = 0xFF;
  static const int jpegSoi1 = 0xD8;
  static const int jpegEoi0 = 0xFF;
  static const int jpegEoi1 = 0xD9;

  /// Maximum buffer size (1MB) allowed before dropping corrupted stream bytes
  /// to prevent unbounded memory growth.
  static const int maxBufferSize = 1024 * 1024;

  final String boundary;

  MjpegStreamParser({String? boundary}) : boundary = boundary ?? 'frame';

  /// Extracts the boundary parameter from a Content-Type header.
  /// Defaults to 'frame' if unspecified or malformed.
  static String extractBoundary(String? contentType) {
    if (contentType == null || contentType.isEmpty) {
      return 'frame';
    }
    final regex = RegExp(r'boundary=([^\s;]+)', caseSensitive: false);
    final match = regex.firstMatch(contentType);
    if (match != null && match.groupCount >= 1) {
      var extracted = match.group(1) ?? 'frame';
      // Strip optional quotes or hyphens
      if (extracted.startsWith('"') && extracted.endsWith('"')) {
        extracted = extracted.substring(1, extracted.length - 1);
      }
      if (extracted.startsWith('--')) {
        extracted = extracted.substring(2);
      }
      return extracted.isNotEmpty ? extracted : 'frame';
    }
    return 'frame';
  }

  /// Validates whether a byte list is a valid JPEG structure (SOI and EOI present).
  static bool isValidJpeg(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final startsWithSoi = bytes[0] == jpegSoi0 && bytes[1] == jpegSoi1;
    final endsWithEoi =
        bytes[bytes.length - 2] == jpegEoi0 &&
        bytes[bytes.length - 1] == jpegEoi1;
    return startsWithSoi && endsWithEoi;
  }

  /// Transforms an arbitrary chunked byte stream into a stream of complete JPEG frames.
  Stream<Uint8List> parseStream(Stream<List<int>> byteStream) async* {
    final buffer = BytesBuilder(copy: false);

    await for (final chunk in byteStream) {
      buffer.add(chunk);

      // Guard against unbounded memory consumption
      if (buffer.length > maxBufferSize) {
        final currentBytes = buffer.toBytes();
        // Attempt to find the next JPEG SOI marker and recover
        final nextSoi = _findSoi(currentBytes, 1);
        buffer.clear();
        if (nextSoi != -1) {
          buffer.add(currentBytes.sublist(nextSoi));
        } else {
          // No recovery point found, drop buffer to protect memory
          continue;
        }
      }

      Uint8List currentBytes = buffer.toBytes();

      while (true) {
        final soiIndex = _findSoi(currentBytes, 0);
        if (soiIndex == -1) {
          // No SOI yet; keep only the last byte in case SOI is split across chunks
          if (currentBytes.isNotEmpty) {
            final lastByte = currentBytes[currentBytes.length - 1];
            buffer.clear();
            if (lastByte == jpegSoi0) {
              buffer.addByte(lastByte);
            }
          }
          break;
        }

        // Search for EOI after SOI
        final eoiIndex = _findEoi(currentBytes, soiIndex + 2);
        if (eoiIndex == -1) {
          // Frame is incomplete; keep buffer from soiIndex onwards
          if (soiIndex > 0) {
            final remaining = currentBytes.sublist(soiIndex);
            buffer.clear();
            buffer.add(remaining);
          }
          break;
        }

        // Complete frame found from soiIndex to eoiIndex + 1 (inclusive)
        final frameBytes = Uint8List.fromList(
          currentBytes.sublist(soiIndex, eoiIndex + 2),
        );

        if (isValidJpeg(frameBytes)) {
          yield frameBytes;
        }

        // Advance buffer past this frame
        final nextStartIndex = eoiIndex + 2;
        if (nextStartIndex < currentBytes.length) {
          currentBytes = currentBytes.sublist(nextStartIndex);
          buffer.clear();
          buffer.add(currentBytes);
        } else {
          buffer.clear();
          break;
        }
      }
    }

    buffer.clear();
  }

  static int _findSoi(Uint8List data, int start) {
    final len = data.length - 1;
    for (int i = start; i < len; i++) {
      if (data[i] == jpegSoi0 && data[i + 1] == jpegSoi1) {
        return i;
      }
    }
    return -1;
  }

  static int _findEoi(Uint8List data, int start) {
    final len = data.length - 1;
    for (int i = start; i < len; i++) {
      if (data[i] == jpegEoi0 && data[i + 1] == jpegEoi1) {
        return i;
      }
    }
    return -1;
  }
}
