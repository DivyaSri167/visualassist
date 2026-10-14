import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/config/device_config.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../device_connection/data/device_providers.dart';
import '../../object_detection/data/object_detection_providers.dart';
import '../../object_detection/data/yolo_config.dart';
import '../../step_counter/domain/user_step_counter_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _hostController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(deviceConfigProvider);
    _hostController = TextEditingController(text: config.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final host = _hostController.text.trim();
    if (host.isNotEmpty) {
      ref.read(deviceConfigProvider.notifier).updateHost(host);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device host saved successfully.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  void _resetDefault() {
    _hostController.text = DeviceConfig.defaultHost;
    ref.read(deviceConfigProvider.notifier).resetToDefault();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Host reset to default: 192.168.4.1'),
        backgroundColor: AppTheme.primaryAmber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(deviceConfigProvider);
    final connectionState = ref.watch(deviceConnectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Device Status Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Smart-Cap',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.highContrastText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config.baseUrl,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    ConnectionStatusBadge(status: connectionState.status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'NETWORK CONFIGURATION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.primaryAmber,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _hostController,
              keyboardType: TextInputType.url,
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.highContrastText,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'ESP32-CAM Host / IP',
                labelStyle: const TextStyle(color: AppTheme.primaryAmber),
                filled: true,
                fillColor: AppTheme.darkSurface,
                hintText: '192.168.4.1',
                prefixIcon: const Icon(
                  Icons.router,
                  color: AppTheme.primaryAmber,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryAmber,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    label: 'Save Host',
                    icon: Icons.save,
                    onPressed: _saveSettings,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AccessibleButton(
                    label: 'Reset to Default',
                    icon: Icons.restore,
                    isPrimary: false,
                    onPressed: _resetDefault,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            AccessibleButton(
              label: 'Test Link Now',
              icon: Icons.network_check,
              isPrimary: false,
              isLoading: connectionState.isConnecting,
              onPressed: () {
                _saveSettings();
                ref.read(deviceConnectionProvider.notifier).checkConnection();
              },
            ),

            const SizedBox(height: 28),

            const Text(
              'HARDWARE & AP CREDENTIALS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    _buildParam('Access Point SSID', DeviceConfig.defaultSsid),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildParam('Wi-Fi Password', DeviceConfig.defaultPassword),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildParam('Default Gateway', DeviceConfig.defaultHost),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildParam('Camera Sensor', 'OV2640 (AI-Thinker)'),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildParam('Status API', '/status (JSON)'),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildParam('Capture API', '/capture (JPEG)'),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildParam('Stream API', '/stream (MJPEG)'),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildParam('SOS API', '/sos (POST)'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cleartext security prototype notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x2238BDF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cleartext HTTP is enabled in the Android network security configuration specifically for prototype communication with the ESP32-CAM local access point.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.highContrastText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── YOLO11n AI SETTINGS ──────────────────────────────────
            const Text(
              'YOLO11n DETECTION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 10),
            _YoloSettingsPanel(),

            const SizedBox(height: 24),

            // ── STEP COUNTER ─────────────────────────────────────────
            const Text(
              'STEP COUNTER',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(height: 10),
            _StepCounterPanel(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildParam(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: AppTheme.secondaryText),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.highContrastText,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YOLO Settings Panel
// ─────────────────────────────────────────────────────────────────────────────
class _YoloSettingsPanel extends ConsumerWidget {
  const _YoloSettingsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(yoloConfigProvider);
    final pipeline = ref.watch(pipelineStateProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model status row
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pipeline.isModelLoaded
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  pipeline.isModelLoaded
                      ? 'YOLO11n model loaded — ${YoloConfig.defaultInputSize}×${YoloConfig.defaultInputSize}'
                      : pipeline.isModelLoading
                          ? 'Loading YOLO11n…'
                          : 'YOLO11n not yet loaded',
                  style: TextStyle(
                    color: pipeline.isModelLoaded
                        ? AppTheme.successGreen
                        : AppTheme.secondaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!pipeline.isModelLoaded)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: pipeline.isModelLoading
                      ? null
                      : () => ref.read(pipelineStateProvider.notifier).loadModel(),
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Load YOLO11n Model'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),

            if (pipeline.isModelLoaded) ...[
              // Confidence Threshold
              Text(
                'Confidence Threshold: ${(config.confidenceThreshold * 100).toInt()}%',
                style: const TextStyle(fontSize: 14, color: AppTheme.highContrastText),
              ),
              Slider(
                value: config.confidenceThreshold,
                min: 0.20,
                max: 0.80,
                divisions: 12,
                activeColor: AppTheme.successGreen,
                label: '${(config.confidenceThreshold * 100).toInt()}%',
                onChanged: (val) =>
                    ref.read(yoloConfigProvider.notifier).updateConfidence(val),
              ),

              // Max FPS
              Text(
                'Max Inference Rate: ${config.maxInferenceFps} FPS',
                style: const TextStyle(fontSize: 14, color: AppTheme.highContrastText),
              ),
              Slider(
                value: config.maxInferenceFps.toDouble(),
                min: 2,
                max: 15,
                divisions: 13,
                activeColor: AppTheme.accentCyan,
                label: '${config.maxInferenceFps} FPS',
                onChanged: (val) =>
                    ref.read(yoloConfigProvider.notifier).updateMaxFps(val.round()),
              ),

              // Cooldown
              Text(
                'Re-announcement Cooldown: ${config.announcementCooldownSeconds}s',
                style: const TextStyle(fontSize: 14, color: AppTheme.highContrastText),
              ),
              Slider(
                value: config.announcementCooldownSeconds.toDouble(),
                min: 2,
                max: 15,
                divisions: 13,
                activeColor: AppTheme.primaryAmber,
                label: '${config.announcementCooldownSeconds}s',
                onChanged: (val) =>
                    ref.read(yoloConfigProvider.notifier).updateCooldown(val.round()),
              ),

              // Speech toggle
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  dense: true,
                  activeThumbColor: AppTheme.primaryAmber,
                  title: const Text(
                    'Spoken Announcements',
                    style: TextStyle(fontSize: 15, color: AppTheme.highContrastText),
                  ),
                  subtitle: const Text(
                    'Speaks object name and direction through earphones',
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                  ),
                  value: config.speechEnabled,
                  onChanged: (_) =>
                      ref.read(yoloConfigProvider.notifier).toggleSpeech(),
                ),
              ),

              // Announcement Mode
              const SizedBox(height: 6),
              const Text(
                'Announcement Mode',
                style: TextStyle(fontSize: 14, color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 6),
              RadioGroup<AnnouncementMode>(
                groupValue: config.announcementMode,
                onChanged: (m) {
                  if (m != null) {
                    ref.read(yoloConfigProvider.notifier).updateMode(m);
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: AnnouncementMode.values.map((mode) {
                      final selected = mode == config.announcementMode;
                      return RadioListTile<AnnouncementMode>(
                        dense: true,
                        activeColor: AppTheme.primaryAmber,
                        value: mode,
                        title: Text(
                          mode.shortName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: AppTheme.highContrastText,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppTheme.accentCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Model: yolo11n.tflite  |  80 COCO classes  |  Input: 320×320 RGB  |  Output: [1, 84, 2100]',
                        style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Counter Panel
// ─────────────────────────────────────────────────────────────────────────────
class _StepCounterPanel extends ConsumerWidget {
  const _StepCounterPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepService = ref.watch(userStepServiceProvider);
    final stepState = ref.watch(userStepStateProvider).value ?? stepService.currentState;
    final speechEngine = ref.watch(speechEngineProvider);

    final minutes = stepState.walkingDuration.inMinutes;
    final seconds = stepState.walkingDuration.inSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source and quality
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stepState.sensorSource == StepSensorSource.nativePedometer
                          ? 'Native Android Pedometer'
                          : stepState.sensorSource == StepSensorSource.accelerometerFallback
                              ? 'Accelerometer Algorithm'
                              : 'No Sensor Available',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stepState.sensorDiagnosticMessage ??
                          (stepState.isTracking ? 'Tracking active' : 'Not started'),
                      style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                      maxLines: 2,
                    ),
                  ],
                ),
                const Icon(Icons.directions_walk, color: AppTheme.primaryAmber, size: 36),
              ],
            ),

            const Divider(color: Color(0xFF334155), height: 24),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Steps', '${stepState.sessionSteps}'),
                _buildStatColumn('Cadence', '${stepState.currentCadence.toStringAsFixed(0)}/min'),
                _buildStatColumn('Time', timeStr),
              ],
            ),

            const SizedBox(height: 14),

            // Controls
            Row(
              children: [
                Expanded(
                  child: stepState.isTracking && !stepState.isPaused
                      ? OutlinedButton.icon(
                          onPressed: () => stepService.pauseTracking(),
                          icon: const Icon(Icons.pause, size: 18),
                          label: const Text('Pause', style: TextStyle(fontSize: 14)),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => stepService.startTracking(),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(
                            stepState.isPaused ? 'Resume' : 'Start',
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            backgroundColor: AppTheme.accentCyan,
                            foregroundColor: Colors.black,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => stepService.reset(),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => speechEngine.speakDirect(stepService.getSpokenSummary()),
                  icon: const Icon(Icons.record_voice_over, size: 18),
                  label: const Text('Speak', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.highContrastText,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText)),
      ],
    );
  }
}

