import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/object_detection/domain/detected_object.dart';
import 'package:vision_assist/features/object_detection/domain/direction_zone.dart';
import 'package:vision_assist/features/scene_understanding/data/scene_description_engine.dart';

DetectedObject _createDet({
  required String label,
  required DirectionZone zone,
  double priorityScore = 1.0,
}) {
  return DetectedObject(
    classId: 0,
    label: label,
    confidence: 0.88,
    xMin: 10,
    yMin: 10,
    xMax: 100,
    yMax: 100,
    normalizedXMin: 0.1,
    normalizedYMin: 0.1,
    normalizedXMax: 0.4,
    normalizedYMax: 0.6,
    normalizedCenterX: 0.25,
    normalizedCenterY: 0.35,
    directionZone: zone,
    priorityScore: priorityScore,
    timestamp: DateTime.now(),
  );
}

void main() {
  group('SceneDescriptionEngine Unit Tests', () {
    test('returns clear message when no detections are present', () {
      final desc = SceneDescriptionEngine.describe(detections: []);
      expect(desc, contains('The scene appears clear'));
      expect(desc, contains('No objects were detected'));
    });

    test('generates direction-aware description for multiple objects', () {
      final detections = [
        _createDet(label: 'chair', zone: DirectionZone.center),
        _createDet(label: 'person', zone: DirectionZone.left),
        _createDet(label: 'bottle', zone: DirectionZone.right),
      ];

      final desc = SceneDescriptionEngine.describe(detections: detections);

      expect(desc, contains('directly ahead in your path'));
      expect(desc, contains('on your left'));
      expect(desc, contains('on your right'));
      expect(desc, contains('Total of 3 objects detected in the scene.'));
    });

    test('announces hazard objects with caution priority', () {
      final detections = [
        _createDet(
          label: 'car',
          zone: DirectionZone.center,
          priorityScore: 3.5,
        ),
      ];

      final desc = SceneDescriptionEngine.describe(detections: detections);
      expect(desc, contains('Caution: car detected in your environment.'));
    });

    test('buildLabelSummary aggregates counts and prioritizes hazard classes', () {
      final detections = [
        _createDet(label: 'bottle', zone: DirectionZone.center),
        _createDet(label: 'stairs', zone: DirectionZone.center),
        _createDet(label: 'bottle', zone: DirectionZone.left),
      ];

      final summary = SceneDescriptionEngine.buildLabelSummary(detections);

      expect(summary.length, equals(2));
      // stairs is a hazard class, should come first before non-hazard bottle
      expect(summary.first.label, equals('stairs'));
      expect(summary.first.count, equals(1));
      expect(summary.first.isHazard, isTrue);

      final bottleItem = summary.firstWhere((s) => s.label == 'bottle');
      expect(bottleItem.count, equals(2));
      expect(bottleItem.isHazard, isFalse);
    });

    test('classifyEnvironment correctly infers office, traffic, and clear environments', () {
      final officeDetections = [
        _createDet(label: 'laptop', zone: DirectionZone.center),
        _createDet(label: 'chair', zone: DirectionZone.left),
      ];
      expect(
        SceneDescriptionEngine.classifyEnvironment(officeDetections),
        equals(EnvironmentType.officeWorkspace),
      );

      final trafficDetections = [
        _createDet(label: 'car', zone: DirectionZone.center),
        _createDet(label: 'traffic light', zone: DirectionZone.right),
      ];
      expect(
        SceneDescriptionEngine.classifyEnvironment(trafficDetections),
        equals(EnvironmentType.outdoorTraffic),
      );

      expect(
        SceneDescriptionEngine.classifyEnvironment([]),
        equals(EnvironmentType.openClearSpace),
      );
    });

    test('checkPathClearance reports clear when center is empty and blocked for hazards', () {
      final clearDetections = [
        _createDet(label: 'chair', zone: DirectionZone.left),
        _createDet(label: 'bottle', zone: DirectionZone.right),
      ];
      expect(
        SceneDescriptionEngine.checkPathClearance(clearDetections),
        equals(PathClearanceLevel.clear),
      );

      final blockedDetections = [
        _createDet(label: 'car', zone: DirectionZone.center),
      ];
      expect(
        SceneDescriptionEngine.checkPathClearance(blockedDetections),
        equals(PathClearanceLevel.hazardDirectlyBlocked),
      );
    });

    test('synthesize returns comprehensive SceneSynthesis bundle', () {
      final detections = [
        _createDet(label: 'chair', zone: DirectionZone.center),
      ];
      final synthesis = SceneDescriptionEngine.synthesize(detections: detections);
      expect(synthesis.totalObjects, equals(1));
      expect(synthesis.environment, equals(EnvironmentType.livingRoomIndoor));
      expect(synthesis.spokenNarration, isNotEmpty);
    });
  });
}
