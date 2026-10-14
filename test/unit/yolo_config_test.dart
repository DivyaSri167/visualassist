import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/object_detection/data/yolo_config.dart';

void main() {
  group('YoloConfig Unit Tests', () {
    test('default configuration has expected defaults', () {
      const config = YoloConfig();
      expect(config.confidenceThreshold, 0.40);
      expect(config.iouThreshold, 0.45);
      expect(config.maxInferenceFps, 7);
      expect(config.speechEnabled, true);
      expect(config.announcementCooldownSeconds, 5);
      expect(config.announcementMode, AnnouncementMode.walkingAssistance);
      expect(config.leftZoneThreshold, 0.35);
      expect(config.rightZoneThreshold, 0.65);
    });

    test('copyWith updates individual fields correctly', () {
      const config = YoloConfig();
      final updated = config.copyWith(
        confidenceThreshold: 0.60,
        speechEnabled: false,
        announcementMode: AnnouncementMode.importantObjects,
        maxInferenceFps: 10,
        announcementCooldownSeconds: 3,
      );

      expect(updated.confidenceThreshold, 0.60);
      expect(updated.speechEnabled, false);
      expect(updated.announcementMode, AnnouncementMode.importantObjects);
      expect(updated.maxInferenceFps, 10);
      expect(updated.announcementCooldownSeconds, 3);
      expect(updated.iouThreshold, 0.45); // Unchanged
    });

    test('isHazardClass identifies priority mobility hazards', () {
      expect(YoloConfig.isHazardClass('person'), isTrue);
      expect(YoloConfig.isHazardClass('car'), isTrue);
      expect(YoloConfig.isHazardClass('bus'), isTrue);
      expect(YoloConfig.isHazardClass('stairs'), isTrue);
      expect(YoloConfig.isHazardClass('chair'), isTrue);
      expect(YoloConfig.isHazardClass('motorcycle'), isTrue);
      expect(YoloConfig.isHazardClass('bicycle'), isTrue);

      expect(YoloConfig.isHazardClass('apple'), isFalse);
      expect(YoloConfig.isHazardClass('book'), isFalse);
      expect(YoloConfig.isHazardClass('toothbrush'), isFalse);
    });

    test('getClassBasePriority returns correct tiered weights', () {
      expect(YoloConfig.getClassBasePriority('person'), 4.5);
      expect(YoloConfig.getClassBasePriority('car'), 5.0);
      expect(YoloConfig.getClassBasePriority('chair'), 3.0);
      expect(YoloConfig.getClassBasePriority('dog'), 3.5);
      expect(YoloConfig.getClassBasePriority('bottle'), 2.0);
      expect(YoloConfig.getClassBasePriority('unknown_object'), 1.5);
    });

    test('AnnouncementMode extensions return correct human-readable names', () {
      expect(AnnouncementMode.importantObjects.shortName, 'Mode A (Important)');
      expect(AnnouncementMode.allObjects.shortName, 'Mode B (All)');
      expect(AnnouncementMode.walkingAssistance.shortName, 'Mode C (Walking)');

      expect(AnnouncementMode.walkingAssistance.displayName, 'Mode C: Walking Guidance');
    });
  });
}
