import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../camera/data/camera_providers.dart';
import '../../device_connection/data/device_providers.dart';
import '../../object_detection/data/object_detection_providers.dart';
import '../../object_detection/data/yolo_config.dart';
import '../domain/scene_state.dart';
import 'scene_description_engine.dart';

/// Riverpod notifier managing state for the Scene Understanding AI Assistant.
class SceneUnderstandingNotifier extends Notifier<SceneState> {
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  @override
  SceneState build() {
    ref.onDispose(() {
      _tts.stop();
    });
    _initTts();
    return const SceneState();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.50);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        state = state.copyWith(isSpeaking: true);
      });
      _tts.setCompletionHandler(() {
        state = state.copyWith(isSpeaking: false);
      });
      _tts.setErrorHandler((_) {
        state = state.copyWith(isSpeaking: false);
      });
      _tts.setCancelHandler(() {
        state = state.copyWith(isSpeaking: false);
      });
      _ttsReady = true;
    } catch (_) {}
  }

  /// Triggers full AI scene perception:
  /// 1. Grabs latest frame from live stream or requests fresh capture from ESP32-CAM.
  /// 2. Executes on-device YOLO11n neural detector on the frame.
  /// 3. Generates structured, natural-language spatial narration.
  /// 4. Speaks narration through TTS for hands-free assistive guidance.
  Future<void> captureAndDescribe() async {
    state = state.copyWith(
      phase: ScenePhase.capturing,
      clearNarration: true,
      clearError: true,
    );

    try {
      Uint8List? frameBytes;
      double fps = 0.0;

      // Check if camera live stream has an active frame
      final streamService = ref.read(cameraStreamServiceProvider);
      final currentStreamFrame = streamService.currentState.currentFrame;
      if (currentStreamFrame != null) {
        frameBytes = currentStreamFrame.bytes;
        fps = streamService.currentState.fps;
      }

      // If not streaming, fetch snapshot from device /capture
      if (frameBytes == null) {
        final repository = ref.read(deviceRepositoryProvider);
        frameBytes = await repository.captureStillImage(
          timeout: const Duration(seconds: 8),
        );
      }

      state = state.copyWith(
        phase: ScenePhase.analyzing,
        capturedImage: frameBytes,
      );

      // Run inference through pipeline
      final pipelineNotifier = ref.read(pipelineStateProvider.notifier);
      final detections = await pipelineNotifier.processStillFrame(frameBytes);

      // Synthesize rich natural-language description and structured context
      final synthesis = SceneDescriptionEngine.synthesize(
        detections: detections,
        cameraFps: fps,
      );

      state = state.copyWith(
        phase: ScenePhase.idle,
        narration: synthesis.spokenNarration,
        detections: detections,
        labels: synthesis.labels,
        synthesis: synthesis,
        timestamp: DateTime.now(),
        clearError: true,
      );

      // Speak narration
      await speakNarration();
    } catch (e) {
      state = state.copyWith(
        phase: ScenePhase.error,
        errorMessage: _friendlyError(e),
        isSpeaking: false,
      );
    }
  }

  /// Query specific focus: Hazard analysis
  Future<void> speakHazardCheck() async {
    final detections = state.detections;
    if (detections.isEmpty) {
      await _speakDirect('No hazards detected. Your immediate path appears clear.');
      return;
    }

    final hazards = detections
        .where((d) => YoloConfig.isHazardClass(d.label))
        .map((d) => '${d.label} in ${d.directionZone.name} zone')
        .toList();

    if (hazards.isEmpty) {
      await _speakDirect('No immediate hazards detected in view.');
    } else {
      final msg = 'Attention: ${hazards.length} potential hazard${hazards.length == 1 ? '' : 's'}: ${hazards.join(', ')}.';
      await _speakDirect(msg);
    }
  }

  /// Query specific focus: Path clearance ahead (center zone)
  Future<void> speakPathCheck() async {
    final clearance = state.synthesis?.clearance ??
        SceneDescriptionEngine.checkPathClearance(state.detections);

    final centerObjects = state.detections
        .where((d) => d.directionZone.name == 'center')
        .map((d) => d.label)
        .toSet()
        .toList();

    if (clearance == PathClearanceLevel.clear) {
      await _speakDirect('Center path directly ahead is completely clear.');
    } else if (clearance == PathClearanceLevel.hazardDirectlyBlocked) {
      final items = centerObjects.isNotEmpty ? centerObjects.join(' and ') : 'Obstacle';
      await _speakDirect('Warning: Walking path directly blocked by $items. Shift left or right.');
    } else {
      final items = centerObjects.isNotEmpty ? centerObjects.join(' and ') : 'objects';
      await _speakDirect('Caution: $items ahead in center corridor. Proceed with care.');
    }
  }

  /// Query specific focus: Environmental context ("Where am I?")
  Future<void> speakEnvironment() async {
    final env = state.synthesis?.environment ??
        SceneDescriptionEngine.classifyEnvironment(state.detections);
    await _speakDirect('You appear to be in a ${env.displayName}. ${env.description}.');
  }

  /// Vocalizes current scene narration
  Future<void> speakNarration() async {
    final text = state.narration;
    if (text == null || text.isEmpty) return;
    await _speakDirect(text);
  }

  Future<void> _speakDirect(String text) async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
      state = state.copyWith(isSpeaking: true);
      await _tts.speak(text);
    } catch (_) {
      state = state.copyWith(isSpeaking: false);
    }
  }

  /// Silences TTS
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    state = state.copyWith(isSpeaking: false);
  }

  /// Clears current scene analysis
  void clearScene() {
    stopSpeaking();
    state = const SceneState();
  }

  String _friendlyError(Object error) {
    final s = error.toString().toLowerCase();
    if (s.contains('timed out') || s.contains('timeoutexception')) {
      return 'ESP32-CAM camera timed out. Verify your Wi-Fi link to the Smart-Cap.';
    }
    if (s.contains('socketexception') || s.contains('connection refused')) {
      return 'Cannot reach ESP32-CAM. Check device power and IP connection.';
    }
    return 'Analysis error: $error';
  }
}

/// Provider for SceneUnderstandingNotifier
final sceneUnderstandingProvider =
    NotifierProvider<SceneUnderstandingNotifier, SceneState>(() {
  return SceneUnderstandingNotifier();
});
