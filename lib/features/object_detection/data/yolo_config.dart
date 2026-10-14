/// Announcement modes specified for accessibility assistance
enum AnnouncementMode {
  /// Mode A: Announce important newly detected objects and potential hazards only.
  importantObjects,

  /// Mode B: Announce all sufficiently confident newly observed objects.
  allObjects,

  /// Mode C: Walking assistance — prioritizes central field of view obstacles and path hazards.
  walkingAssistance,
}

extension AnnouncementModeX on AnnouncementMode {
  String get displayName {
    switch (this) {
      case AnnouncementMode.importantObjects:
        return 'Mode A: Hazards & Key Objects';
      case AnnouncementMode.allObjects:
        return 'Mode B: All Detected Objects';
      case AnnouncementMode.walkingAssistance:
        return 'Mode C: Walking Guidance';
    }
  }

  String get shortName {
    switch (this) {
      case AnnouncementMode.importantObjects:
        return 'Mode A (Important)';
      case AnnouncementMode.allObjects:
        return 'Mode B (All)';
      case AnnouncementMode.walkingAssistance:
        return 'Mode C (Walking)';
    }
  }
}

/// Central configuration for YOLO11n inference, thresholds, and priority rules.
class YoloConfig {
  static const String defaultModelPath = 'assets/models/yolo11n.tflite';
  static const String defaultLabelsPath = 'assets/models/coco_labels.txt';
  static const int defaultInputSize = 320;
  static const double defaultConfidenceThreshold = 0.40;
  static const double defaultIouThreshold = 0.45;
  static const int defaultMaxInferenceFps = 7;

  final String modelPath;
  final String labelsPath;
  final int inputSize;
  final double confidenceThreshold;
  final double iouThreshold;
  final int maxInferenceFps;

  // Direction thresholds
  final double leftZoneThreshold;
  final double rightZoneThreshold;

  // Active announcement mode
  final AnnouncementMode announcementMode;

  // Cooldown in seconds before the same tracked object can be re-announced
  final int announcementCooldownSeconds;

  // Whether speech output is enabled
  final bool speechEnabled;

  const YoloConfig({
    this.modelPath = defaultModelPath,
    this.labelsPath = defaultLabelsPath,
    this.inputSize = defaultInputSize,
    this.confidenceThreshold = defaultConfidenceThreshold,
    this.iouThreshold = defaultIouThreshold,
    this.maxInferenceFps = defaultMaxInferenceFps,
    this.leftZoneThreshold = 0.35,
    this.rightZoneThreshold = 0.65,
    this.announcementMode = AnnouncementMode.walkingAssistance,
    this.announcementCooldownSeconds = 5,
    this.speechEnabled = true,
  });

  /// Base priority score for specific classes in assistive navigation context.
  /// Higher numbers indicate urgent navigation importance.
  static double getClassBasePriority(String label) {
    switch (label.toLowerCase()) {
      case 'person':
        return 4.5;
      case 'car':
      case 'truck':
      case 'bus':
        return 5.0; // High hazard on walkways/streets
      case 'motorcycle':
      case 'bicycle':
        return 4.8;
      case 'traffic light':
      case 'stop sign':
        return 4.5;
      case 'dog':
      case 'cat':
        return 3.5;
      case 'chair':
      case 'couch':
      case 'bench':
      case 'dining table':
      case 'bed':
        return 3.0; // Indoor obstacles in walking path
      case 'door':
      case 'stairs':
      case 'curb':
      case 'pothole':
        return 5.0; // Critical walking features
      case 'fire hydrant':
        return 3.0;
      case 'bottle':
      case 'cup':
        return 2.0;
      default:
        return 1.5;
    }
  }

  /// Whether a class is deemed a priority hazard for Mode A
  static bool isHazardClass(String label) {
    const hazardLabels = {
      'person',
      'car',
      'truck',
      'bus',
      'motorcycle',
      'bicycle',
      'traffic light',
      'stop sign',
      'dog',
      'chair',
      'couch',
      'bench',
      'stairs',
      'curb',
      'pothole',
      'door',
    };
    return hazardLabels.contains(label.toLowerCase());
  }

  YoloConfig copyWith({
    String? modelPath,
    String? labelsPath,
    int? inputSize,
    double? confidenceThreshold,
    double? iouThreshold,
    int? maxInferenceFps,
    double? leftZoneThreshold,
    double? rightZoneThreshold,
    AnnouncementMode? announcementMode,
    int? announcementCooldownSeconds,
    bool? speechEnabled,
  }) {
    return YoloConfig(
      modelPath: modelPath ?? this.modelPath,
      labelsPath: labelsPath ?? this.labelsPath,
      inputSize: inputSize ?? this.inputSize,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      iouThreshold: iouThreshold ?? this.iouThreshold,
      maxInferenceFps: maxInferenceFps ?? this.maxInferenceFps,
      leftZoneThreshold: leftZoneThreshold ?? this.leftZoneThreshold,
      rightZoneThreshold: rightZoneThreshold ?? this.rightZoneThreshold,
      announcementMode: announcementMode ?? this.announcementMode,
      announcementCooldownSeconds:
          announcementCooldownSeconds ?? this.announcementCooldownSeconds,
      speechEnabled: speechEnabled ?? this.speechEnabled,
    );
  }
}
