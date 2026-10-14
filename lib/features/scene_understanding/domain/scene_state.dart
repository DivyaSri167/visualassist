import 'dart:typed_data';

import '../../object_detection/domain/detected_object.dart';
import '../data/scene_description_engine.dart';

/// Processing phase for scene narration.
enum ScenePhase {
  idle,
  capturing,
  analyzing,
  speaking,
  error,
}

/// Immutable state for the Scene Understanding AI Assistant.
class SceneState {
  final ScenePhase phase;
  final Uint8List? capturedImage;
  final String? narration;
  final List<DetectedObject> detections;
  final List<SceneLabel> labels;
  final SceneSynthesis? synthesis;
  final String? errorMessage;
  final bool isSpeaking;
  final DateTime? timestamp;

  const SceneState({
    this.phase = ScenePhase.idle,
    this.capturedImage,
    this.narration,
    this.detections = const [],
    this.labels = const [],
    this.synthesis,
    this.errorMessage,
    this.isSpeaking = false,
    this.timestamp,
  });

  bool get isLoading =>
      phase == ScenePhase.capturing || phase == ScenePhase.analyzing;

  SceneState copyWith({
    ScenePhase? phase,
    Uint8List? capturedImage,
    String? narration,
    List<DetectedObject>? detections,
    List<SceneLabel>? labels,
    SceneSynthesis? synthesis,
    String? errorMessage,
    bool? isSpeaking,
    DateTime? timestamp,
    bool clearImage = false,
    bool clearNarration = false,
    bool clearError = false,
  }) {
    return SceneState(
      phase: phase ?? this.phase,
      capturedImage: clearImage ? null : (capturedImage ?? this.capturedImage),
      narration: clearNarration ? null : (narration ?? this.narration),
      detections: detections ?? this.detections,
      labels: labels ?? this.labels,
      synthesis: synthesis ?? this.synthesis,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSpeaking: isSpeaking ?? this.isSpeaking,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
