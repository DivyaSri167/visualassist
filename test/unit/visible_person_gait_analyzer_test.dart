import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/object_detection/domain/detected_object.dart';
import 'package:vision_assist/features/object_detection/domain/direction_zone.dart';
import 'package:vision_assist/features/step_counter/domain/visible_person_gait_analyzer.dart';
import 'package:vision_assist/features/tracking/domain/object_tracker.dart';

DetectedObject createPersonDet({
  double normXMin = 0.3,
  double normYMin = 0.1,
  double normXMax = 0.7,
  double normYMax = 0.85,
  int trackId = 1,
}) {
  return DetectedObject(
    classId: 0,
    label: 'person',
    confidence: 0.90,
    xMin: normXMin * 320,
    yMin: normYMin * 240,
    xMax: normXMax * 320,
    yMax: normYMax * 240,
    normalizedXMin: normXMin,
    normalizedYMin: normYMin,
    normalizedXMax: normXMax,
    normalizedYMax: normYMax,
    normalizedCenterX: (normXMin + normXMax) / 2,
    normalizedCenterY: (normYMin + normYMax) / 2,
    directionZone: DirectionZone.center,
    trackingId: trackId,
    timestamp: DateTime.now(),
  );
}

void main() {
  group('VisiblePersonGaitAnalyzer Unit Tests', () {
    late VisiblePersonGaitAnalyzer analyzer;

    setUp(() {
      analyzer = VisiblePersonGaitAnalyzer();
    });

    test('reports no person when frame has no detections', () {
      final state = analyzer.analyzeFrame(
        detections: [],
        activeTracks: {},
        currentFps: 10.0,
      );

      expect(state.isGaitReliable, isFalse);
      expect(state.statusDescription, contains('No person'));
      expect(state.targetTrackId, isNull);
    });

    test('flags low FPS as unreliable for gait frequency resolution', () {
      final det = createPersonDet();
      final track = TrackedObject(
        trackId: 1,
        currentDetection: det,
        hits: 5,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      final state = analyzer.analyzeFrame(
        detections: [det],
        activeTracks: {1: track},
        currentFps: 2.5, // Below 4.0 threshold
      );

      expect(state.isGaitReliable, isFalse);
      expect(state.statusDescription, contains('FPS too low'));
    });

    test('flags occluded feet when person extends to bottom frame boundary', () {
      final det = createPersonDet(normYMax: 0.98); // >= 0.97
      final track = TrackedObject(
        trackId: 1,
        currentDetection: det,
        hits: 5,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      final state = analyzer.analyzeFrame(
        detections: [det],
        activeTracks: {1: track},
        currentFps: 10.0,
      );

      expect(state.isGaitReliable, isFalse);
      expect(state.statusDescription, contains('feet occluded'));
    });

    test('flags distant person when bounding box area is too small', () {
      // Area = 0.05 * 0.1 = 0.005 (< 0.04)
      final det = createPersonDet(
        normXMin: 0.45,
        normXMax: 0.50,
        normYMin: 0.40,
        normYMax: 0.50,
      );
      final track = TrackedObject(
        trackId: 1,
        currentDetection: det,
        hits: 5,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      final state = analyzer.analyzeFrame(
        detections: [det],
        activeTracks: {1: track},
        currentFps: 10.0,
      );

      expect(state.isGaitReliable, isFalse);
      expect(state.statusDescription, contains('too distant'));
    });

    test('reset clears internal state', () {
      analyzer.reset();
      expect(analyzer.currentState.estimatedSteps, equals(0));
      expect(analyzer.currentState.isGaitReliable, isFalse);
    });
  });
}
