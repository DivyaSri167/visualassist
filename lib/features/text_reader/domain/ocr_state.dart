import 'dart:typed_data';

import '../data/ocr_service.dart';

/// Phase of the OCR pipeline.
enum OcrPhase { idle, capturing, processing, done, error }

/// Immutable state for the OCR feature screen.
class OcrState {
  final OcrPhase phase;
  final Uint8List? capturedBytes;
  final OcrResult? result;
  final String? errorMessage;

  const OcrState({
    this.phase = OcrPhase.idle,
    this.capturedBytes,
    this.result,
    this.errorMessage,
  });

  bool get isLoading =>
      phase == OcrPhase.capturing || phase == OcrPhase.processing;

  OcrState copyWith({
    OcrPhase? phase,
    Uint8List? capturedBytes,
    OcrResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return OcrState(
      phase: phase ?? this.phase,
      capturedBytes: capturedBytes ?? this.capturedBytes,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
