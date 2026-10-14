import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../device_connection/data/device_providers.dart';
import '../domain/camera_frame.dart';
import 'camera_stream_service.dart';

/// Provider for the single MJPEG camera stream service instance.
final cameraStreamServiceProvider = Provider<CameraStreamService>((ref) {
  final service = CameraStreamService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Exposes the live MJPEG stream state as a StreamProvider.
final liveStreamStateProvider = StreamProvider<StreamState>((ref) {
  final service = ref.watch(cameraStreamServiceProvider);
  return service.stateStream;
});

/// State for still capture
class StillCaptureState {
  final bool isLoading;
  final CameraFrame? frame;
  final String? errorMessage;
  final String? troubleshootingGuide;

  const StillCaptureState({
    this.isLoading = false,
    this.frame,
    this.errorMessage,
    this.troubleshootingGuide,
  });

  StillCaptureState copyWith({
    bool? isLoading,
    CameraFrame? frame,
    String? errorMessage,
    String? troubleshootingGuide,
    bool clearError = false,
  }) {
    return StillCaptureState(
      isLoading: isLoading ?? this.isLoading,
      frame: frame ?? this.frame,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      troubleshootingGuide: clearError
          ? null
          : (troubleshootingGuide ?? this.troubleshootingGuide),
    );
  }
}

/// Notifier managing still image capture from `/capture`.
class StillCaptureNotifier extends Notifier<StillCaptureState> {
  @override
  StillCaptureState build() {
    return const StillCaptureState();
  }

  Future<void> captureImage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final repository = ref.read(deviceRepositoryProvider);

    try {
      final Uint8List bytes = await repository.captureStillImage();
      final frame = CameraFrame(bytes: bytes, timestamp: DateTime.now());
      state = state.copyWith(isLoading: false, frame: frame, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        troubleshootingGuide: 'Ensure the camera lens ribbon cable is secure and try reconnecting.',
      );
    }
  }

  void clearCapture() {
    state = const StillCaptureState();
  }
}

final stillCaptureProvider =
    NotifierProvider<StillCaptureNotifier, StillCaptureState>(() {
      return StillCaptureNotifier();
    });
