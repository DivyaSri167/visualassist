import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vision_assist/app/app.dart';

void main() {
  testWidgets(
    'VisionAssistApp mounts cleanly and renders accessible home screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const ProviderScope(child: VisionAssistApp()));

      // Initial frame pump
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('VisionAssist'), findsOneWidget);

      // Verify Smart-Cap Link Card
      expect(find.text('Smart-Cap Link'), findsOneWidget);

      // Verify Primary Action Buttons
      expect(find.text('Open Live Camera Stream'), findsOneWidget);
      expect(find.text('Capture Still Image'), findsOneWidget);

      // Verify Assistive AI Section
      expect(find.text('ASSISTIVE AI MODULES'), findsOneWidget);
      expect(find.text('Object Detection'), findsOneWidget);
      expect(find.text('OCR Text Reader'), findsOneWidget);
    },
  );
}
