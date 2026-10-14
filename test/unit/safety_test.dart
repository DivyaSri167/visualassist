import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vision_assist/features/safety/data/fall_detection_service.dart';
import 'package:vision_assist/features/safety/data/safety_providers.dart';
import 'package:vision_assist/features/safety/domain/safety_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GuardianContact Model Tests', () {
    test('serializes and deserializes guardian contact JSON correctly', () {
      const contact = GuardianContact(
        id: 'c1',
        name: 'Sarah Connor',
        phoneNumber: '+1234567890',
        relationship: 'Caregiver',
        isPrimary: true,
      );

      final jsonMap = contact.toJson();
      expect(jsonMap['id'], equals('c1'));
      expect(jsonMap['name'], equals('Sarah Connor'));
      expect(jsonMap['phoneNumber'], equals('+1234567890'));
      expect(jsonMap['relationship'], equals('Caregiver'));
      expect(jsonMap['isPrimary'], isTrue);

      final restored = GuardianContact.fromJson(jsonMap);
      expect(restored.id, equals('c1'));
      expect(restored.name, equals('Sarah Connor'));
      expect(restored.phoneNumber, equals('+1234567890'));
      expect(restored.isPrimary, isTrue);
    });

    test('copyWith updates properties properly', () {
      const contact = GuardianContact(
        id: 'c2',
        name: 'John',
        phoneNumber: '111',
      );

      final updated = contact.copyWith(name: 'John Doe', phoneNumber: '222');
      expect(updated.id, equals('c2'));
      expect(updated.name, equals('John Doe'));
      expect(updated.phoneNumber, equals('222'));
    });
  });

  group('SafetyIncident Model Tests', () {
    test('creates and parses incident correctly', () {
      final incident = SafetyIncident(
        id: 'inc1',
        timestamp: DateTime(2026, 10, 13, 12, 0),
        title: 'Fall Incident',
        details: 'High impact detected',
        wasCanceled: false,
        smartCapNotified: true,
      );

      final jsonMap = incident.toJson();
      expect(jsonMap['id'], equals('inc1'));
      expect(jsonMap['title'], equals('Fall Incident'));
      expect(jsonMap['wasCanceled'], isFalse);
      expect(jsonMap['smartCapNotified'], isTrue);

      final restored = SafetyIncident.fromJson(jsonMap);
      expect(restored.id, equals('inc1'));
      expect(restored.title, equals('Fall Incident'));
      expect(restored.smartCapNotified, isTrue);
    });
  });

  group('FallDetectionService Tests', () {
    test('triggers fall callback during simulated fall', () {
      bool fallDetected = false;
      final service = FallDetectionService(
        onFallDetected: () {
          fallDetected = true;
        },
      );

      service.triggerSimulatedFall();
      expect(fallDetected, isTrue);

      service.dispose();
    });
  });

  group('SafetyNotifier State Tests', () {
    test('manages contact addition and removal in Riverpod container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(safetyProvider.notifier);
      final initialState = container.read(safetyProvider);
      expect(initialState.isMonitoring, isFalse);

      notifier.addContact(
        const GuardianContact(
          id: 'test_c',
          name: 'Emergency Doc',
          phoneNumber: '911',
        ),
      );

      final updatedState = container.read(safetyProvider);
      expect(
        updatedState.contacts.any((c) => c.id == 'test_c'),
        isTrue,
      );

      notifier.removeContact('test_c');
      final removedState = container.read(safetyProvider);
      expect(
        removedState.contacts.any((c) => c.id == 'test_c'),
        isFalse,
      );
    });

    test('fall detection countdown triggers and can be canceled cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(safetyProvider.notifier);

      notifier.triggerFallDetected(isSimulation: true);
      var state = container.read(safetyProvider);
      expect(state.status, equals(FallDetectionStatus.countdownActive));
      expect(state.countdownRemaining, greaterThan(0));

      notifier.cancelCountdown();
      state = container.read(safetyProvider);
      expect(state.status, isNot(equals(FallDetectionStatus.countdownActive)));
      expect(state.incidentHistory.isNotEmpty, isTrue);
      expect(state.incidentHistory.first.wasCanceled, isTrue);
    });
  });
}
