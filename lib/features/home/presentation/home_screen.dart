import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../device_connection/data/device_providers.dart';
import '../../object_detection/data/object_detection_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasAutoConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAutoConnected && mounted) {
        _hasAutoConnected = true;
        _autoConnectAndInitialize();
      }
    });
  }

  Future<void> _autoConnectAndInitialize() async {
    try {
      final speech = ref.read(speechEngineProvider);
      await speech.initialize();

      speech.speakDirect('VisionAssist ready. Connecting to Smart-Cap camera.');

      // Preload YOLO11n model in background for fast inference
      ref.read(pipelineStateProvider.notifier).loadModel();

      // Proactively connect to ESP32-CAM hardware
      final connected = await ref
          .read(deviceConnectionProvider.notifier)
          .checkConnection();

      if (!mounted) return;

      if (connected) {
        speech.speakDirect('Smart-Cap camera connected. Object detection ready.');
      } else {
        speech.speakDirect(
          'Camera disconnected or unavailable. Please verify Wi-Fi connection to VisionAssist-Cap.',
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(deviceConnectionProvider);
    final config = ref.watch(deviceConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VisionAssist',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Smart-Cap Connection Status Card
            Semantics(
              container: true,
              label:
                  'ESP32-CAM Smart Cap Status: ${connectionState.status.name}. Host IP: ${config.host}',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.wifi_tethering,
                                  color: AppTheme.primaryAmber,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Smart-Cap Link',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.highContrastText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConnectionStatusBadge(status: connectionState.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Device Address: ${config.baseUrl}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      if (connectionState.lastSuccessfulResponse != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last sync: ${connectionState.lastSuccessfulResponse!.hour.toString().padLeft(2, '0')}:${connectionState.lastSuccessfulResponse!.minute.toString().padLeft(2, '0')}:${connectionState.lastSuccessfulResponse!.second.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: connectionState.isConnecting
                                  ? null
                                  : () => ref
                                        .read(deviceConnectionProvider.notifier)
                                        .checkConnection(),
                              icon: const Icon(Icons.refresh, size: 20),
                              label: Text(
                                connectionState.isConnecting
                                    ? 'Testing...'
                                    : 'Test Link',
                                style: const TextStyle(fontSize: 15),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/connection'),
                              icon: const Icon(Icons.tune, size: 20),
                              label: const Text(
                                'Manage',
                                style: TextStyle(fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Primary Camera Action Controls
            const Text(
              'ASSISTIVE NAVIGATION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.primaryAmber,
              ),
            ),
            const SizedBox(height: 10),

            // Large Walking Assistance Mode Button
            AccessibleButton(
              label: 'Start Walking Assistance',
              icon: Icons.directions_walk,
              isPrimary: true,
              semanticHint:
                  'Starts real-time YOLO11n obstacle detection, multi-object tracking, and spoken directions',
              onPressed: () => context.push('/walking-assistance'),
            ),

            const SizedBox(height: 12),

            // Large Live Camera Button
            AccessibleButton(
              label: 'Open Live Camera Stream',
              icon: Icons.videocam,
              isPrimary: false,
              semanticHint:
                  'Opens real-time MJPEG camera stream from ESP32-CAM',
              onPressed: () => context.push('/camera/live'),
            ),

            const SizedBox(height: 12),

            // Capture Still Image Button
            AccessibleButton(
              label: 'Capture Still Image',
              icon: Icons.camera_alt,
              isPrimary: false,
              semanticHint: 'Downloads a single high-resolution JPEG still frame from /capture',
              onPressed: () => context.push('/camera/capture'),
            ),

            const SizedBox(height: 28),

            // AI Features Section
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ASSISTIVE AI MODULES',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.accentCyan,
                  ),
                ),
                Text(
                  'Edge Intelligence',
                  style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _FeatureCard(
              title: 'Walking Assistance',
              subtitle: 'Obstacle avoidance with directional audio & footstep counting.',
              icon: Icons.directions_walk,
              badgeText: 'Active',
              onTap: () => context.push('/walking-assistance'),
            ),
            const SizedBox(height: 10),

            _FeatureCard(
              title: 'Object Detection',
              subtitle: 'Real-time YOLO11n neural detector with tracking and NMS.',
              icon: Icons.view_in_ar,
              badgeText: 'Ready',
              onTap: () => context.push('/features/object-detection'),
            ),
            const SizedBox(height: 10),

            _FeatureCard(
              title: 'OCR Text Reader',
              subtitle: 'Reads packaging text, signage, and documents aloud.',
              icon: Icons.text_fields,
              badgeText: 'Active',
              onTap: () => context.push('/features/text-reader'),
            ),
            const SizedBox(height: 10),

            _FeatureCard(
              title: 'Scene Understanding',
              subtitle: 'Contextual AI environmental summary on demand.',
              icon: Icons.psychology,
              badgeText: 'Active',
              onTap: () => context.push('/features/scene-understanding'),
            ),
            const SizedBox(height: 10),

            _FeatureCard(
              title: 'Voice Assistant',
              subtitle: 'Hands-free voice querying and verbal commands.',
              icon: Icons.mic,
              badgeText: 'Active',
              onTap: () => context.push('/features/voice-assistant'),
            ),
            const SizedBox(height: 10),

            _FeatureCard(
              title: 'Safety & Guardians',
              subtitle: 'Fall detection and emergency SMS escalation.',
              icon: Icons.emergency,
              badgeText: 'Active',
              onTap: () => context.push('/features/safety'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = badgeText == 'Active' || badgeText == 'Ready';

    return Semantics(
      button: true,
      label: '$title. $badgeText. $subtitle',
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Icon(icon, color: AppTheme.accentCyan, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.highContrastText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0x2200E676)
                                  : const Color(0x22CBD5E1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isActive
                                    ? AppTheme.successGreen
                                    : const Color(0xFF475569),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.successGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isActive
                                        ? AppTheme.successGreen
                                        : AppTheme.secondaryText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppTheme.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
