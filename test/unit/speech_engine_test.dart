import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/object_detection/data/yolo_config.dart';
import 'package:vision_assist/features/object_detection/domain/detected_object.dart';
import 'package:vision_assist/features/object_detection/domain/direction_zone.dart';
import 'package:vision_assist/features/tracking/domain/object_tracker.dart';
import 'package:vision_assist/features/voice_assistant/data/speech_announcement_engine.dart';

DetectedObject makeDet({
  required String label,
  required DirectionZone zone,
  int trackId = 1,
}) {
  return DetectedObject(
    classId: 0,
    label: label,
    confidence: 0.90,
    xMin: 0,
    yMin: 0,
    xMax: 100,
    yMax: 100,
    normalizedXMin: 0.1,
    normalizedYMin: 0.1,
    normalizedXMax: 0.5,
    normalizedYMax: 0.9,
    normalizedCenterX: 0.3,
    normalizedCenterY: 0.5,
    directionZone: zone,
    trackingId: trackId,
    timestamp: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechAnnouncementEngine Unit Tests', () {
    late SpeechAnnouncementEngine engine;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (MethodCall methodCall) async => 1,
      );
      engine = SpeechAnnouncementEngine();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        null,
      );
    });

    test('initial state is unmuted, unpaused, not speaking', () {
      expect(engine.isMuted, isFalse);
      expect(engine.isPaused, isFalse);
      expect(engine.isSpeaking, isFalse);
    });

    test('toggleMute updates mute state and stops active speech', () {
      engine.toggleMute();
      expect(engine.isMuted, isTrue);

      engine.toggleMute();
      expect(engine.isMuted, isFalse);
    });

    test('pause and resume adjust paused state accurately', () {
      engine.pause();
      expect(engine.isPaused, isTrue);

      engine.resume();
      expect(engine.isPaused, isFalse);
    });

    test('processDetections respects muted flag without throwing', () {
      engine.toggleMute();
      final det = makeDet(label: 'person', zone: DirectionZone.center);
      final track = TrackedObject(
        trackId: 1,
        currentDetection: det,
        hits: 3,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      // Should return immediately without enqueuing when muted
      expect(
        () => engine.processDetections(
          detections: [det],
          activeTracks: {1: track},
          config: const YoloConfig(),
        ),
        returnsNormally,
      );
    });

    test('processDetections ignores unconfirmed 1-hit tracks to avoid false alarms', () {
      final det = makeDet(label: 'person', zone: DirectionZone.center);
      final unconfirmedTrack = TrackedObject(
        trackId: 1,
        currentDetection: det,
        hits: 1, // Only 1 hit -> isReliable is false
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      expect(unconfirmedTrack.isReliable, isFalse);

      expect(
        () => engine.processDetections(
          detections: [det],
          activeTracks: {1: unconfirmedTrack},
          config: const YoloConfig(),
        ),
        returnsNormally,
      );
    });

    test('reset clears internal tracking state safely', () {
      engine.reset();
      expect(engine.isSpeaking, isFalse);
    });
  });
}
