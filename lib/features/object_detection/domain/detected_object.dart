import 'package:flutter/material.dart';

import 'direction_zone.dart';

/// Represents a single object detected by YOLO11n in an ESP32-CAM frame.
class DetectedObject {
  final int classId;
  final String label;
  final double confidence;

  /// Absolute bounding-box coordinates in source image pixels
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  /// Normalized coordinates (0.0 to 1.0)
  final double normalizedXMin;
  final double normalizedYMin;
  final double normalizedXMax;
  final double normalizedYMax;

  /// Normalized center coordinates
  final double normalizedCenterX;
  final double normalizedCenterY;

  /// Direction zone (Left, Center, Right)
  final DirectionZone directionZone;

  /// Optional stable multi-object tracking ID
  final int? trackingId;

  /// Timestamp when detection occurred
  final DateTime timestamp;

  /// Priority score computed for speech dispatching (higher = more urgent)
  final double priorityScore;

  const DetectedObject({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.normalizedXMin,
    required this.normalizedYMin,
    required this.normalizedXMax,
    required this.normalizedYMax,
    required this.normalizedCenterX,
    required this.normalizedCenterY,
    required this.directionZone,
    this.trackingId,
    required this.timestamp,
    this.priorityScore = 1.0,
  });

  /// Bounding box width in source pixels
  double get width => (xMax - xMin).clamp(0.0, double.infinity);

  /// Bounding box height in source pixels
  double get height => (yMax - yMin).clamp(0.0, double.infinity);

  /// Normalized bounding box area (0.0 to 1.0)
  double get normalizedArea =>
      ((normalizedXMax - normalizedXMin) * (normalizedYMax - normalizedYMin))
          .clamp(0.0, 1.0);

  /// Convenience Rect representation in source coordinates
  Rect get rect => Rect.fromLTRB(xMin, yMin, xMax, yMax);

  /// Convenience Rect representation in normalized 0.0..1.0 coordinates
  Rect get normalizedRect => Rect.fromLTRB(
        normalizedXMin,
        normalizedYMin,
        normalizedXMax,
        normalizedYMax,
      );

  /// Natural spoken announcement representation for assistive TTS,
  /// e.g. "Person detected in front.", "Chair detected on your left.",
  /// "Vehicle detected on your right.", "Stairs detected ahead. Please proceed carefully."
  String get spokenAnnouncement {
    final lower = label.toLowerCase();
    if (lower == 'stairs') {
      return 'Stairs detected ahead. Please proceed carefully.';
    }
    if (lower == 'car' || lower == 'truck' || lower == 'bus' || lower == 'motorcycle') {
      return 'Vehicle detected ${directionZone.naturalSpokenLabel}.';
    }
    final formatted = label.isNotEmpty
        ? '${label[0].toUpperCase()}${label.substring(1)}'
        : label;
    return '$formatted detected ${directionZone.naturalSpokenLabel}.';
  }

  /// Detailed spoken announcement with fine-grained direction
  String getDetailedSpokenAnnouncement(DirectionClassifier classifier) {
    final detail = classifier.getDetailedSpokenDirection(normalizedCenterX);
    return '$label, $detail.';
  }

  DetectedObject copyWith({
    int? classId,
    String? label,
    double? confidence,
    double? xMin,
    double? yMin,
    double? xMax,
    double? yMax,
    double? normalizedXMin,
    double? normalizedYMin,
    double? normalizedXMax,
    double? normalizedYMax,
    double? normalizedCenterX,
    double? normalizedCenterY,
    DirectionZone? directionZone,
    int? trackingId,
    DateTime? timestamp,
    double? priorityScore,
  }) {
    return DetectedObject(
      classId: classId ?? this.classId,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      xMin: xMin ?? this.xMin,
      yMin: yMin ?? this.yMin,
      xMax: xMax ?? this.xMax,
      yMax: yMax ?? this.yMax,
      normalizedXMin: normalizedXMin ?? this.normalizedXMin,
      normalizedYMin: normalizedYMin ?? this.normalizedYMin,
      normalizedXMax: normalizedXMax ?? this.normalizedXMax,
      normalizedYMax: normalizedYMax ?? this.normalizedYMax,
      normalizedCenterX: normalizedCenterX ?? this.normalizedCenterX,
      normalizedCenterY: normalizedCenterY ?? this.normalizedCenterY,
      directionZone: directionZone ?? this.directionZone,
      trackingId: trackingId ?? this.trackingId,
      timestamp: timestamp ?? this.timestamp,
      priorityScore: priorityScore ?? this.priorityScore,
    );
  }

  @override
  String toString() {
    return 'DetectedObject($label, conf: ${(confidence * 100).toStringAsFixed(1)}%, zone: ${directionZone.name}, trackId: $trackingId)';
  }
}
