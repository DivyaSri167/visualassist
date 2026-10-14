import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/core/networking/mjpeg_stream_parser.dart';

void main() {
  group('MjpegStreamParser Tests', () {
    test(
      'extractBoundary parses standard and non-standard Content-Type headers',
      () {
        expect(
          MjpegStreamParser.extractBoundary(
            'multipart/x-mixed-replace; boundary=frame',
          ),
          equals('frame'),
        );
        expect(
          MjpegStreamParser.extractBoundary(
            'multipart/x-mixed-replace; boundary="esp32_cam"',
          ),
          equals('esp32_cam'),
        );
        expect(
          MjpegStreamParser.extractBoundary(
            'multipart/x-mixed-replace; boundary=--boundary123',
          ),
          equals('boundary123'),
        );
        expect(MjpegStreamParser.extractBoundary(null), equals('frame'));
        expect(
          MjpegStreamParser.extractBoundary('application/octet-stream'),
          equals('frame'),
        );
      },
    );

    test('isValidJpeg checks start-of-image (SOI) and end-of-image (EOI)', () {
      final valid = Uint8List.fromList([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9]);
      expect(MjpegStreamParser.isValidJpeg(valid), isTrue);

      final invalidStart = Uint8List.fromList([
        0x00,
        0xD8,
        0x01,
        0x02,
        0xFF,
        0xD9,
      ]);
      expect(MjpegStreamParser.isValidJpeg(invalidStart), isFalse);

      final invalidEnd = Uint8List.fromList([
        0xFF,
        0xD8,
        0x01,
        0x02,
        0xFF,
        0x00,
      ]);
      expect(MjpegStreamParser.isValidJpeg(invalidEnd), isFalse);

      final tooShort = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      expect(MjpegStreamParser.isValidJpeg(tooShort), isFalse);
    });

    test(
      'parseStream extracts single complete JPEG from multipart stream',
      () async {
        final parser = MjpegStreamParser(boundary: 'frame');

        // Construct multipart payload with headers and JPEG body
        final rawData = <int>[
          // --frame header
          ...('--frame\r\nContent-Type: image/jpeg\r\n\r\n'.codeUnits),
          // JPEG payload
          0xFF, 0xD8, 0xAA, 0xBB, 0xCC, 0xFF, 0xD9,
          // Trailing newline
          13, 10,
        ];

        final controller = StreamController<List<int>>();
        final framesFuture = parser.parseStream(controller.stream).toList();

        controller.add(rawData);
        await controller.close();

        final frames = await framesFuture;
        expect(frames.length, equals(1));
        expect(frames[0], equals([0xFF, 0xD8, 0xAA, 0xBB, 0xCC, 0xFF, 0xD9]));
      },
    );

    test(
      'parseStream extracts multiple frames delivered in arbitrary byte chunks',
      () async {
        final parser = MjpegStreamParser(boundary: 'frame');

        final frame1 = [0xFF, 0xD8, 0x11, 0x22, 0xFF, 0xD9];
        final frame2 = [0xFF, 0xD8, 0x33, 0x44, 0x55, 0xFF, 0xD9];

        final rawStreamBytes = <int>[
          ...('--frame\r\nContent-Type: image/jpeg\r\n\r\n'.codeUnits),
          ...frame1,
          ...('\r\n--frame\r\nContent-Type: image/jpeg\r\n\r\n'.codeUnits),
          ...frame2,
          ...('\r\n'.codeUnits),
        ];

        final controller = StreamController<List<int>>();
        final framesFuture = parser.parseStream(controller.stream).toList();

        // Chunk into tiny 3-byte fragments to simulate arbitrary TCP fragmentation
        for (int i = 0; i < rawStreamBytes.length; i += 3) {
          final end = (i + 3 < rawStreamBytes.length)
              ? i + 3
              : rawStreamBytes.length;
          controller.add(rawStreamBytes.sublist(i, end));
        }
        await controller.close();

        final frames = await framesFuture;
        expect(frames.length, equals(2));
        expect(frames[0], equals(frame1));
        expect(frames[1], equals(frame2));
      },
    );

    test('parseStream ignores noise and recovers when SOI is found', () async {
      final parser = MjpegStreamParser();

      final noise = [0x01, 0x02, 0x03, 0x04];
      final validFrame = [0xFF, 0xD8, 0x99, 0x88, 0xFF, 0xD9];

      final controller = StreamController<List<int>>();
      final framesFuture = parser.parseStream(controller.stream).toList();

      controller.add(noise);
      controller.add(validFrame);
      await controller.close();

      final frames = await framesFuture;
      expect(frames.length, equals(1));
      expect(frames[0], equals(validFrame));
    });
  });
}
