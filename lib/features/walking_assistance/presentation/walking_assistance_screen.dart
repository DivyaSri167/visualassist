import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../camera/data/camera_providers.dart';
import '../../camera/data/camera_stream_service.dart';
import '../../device_connection/data/device_providers.dart';
import '../../object_detection/data/object_detection_providers.dart';
import '../../object_detection/data/yolo_config.dart';
import '../../object_detection/domain/direction_zone.dart';
import '../../object_detection/presentation/widgets/detection_box_painter.dart';
import '../../step_counter/domain/user_step_counter_state.dart';

class WalkingAssistanceScreen extends ConsumerStatefulWidget {
  const WalkingAssistanceScreen({super.key});

  @override
  ConsumerState<WalkingAssistanceScreen> createState() =>
      _WalkingAssistanceScreenState();
}

class _WalkingAssistanceScreenState
    extends ConsumerState<WalkingAssistanceScreen> {
  bool _initialized = false;

  late PipelineNotifier _pipelineNotifier;
  late CameraStreamService _streamService;

  @override
  void initState() {
    super.initState();
    _pipelineNotifier = ref.read(pipelineStateProvider.notifier);
    _streamService = ref.read(cameraStreamServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized && mounted) {
        _initialized = true;
        _startWalkingAssistance();
      }
    });
  }

  Future<void> _startWalkingAssistance() async {
    // Set Mode C (Walking Guidance)
    ref
        .read(yoloConfigProvider.notifier)
        .updateMode(AnnouncementMode.walkingAssistance);

    // Initialize YOLO and start camera stream
    final config = ref.read(deviceConfigProvider);
    await _streamService.startStream(config.streamUri);

    // Start pipeline and step tracking
    await _pipelineNotifier.startPipeline();
  }

  void _stopWalkingAssistance() {
    _pipelineNotifier.stopPipeline();
    _streamService.stopStream();
  }

  @override
  void dispose() {
    _stopWalkingAssistance();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = ref.watch(pipelineStateProvider);
    final streamState = ref.watch(liveStreamStateProvider).value ??
        ref.watch(cameraStreamServiceProvider).currentState;
    final userStepState = ref.watch(userStepStateProvider).value ??
        ref.watch(userStepServiceProvider).currentState;
    final yoloConfig = ref.watch(yoloConfigProvider);
    final speechEngine = ref.watch(speechEngineProvider);

    // Partition detections by direction zone
    final leftObjects = pipeline.currentDetections
        .where((d) => d.directionZone == DirectionZone.left)
        .toList();
    final centerObjects = pipeline.currentDetections
        .where((d) => d.directionZone == DirectionZone.center)
        .toList();
    final rightObjects = pipeline.currentDetections
        .where((d) => d.directionZone == DirectionZone.right)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking Assistance'),
        actions: [
          // Audio Mute Toggle
          IconButton(
            icon: Icon(
              speechEngine.isMuted ? Icons.volume_off : Icons.volume_up,
              color: speechEngine.isMuted
                  ? AppTheme.errorRed
                  : AppTheme.accentCyan,
              size: 26,
            ),
            tooltip: speechEngine.isMuted ? 'Unmute Audio' : 'Mute Audio',
            onPressed: () {
              setState(() {
                speechEngine.toggleMute();
              });
            },
          ),
          // Speak Step Count Summary
          IconButton(
            icon: const Icon(Icons.directions_walk, size: 26),
            tooltip: 'Announce Step Count',
            onPressed: () {
              final summary = ref
                  .read(userStepServiceProvider)
                  .getSpokenSummary();
              speechEngine.speakDirect(summary);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Directional Path Guidance Banner
            _buildPathStatusBanner(centerObjects),

            // Camera Viewport with YOLO Overlay
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (streamState.currentFrame != null)
                          Image.memory(
                            streamState.currentFrame!.bytes,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                          )
                        else
                          const Center(
                            child: Text(
                              'Connecting to camera...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        CustomPaint(
                          painter: DetectionBoxPainter(
                            objects: pipeline.currentDetections,
                            leftZoneThreshold: yoloConfig.leftZoneThreshold,
                            rightZoneThreshold: yoloConfig.rightZoneThreshold,
                            showZoneDividers: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Left / Center / Right Horizontal Zone Strip
            _buildDirectionalStrip(leftObjects, centerObjects, rightObjects),

            // User Motion Sensors & Step Counter Card
            _buildUserStepCard(userStepState),

            // Camera-Based Visible Person Gait Estimation Card (Clearly marked as Estimate)
            _buildVisiblePersonGaitCard(pipeline.visiblePersonGait),

            // Controls & Pause / Stop Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.darkSurface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AccessibleButton(
                          label: pipeline.isAssistanceRunning
                              ? 'Pause Assistance'
                              : 'Resume Assistance',
                          icon: pipeline.isAssistanceRunning
                              ? Icons.pause
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
                          onPressed: () {
                            final summary = ref
                                .read(userStepServiceProvider)
                                .getSpokenSummary();
                            speechEngine.speakDirect(summary);
                          },
                          icon: const Icon(Icons.record_voice_over, size: 20),
                          label: const Text('Speak Status'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Assistive prototype. Always maintain primary mobility aid (cane/dog).',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathStatusBanner(List centerObjects) {
    final hasCenterObstacles = centerObjects.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: hasCenterObstacles
          ? const Color(0x44FF5252)
          : const Color(0x3300E676),
      child: Row(
        children: [
          Icon(
            hasCenterObstacles
                ? Icons.warning_rounded
                : Icons.check_circle_outline,
            color: hasCenterObstacles
                ? AppTheme.errorRed
                : AppTheme.successGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasCenterObstacles
                  ? 'CAUTION: ${centerObjects.length} obstacle(s) detected directly in forward path.'
                  : 'Forward path appears unobstructed by recognized obstacles.',
              style: TextStyle(
                color: hasCenterObstacles
                    ? const Color(0xFFFF8A80)
                    : const Color(0xFFB9F6CA),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionalStrip(
    List leftObjects,
    List centerObjects,
    List rightObjects,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          Expanded(
            child: _buildZoneColumn(
              'LEFT (${leftObjects.length})',
              leftObjects.map((o) => o.label).join(', '),
              AppTheme.secondaryText,
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFF334155)),
          Expanded(
            child: _buildZoneColumn(
              'CENTER (${centerObjects.length})',
              centerObjects.map((o) => o.label).join(', '),
              centerObjects.isNotEmpty ? AppTheme.errorRed : AppTheme.successGreen,
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFF334155)),
          Expanded(
            child: _buildZoneColumn(
              'RIGHT (${rightObjects.length})',
              rightObjects.map((o) => o.label).join(', '),
              AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneColumn(String title, String items, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            items.isEmpty ? 'None' : items,
            style: const TextStyle(fontSize: 11, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUserStepCard(UserStepCounterState state) {
    final minutes = state.walkingDuration.inMinutes;
    final seconds = state.walkingDuration.inSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_walk,
                color: AppTheme.primaryAmber,
                size: 28,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Steps (Phone Sensors)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  Text(
                    '${state.sessionSteps} steps',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.highContrastText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Walking Time: $timeStr',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                state.sensorSource == StepSensorSource.nativePedometer
                    ? 'Native Step Sensor'
                    : 'Accelerometer Engine',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisiblePersonGaitCard(
    dynamic gaitState, // VisiblePersonGaitState
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.accessibility_new,
            color: AppTheme.accentCyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              gaitState.statusDescription,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
