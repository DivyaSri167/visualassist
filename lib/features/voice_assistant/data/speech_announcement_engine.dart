import 'dart:async';
import 'dart:collection';

import 'package:flutter_tts/flutter_tts.dart';

import '../../object_detection/data/yolo_config.dart';
import '../../object_detection/domain/detected_object.dart';
import '../../object_detection/domain/direction_zone.dart';
import '../../tracking/domain/object_tracker.dart';

/// Announcement priority level
enum AnnouncementPriority {
  routine,
  elevated,
  urgent,
}

class QueuedAnnouncement {
  final String message;
  final AnnouncementPriority priority;
  final DateTime timestamp;
  final int? trackId;

  const QueuedAnnouncement({
    required this.message,
    required this.priority,
    required this.timestamp,
    this.trackId,
  });
}

/// Spoken announcement engine prioritizing assistive feedback, deduplicating
/// repeated observations, and handling Bluetooth earphones.
class SpeechAnnouncementEngine {
  final FlutterTts _flutterTts = FlutterTts();
  final Queue<QueuedAnnouncement> _queue = Queue<QueuedAnnouncement>();

  bool _isSpeaking = false;
  bool _isMuted = false;
  bool _isPaused = false;
  bool _isInitialized = false;

  // Track ID -> last announced timestamp
  final Map<int, DateTime> _lastAnnouncedTimes = {};
  // Track ID -> last announced direction zone
  final Map<int, DirectionZone> _lastAnnouncedZones = {};

  bool get isSpeaking => _isSpeaking;
  bool get isMuted => _isMuted;
  bool get isPaused => _isPaused;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.52); // Natural cadence for accessibility
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _processNextInQueue();
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        _processNextInQueue();
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _isInitialized = true;
    } catch (_) {
      // In testing or environments without audio hardware, continue silently
    }
  }

  /// Evaluates tracked detections and dispatches speech announcements according to mode and priority.
  void processDetections({
    required List<DetectedObject> detections,
    required Map<int, TrackedObject> activeTracks,
    required YoloConfig config,
  }) {
    if (_isMuted || _isPaused || !config.speechEnabled) return;

    final now = DateTime.now();
    final cooldown = Duration(seconds: config.announcementCooldownSeconds);

    // Sort detections by priority score descending
    final sortedDetections = List<DetectedObject>.from(detections)
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    for (final det in sortedDetections) {
      final trackId = det.trackingId;
      if (trackId == null) continue;

      final track = activeTracks[trackId];
      if (track == null || !track.isReliable) {
        // Wait until track is confirmed over >= 2 frames to avoid phantom announcements
        continue;
      }

      final lastAnnounce = _lastAnnouncedTimes[trackId];
      final lastZone = _lastAnnouncedZones[trackId];
      final isNew = lastAnnounce == null;
      final cooldownExpired =
          lastAnnounce != null && now.difference(lastAnnounce) > cooldown;
      final zoneChanged = lastZone != null && lastZone != det.directionZone;

      switch (config.announcementMode) {
        case AnnouncementMode.importantObjects:
          // Mode A: Only announce validated hazard classes
          if (!YoloConfig.isHazardClass(det.label)) continue;

          if (isNew || zoneChanged || (cooldownExpired && track.isApproaching)) {
            final priority = track.isApproaching
                ? AnnouncementPriority.urgent
                : AnnouncementPriority.elevated;
            _enqueue(
              message: det.spokenAnnouncement,
              priority: priority,
              trackId: trackId,
              zone: det.directionZone,
            );
          }
          break;

        case AnnouncementMode.allObjects:
          // Mode B: Announce all sufficiently confident objects with deduplication
          if (isNew || (cooldownExpired && zoneChanged)) {
            _enqueue(
              message: det.spokenAnnouncement,
              priority: AnnouncementPriority.routine,
              trackId: trackId,
              zone: det.directionZone,
            );
          }
          break;

        case AnnouncementMode.walkingAssistance:
          // Mode C: Prioritize center walking path obstacles and hazards
          final isCenter = det.directionZone == DirectionZone.center;
          final isHazard = YoloConfig.isHazardClass(det.label);

          if (isCenter && (isNew || cooldownExpired || track.isApproaching)) {
            // Immediate attention for path obstacles
            final priority = isHazard
                ? AnnouncementPriority.urgent
                : AnnouncementPriority.elevated;
            _enqueue(
              message: det.spokenAnnouncement,
              priority: priority,
              trackId: trackId,
              zone: det.directionZone,
            );
          } else if (isNew && isHazard) {
            _enqueue(
              message: det.spokenAnnouncement,
              priority: AnnouncementPriority.elevated,
              trackId: trackId,
              zone: det.directionZone,
            );
          } else if (zoneChanged && (isCenter || isHazard)) {
            _enqueue(
              message: '${det.label} now ${det.directionZone.spokenLabel}.',
              priority: AnnouncementPriority.elevated,
              trackId: trackId,
              zone: det.directionZone,
            );
          }
          break;
      }
    }
  }

  void _enqueue({
    required String message,
    required AnnouncementPriority priority,
    required int trackId,
    required DirectionZone zone,
  }) {
    // Record announcement to enforce cooldown
    _lastAnnouncedTimes[trackId] = DateTime.now();
    _lastAnnouncedZones[trackId] = zone;

    // Avoid duplicate message if already in queue
    for (final item in _queue) {
      if (item.message == message) return;
    }

    final item = QueuedAnnouncement(
      message: message,
      priority: priority,
      timestamp: DateTime.now(),
      trackId: trackId,
    );

    if (priority == AnnouncementPriority.urgent) {
      // Urgent hazards jump directly to front of queue
      _queue.addFirst(item);
    } else {
      _queue.addLast(item);
    }

    // Keep queue bounded
    while (_queue.length > 5) {
      _queue.removeLast();
    }

    if (!_isSpeaking) {
      _processNextInQueue();
    }
  }

  Future<void> _processNextInQueue() async {
    if (_queue.isEmpty || _isMuted || _isPaused) {
      return;
    }

    final item = _queue.removeFirst();
    try {
      _isSpeaking = true;
      await _flutterTts.speak(item.message);
    } catch (_) {
      _isSpeaking = false;
    }
  }

  /// Speak a one-time immediate message (e.g., footstep summary or system status)
  Future<void> speakDirect(String message) async {
    if (_isMuted || _isPaused) return;
    try {
      await _flutterTts.speak(message);
    } catch (_) {}
  }

  void pause() {
    _isPaused = true;
    _flutterTts.stop();
  }

  void resume() {
    _isPaused = false;
    _processNextInQueue();
  }

  void stop() {
    _queue.clear();
    _flutterTts.stop();
    _isSpeaking = false;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stop();
    }
  }

  void reset() {
    stop();
    _lastAnnouncedTimes.clear();
    _lastAnnouncedZones.clear();
  }

  void dispose() {
    stop();
    _flutterTts.stop();
  }
}
