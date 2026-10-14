import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/step_counter/data/user_step_detector_service.dart';
import 'package:vision_assist/features/step_counter/domain/user_step_counter_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserStepCounterState Unit Tests', () {
    test('default state has expected initial values', () {
      const state = UserStepCounterState();
      expect(state.sessionSteps, 0);
      expect(state.totalSensorSteps, 0);
      expect(state.walkingDuration, Duration.zero);
      expect(state.isTracking, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.currentCadence, 0.0);
      expect(state.signalQuality, StepSignalQuality.idle);
      expect(state.isReliable, isFalse);
    });

    test('isReliable is true for high and medium signal qualities', () {
      const highState = UserStepCounterState(signalQuality: StepSignalQuality.high);
      expect(highState.isReliable, isTrue);

      const medState = UserStepCounterState(signalQuality: StepSignalQuality.medium);
      expect(medState.isReliable, isTrue);

      const lowState = UserStepCounterState(signalQuality: StepSignalQuality.low);
      expect(lowState.isReliable, isFalse);

      const idleState = UserStepCounterState(signalQuality: StepSignalQuality.idle);
      expect(idleState.isReliable, isFalse);
    });

    test('copyWith updates state attributes cleanly', () {
      const state = UserStepCounterState();
      final updated = state.copyWith(
        sessionSteps: 154,
        isTracking: true,
        currentCadence: 92.5,
        signalQuality: StepSignalQuality.high,
      );

      expect(updated.sessionSteps, 154);
      expect(updated.isTracking, isTrue);
      expect(updated.currentCadence, 92.5);
      expect(updated.signalQuality, StepSignalQuality.high);
      expect(updated.isReliable, isTrue);
    });
  });

  group('UserStepDetectorService Unit Tests', () {
    late UserStepDetectorService service;

    setUp(() {
      service = UserStepDetectorService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial service state is idle', () {
      expect(service.currentState.isTracking, isFalse);
      expect(service.currentState.sessionSteps, 0);
    });

    test('pauseTracking marks service as paused', () {
      service.startTracking();
      service.pauseTracking();
      expect(service.currentState.isPaused, isTrue);
    });

    test('reset zeroes step count and resets walking duration', () {
      service.startTracking();
      service.reset();
      expect(service.currentState.sessionSteps, 0);
      expect(service.currentState.walkingDuration, Duration.zero);
    });

    test('getSpokenSummary contains explicit estimate label and duration', () {
      final summary = service.getSpokenSummary();
      // Must clearly state this is an estimate for assistive safety
      expect(summary.toLowerCase(), contains('estimate'));
      expect(summary.toLowerCase(), contains('step'));
    });
  });
}
