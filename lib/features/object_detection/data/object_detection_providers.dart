import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/data/camera_providers.dart';
import '../../camera/data/camera_stream_service.dart';
import '../../step_counter/data/user_step_detector_service.dart';
import '../../step_counter/domain/user_step_counter_state.dart';
import '../../step_counter/domain/visible_person_gait_analyzer.dart';
import '../../tracking/domain/object_tracker.dart';
import '../../voice_assistant/data/speech_announcement_engine.dart';
import '../domain/detected_object.dart';
import 'yolo_config.dart';
import 'yolo_detector.dart';

/// State of the active AI inference and walking pipeline
class PipelineState {
  final bool isModelLoaded;
  final bool isModelLoading;
  final String? modelError;
  final List<DetectedObject> currentDetections;
  final int inferenceTimeMs;
  final int totalProcessingTimeMs;
  final double currentFps;
  final bool isAssistanceRunning;
  final VisiblePersonGaitState visiblePersonGait;

  const PipelineState({
    this.isModelLoaded = false,
    this.isModelLoading = false,
    this.modelError,
    this.currentDetections = const [],
    this.inferenceTimeMs = 0,
    this.totalProcessingTimeMs = 0,
    this.currentFps = 0.0,
    this.isAssistanceRunning = false,
    this.visiblePersonGait = const VisiblePersonGaitState(),
  });

  PipelineState copyWith({
    bool? isModelLoaded,
    bool? isModelLoading,
    String? modelError,
    List<DetectedObject>? currentDetections,
    int? inferenceTimeMs,
    int? totalProcessingTimeMs,
    double? currentFps,
    bool? isAssistanceRunning,
    VisiblePersonGaitState? visiblePersonGait,
    bool clearError = false,
  }) {
    return PipelineState(
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      isModelLoading: isModelLoading ?? this.isModelLoading,
      modelError: clearError ? null : (modelError ?? this.modelError),
      currentDetections: currentDetections ?? this.currentDetections,
      inferenceTimeMs: inferenceTimeMs ?? this.inferenceTimeMs,
      totalProcessingTimeMs:
          totalProcessingTimeMs ?? this.totalProcessingTimeMs,
      currentFps: currentFps ?? this.currentFps,
      isAssistanceRunning: isAssistanceRunning ?? this.isAssistanceRunning,
      visiblePersonGait: visiblePersonGait ?? this.visiblePersonGait,
    );
  }
}

/// Provider for YOLO configuration
class YoloConfigNotifier extends Notifier<YoloConfig> {
  @override
  YoloConfig build() => const YoloConfig();

  void updateMode(AnnouncementMode mode) {
    state = state.copyWith(announcementMode: mode);
  }

  void updateConfidence(double confidence) {
    state = state.copyWith(confidenceThreshold: confidence);
  }

  void toggleSpeech() {
    state = state.copyWith(speechEnabled: !state.speechEnabled);
  }

  void updateMaxFps(int fps) {
    state = state.copyWith(maxInferenceFps: fps);
  }

  void updateCooldown(int seconds) {
    state = state.copyWith(announcementCooldownSeconds: seconds);
  }
}

final yoloConfigProvider =
    NotifierProvider<YoloConfigNotifier, YoloConfig>(() {
  return YoloConfigNotifier();
});

/// Singletons for edge AI processors
final yoloDetectorProvider = Provider<YoloDetector>((ref) {
  final config = ref.watch(yoloConfigProvider);
  final detector = YoloDetector(config: config);
  ref.onDispose(() => detector.dispose());
  return detector;
});

final objectTrackerProvider = Provider<ObjectTracker>((ref) {
  return ObjectTracker();
});

final speechEngineProvider = Provider<SpeechAnnouncementEngine>((ref) {
  final engine = SpeechAnnouncementEngine();
  engine.initialize();
  ref.onDispose(() => engine.dispose());
  return engine;
});

final userStepServiceProvider = Provider<UserStepDetectorService>((ref) {
  final service = UserStepDetectorService();
  ref.onDispose(() => service.dispose());
  return service;
});

final userStepStateProvider = StreamProvider<UserStepCounterState>((ref) {
  final service = ref.watch(userStepServiceProvider);
  return service.stateStream;
});

final visiblePersonGaitAnalyzerProvider =
    Provider<VisiblePersonGaitAnalyzer>((ref) {
  return VisiblePersonGaitAnalyzer();
});

/// Master Pipeline Notifier coordinating ESP32-CAM MJPEG frames,
/// YOLO11n inference, Multi-Object Tracking, Gait Analysis, and Spoken Announcements.
class PipelineNotifier extends Notifier<PipelineState> {
  StreamSubscription<StreamState>? _frameSubscription;
  bool _isProcessingFrame = false;

  @override
  PipelineState build() {
    ref.onDispose(() {
      _frameSubscription?.cancel();
    });
    return const PipelineState();
  }

  /// Loads YOLO11n model from assets
  Future<void> loadModel() async {
    state = state.copyWith(isModelLoading: true, clearError: true);
    final detector = ref.read(yoloDetectorProvider);
    final speechEngine = ref.read(speechEngineProvider);

    try {
      await detector.initialize();
      await speechEngine.initialize();
      state = state.copyWith(
        isModelLoaded: true,
        isModelLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isModelLoaded: false,
        isModelLoading: false,
        modelError: 'Failed to load YOLO11n model: $e',
      );
    }
  }

  /// Starts the end-to-end walking assistance pipeline
  Future<void> startPipeline() async {
    if (!state.isModelLoaded) {
      await loadModel();
      if (!state.isModelLoaded) return;
    }

    state = state.copyWith(isAssistanceRunning: true);

    // Start user step tracking
    ref.read(userStepServiceProvider).startTracking();

    // Listen to incoming live camera frames from CameraStreamService
    final streamService = ref.read(cameraStreamServiceProvider);
    _frameSubscription?.cancel();
    _frameSubscription = streamService.stateStream.listen((streamState) {
      if (streamState.currentFrame != null && state.isAssistanceRunning) {
        if (_isProcessingFrame) return; // Drop frame immediately to ensure 0ms latency
        _isProcessingFrame = true;
        _processFrame(streamState.currentFrame!.bytes, streamState.fps).whenComplete(() {
          _isProcessingFrame = false;
        });
      }
    });
  }

  /// Runs inference on a single still image (e.g. from /capture or offline test)
  Future<List<DetectedObject>> processStillFrame(Uint8List bytes) async {
    if (!state.isModelLoaded) {
      await loadModel();
      if (!state.isModelLoaded) return [];
    }
    return _processFrame(bytes, 0.0);
  }

  Future<List<DetectedObject>> _processFrame(
    Uint8List jpegBytes,
    double streamFps,
  ) async {
    final detector = ref.read(yoloDetectorProvider);
    final tracker = ref.read(objectTrackerProvider);
    final speechEngine = ref.read(speechEngineProvider);
    final gaitAnalyzer = ref.read(visiblePersonGaitAnalyzerProvider);
    final config = ref.read(yoloConfigProvider);

    detector.updateConfig(config);

    final result = await detector.detectFrame(jpegBytes);
    if (result == null) {
      return state.currentDetections;
    }

    // 1. Associate tracks
    final trackedDetections = tracker.updateTracks(result.objects);

    // 2. Prioritize and speak announcements
    speechEngine.processDetections(
      detections: trackedDetections,
      activeTracks: tracker.activeTracks,
      config: config,
    );

    // 3. Gait cycle analysis on visible person
    final gaitState = gaitAnalyzer.analyzeFrame(
      detections: trackedDetections,
      activeTracks: tracker.activeTracks,
      currentFps: streamFps,
    );

    state = state.copyWith(
      currentDetections: trackedDetections,
      inferenceTimeMs: result.inferenceTimeMs,
      totalProcessingTimeMs: result.totalProcessingTimeMs,
      currentFps: streamFps,
      visiblePersonGait: gaitState,
    );

    return trackedDetections;
  }

  void pausePipeline() {
    state = state.copyWith(isAssistanceRunning: false);
    ref.read(speechEngineProvider).pause();
    ref.read(userStepServiceProvider).pauseTracking();
  }

  void resumePipeline() {
    state = state.copyWith(isAssistanceRunning: true);
    ref.read(speechEngineProvider).resume();
    ref.read(userStepServiceProvider).resumeTracking();
  }

  void stopPipeline() {
    _frameSubscription?.cancel();
    _frameSubscription = null;
    state = state.copyWith(
      isAssistanceRunning: false,
      currentDetections: [],
    );
    ref.read(speechEngineProvider).stop();
    ref.read(objectTrackerProvider).reset();
    ref.read(visiblePersonGaitAnalyzerProvider).reset();
    ref.read(userStepServiceProvider).reset();
  }
}

final pipelineStateProvider =
    NotifierProvider<PipelineNotifier, PipelineState>(() {
  return PipelineNotifier();
});
