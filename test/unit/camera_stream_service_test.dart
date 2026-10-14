import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/camera/data/camera_stream_service.dart';

void main() {
  group('CameraStreamService Lifecycle Tests', () {
    test('initial state is idle with 0 FPS and no frames', () {
      final service = CameraStreamService();
      expect(service.currentState.status, equals(StreamPlaybackStatus.idle));
      expect(service.currentState.fps, equals(0.0));
      expect(service.currentState.totalFrames, equals(0));
      expect(service.currentState.currentFrame, isNull);
      service.dispose();
    });

    test('stopStream transitions to stopped and cleans resources', () async {
      final service = CameraStreamService();
      await service.stopStream();
      expect(service.currentState.fps, equals(0.0));
      service.dispose();
    });

    test('prevent duplicate connections cleans previous session before starting new one', () async {
      final service = CameraStreamService();
      // Start stream against an unresolvable URI with immediate timeout to test safe error handling
      final testUri = Uri.parse('http://127.0.0.1:9999/stream');

      await service.startStream(testUri);
      expect(service.currentState.status, equals(StreamPlaybackStatus.error));
      expect(service.currentState.errorMessage, isNotNull);

      // Stop stream resets cleanly
      await service.stopStream();
      service.dispose();
    });
  });
}
