import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/object_detection/domain/detected_object.dart';
import 'package:vision_assist/features/object_detection/domain/direction_zone.dart';
import 'package:vision_assist/features/voice_assistant/data/voice_query_engine.dart';

void main() {
  group('VoiceQueryEngine Unit Tests', () {
    test('accurately classifies natural voice queries into intents', () {
      expect(
        VoiceQueryEngine.matchIntent('what is in front of me'),
        equals(VoiceIntent.describeScene),
      );
      expect(
        VoiceQueryEngine.matchIntent('read text'),
        equals(VoiceIntent.readText),
      );
      expect(
        VoiceQueryEngine.matchIntent('is the path clear to walk?'),
        equals(VoiceIntent.checkPath),
      );
      expect(
        VoiceQueryEngine.matchIntent('where am I right now'),
        equals(VoiceIntent.whereAmI),
      );
      expect(
        VoiceQueryEngine.matchIntent('how many steps have I walked?'),
        equals(VoiceIntent.stepCount),
      );
      expect(
        VoiceQueryEngine.matchIntent('check camera connection and status'),
        equals(VoiceIntent.deviceStatus),
      );
      expect(
        VoiceQueryEngine.matchIntent('stop'),
        equals(VoiceIntent.stopSpeech),
      );
      expect(
        VoiceQueryEngine.matchIntent('what is written on this board?'),
        equals(VoiceIntent.readText),
      );
      expect(
        VoiceQueryEngine.matchIntent('is there a person near me?'),
        equals(VoiceIntent.personNearby),
      );
      expect(
        VoiceQueryEngine.matchIntent('what objects are on my left?'),
        equals(VoiceIntent.objectsOnLeft),
      );
      expect(
        VoiceQueryEngine.matchIntent('what is on my right?'),
        equals(VoiceIntent.objectsOnRight),
      );
    });

    test('generates grounded answers for surrounding object queries', () {
      final now = DateTime.now();
      final personDet = DetectedObject(
        classId: 0,
        label: 'person',
        confidence: 0.92,
        xMin: 0,
        yMin: 0,
        xMax: 100,
        yMax: 100,
        normalizedXMin: 0.4,
        normalizedYMin: 0.2,
        normalizedXMax: 0.6,
        normalizedYMax: 0.9,
        normalizedCenterX: 0.5,
        normalizedCenterY: 0.55,
        directionZone: DirectionZone.center,
        timestamp: now,
      );
      final chairDet = DetectedObject(
        classId: 56,
        label: 'chair',
        confidence: 0.85,
        xMin: 0,
        yMin: 0,
        xMax: 100,
        yMax: 100,
        normalizedXMin: 0.05,
        normalizedYMin: 0.3,
        normalizedXMax: 0.25,
        normalizedYMax: 0.7,
        normalizedCenterX: 0.15,
        normalizedCenterY: 0.5,
        directionZone: DirectionZone.left,
        timestamp: now,
      );

      final personAnswer = VoiceQueryEngine.generateAnswer(
        intent: VoiceIntent.personNearby,
        query: 'is there a person near me',
        detections: [personDet],
      );
      expect(personAnswer.answer, contains('Yes, a person is detected in front'));

      final leftAnswer = VoiceQueryEngine.generateAnswer(
        intent: VoiceIntent.objectsOnLeft,
        query: 'what is on my left',
        detections: [chairDet],
      );
      expect(leftAnswer.answer, contains('On your left, there is chair'));
    });

    test('generates helpful answers for step counts and device status', () {
      final stepAnswer = VoiceQueryEngine.generateAnswer(
        intent: VoiceIntent.stepCount,
        query: 'steps',
        sessionSteps: 1250,
        estimatedDistanceMeters: 875.0,
      );
      expect(stepAnswer.answer, contains('1250 steps'));
      expect(stepAnswer.answer, contains('0.88 kilometers'));

      final statusAnswer = VoiceQueryEngine.generateAnswer(
        intent: VoiceIntent.deviceStatus,
        query: 'status',
        isConnected: true,
        cameraFps: 12.5,
      );
      expect(statusAnswer.answer, contains('connected and operational'));
      expect(statusAnswer.answer, contains('12.5 frames per second'));
    });
  });
}
