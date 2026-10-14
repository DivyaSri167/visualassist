/// Horizontal direction zone of a detected object within the camera field of view.
enum DirectionZone {
  left,
  center,
  right,
}

/// Helper extension for DirectionZone
extension DirectionZoneX on DirectionZone {
  String get displayName {
    switch (this) {
      case DirectionZone.left:
        return 'Left';
      case DirectionZone.center:
        return 'Center';
      case DirectionZone.right:
        return 'Right';
    }
  }

  String get spokenLabel {
    switch (this) {
      case DirectionZone.left:
        return 'left';
      case DirectionZone.center:
        return 'center';
      case DirectionZone.right:
        return 'right';
    }
  }
}

/// Computes horizontal direction zone from normalized X coordinate (0.0 to 1.0).
/// Default thresholds: Left < 0.35, Center 0.35..0.65, Right > 0.65.
class DirectionClassifier {
  final double leftThreshold;
  final double rightThreshold;

  const DirectionClassifier({
    this.leftThreshold = 0.35,
    this.rightThreshold = 0.65,
  });

  DirectionZone classify(double normalizedX) {
    if (normalizedX < leftThreshold) {
      return DirectionZone.left;
    } else if (normalizedX > rightThreshold) {
      return DirectionZone.right;
    } else {
      return DirectionZone.center;
    }
  }

  /// Provides more nuanced directional speech if desired, e.g. "slightly left"
  String getDetailedSpokenDirection(double normalizedX) {
    if (normalizedX < 0.25) {
      return 'far left';
    } else if (normalizedX < leftThreshold) {
      return 'left';
    } else if (normalizedX < 0.45) {
      return 'slightly left';
    } else if (normalizedX <= 0.55) {
      return 'dead center';
    } else if (normalizedX <= rightThreshold) {
      return 'slightly right';
    } else if (normalizedX <= 0.75) {
      return 'right';
    } else {
      return 'far right';
    }
  }
}
