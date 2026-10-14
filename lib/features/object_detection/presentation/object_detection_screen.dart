import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../camera/data/camera_providers.dart';
import '../../camera/data/camera_stream_service.dart';
import '../../device_connection/data/device_providers.dart';
import '../data/object_detection_providers.dart';
import '../data/yolo_config.dart';
import '../domain/direction_zone.dart';
import 'widgets/detection_box_painter.dart';

class ObjectDetectionScreen extends ConsumerStatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  ConsumerState<ObjectDetectionScreen> createState() =>
      _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends ConsumerState<ObjectDetectionScreen> {
  bool _autoStarted = false;

  late PipelineNotifier _pipelineNotifier;
  late CameraStreamService _streamService;

  @override
  void initState() {
    super.initState();
    _pipelineNotifier = ref.read(pipelineStateProvider.notifier);
    _streamService = ref.read(cameraStreamServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoStarted && mounted) {
        _autoStarted = true;
        _startDetectionSession();
      }
    });
  }

  Future<void> _startDetectionSession() async {
    // 1. Initialize YOLO model
    await _pipelineNotifier.loadModel();

    // 2. Start camera stream
    final config = ref.read(deviceConfigProvider);
    await _streamService.startStream(config.streamUri);

    // 3. Start pipeline
    await _pipelineNotifier.startPipeline();
  }

  void _stopDetectionSession() {
    _pipelineNotifier.stopPipeline();
    _streamService.stopStream();
  }

  @override
  void dispose() {
    _stopDetectionSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = ref.watch(pipelineStateProvider);
    final streamState = ref.watch(liveStreamStateProvider).value ??
        ref.watch(cameraStreamServiceProvider).currentState;
    final yoloConfig = ref.watch(yoloConfigProvider);
    final deviceConfig = ref.watch(deviceConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('YOLO11n Object Detection'),
        actions: [
          // Speech Toggle Button
          IconButton(
            icon: Icon(
              yoloConfig.speechEnabled ? Icons.volume_up : Icons.volume_off,
              color: yoloConfig.speechEnabled
                  ? AppTheme.accentCyan
                  : AppTheme.secondaryText,
            ),
            tooltip: yoloConfig.speechEnabled ? 'Mute Speech' : 'Enable Speech',
            onPressed: () {
              ref.read(yoloConfigProvider.notifier).toggleSpeech();
              final engine = ref.read(speechEngineProvider);
              engine.toggleMute();
            },
          ),
          // Configuration Bottom Sheet
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Detection Settings',
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Diagnostic Performance Bar
            _buildMetricsBar(pipeline, streamState),

            // Video Viewport with YOLO Bounding Box Overlay
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Center(
                  child: _buildVideoViewport(streamState, pipeline, yoloConfig),
                ),
              ),
            ),

            // Detected Objects Summary Strip
            _buildDetectionsList(pipeline),

            // Controls Footer
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.darkSurface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pipeline.modelError != null) ...[
                    ErrorBanner(
                      title: 'Model Notice',
                      message: pipeline.modelError!,
                      onRetry: _startDetectionSession,
                      retryLabel: 'Retry Initializing Model',
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: AccessibleButton(
                          label: pipeline.isAssistanceRunning
                              ? 'Pause Detection'
                              : 'Resume Detection',
                          icon: pipeline.isAssistanceRunning
                              ? Icons.pause_circle_outline
                              : Icons.play_arrow,
                          isPrimary: !pipeline.isAssistanceRunning,
                          onPressed: () {
                            if (pipeline.isAssistanceRunning) {
                              ref
                                  .read(pipelineStateProvider.notifier)
                                  .pausePipeline();
                            } else {
                              ref
                                  .read(pipelineStateProvider.notifier)
                                  .resumePipeline();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showModeSelector(context),
                          icon: const Icon(Icons.alt_route, size: 20),
                          label: Text(
                            yoloConfig.announcementMode.shortName,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connected to: ${deviceConfig.streamUri}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsBar(PipelineState pipeline, StreamState streamState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0F172A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pipeline.isModelLoaded
                      ? AppTheme.successGreen
                      : (pipeline.isModelLoading
                          ? AppTheme.primaryAmber
                          : AppTheme.errorRed),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pipeline.isModelLoaded
                    ? 'YOLO11n Ready'
                    : (pipeline.isModelLoading ? 'Loading Model...' : 'Model Offline'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.highContrastText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Stream: ${streamState.fps.toStringAsFixed(1)} FPS',
                style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
              const SizedBox(width: 12),
              Text(
                'Inference: ${pipeline.inferenceTimeMs}ms',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: pipeline.inferenceTimeMs < 120
                      ? AppTheme.accentCyan
                      : AppTheme.primaryAmber,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Objects: ${pipeline.currentDetections.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.highContrastText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoViewport(
    StreamState streamState,
    PipelineState pipeline,
    YoloConfig config,
  ) {
    if (pipeline.isModelLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
          ),
          SizedBox(height: 16),
          Text(
            'Initializing YOLO11n Neural Engine...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
    }

    if (streamState.currentFrame != null) {
      return AspectRatio(
        aspectRatio: 4 / 3, // OV2640 native camera aspect ratio
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Raw Camera Frame
            Image.memory(
              streamState.currentFrame!.bytes,
              gaplessPlayback: true,
              fit: BoxFit.contain,
            ),
            // Real-Time YOLO11n Bounding Box & Direction Divider Overlay
            CustomPaint(
              painter: DetectionBoxPainter(
                objects: pipeline.currentDetections,
                leftZoneThreshold: config.leftZoneThreshold,
                rightZoneThreshold: config.rightZoneThreshold,
                showZoneDividers: true,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_off, color: Color(0xFF64748B), size: 48),
        const SizedBox(height: 12),
        const Text(
          'Waiting for ESP32-CAM stream...',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          streamState.errorMessage ?? 'Ensure phone is connected to camera Wi-Fi.',
          style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildDetectionsList(PipelineState pipeline) {
    if (pipeline.currentDetections.isEmpty) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFF1E293B),
        alignment: Alignment.centerLeft,
        child: const Text(
          'Path clear — no objects detected meeting confidence threshold.',
          style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
        ),
      );
    }

    return Container(
      height: 64,
      color: const Color(0xFF1E293B),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: pipeline.currentDetections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final obj = pipeline.currentDetections[index];
          final isCenter = obj.directionZone == DirectionZone.center;
          final isHazard = YoloConfig.isHazardClass(obj.label);

          final chipColor = isCenter && isHazard
              ? const Color(0x33FF5252)
              : const Color(0x2200E5FF);
          final borderColor = isCenter && isHazard
              ? AppTheme.errorRed
              : AppTheme.accentCyan;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHazard ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: borderColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${obj.label} (${obj.directionZone.displayName})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(obj.confidence * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showModeSelector(BuildContext context) {
    final currentMode = ref.read(yoloConfigProvider).announcementMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Material(
          color: AppTheme.darkSurface,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                  'Announcement Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.highContrastText,
                  ),
                ),
                const SizedBox(height: 16),
                ...AnnouncementMode.values.map((mode) {
                  final isSelected = mode == currentMode;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? AppTheme.primaryAmber
                          : AppTheme.secondaryText,
                    ),
                    title: Text(
                      mode.displayName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: AppTheme.highContrastText,
                      ),
                    ),
                    subtitle: Text(
                      _getModeDescription(mode),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    onTap: () {
                      ref.read(yoloConfigProvider.notifier).updateMode(mode);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  String _getModeDescription(AnnouncementMode mode) {
    switch (mode) {
      case AnnouncementMode.importantObjects:
        return 'Alerts only for recognized hazards (vehicles, pedestrians, stairs, obstacles).';
      case AnnouncementMode.allObjects:
        return 'Speaks every confident object detected with deduplication.';
      case AnnouncementMode.walkingAssistance:
        return 'Prioritizes objects directly in your walking path (center zone) and approaching objects.';
    }
  }

  void _showSettingsSheet(BuildContext context) {
    final yoloConfig = ref.read(yoloConfigProvider);
    double confidence = yoloConfig.confidenceThreshold;
    int fps = yoloConfig.maxInferenceFps;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detection Parameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.highContrastText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Confidence Threshold: ${(confidence * 100).toInt()}%',
                      style: const TextStyle(color: AppTheme.highContrastText),
                    ),
                    Slider(
                      value: confidence,
                      min: 0.20,
                      max: 0.80,
                      divisions: 12,
                      activeColor: AppTheme.primaryAmber,
                      onChanged: (val) {
                        setSheetState(() => confidence = val);
                        ref.read(yoloConfigProvider.notifier).updateConfidence(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Max Inference Rate: $fps FPS',
                      style: const TextStyle(color: AppTheme.highContrastText),
                    ),
                    Slider(
                      value: fps.toDouble(),
                      min: 2,
                      max: 15,
                      divisions: 13,
                      activeColor: AppTheme.accentCyan,
                      onChanged: (val) {
                        setSheetState(() => fps = val.round());
                        ref.read(yoloConfigProvider.notifier).updateMaxFps(val.round());
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
