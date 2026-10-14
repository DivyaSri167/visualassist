import '../../../features/object_detection/domain/detected_object.dart';
import '../../../features/object_detection/data/yolo_config.dart';

/// Generates natural-language scene descriptions from YOLO detections.
/// Runs fully on-device — no cloud API required.
class SceneDescriptionEngine {
  /// Builds a rich spoken scene description from a snapshot of detections.
  ///
  /// [detections] — current frame's detected objects with zone info.
  /// [cameraFps]  — used to assess stream quality in the description.
  static String describe({
    required List<DetectedObject> detections,
    double cameraFps = 0,
  }) {
    if (detections.isEmpty) {
      return 'The scene appears clear. No objects were detected in the current frame.';
    }

    // Group by direction zone
    final left = <String>[];
    final center = <String>[];
    final right = <String>[];

    // Deduplicate labels per zone
    final seen = <String>{};

    // Sort by priority score so most important items are described first
    final sorted = List<DetectedObject>.from(detections)
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    for (final det in sorted) {
      final key = '${det.label}_${det.directionZone.name}';
      if (seen.contains(key)) continue;
      seen.add(key);

      final label = _humanize(det.label);
      switch (det.directionZone.name) {
        case 'left':
          left.add(label);
        case 'right':
          right.add(label);
        default:
          center.add(label);
      }
    }

    final parts = <String>[];

    // Hazard-first: scan for safety-critical hazard objects
    final hazards = sorted
        .where((d) => YoloConfig.isHazardClass(d.label))
        .map((d) => _humanize(d.label))
        .toSet()
        .toList();
    if (hazards.isNotEmpty) {
      final hazardList = _joinWithAnd(hazards);
      parts.add('Caution: $hazardList detected in your environment.');
    }

    // Center zone — most critical for walking path
    if (center.isNotEmpty) {
      final centerList = _joinWithAnd(center);
      parts.add(
        '${_capitalize(centerList)} ${center.length == 1 ? 'is' : 'are'} directly ahead in your path.',
      );
    }

    // Left zone
    if (left.isNotEmpty) {
      final leftList = _joinWithAnd(left);
      parts.add(
        '${_capitalize(leftList)} ${left.length == 1 ? 'is' : 'are'} on your left.',
      );
    }

    // Right zone
    if (right.isNotEmpty) {
      final rightList = _joinWithAnd(right);
      parts.add(
        '${_capitalize(rightList)} ${right.length == 1 ? 'is' : 'are'} on your right.',
      );
    }

    // Summary count
    final total = detections.length;
    parts.add(
      'Total of $total object${total == 1 ? '' : 's'} detected in the scene.',
    );

    // Stream quality advisory
    if (cameraFps > 0 && cameraFps < 4.0) {
      parts.add(
        'Note: camera frame rate is low at ${cameraFps.toStringAsFixed(1)} frames per second. Scene accuracy may be reduced.',
      );
    }

    return parts.join(' ');
  }

  /// Summary label counts for UI display chips.
  static List<SceneLabel> buildLabelSummary(List<DetectedObject> detections) {
    final counts = <String, int>{};
    for (final d in detections) {
      counts[d.label] = (counts[d.label] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => SceneLabel(
              label: _humanize(e.key),
              count: e.value,
              isHazard: YoloConfig.isHazardClass(e.key),
            ))
        .toList()
      ..sort((a, b) {
        // Hazards first, then alpha
        if (a.isHazard && !b.isHazard) return -1;
        if (!a.isHazard && b.isHazard) return 1;
        return a.label.compareTo(b.label);
      });
  }

  /// Comprehensive structured scene synthesis including environmental classification,
  /// path clearance, immediate hazards, and rich spoken narration.
  static SceneSynthesis synthesize({
    required List<DetectedObject> detections,
    double cameraFps = 0,
  }) {
    final spoken = describe(detections: detections, cameraFps: cameraFps);
    final env = classifyEnvironment(detections);
    final clearance = checkPathClearance(detections);
    final labels = buildLabelSummary(detections);

    final hazards = detections
        .where((d) => YoloConfig.isHazardClass(d.label))
        .map((d) => _humanize(d.label))
        .toSet()
        .toList();

    return SceneSynthesis(
      spokenNarration: spoken,
      environment: env,
      clearance: clearance,
      labels: labels,
      totalObjects: detections.length,
      immediateHazards: hazards,
    );
  }

  /// Classifies environmental context based on semantic co-occurrence of detected objects.
  static EnvironmentType classifyEnvironment(List<DetectedObject> detections) {
    if (detections.isEmpty) return EnvironmentType.openClearSpace;

    final labels = detections.map((d) => d.label.toLowerCase()).toSet();

    // Outdoor traffic / road
    if (labels.contains('car') ||
        labels.contains('bus') ||
        labels.contains('truck') ||
        labels.contains('traffic light') ||
        labels.contains('stop sign') ||
        labels.contains('motorcycle') ||
        labels.contains('bicycle')) {
      return EnvironmentType.outdoorTraffic;
    }

    // Office / Workspace
    if (labels.contains('laptop') ||
        labels.contains('keyboard') ||
        labels.contains('mouse') ||
        labels.contains('tv') ||
        labels.contains('monitor') ||
        labels.contains('book')) {
      return EnvironmentType.officeWorkspace;
    }

    // Kitchen / Dining
    if (labels.contains('dining table') ||
        labels.contains('refrigerator') ||
        labels.contains('microwave') ||
        labels.contains('oven') ||
        labels.contains('cup') ||
        labels.contains('bowl') ||
        labels.contains('bottle') ||
        labels.contains('fork') ||
        labels.contains('spoon')) {
      return EnvironmentType.kitchenDining;
    }

    // Living Room / Lounge
    if (labels.contains('sofa') ||
        labels.contains('couch') ||
        labels.contains('bed') ||
        labels.contains('chair')) {
      return EnvironmentType.livingRoomIndoor;
    }

    // Pedestrian / Public Area
    final personCount = detections.where((d) => d.label == 'person').length;
    if (personCount >= 2 || labels.contains('backpack') || labels.contains('handbag')) {
      return EnvironmentType.pedestrianWalkway;
    }

    return EnvironmentType.generalIndoor;
  }

  /// Evaluates walking path clearance based on obstacles in the center corridor.
  static PathClearanceLevel checkPathClearance(List<DetectedObject> detections) {
    final centerObjects = detections
        .where((d) => d.directionZone.name == 'center')
        .toList();

    if (centerObjects.isEmpty) {
      return PathClearanceLevel.clear;
    }

    // Check if any obstacle is large/close (bounding box area > 0.12 or is a hazard)
    final hasCloseObstacle = centerObjects.any((d) {
      final area = (d.normalizedXMax - d.normalizedXMin) *
          (d.normalizedYMax - d.normalizedYMin);
      final isHazard = YoloConfig.isHazardClass(d.label);
      return area > 0.12 || isHazard;
    });

    if (hasCloseObstacle) {
      return PathClearanceLevel.hazardDirectlyBlocked;
    }

    return PathClearanceLevel.cautionPartiallyObstructed;
  }

  static String _humanize(String label) {
    // Convert snake_case and apply minor corrections for TTS fluency
    return label
        .replaceAll('_', ' ')
        .replaceAll('tv', 'television')
        .replaceAll('cell phone', 'mobile phone');
  }

  static String _joinWithAnd(List<String> items) {
    if (items.length == 1) return items[0];
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.take(items.length - 1).join(', ')}, and ${items.last}';
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
}

/// Inferred environmental context.
enum EnvironmentType {
  officeWorkspace('Office / Study', 'Workspace setting with desk, computing, or reading materials'),
  livingRoomIndoor('Living Room / Lounge', 'Indoor room with seating and furnishings'),
  kitchenDining('Kitchen / Dining Area', 'Dining space with tableware or appliances'),
  outdoorTraffic('Outdoor Street / Traffic', 'Roadway or street with active vehicles'),
  pedestrianWalkway('Pedestrian Area', 'Sidewalk or walkway with people present'),
  generalIndoor('Indoor Space', 'Enclosed room with general items'),
  openClearSpace('Open / Clear Area', 'No obstacles detected in current view');

  final String displayName;
  final String description;
  const EnvironmentType(this.displayName, this.description);
}

/// Forward walking path clearance status.
enum PathClearanceLevel {
  clear('Path Clear', 'Forward walking trajectory is completely unobstructed'),
  cautionPartiallyObstructed('Caution Ahead', 'Obstacles nearby in forward corridor; proceed carefully'),
  hazardDirectlyBlocked('Path Blocked', 'Imminent obstacle directly in center walking lane; shift trajectory');

  final String label;
  final String description;
  const PathClearanceLevel(this.label, this.description);
}

/// Structured synthesis of the scene for assistive presentation.
class SceneSynthesis {
  final String spokenNarration;
  final EnvironmentType environment;
  final PathClearanceLevel clearance;
  final List<SceneLabel> labels;
  final int totalObjects;
  final List<String> immediateHazards;

  const SceneSynthesis({
    required this.spokenNarration,
    required this.environment,
    required this.clearance,
    required this.labels,
    required this.totalObjects,
    required this.immediateHazards,
  });
}

/// A detected label with its occurrence count.
class SceneLabel {
  final String label;
  final int count;
  final bool isHazard;

  const SceneLabel({
    required this.label,
    required this.count,
    required this.isHazard,
  });
}
