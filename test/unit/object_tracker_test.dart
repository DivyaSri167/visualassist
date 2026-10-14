import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/object_detection/domain/detected_object.dart';
import 'package:vision_assist/features/object_detection/domain/direction_zone.dart';
import 'package:vision_assist/features/tracking/domain/object_tracker.dart';

DetectedObject createTestDetection({
  int classId = 0,
  String label = 'person',
  double confidence = 0.85,
  double normXMin = 0.4,
  double normYMin = 0.2,
  double normXMax = 0.6,
  double normYMax = 0.8,
  DirectionZone zone = DirectionZone.center,
  int? trackingId,
}) {
  final normW = normXMax - normXMin;
  final normH = normYMax - normYMin;
  return DetectedObject(
    classId: classId,
    label: label,
    confidence: confidence,
    xMin: normXMin * 320,
    yMin: normYMin * 240,
    xMax: normXMax * 320,
    yMax: normYMax * 240,
    normalizedXMin: normXMin,
    normalizedYMin: normYMin,
    normalizedXMax: normXMax,
    normalizedYMax: normYMax,
    normalizedCenterX: normXMin + normW / 2,
    normalizedCenterY: normYMin + normH / 2,
    directionZone: zone,
    trackingId: trackingId,
    timestamp: DateTime.now(),
  );
}

void main() {
  group('ObjectTracker Unit Tests', () {
    test('initial frame assigns unique track IDs to all detections', () {
      final tracker = ObjectTracker();
      final det1 = createTestDetection(classId: 0, label: 'person', normXMin: 0.1, normXMax: 0.3);
      final det2 = createTestDetection(classId: 56, label: 'chair', normXMin: 0.7, normXMax: 0.9);

      final tracked = tracker.updateTracks([det1, det2]);

      expect(tracked.length, 2);
      expect(tracked[0].trackingId, isNotNull);
      expect(tracked[1].trackingId, isNotNull);
      expect(tracked[0].trackingId, isNot(equals(tracked[1].trackingId)));
      expect(tracker.activeTracks.length, 2);
    });

    test('preserves track ID across frames for overlapping detections', () {
      final tracker = ObjectTracker();
      final frame1 = [
        createTestDetection(classId: 0, label: 'person', normXMin: 0.4, normXMax: 0.6),
      ];
      final tracked1 = tracker.updateTracks(frame1);
      final initialId = tracked1.first.trackingId!;

      // Frame 2: slightly shifted position (high IoU overlap)
      final frame2 = [
        createTestDetection(classId: 0, label: 'person', normXMin: 0.42, normXMax: 0.62),
      ];
      final tracked2 = tracker.updateTracks(frame2);

      expect(tracked2.first.trackingId, equals(initialId));
      expect(tracker.activeTracks[initialId]!.hits, 2);
      expect(tracker.activeTracks[initialId]!.isReliable, isTrue);
    });

    test('identifies approaching objects when bounding box expands', () {
      final tracker = ObjectTracker();

      // Frame 1: Small person far away (area = 0.1 * 0.2 = 0.02)
      tracker.updateTracks([
        createTestDetection(normXMin: 0.45, normXMax: 0.55, normYMin: 0.4, normYMax: 0.6),
      ]);

      // Frame 2: Moderate expansion
      tracker.updateTracks([
        createTestDetection(normXMin: 0.42, normXMax: 0.58, normYMin: 0.35, normYMax: 0.65),
      ]);

      // Frame 3: Significantly larger (area > 1.25x initial)
      final frame3 = tracker.updateTracks([
        createTestDetection(normXMin: 0.35, normXMax: 0.65, normYMin: 0.2, normYMax: 0.8),
      ]);

      final trackId = frame3.first.trackingId!;
      final track = tracker.activeTracks[trackId]!;
      expect(track.isApproaching, isTrue);
    });

    test('expires stale tracks when absent beyond maxLostFrames', () {
      final tracker = ObjectTracker(maxLostFrames: 2);

      // Frame 1: object present
      tracker.updateTracks([
        createTestDetection(normXMin: 0.4, normXMax: 0.6),
      ]);
      expect(tracker.activeTracks.length, 1);

      // Frames 2, 3, 4: object absent
      tracker.updateTracks([]);
      expect(tracker.activeTracks.length, 1); // lostFrames = 1

      tracker.updateTracks([]);
      expect(tracker.activeTracks.length, 1); // lostFrames = 2

      tracker.updateTracks([]);
      // Exceeds maxLostFrames=2 -> expired
      expect(tracker.activeTracks.length, 0);
    });

    test('reset clears all tracks and resets ID generation', () {
      final tracker = ObjectTracker();
      tracker.updateTracks([createTestDetection()]);
      expect(tracker.activeTracks.isNotEmpty, isTrue);

      tracker.reset();
      expect(tracker.activeTracks.isEmpty, isTrue);

      final nextDetections = tracker.updateTracks([createTestDetection()]);
      expect(nextDetections.first.trackingId, equals(1));
    });
  });
}
