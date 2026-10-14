import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../device_connection/data/device_providers.dart';
import '../data/camera_providers.dart';

class CapturedImageScreen extends ConsumerStatefulWidget {
  const CapturedImageScreen({super.key});

  @override
  ConsumerState<CapturedImageScreen> createState() =>
      _CapturedImageScreenState();
}

class _CapturedImageScreenState extends ConsumerState<CapturedImageScreen> {
  bool _autoCaptured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoCaptured && mounted) {
        _autoCaptured = true;
        ref.read(stillCaptureProvider.notifier).captureImage();
      }
    });
  }

  void _triggerCapture() {
    ref.read(stillCaptureProvider.notifier).captureImage();
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(stillCaptureProvider);
    final config = ref.watch(deviceConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Still Capture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: 'Capture new image',
            onPressed: captureState.isLoading ? null : _triggerCapture,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image Display Area
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Center(child: _buildImageContent(captureState)),
              ),
            ),

            // Diagnostic & Metadata Panel
            Container(
              padding: const EdgeInsets.all(18),
              color: AppTheme.darkSurface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (captureState.errorMessage != null) ...[
                    ErrorBanner(
                      title: 'Capture Failed',
                      message: captureState.errorMessage!,
                      troubleshootingGuide: captureState.troubleshootingGuide,
                      onRetry: _triggerCapture,
                      retryLabel: 'Retry Capture',
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (captureState.frame != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Capture Metadata',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAmber,
                          ),
                        ),
                        Text(
                          'Size: ${captureState.frame!.sizeFormatted}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Captured: ${captureState.frame!.timestamp.toLocal().toString().split('.').first}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: AccessibleButton(
                          label: 'Retake Photo',
                          icon: Icons.camera_alt,
                          isLoading: captureState.isLoading,
                          onPressed: _triggerCapture,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AccessibleButton(
                          label: 'Back to Home',
                          icon: Icons.home,
                          isPrimary: false,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Endpoint: ${config.captureUri}',
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

  Widget _buildImageContent(StillCaptureState state) {
    if (state.isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAmber),
            strokeWidth: 3,
          ),
          SizedBox(height: 18),
          Text(
            'Downloading JPEG from /capture...',
            style: TextStyle(
              color: AppTheme.highContrastText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    if (state.frame != null) {
      return Semantics(
        label:
            'Captured still photo from ESP32-CAM, size ${state.frame!.sizeFormatted}',
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.memory(
            state.frame!.bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Failed to render image bytes.',
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
          Icons.no_photography_outlined,
          color: Color(0xFF64748B),
          size: 64,
        ),
        const SizedBox(height: 12),
        const Text(
          'No Image Captured',
          style: TextStyle(
            color: AppTheme.highContrastText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _triggerCapture,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Capture Now'),
        ),
      ],
    );
  }
}
