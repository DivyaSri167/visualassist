import 'package:flutter/material.dart';

import '../../data/yolo_config.dart';
import '../../domain/detected_object.dart';
import '../../domain/direction_zone.dart';

/// CustomPainter rendering YOLO11n bounding boxes, labels, confidence scores,
/// tracking IDs, and horizontal direction zone dividers over camera frames.
class DetectionBoxPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final double leftZoneThreshold;
  final double rightZoneThreshold;
  final bool showZoneDividers;

  const DetectionBoxPainter({
    required this.objects,
    this.leftZoneThreshold = 0.35,
    this.rightZoneThreshold = 0.65,
    this.showZoneDividers = true,
  });

  static final Paint _dividerPaint = Paint()
    ..color = const Color(0x4464748B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static final TextPainter _leftZonePainter = _createZonePainter('LEFT');
  static final TextPainter _centerZonePainter = _createZonePainter('CENTER PATH');
  static final TextPainter _rightZonePainter = _createZonePainter('RIGHT');

  static TextPainter _createZonePainter(String text) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0x9994A3B8),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw Direction Zone Dividers (Left, Center, Right)
    if (showZoneDividers) {
      final leftX = size.width * leftZoneThreshold;
      final rightX = size.width * rightZoneThreshold;

      canvas.drawLine(Offset(leftX, 0), Offset(leftX, size.height), _dividerPaint);
      canvas.drawLine(Offset(rightX, 0), Offset(rightX, size.height), _dividerPaint);

      // Zone indicator text at top
      _leftZonePainter.paint(
        canvas,
        Offset(leftX * 0.5 - _leftZonePainter.width * 0.5, 8),
      );
      _centerZonePainter.paint(
        canvas,
        Offset((leftX + rightX) * 0.5 - _centerZonePainter.width * 0.5, 8),
      );
      _rightZonePainter.paint(
        canvas,
        Offset((rightX + size.width) * 0.5 - _rightZonePainter.width * 0.5, 8),
      );
    }

    // 2. Draw Detected Objects
    for (final obj in objects) {
      final isHazard = YoloConfig.isHazardClass(obj.label);
      final isCenter = obj.directionZone == DirectionZone.center;

      // Color coding: Red/Amber for central hazards, Cyan for routine objects
      final Color boxColor;
      if (isCenter && isHazard) {
        boxColor = const Color(0xFFFF5252); // Alert Red
      } else if (isHazard) {
        boxColor = const Color(0xFFFFB300); // Amber warning
      } else {
        boxColor = const Color(0xFF00E5FF); // Cyan
      }

      final rect = Rect.fromLTRB(
        obj.normalizedXMin * size.width,
        obj.normalizedYMin * size.height,
        obj.normalizedXMax * size.width,
        obj.normalizedYMax * size.height,
      );

      // Bounding box rectangle
      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCenter ? 3.0 : 2.0;

      // Fill background tint
      final fillPaint = Paint()
        ..color = boxColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, boxPaint);

      // Label badge text: e.g. "Person #1 84% [Center]"
      final trackText = obj.trackingId != null ? ' #${obj.trackingId}' : '';
      final confText = ' ${(obj.confidence * 100).toInt()}%';
      final labelText = '${obj.label}$trackText$confText';

      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeWidth = textPainter.width + 10;
      final badgeHeight = textPainter.height + 6;
      final badgeTop = (rect.top - badgeHeight).clamp(0.0, size.height - badgeHeight);
      final badgeLeft = rect.left.clamp(0.0, size.width - badgeWidth);

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeLeft, badgeTop, badgeWidth, badgeHeight),
        const Radius.circular(3),
      );

      final badgePaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(badgeRect, badgePaint);
      textPainter.paint(canvas, Offset(badgeLeft + 5, badgeTop + 3));
    }
  }


  @override
  bool shouldRepaint(covariant DetectionBoxPainter oldDelegate) {
    return oldDelegate.objects != objects;
  }
}
