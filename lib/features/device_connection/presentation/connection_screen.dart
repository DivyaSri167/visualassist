import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/config/device_config.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/device_providers.dart';
import '../domain/connection_state.dart';

class DeviceConnectionScreen extends ConsumerStatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState
    extends ConsumerState<DeviceConnectionScreen> {
  late final TextEditingController _ipController;
  bool _isSosTesting = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(deviceConfigProvider);
    _ipController = TextEditingController(text: config.host);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _saveIpAndTest() {
    final newHost = _ipController.text.trim();
    if (newHost.isNotEmpty) {
      ref.read(deviceConfigProvider.notifier).updateHost(newHost);
      ref.read(deviceConnectionProvider.notifier).checkConnection();
    }
  }

  void _resetDefaultIp() {
    _ipController.text = DeviceConfig.defaultHost;
    ref.read(deviceConfigProvider.notifier).resetToDefault();
    ref.read(deviceConnectionProvider.notifier).checkConnection();
  }

  Future<void> _testSos() async {
    setState(() => _isSosTesting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(deviceConnectionProvider.notifier)
        .triggerSosTest();
    if (mounted) {
      setState(() => _isSosTesting = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Test SOS event recorded on ESP32-CAM!' : 'Failed to record SOS event. Note: Camera stream may be blocking requests.',
          ),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(deviceConnectionProvider);
    final config = ref.watch(deviceConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ESP32-CAM Connection')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Diagnostics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Connection Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.highContrastText,
                          ),
                        ),
                        ConnectionStatusBadge(status: connectionState.status),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFF334155)),
                    _buildInfoRow(
                      'Device Name',
                      connectionState.deviceStatus?.device ?? 'Not Connected',
                    ),
                    _buildInfoRow(
                      'Camera Status',
                      connectionState.deviceStatus?.camera ??
                          (connectionState.status ==
                                  ConnectionStatus.cameraUnavailable
                              ? 'Sensor Error'
                              : 'Offline'),
                    ),
                    _buildInfoRow('Target Host', config.baseUrl),
                    _buildInfoRow(
                      'SOS Counter',
                      connectionState.deviceStatus != null
                          ? '${connectionState.deviceStatus!.sosCount} events'
                          : 'Unavailable',
                    ),
                    _buildInfoRow(
                      'Last Verified Sync',
                      connectionState.lastSuccessfulResponse != null
                          ? '${connectionState.lastSuccessfulResponse!.hour.toString().padLeft(2, '0')}:${connectionState.lastSuccessfulResponse!.minute.toString().padLeft(2, '0')}:${connectionState.lastSuccessfulResponse!.second.toString().padLeft(2, '0')}'
                          : 'Never',
                    ),
                  ],
                ),
              ),
            ),

            if (connectionState.errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(
                title:
                    connectionState.status == ConnectionStatus.cameraUnavailable
                    ? 'Camera Sensor Warning'
                    : 'Network Error',
                message: connectionState.errorMessage!,
                troubleshootingGuide: connectionState.troubleshootingGuide,
                onRetry: () => ref
                    .read(deviceConnectionProvider.notifier)
                    .checkConnection(isReconnect: true),
                retryLabel: 'Retry Connection',
              ),
            ],

            const SizedBox(height: 20),

            // IP Configuration Input
            const Text(
              'DEVICE ADDRESS (IP)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.primaryAmber,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _ipController,
              keyboardType: TextInputType.url,
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.highContrastText,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.darkSurface,
                hintText: 'e.g. 192.168.4.1',
                prefixIcon: const Icon(Icons.dns, color: AppTheme.primaryAmber),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.restore, color: AppTheme.accentCyan),
                  tooltip: 'Reset to default IP (192.168.4.1)',
                  onPressed: _resetDefaultIp,
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

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    label: 'Test Connection',
                    icon: Icons.network_check,
                    isLoading: connectionState.isConnecting,
                    onPressed: _saveIpAndTest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AccessibleButton(
                    label: 'Reconnect',
                    icon: Icons.refresh,
                    isPrimary: false,
                    isLoading: connectionState.isConnecting,
                    onPressed: () => ref
                        .read(deviceConnectionProvider.notifier)
                        .checkConnection(isReconnect: true),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // SOS Test Button
            AccessibleButton(
              label: 'Test Device SOS (POST /sos)',
              icon: Icons.emergency,
              isPrimary: false,
              isLoading: _isSosTesting,
              customColor: const Color(0xFFEF4444),
              customTextColor: Colors.white,
              onPressed: connectionState.isConnected ? _testSos : null,
              semanticHint: 'Sends a test SOS trigger to the ESP32-CAM. Note that stream must be paused.',
            ),

            const SizedBox(height: 24),

            // Wi-Fi Setup Guidance Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi, color: AppTheme.accentCyan, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Wi-Fi Connection Guide',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.highContrastText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Open your phone\'s Wi-Fi settings.\n'
                      '2. Select network: VisionAssist-Cap\n'
                      '3. Enter password: VisionAssist123\n'
                      '4. If Android displays "No internet access, stay connected?", tap YES / KEEP CONNECTION.\n'
                      '5. Return to this app and tap "Test Connection".',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.secondaryText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFC107),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: AppTheme.primaryAmber,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The ESP32-CAM access point is a local IoT network without cellular or internet data.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: AppTheme.secondaryText),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.highContrastText,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
