import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/detected_object.dart';
import '../domain/direction_zone.dart';
import 'yolo_config.dart';

/// Detection result containing detected objects and execution diagnostics.
class DetectionResult {
  final List<DetectedObject> objects;
  final int inferenceTimeMs;
  final int preprocessingTimeMs;
  final int postprocessingTimeMs;
  final int sourceWidth;
  final int sourceHeight;
  final DateTime timestamp;

  const DetectionResult({
    required this.objects,
    required this.inferenceTimeMs,
    required this.preprocessingTimeMs,
    required this.postprocessingTimeMs,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.timestamp,
  });

  int get totalProcessingTimeMs =>
      preprocessingTimeMs + inferenceTimeMs + postprocessingTimeMs;
}

/// Real YOLO11n object detector using TensorFlow Lite.
/// Implements aspect-ratio letterboxing, float32 normalization, tensor execution,
/// anchor decoding for shape [1, 84, 2100], and Non-Maximum Suppression (NMS).
class YoloDetector {
  YoloConfig _config;
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  bool _isProcessing = false;
  DateTime _lastInferenceTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Reusable output tensor buffer
  late List<List<List<double>>> _outputTensor;

  YoloDetector({this._config = const YoloConfig()});

  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  YoloConfig get config => _config;

  void updateConfig(YoloConfig newConfig) {
    _config = newConfig;
  }

  /// Initializes the TFLite interpreter and loads the 80 COCO class labels.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure interpreter options
      final options = InterpreterOptions()..threads = 4;

      // Load model from Flutter asset bundle
      _interpreter = await Interpreter.fromAsset(
        _config.modelPath,
        options: options,
      );

      // Load class labels
      final labelsData = await rootBundle.loadString(_config.labelsPath);
      _labels = labelsData
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      // Output shape: [1, 84, 2100]
      final numClasses = _labels.length;
      final numAttributes = 4 + numClasses; // 84
      final numAnchors = 2100;
      _outputTensor = List.generate(
        1,
        (_) => List.generate(numAttributes, (_) => List.filled(numAnchors, 0.0)),
      );

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Detects objects in a raw JPEG frame from ESP32-CAM.
  /// Discards obsolete frames if inference is currently running or within rate limit.
  Future<DetectionResult?> detectFrame(Uint8List jpegBytes) async {
    if (!_isInitialized || _interpreter == null) {
      return null;
    }

    final now = DateTime.now();

    // Enforce maximum inference rate (FPS throttle) to keep device responsive
    final minIntervalMs = (1000 / _config.maxInferenceFps).round();
    if (now.difference(_lastInferenceTime).inMilliseconds < minIntervalMs) {
      return null; // Throttle: drop frame
    }

    // Bounded pipeline: discard frame if prior inference job is still running
    if (_isProcessing) {
      return null;
    }

    _isProcessing = true;
    _lastInferenceTime = now;

    try {
      // 1 & 2. Offload heavy JPEG decoding, resizing, and float normalization to a background isolate.
      // This completely prevents UI jank and preserves a smooth 60 FPS main thread.
      final _PreprocessResult preprocessed;
      try {
        preprocessed = await Isolate.run(
          () => _preprocessWorker(
            _PreprocessParams(
              jpegBytes: jpegBytes,
              targetSize: _config.inputSize,
            ),
          ),
        );
      } catch (_) {
        return null;
      }

      final srcWidth = preprocessed.srcWidth;
      final srcHeight = preprocessed.srcHeight;
      final scale = preprocessed.scale;
      final padX = preprocessed.padX;
      final padY = preprocessed.padY;
      final preprocessingTimeMs = preprocessed.elapsedMs;

      // 3. Inference on native C++ TFLite engine
      final inferenceStopwatch = Stopwatch()..start();
      _interpreter!.run(preprocessed.inputTensor, _outputTensor);
      inferenceStopwatch.stop();

      // 4. Output Post-Processing & NMS
      final postprocessStopwatch = Stopwatch()..start();
      final candidates = <_CandidateBox>[];
      final directionClassifier = DirectionClassifier(
        leftThreshold: _config.leftZoneThreshold,
        rightThreshold: _config.rightZoneThreshold,
      );

      final numAnchors = 2100;
      final numClasses = _labels.length;

      // Scan all 2100 anchors from output shape [1, 84, 2100]
      for (int a = 0; a < numAnchors; a++) {
        // Find best class score
        double maxClassScore = 0.0;
        int bestClassId = 0;

        for (int c = 0; c < numClasses; c++) {
          final score = _outputTensor[0][4 + c][a];
          if (score > maxClassScore) {
            maxClassScore = score;
            bestClassId = c;
          }
        }

        if (maxClassScore < _config.confidenceThreshold) {
          continue;
        }

        // Extract center, width, height in 320x320 letterbox coordinates
        final cx = _outputTensor[0][0][a];
        final cy = _outputTensor[0][1][a];
        final w = _outputTensor[0][2][a];
        final h = _outputTensor[0][3][a];

        // Inverse letterbox transformation back to source image coordinates
        final x1 = (((cx - w / 2) - padX) / scale).clamp(0.0, srcWidth.toDouble());
        final y1 = (((cy - h / 2) - padY) / scale).clamp(0.0, srcHeight.toDouble());
        final x2 = (((cx + w / 2) - padX) / scale).clamp(0.0, srcWidth.toDouble());
        final y2 = (((cy + h / 2) - padY) / scale).clamp(0.0, srcHeight.toDouble());

        if (x2 <= x1 || y2 <= y1) continue;

        candidates.add(
          _CandidateBox(
            classId: bestClassId,
            score: maxClassScore,
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
          ),
        );
      }

      // Non-Maximum Suppression (NMS)
      final nmsBoxes = _applyNms(candidates, _config.iouThreshold);

      // Convert surviving boxes to domain DetectedObject
      final detectedObjects = <DetectedObject>[];
      for (final box in nmsBoxes) {
        final label = box.classId < _labels.length
            ? _labels[box.classId]
            : 'Class ${box.classId}';

        final normXMin = (box.x1 / srcWidth).clamp(0.0, 1.0);
        final normYMin = (box.y1 / srcHeight).clamp(0.0, 1.0);
        final normXMax = (box.x2 / srcWidth).clamp(0.0, 1.0);
        final normYMax = (box.y2 / srcHeight).clamp(0.0, 1.0);
        final normCenterX = ((normXMin + normXMax) / 2.0).clamp(0.0, 1.0);
        final normCenterY = ((normYMin + normYMax) / 2.0).clamp(0.0, 1.0);

        final direction = directionClassifier.classify(normCenterX);

        // Assistive Priority Calculation
        final basePriority = YoloConfig.getClassBasePriority(label);
        final centerWeight = 1.0 - (normCenterX - 0.5).abs() * 0.6; // Center objects get up to 1.0x vs 0.7x at edges
        final area = (normXMax - normXMin) * (normYMax - normYMin);
        final sizeWeight = 1.0 + area * 2.5; // Larger objects (closer) get higher priority
        final priorityScore = basePriority * box.score * centerWeight * sizeWeight;

        detectedObjects.add(
          DetectedObject(
            classId: box.classId,
            label: label,
            confidence: box.score,
            xMin: box.x1,
            yMin: box.y1,
            xMax: box.x2,
            yMax: box.y2,
            normalizedXMin: normXMin,
            normalizedYMin: normYMin,
            normalizedXMax: normXMax,
            normalizedYMax: normYMax,
            normalizedCenterX: normCenterX,
            normalizedCenterY: normCenterY,
            directionZone: direction,
            timestamp: now,
            priorityScore: priorityScore,
          ),
        );
      }

      postprocessStopwatch.stop();

      return DetectionResult(
        objects: detectedObjects,
        inferenceTimeMs: inferenceStopwatch.elapsedMilliseconds,
        preprocessingTimeMs: preprocessingTimeMs,
        postprocessingTimeMs: postprocessStopwatch.elapsedMilliseconds,
        sourceWidth: srcWidth,
        sourceHeight: srcHeight,
        timestamp: now,
      );
    } catch (e) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Greedy Non-Maximum Suppression (per-class)
  List<_CandidateBox> _applyNms(List<_CandidateBox> boxes, double iouThreshold) {
    if (boxes.isEmpty) return [];

    // Sort descending by confidence score
    boxes.sort((a, b) => b.score.compareTo(a.score));

    final selected = <_CandidateBox>[];
    final active = List<bool>.filled(boxes.length, true);

    for (int i = 0; i < boxes.length; i++) {
      if (!active[i]) continue;

      final current = boxes[i];
      selected.add(current);

      for (int j = i + 1; j < boxes.length; j++) {
        if (!active[j]) continue;

        // Apply NMS per-class to preserve overlapping distinct objects (e.g. cup on table)
        if (boxes[j].classId == current.classId) {
          final iou = _calculateIou(current, boxes[j]);
          if (iou >= iouThreshold) {
            active[j] = false;
          }
        }
      }
    }

    return selected;
  }

  /// Calculates Intersection over Union (IoU) of two candidate bounding boxes
  double _calculateIou(_CandidateBox a, _CandidateBox b) {
    final interX1 = max(a.x1, b.x1);
    final interY1 = max(a.y1, b.y1);
    final interX2 = min(a.x2, b.x2);
    final interY2 = min(a.y2, b.y2);

    if (interX2 <= interX1 || interY2 <= interY1) return 0.0;

    final interArea = (interX2 - interX1) * (interY2 - interY1);
    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    final unionArea = areaA + areaB - interArea;

    return unionArea > 0.0 ? interArea / unionArea : 0.0;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _isProcessing = false;
  }
}

class _CandidateBox {
  final int classId;
  final double score;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const _CandidateBox({
    required this.classId,
    required this.score,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
}

class _PreprocessParams {
  final Uint8List jpegBytes;
  final int targetSize;

  const _PreprocessParams({
    required this.jpegBytes,
    required this.targetSize,
  });
}

class _PreprocessResult {
  final List<List<List<List<double>>>> inputTensor;
  final int srcWidth;
  final int srcHeight;
  final double scale;
  final int padX;
  final int padY;
  final int elapsedMs;

  const _PreprocessResult({
    required this.inputTensor,
    required this.srcWidth,
    required this.srcHeight,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.elapsedMs,
  });
}

/// Standalone top-level worker executing on a background Dart isolate.
/// Completely separates CPU-heavy JPEG decoding and letterboxing from the UI thread.
_PreprocessResult _preprocessWorker(_PreprocessParams params) {
  final sw = Stopwatch()..start();
  final image = img.decodeJpg(params.jpegBytes);
  if (image == null) {
    throw Exception('Failed to decode JPEG frame in background worker.');
  }

  final srcWidth = image.width;
  final srcHeight = image.height;
  final targetSize = params.targetSize;

  final double scale = min(targetSize / srcWidth, targetSize / srcHeight);
  final int newWidth = (srcWidth * scale).round();
  final int newHeight = (srcHeight * scale).round();
  final int padX = ((targetSize - newWidth) / 2).round();
  final int padY = ((targetSize - newHeight) / 2).round();

  final resizedImage = img.copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.nearest,
  );

  const borderVal = 114.0 / 255.0;
  final tensor = List.generate(
    1,
    (_) => List.generate(
      targetSize,
      (_) => List.generate(targetSize, (_) => List.filled(3, borderVal)),
    ),
  );

  for (int y = 0; y < newHeight; y++) {
    final targetY = y + padY;
    for (int x = 0; x < newWidth; x++) {
      final pixel = resizedImage.getPixel(x, y);
      final targetX = x + padX;
      tensor[0][targetY][targetX][0] = pixel.r / 255.0;
      tensor[0][targetY][targetX][1] = pixel.g / 255.0;
      tensor[0][targetY][targetX][2] = pixel.b / 255.0;
    }
  }

  sw.stop();
  return _PreprocessResult(
    inputTensor: tensor,
    srcWidth: srcWidth,
    srcHeight: srcHeight,
    scale: scale,
    padX: padX,
    padY: padY,
    elapsedMs: sw.elapsedMilliseconds,
  );
}
