import 'package:flutter_test/flutter_test.dart';
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
        VoiceQueryEngine.matchIntent('help with commands'),
        equals(VoiceIntent.help),
      );
    });

    test('generates helpful answers for step counts and device status', () {
      final stepAnswer = VoiceQueryEngine.generateAnswer(
        intent: VoiceIntent.stepCount,
        query: 'steps',
        sessionSteps: 1250,
        estimatedDistanceMeters: 875.0,
      );
      expect(stepAnswer, contains('1250 steps'));
      expect(stepAnswer, contains('0.88 kilometers'));

      final statusAnswer = VoiceQueryEngine.generateAnswer(
        intent: VoiceIntent.deviceStatus,
        query: 'status',
        isConnected: true,
        cameraFps: 12.5,
      );
      expect(statusAnswer, contains('connected and operational'));
      expect(statusAnswer, contains('12.5 frames per second'));
    });
  });
}
