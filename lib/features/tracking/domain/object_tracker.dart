import 'dart:math';

import '../../object_detection/domain/detected_object.dart';
import '../../object_detection/domain/direction_zone.dart';

/// Represents an actively tracked object trajectory across consecutive video frames.
class TrackedObject {
  final int trackId;
  DetectedObject currentDetection;
  final List<DetectedObject> history;
  int hits;
  int lostFrames;
  final DateTime firstSeen;
  DateTime lastSeen;
  bool announced;
  DateTime? lastAnnouncedAt;
  DirectionZone? lastAnnouncedZone;

  TrackedObject({
    required this.trackId,
    required this.currentDetection,
    List<DetectedObject>? history,
    this.hits = 1,
    this.lostFrames = 0,
    required this.firstSeen,
    required this.lastSeen,
    this.announced = false,
    this.lastAnnouncedAt,
    this.lastAnnouncedZone,
  }) : history = history ?? [currentDetection];

  /// Track is deemed reliable when seen across at least 2 consecutive frames,
  /// suppressing one-frame false-positive sensor glitches.
  bool get isReliable => hits >= 2;

  /// Whether the tracked object is expanding in size (approaching user)
  bool get isApproaching {
    if (history.length < 3) return false;
    final initialArea = history.first.normalizedArea;
    final currentArea = currentDetection.normalizedArea;
    return initialArea > 0.005 && currentArea > initialArea * 1.25;
  }

  /// Whether the object has shifted between horizontal direction zones
  bool get hasShiftedZone {
    if (lastAnnouncedZone == null) return false;
    return currentDetection.directionZone != lastAnnouncedZone;
  }

  void update(DetectedObject newDetection) {
    currentDetection = newDetection;
    history.add(newDetection);
    if (history.length > 10) {
      history.removeAt(0); // keep rolling 10-frame window
    }
    hits++;
    lostFrames = 0;
    lastSeen = newDetection.timestamp;
  }

  void markAnnounced() {
    announced = true;
    lastAnnouncedAt = DateTime.now();
    lastAnnouncedZone = currentDetection.directionZone;
  }
}

/// Lightweight Multi-Object Tracker for mobile real-time edge execution.
/// Associates YOLO detections across frames using IoU and spatial proximity,
/// assigns stable tracking IDs, handles brief occlusions, and expires stale tracks.
class ObjectTracker {
  final int maxLostFrames;
  final double iouThreshold;
  final double maxDistanceThreshold;

  int _nextTrackId = 1;
  final Map<int, TrackedObject> _tracks = {};

  ObjectTracker({
    this.maxLostFrames = 5,
    this.iouThreshold = 0.25,
    this.maxDistanceThreshold = 0.22,
  });

  Map<int, TrackedObject> get activeTracks => Map.unmodifiable(_tracks);

  /// Processes current frame detections and updates track associations.
  /// Returns updated detections with attached `trackingId`s.
  List<DetectedObject> updateTracks(List<DetectedObject> detections) {
    final now = DateTime.now();

    if (_tracks.isEmpty) {
      // First frame: register all detections as new tracks
      final updatedDetections = <DetectedObject>[];
      for (final det in detections) {
        final id = _nextTrackId++;
        final trackedDet = det.copyWith(trackingId: id);
        _tracks[id] = TrackedObject(
          trackId: id,
          currentDetection: trackedDet,
          firstSeen: now,
          lastSeen: now,
        );
        updatedDetections.add(trackedDet);
      }
      return updatedDetections;
    }

    // Match existing tracks with incoming detections
    final trackIds = _tracks.keys.toList();
    final matchedTracks = <int>{};
    final matchedDetections = <int>{};
    final updatedDetections = <DetectedObject>[];

    // 1. Primary Association: IoU overlap with identical classId
    for (int d = 0; d < detections.length; d++) {
      final det = detections[d];
      int? bestTrackId;
      double bestIou = iouThreshold;

      for (final tId in trackIds) {
        if (matchedTracks.contains(tId)) continue;
        final track = _tracks[tId]!;
        if (track.currentDetection.classId != det.classId) continue;

        final iou = _calculateIou(track.currentDetection, det);
        if (iou > bestIou) {
          bestIou = iou;
          bestTrackId = tId;
        }
      }

      if (bestTrackId != null) {
        matchedTracks.add(bestTrackId);
        matchedDetections.add(d);
        final trackedDet = det.copyWith(trackingId: bestTrackId);
        _tracks[bestTrackId]!.update(trackedDet);
        updatedDetections.add(trackedDet);
      }
    }

    // 2. Secondary Association: Center spatial proximity for fast movements
    for (int d = 0; d < detections.length; d++) {
      if (matchedDetections.contains(d)) continue;
      final det = detections[d];

      int? bestTrackId;
      double minDistance = maxDistanceThreshold;

      for (final tId in trackIds) {
        if (matchedTracks.contains(tId)) continue;
        final track = _tracks[tId]!;
        if (track.currentDetection.classId != det.classId) continue;

        final dx = track.currentDetection.normalizedCenterX - det.normalizedCenterX;
        final dy = track.currentDetection.normalizedCenterY - det.normalizedCenterY;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < minDistance) {
          minDistance = dist;
          bestTrackId = tId;
        }
      }

      if (bestTrackId != null) {
        matchedTracks.add(bestTrackId);
        matchedDetections.add(d);
        final trackedDet = det.copyWith(trackingId: bestTrackId);
        _tracks[bestTrackId]!.update(trackedDet);
        updatedDetections.add(trackedDet);
      }
    }

    // 3. Register unmatched detections as new tracks
    for (int d = 0; d < detections.length; d++) {
      if (matchedDetections.contains(d)) continue;
      final det = detections[d];
      final id = _nextTrackId++;
      final trackedDet = det.copyWith(trackingId: id);
      _tracks[id] = TrackedObject(
        trackId: id,
        currentDetection: trackedDet,
        firstSeen: now,
        lastSeen: now,
      );
      updatedDetections.add(trackedDet);
    }

    // 4. Age and expire unmatched tracks
    final expiredTrackIds = <int>[];
    for (final tId in trackIds) {
      if (!matchedTracks.contains(tId)) {
        final track = _tracks[tId]!;
        track.lostFrames++;
        if (track.lostFrames > maxLostFrames) {
          expiredTrackIds.add(tId);
        }
      }
    }

    for (final id in expiredTrackIds) {
      _tracks.remove(id);
    }

    return updatedDetections;
  }

  /// Calculates IoU between two detected objects in normalized image space
  double _calculateIou(DetectedObject a, DetectedObject b) {
    final x1 = max(a.normalizedXMin, b.normalizedXMin);
    final y1 = max(a.normalizedYMin, b.normalizedYMin);
    final x2 = min(a.normalizedXMax, b.normalizedXMax);
    final y2 = min(a.normalizedYMax, b.normalizedYMax);

    if (x2 <= x1 || y2 <= y1) return 0.0;

    final interArea = (x2 - x1) * (y2 - y1);
    final areaA = a.normalizedArea;
    final areaB = b.normalizedArea;
    final unionArea = areaA + areaB - interArea;

    return unionArea > 0.0 ? interArea / unionArea : 0.0;
  }

  void reset() {
    _tracks.clear();
    _nextTrackId = 1;
  }
}
