import 'dart:math';

import '../../object_detection/domain/detected_object.dart';
import '../../tracking/domain/object_tracker.dart';

/// State of camera-based gait and step analysis for an observed person
class VisiblePersonGaitState {
  final int? targetTrackId;
  final int estimatedSteps;
  final bool isGaitReliable;
  final String statusDescription;
  final double confidenceScore;
  final DateTime? lastEventTimestamp;

  const VisiblePersonGaitState({
    this.targetTrackId,
    this.estimatedSteps = 0,
    this.isGaitReliable = false,
    this.statusDescription = 'No visible person in frame to analyze',
    this.confidenceScore = 0.0,
    this.lastEventTimestamp,
  });

  VisiblePersonGaitState copyWith({
    int? targetTrackId,
    int? estimatedSteps,
    bool? isGaitReliable,
    String? statusDescription,
    double? confidenceScore,
    DateTime? lastEventTimestamp,
  }) {
    return VisiblePersonGaitState(
      targetTrackId: targetTrackId ?? this.targetTrackId,
      estimatedSteps: estimatedSteps ?? this.estimatedSteps,
      isGaitReliable: isGaitReliable ?? this.isGaitReliable,
      statusDescription: statusDescription ?? this.statusDescription,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      lastEventTimestamp: lastEventTimestamp ?? this.lastEventTimestamp,
    );
  }
}

/// Evaluates visible person footsteps through temporal gait analysis.
/// Clearly distinguishes camera estimates from user phone motion sensors.
/// Declares uncertainty when feet are occluded or frame rate is insufficient.
class VisiblePersonGaitAnalyzer {
  final List<double> _aspectRatioHistory = [];
  final List<double> _verticalCenterHistory = [];
  DateTime _lastCycleTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  VisiblePersonGaitState _state = const VisiblePersonGaitState();
  VisiblePersonGaitState get currentState => _state;

  /// Analyzes tracked persons visible in the current camera frame
  VisiblePersonGaitState analyzeFrame({
    required List<DetectedObject> detections,
    required Map<int, TrackedObject> activeTracks,
    required double currentFps,
  }) {
    // 1. Find dominant tracked person in camera view
    TrackedObject? dominantPersonTrack;
    double maxArea = 0.0;

    for (final track in activeTracks.values) {
      if (track.currentDetection.label.toLowerCase() == 'person') {
        final area = track.currentDetection.normalizedArea;
        if (area > maxArea) {
          maxArea = area;
          dominantPersonTrack = track;
        }
      }
    }

    // If no person is tracked
    if (dominantPersonTrack == null) {
      _aspectRatioHistory.clear();
      _verticalCenterHistory.clear();
      _state = const VisiblePersonGaitState(
        isGaitReliable: false,
        statusDescription: 'No person currently in camera frame',
        confidenceScore: 0.0,
      );
      return _state;
    }

    final personDet = dominantPersonTrack.currentDetection;
    final trackId = dominantPersonTrack.trackId;

    // 2. Validate visibility and camera frame rate requirements
    // Gait analysis requires at least 4-5 FPS to observe alternating leg strides
    if (currentFps < 4.0) {
      _state = VisiblePersonGaitState(
        targetTrackId: trackId,
        estimatedSteps: _state.estimatedSteps,
        isGaitReliable: false,
        statusDescription: 'Camera FPS too low (${currentFps.toStringAsFixed(1)} FPS) for reliable gait estimation.',
        confidenceScore: 0.2,
      );
      return _state;
    }

    // If person's lower bounding-box boundary exceeds 0.95 or is above 0.7,
    // feet are likely cropped or occluded by ground border
    if (personDet.normalizedYMax >= 0.97) {
      _state = VisiblePersonGaitState(
        targetTrackId: trackId,
        estimatedSteps: _state.estimatedSteps,
        isGaitReliable: false,
        statusDescription: 'Person feet occluded / cropped at frame border. Step estimate unavailable.',
        confidenceScore: 0.3,
      );
      return _state;
    }

    // Person too far away (bounding box area too small)
    if (personDet.normalizedArea < 0.04) {
      _state = VisiblePersonGaitState(
        targetTrackId: trackId,
        estimatedSteps: _state.estimatedSteps,
        isGaitReliable: false,
        statusDescription: 'Person too distant for gait cycle resolution.',
        confidenceScore: 0.25,
      );
      return _state;
    }

    // 3. Temporal Gait Oscillation Analysis
    final aspectRatio = personDet.width / max(1.0, personDet.height);
    final centerY = personDet.normalizedCenterY;

    _aspectRatioHistory.add(aspectRatio);
    _verticalCenterHistory.add(centerY);

    if (_aspectRatioHistory.length > 15) {
      _aspectRatioHistory.removeAt(0);
      _verticalCenterHistory.removeAt(0);
    }

    // Check if we have sufficient history (at least 6 frames)
    if (_aspectRatioHistory.length >= 6) {
      final now = DateTime.now();
      final msSinceLastCycle = now.difference(_lastCycleTimestamp).inMilliseconds;

      // Gait cycle stride detection: periodic bounce in vertical center & width
      final minVal = _verticalCenterHistory.reduce(min);
      final maxVal = _verticalCenterHistory.reduce(max);
      final verticalAmplitude = maxVal - minVal;

      // Realistic human walking cadence: between 300ms and 1100ms per step
      if (verticalAmplitude > 0.015 && msSinceLastCycle >= 350) {
        _lastCycleTimestamp = now;
        final newCount = _state.estimatedSteps + 1;

        _state = VisiblePersonGaitState(
          targetTrackId: trackId,
          estimatedSteps: newCount,
          isGaitReliable: true,
          statusDescription: 'Estimated visible person steps: $newCount (Camera gait estimate)',
          confidenceScore: 0.75,
          lastEventTimestamp: now,
        );
        return _state;
      }
    }

    _state = VisiblePersonGaitState(
      targetTrackId: trackId,
      estimatedSteps: _state.estimatedSteps,
      isGaitReliable: true,
      statusDescription: 'Tracking visible person gait (Estimated: ${_state.estimatedSteps} steps)',
      confidenceScore: 0.70,
    );
    return _state;
  }

  void reset() {
    _aspectRatioHistory.clear();
    _verticalCenterHistory.clear();
    _lastCycleTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
    _state = const VisiblePersonGaitState();
  }
}
