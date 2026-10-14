import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../camera/data/camera_providers.dart';
import '../../device_connection/data/device_providers.dart';
import '../domain/ocr_state.dart';
import 'ocr_service.dart';

/// Single shared OcrService instance.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

/// Manages the state machine for OCR capture → process → speak.
class OcrNotifier extends Notifier<OcrState> {
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  @override
  OcrState build() {
    ref.onDispose(() {
      _tts.stop();
    });
    _initTts();
    return const OcrState();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsReady = true;
    } catch (_) {}
  }

  /// Captures an image from the active stream or ESP32-CAM `/capture` endpoint and runs OCR on it.
  Future<void> captureAndRead() async {
    state = state.copyWith(phase: OcrPhase.capturing, clearResult: true, clearError: true);

    try {
      // 1. Prefer the latest live frame from the active stream if running
      final streamService = ref.read(cameraStreamServiceProvider);
      Uint8List? bytes = streamService.currentState.currentFrame?.bytes;

      // 2. If stream is not active, capture a high-res frame via /capture
      if (bytes == null || bytes.isEmpty) {
        final repository = ref.read(deviceRepositoryProvider);
        bytes = await repository.captureStillImage(
          timeout: const Duration(seconds: 8),
        );
      }

      state = state.copyWith(phase: OcrPhase.processing, capturedBytes: bytes);

      final service = ref.read(ocrServiceProvider);
      final result = await service.recognizeFromJpeg(bytes);

      state = state.copyWith(phase: OcrPhase.done, result: result, clearError: true);

      // Automatically speak the result
      if (_ttsReady) {
        await _tts.stop();
        await _tts.speak(result.spokenText);
      }
    } catch (e) {
      final message = _friendlyError(e);
      state = state.copyWith(
        phase: OcrPhase.error,
        errorMessage: message,
      );
      if (_ttsReady) {
        try {
          await _tts.stop();
          await _tts.speak(message);
        } catch (_) {}
      }
    }
  }

  /// Re-reads the last OCR result aloud.
  Future<void> speakResult() async {
    final result = state.result;
    if (result == null || !_ttsReady) return;
    await _tts.stop();
    await _tts.speak(result.spokenText);
  }

  /// Speaks a specific individual block on user tap.
  Future<void> speakBlock(OcrBlock block) async {
    if (!_ttsReady) return;
    await _tts.stop();
    final prefix = block.category == OcrCategory.safety ? 'Safety notice: ' : '';
    await _tts.speak('$prefix${block.text.replaceAll('\n', '. ')}');
  }

  /// Stops TTS playback.
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  void clearResult() {
    _tts.stop();
    state = const OcrState();
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timeout') || s.contains('timed out')) {
      return 'Camera capture timed out. Make sure the phone is connected to VisionAssist-Cap Wi-Fi.';
    }
    if (s.contains('socket') || s.contains('network') || s.contains('connection refused')) {
      return 'Cannot reach the camera. Verify Wi-Fi connection to VisionAssist-Cap.';
    }
    return 'OCR failed: $e';
  }
}

final ocrProvider = NotifierProvider<OcrNotifier, OcrState>(OcrNotifier.new);
