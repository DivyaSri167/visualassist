import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/object_detection/domain/direction_zone.dart';

void main() {
  group('DirectionClassifier Tests', () {
    const classifier = DirectionClassifier(
      leftThreshold: 0.35,
      rightThreshold: 0.65,
    );

    test('classifies normalizedX < 0.35 as Left', () {
      expect(classifier.classify(0.0), DirectionZone.left);
      expect(classifier.classify(0.20), DirectionZone.left);
      expect(classifier.classify(0.349), DirectionZone.left);
    });

    test('classifies 0.35 <= normalizedX <= 0.65 as Center', () {
      expect(classifier.classify(0.35), DirectionZone.center);
      expect(classifier.classify(0.50), DirectionZone.center);
      expect(classifier.classify(0.65), DirectionZone.center);
    });

    test('classifies normalizedX > 0.65 as Right', () {
      expect(classifier.classify(0.651), DirectionZone.right);
      expect(classifier.classify(0.80), DirectionZone.right);
      expect(classifier.classify(1.0), DirectionZone.right);
    });

    test('detailed spoken directions generate appropriate labels', () {
      expect(classifier.getDetailedSpokenDirection(0.10), 'far left');
      expect(classifier.getDetailedSpokenDirection(0.30), 'left');
      expect(classifier.getDetailedSpokenDirection(0.40), 'slightly left');
      expect(classifier.getDetailedSpokenDirection(0.50), 'dead center');
      expect(classifier.getDetailedSpokenDirection(0.60), 'slightly right');
      expect(classifier.getDetailedSpokenDirection(0.70), 'right');
      expect(classifier.getDetailedSpokenDirection(0.90), 'far right');
    });
  });
}
