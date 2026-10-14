import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Wraps Google ML Kit Text Recognition for on-device OCR.
/// Runs 100% on-device — no network call, no cloud API.
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  bool _disposed = false;

  /// Runs OCR on raw JPEG [bytes] (from the ESP32-CAM `/capture` endpoint).
  /// Writes bytes to a temp file (ML Kit requires file-path input on Android),
  /// processes recognition, then deletes the temp file.
  Future<OcrResult> recognizeFromJpeg(Uint8List bytes) async {
    if (_disposed) throw StateError('OcrService has been disposed.');

    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/ocr_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(bytes);

    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognizedText = await _recognizer.processImage(inputImage);

      final rawText = recognizedText.text.trim();
      final blocks = recognizedText.blocks
          .map(
            (b) {
              final text = b.text.trim();
              return OcrBlock(
                text: text,
                lineCount: b.lines.length,
                category: OcrBlock.detectCategory(text),
              );
            },
          )
          .where((b) => b.text.isNotEmpty)
          .toList();

      return OcrResult(
        rawText: rawText,
        blocks: blocks,
        timestamp: DateTime.now(),
      );
    } finally {
      try {
        await tempFile.delete();
      } catch (_) {}
    }
  }

  void dispose() {
    _disposed = true;
    _recognizer.close();
  }
}

/// Classification category for detected text.
enum OcrCategory { general, safety, currency, numeric }

/// A single detected text block from the OCR pass.
class OcrBlock {
  final String text;
  final int lineCount;
  final OcrCategory category;

  const OcrBlock({
    required this.text,
    required this.lineCount,
    this.category = OcrCategory.general,
  });

  /// Automatically classifies text content based on assistive domain heuristics.
  static OcrCategory detectCategory(String text) {
    final upper = text.toUpperCase();
    // 1. Safety & Warning signs
    if (upper.contains('CAUTION') ||
        upper.contains('DANGER') ||
        upper.contains('WARNING') ||
        upper.contains('STOP') ||
        upper.contains('EXIT') ||
        upper.contains('EMERGENCY') ||
        upper.contains('WET FLOOR') ||
        upper.contains('DO NOT ENTER') ||
        upper.contains('NO ENTRY') ||
        upper.contains('FIRE') ||
        upper.contains('POISON') ||
        upper.contains('BEWARE')) {
      return OcrCategory.safety;
    }

    // 2. Pricing & Currency
    if (text.contains('\$') ||
        text.contains('€') ||
        text.contains('£') ||
        text.contains('₹') ||
        upper.contains('USD') ||
        upper.contains('EUR') ||
        upper.contains('INR') ||
        RegExp(r'\b\d+\.\d{2}\b').hasMatch(text)) {
      return OcrCategory.currency;
    }

    // 3. Numbers / Phone / Dates
    if (RegExp(r'\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b').hasMatch(text) ||
        RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b').hasMatch(text)) {
      return OcrCategory.numeric;
    }

    return OcrCategory.general;
  }
}

/// Structured result from a single OCR inference pass.
class OcrResult {
  final String rawText;
  final List<OcrBlock> blocks;
  final DateTime timestamp;

  const OcrResult({
    required this.rawText,
    required this.blocks,
    required this.timestamp,
  });

  bool get isEmpty => rawText.isEmpty;

  /// High-priority safety warnings found in the frame.
  List<OcrBlock> get safetyAlerts =>
      blocks.where((b) => b.category == OcrCategory.safety).toList();

  /// Currency and pricing items detected.
  List<OcrBlock> get currencyBlocks =>
      blocks.where((b) => b.category == OcrCategory.currency).toList();

  bool get hasSafetyAlerts => safetyAlerts.isNotEmpty;

  /// Natural speech output for TTS — safety warnings are voiced with urgency.
  String get spokenText {
    if (isEmpty) return 'No readable text found in this image.';

    final buffer = StringBuffer();
    if (hasSafetyAlerts) {
      final alerts = safetyAlerts.map((a) => a.text.replaceAll('\n', '. ')).join('. ');
      buffer.write('Safety Alert: $alerts. ');
    }

    final remaining = blocks
        .where((b) => b.category != OcrCategory.safety)
        .map((b) => b.text.replaceAll('\n', '. '))
        .join('. ');

    if (remaining.isNotEmpty) {
      buffer.write(remaining);
    }

    return buffer.toString().trim();
  }

  /// Short label for UI.
  String get summary {
    if (isEmpty) return 'No text detected';
    final wordCount = rawText.split(RegExp(r'\s+')).length;
    final alertCount = safetyAlerts.length;
    final alertNotice = alertCount > 0 ? ' ($alertCount safety notice${alertCount == 1 ? '' : 's'})' : '';
    return '$wordCount word${wordCount == 1 ? '' : 's'} in '
        '${blocks.length} block${blocks.length == 1 ? '' : 's'}$alertNotice';
  }
}
