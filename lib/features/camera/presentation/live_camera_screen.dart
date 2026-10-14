import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../device_connection/data/device_providers.dart';
import '../data/camera_providers.dart';
import '../data/camera_stream_service.dart';

class LiveCameraScreen extends ConsumerStatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  ConsumerState<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends ConsumerState<LiveCameraScreen> {
  StreamSubscription<StreamState>? _streamSubscription;
  StreamState _streamState = const StreamState();
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    final service = ref.read(cameraStreamServiceProvider);
    _streamState = service.currentState;

    // Listen to stream state updates
    _streamSubscription = service.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _streamState = state;
        });
        // Sync streaming state to the global device connection provider
        ref
            .read(deviceConnectionProvider.notifier)
            .setStreaming(state.isStreaming);
      }
    });

    // Auto-start stream after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoStarted && mounted) {
        _autoStarted = true;
        _startStream();
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    // Stop the stream immediately to free sockets and ESP32-CAM synchronous web server
    final service = ref.read(cameraStreamServiceProvider);
    service.stopStream();
    ref.read(deviceConnectionProvider.notifier).setStreaming(false);
    super.dispose();
  }

  void _startStream() {
    final config = ref.read(deviceConfigProvider);
    final service = ref.read(cameraStreamServiceProvider);
    service.startStream(config.streamUri);
  }

  void _stopStream() {
    final service = ref.read(cameraStreamServiceProvider);
    service.stopStream();
    ref.read(deviceConnectionProvider.notifier).setStreaming(false);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(deviceConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Stream'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _streamState.isStreaming
                  ? const Color(0x3300E676)
                  : const Color(0x33FF5252),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _streamState.isStreaming
                    ? AppTheme.successGreen
                    : AppTheme.errorRed,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _streamState.isStreaming
                      ? Icons.fiber_manual_record
                      : Icons.pause_circle_outline,
                  color: _streamState.isStreaming
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _streamState.isStreaming
                      ? '${_streamState.fps.toStringAsFixed(1)} FPS'
                      : 'OFFLINE',
                  style: TextStyle(
                    color: _streamState.isStreaming
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 26),
            tooltip: 'Connection Settings',
            onPressed: () => context.push('/connection'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Video Viewport (Black background, aspect ratio preserved)
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Center(child: _buildVideoContent()),
              ),
            ),

            // Hardware Limitation Notice Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryAmber,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ESP32 synchronous server limitation: Active stream blocks status polling.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Controls & Diagnostic Footer
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.darkSurface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_streamState.errorMessage != null) ...[
                    ErrorBanner(
                      title: 'Stream Notice',
                      message: _streamState.errorMessage!,
                      troubleshootingGuide: _streamState.troubleshootingGuide,
                      onRetry: _startStream,
                      retryLabel: 'Reconnect Stream',
                    ),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
                      // Start/Stop Stream Toggle
                      Expanded(
                        child: AccessibleButton(
                          label: _streamState.isStreaming
                              ? 'Stop Stream'
                              : (_streamState.isConnecting
                                    ? 'Connecting...'
                                    : 'Start Stream'),
                          icon: _streamState.isStreaming
                              ? Icons.stop_circle_outlined
                              : Icons.play_arrow,
                          isLoading: _streamState.isConnecting,
                          isPrimary: !_streamState.isStreaming,
                          customColor: _streamState.isStreaming
                              ? const Color(0xFF334155)
                              : null,
                          customTextColor: _streamState.isStreaming
                              ? Colors.white
                              : null,
                          onPressed: _streamState.isConnecting
                              ? null
                              : (_streamState.isStreaming
                                    ? _stopStream
                                    : _startStream),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Capture Still Image Button
                      Expanded(
                        child: AccessibleButton(
                          label: 'Capture Image',
                          icon: Icons.camera_alt,
                          isPrimary: false,
                          onPressed: () {
                            // Pause stream first so synchronous server can service /capture
                            _stopStream();
                            context.push('/camera/capture');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stream URI: ${config.streamUri}',
                    style: const TextStyle(
                      fontSize: 12,
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

  Widget _buildVideoContent() {
    if (_streamState.isConnecting) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAmber),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Connecting to camera stream...',
            style: TextStyle(
              color: AppTheme.highContrastText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Negotiating MJPEG multipart response',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
          ),
        ],
      );
    }

    if (_streamState.currentFrame != null) {
      return Semantics(
        label:
            'Live ESP32-CAM video stream, ${_streamState.fps.toStringAsFixed(0)} frames per second',
        child: AspectRatio(
          aspectRatio: 4 / 3, // OV2640 standard aspect ratio
          child: Image.memory(
            _streamState.currentFrame!.bytes,
            gaplessPlayback: true,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Frame decode error',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
              );
            },
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.videocam_off_outlined,
          color: Color(0xFF64748B),
          size: 64,
        ),
        const SizedBox(height: 12),
        const Text(
          'Video Stream Inactive',
          style: TextStyle(
            color: AppTheme.highContrastText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap "Start Stream" to view live camera feed.',
          style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _startStream,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Stream'),
        ),
      ],
    );
  }
}
