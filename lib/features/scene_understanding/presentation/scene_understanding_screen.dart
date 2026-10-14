import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../object_detection/data/object_detection_providers.dart';
import '../data/scene_description_engine.dart';
import '../data/scene_providers.dart';
import '../domain/scene_state.dart';

/// Scene Understanding AI Assistant Screen
///
/// On-demand environmental perception and contextual scene narration
/// powered by edge YOLO11n object perception and natural-language narration.
class SceneUnderstandingScreen extends ConsumerWidget {
  const SceneUnderstandingScreen({super.key});

  static const Color _cardBorderColor = Color(0xFF334155);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sceneState = ref.watch(sceneUnderstandingProvider);
    final pipelineState = ref.watch(pipelineStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scene Understanding'),
        actions: [
          if (sceneState.narration != null || sceneState.capturedImage != null)
            IconButton(
              tooltip: 'Reset scene',
              icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber),
              onPressed: () {
                ref.read(sceneUnderstandingProvider.notifier).clearScene();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status and Prompt Header
            _buildStatusHeader(context, ref, sceneState),

            const SizedBox(height: 16),

            // Primary Action Card
            _buildTriggerCard(context, ref, sceneState, pipelineState),

            // Captured frame preview (if available)
            if (sceneState.capturedImage != null) ...[
              const SizedBox(height: 16),
              _buildImageCard(sceneState),
            ],

            // Error display (if any)
            if (sceneState.errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(sceneState.errorMessage!),
            ],

            // AI Narration Result Card
            if (sceneState.narration != null) ...[
              const SizedBox(height: 16),
              _buildNarrationCard(context, ref, sceneState),

              const SizedBox(height: 16),
              _buildQuickQueriesCard(context, ref, sceneState),

              if (sceneState.labels.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetectedObjectsCard(sceneState),
              ],
            ],

            const SizedBox(height: 16),

            // Accessibility & Smart-Cap Guidance
            _buildGuidanceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(
    BuildContext context,
    WidgetRef ref,
    SceneState state,
  ) {
    String statusTitle;
    Color statusColor;
    IconData statusIcon;

    switch (state.phase) {
      case ScenePhase.capturing:
        statusTitle = 'Capturing Camera Frame...';
        statusColor = AppTheme.primaryAmber;
        statusIcon = Icons.camera_alt;
        break;
      case ScenePhase.analyzing:
        statusTitle = 'AI Analyzing Environment...';
        statusColor = AppTheme.accentCyan;
        statusIcon = Icons.psychology;
        break;
      case ScenePhase.speaking:
        statusTitle = 'Describing Scene Aloud';
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.record_voice_over;
        break;
      case ScenePhase.error:
        statusTitle = 'Perception Interrupted';
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.warning_amber;
        break;
      case ScenePhase.idle:
        if (state.narration != null) {
          statusTitle = 'Scene Ready';
          statusColor = AppTheme.successGreen;
          statusIcon = Icons.check_circle_outline;
        } else {
          statusTitle = 'Assistant Ready';
          statusColor = AppTheme.primaryAmber;
          statusIcon = Icons.auto_awesome;
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.highContrastText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.isLoading
                      ? 'Processing frame with edge neural network...'
                      : 'Tap button below to capture and synthesize spoken surroundings.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerCard(
    BuildContext context,
    WidgetRef ref,
    SceneState state,
    PipelineState pipeline,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccessibleButton(
            label: state.isLoading ? 'Analyzing Scene...' : 'Describe Scene Now',
            icon: state.isLoading ? Icons.hourglass_top : Icons.record_voice_over,
            isPrimary: true,
            customColor: AppTheme.primaryAmber,
            customTextColor: Colors.black,
            onPressed: state.isLoading
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(sceneUnderstandingProvider.notifier)
                        .captureAndDescribe();
                  },
          ),
          if (pipeline.inferenceTimeMs > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Last inference: ${pipeline.inferenceTimeMs}ms • Neural engine on-device',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageCard(SceneState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.memory(
                state.capturedImage!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  color: AppTheme.darkBackground,
                  child: const Center(
                    child: Text(
                      'Preview unavailable',
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _cardBorderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye, color: AppTheme.accentCyan, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${state.detections.length} objects detected',
                        style: const TextStyle(
                          color: AppTheme.highContrastText,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNarrationCard(
    BuildContext context,
    WidgetRef ref,
    SceneState state,
  ) {
    final narration = state.narration ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.speaker_notes, color: AppTheme.primaryAmber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI Scene Narration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.highContrastText,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: AppTheme.secondaryText),
                tooltip: 'Copy narration',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: narration));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Narration copied to clipboard.')),
                  );
                },
              ),
            ],
          ),
          // Contextual environment and path clearance badges
          if (state.synthesis != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x3338BDF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentCyan, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 14, color: AppTheme.accentCyan),
                      const SizedBox(width: 4),
                      Text(
                        state.synthesis!.environment.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.synthesis!.clearance == PathClearanceLevel.clear
                        ? const Color(0x3300E676)
                        : const Color(0x33FF5252),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: state.synthesis!.clearance == PathClearanceLevel.clear
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.synthesis!.clearance == PathClearanceLevel.clear
                            ? Icons.check_circle_outline
                            : Icons.warning_amber,
                        size: 14,
                        color: state.synthesis!.clearance == PathClearanceLevel.clear
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.synthesis!.clearance.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: state.synthesis!.clearance == PathClearanceLevel.clear
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Semantics(
            label: 'Environmental description: $narration',
            child: Text(
              narration,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppTheme.highContrastText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AccessibleButton(
                  label: state.isSpeaking ? 'Speaking...' : 'Replay Audio',
                  icon: state.isSpeaking ? Icons.volume_up : Icons.play_arrow,
                  isPrimary: false,
                  customColor: _cardBorderColor,
                  customTextColor: AppTheme.highContrastText,
                  onPressed: () {
                    ref.read(sceneUnderstandingProvider.notifier).speakNarration();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccessibleButton(
                  label: 'Stop Audio',
                  icon: Icons.stop,
                  isPrimary: false,
                  customColor: _cardBorderColor,
                  customTextColor: AppTheme.errorRed,
                  onPressed: () {
                    ref.read(sceneUnderstandingProvider.notifier).stopSpeaking();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQueriesCard(
    BuildContext context,
    WidgetRef ref,
    SceneState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Instant Scene Inquiries',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.highContrastText,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.explore, size: 16, color: AppTheme.accentCyan),
                label: const Text('Where Am I?', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(sceneUnderstandingProvider.notifier).speakEnvironment();
                },
              ),
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.straight, size: 16, color: AppTheme.primaryAmber),
                label: const Text('Path Ahead', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(sceneUnderstandingProvider.notifier).speakPathCheck();
                },
              ),
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.warning, size: 16, color: AppTheme.errorRed),
                label: const Text('Check Hazards', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(sceneUnderstandingProvider.notifier).speakHazardCheck();
                },
              ),
              ActionChip(
                backgroundColor: _cardBorderColor,
                avatar: const Icon(Icons.refresh, size: 16, color: AppTheme.secondaryText),
                label: const Text('Describe Again', style: TextStyle(color: AppTheme.highContrastText)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(sceneUnderstandingProvider.notifier).captureAndDescribe();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedObjectsCard(SceneState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Identified Scene Elements',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.highContrastText,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.labels.map((item) {
              final color = item.isHazard ? AppTheme.errorRed : AppTheme.accentCyan;
              return Chip(
                backgroundColor: AppTheme.darkBackground,
                side: BorderSide(color: color.withValues(alpha: 0.6)),
                label: Text(
                  '${item.label} (${item.count})',
                  style: TextStyle(
                    color: item.isHazard ? AppTheme.errorRed : AppTheme.highContrastText,
                    fontWeight: item.isHazard ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorRed),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryAmber, size: 20),
              SizedBox(width: 8),
              Text(
                'Assistant Tips',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.highContrastText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Point your Smart-Cap camera toward the room or path you wish to explore.\n'
            '• Narration reports approaching hazards first, followed by center path, then lateral objects.\n'
            '• Tap "Path Ahead" to check if your immediate center zone is clear of chairs, doors, or stairs.\n'
            '• All vision perception is performed 100% locally on your phone without cloud dependency.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
