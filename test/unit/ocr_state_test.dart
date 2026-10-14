import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/text_reader/data/ocr_service.dart';
import 'package:vision_assist/features/text_reader/domain/ocr_state.dart';

void main() {
  group('OcrState & OcrResult Unit Tests', () {
    test('initial OcrState is idle without errors', () {
      const state = OcrState();
      expect(state.phase, equals(OcrPhase.idle));
      expect(state.isLoading, isFalse);
      expect(state.result, isNull);
      expect(state.errorMessage, isNull);
    });

    test('OcrState copyWith updates phase and clearResult correctly', () {
      final now = DateTime.now();
      final result = OcrResult(
        rawText: 'EXIT',
        blocks: [const OcrBlock(text: 'EXIT', lineCount: 1)],
        timestamp: now,
      );

      final stateWithResult = const OcrState().copyWith(
        phase: OcrPhase.done,
        result: result,
      );

      expect(stateWithResult.phase, equals(OcrPhase.done));
      expect(stateWithResult.result?.rawText, equals('EXIT'));

      final clearedState = stateWithResult.copyWith(
        phase: OcrPhase.capturing,
        clearResult: true,
      );
      expect(clearedState.phase, equals(OcrPhase.capturing));
      expect(clearedState.isLoading, isTrue);
      expect(clearedState.result, isNull);
    });

    test('OcrResult spokenText handles empty and multi-block text', () {
      final emptyResult = OcrResult(
        rawText: '',
        blocks: const [],
        timestamp: DateTime.now(),
      );
      expect(emptyResult.isEmpty, isTrue);
      expect(emptyResult.spokenText, contains('No readable text found'));
      expect(emptyResult.summary, equals('No text detected'));

      final multiBlockResult = OcrResult(
        rawText: 'Caution Wet Floor\nRestroom',
        blocks: const [
          OcrBlock(text: 'Caution\nWet Floor', lineCount: 2),
          OcrBlock(text: 'Restroom Ahead', lineCount: 1),
        ],
        timestamp: DateTime.now(),
      );
      expect(multiBlockResult.isEmpty, isFalse);
      expect(multiBlockResult.spokenText, contains('Caution. Wet Floor'));
      expect(multiBlockResult.spokenText, contains('Restroom Ahead'));
      expect(multiBlockResult.summary, contains('blocks'));
    });
  });
}
