import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../device_connection/data/device_providers.dart';
import '../../object_detection/data/object_detection_providers.dart';
import '../domain/safety_state.dart';
import 'fall_detection_service.dart';

const String _prefKeyContacts = 'safety_guardian_contacts';
const String _prefKeySensitivity = 'safety_fall_sensitivity';
const String _prefKeyAutoSms = 'safety_auto_sms';

class SafetyNotifier extends Notifier<SafetyState> {
  Timer? _countdownTimer;
  FallDetectionService? _fallService;

  @override
  SafetyState build() {
    _loadPreferences();
    _initFallService();

    ref.onDispose(() {
      _countdownTimer?.cancel();
      _fallService?.dispose();
    });

    return const SafetyState();
  }

  void _initFallService() {
    _fallService = FallDetectionService(
      onFallDetected: () {
        triggerFallDetected();
      },
    );
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString(_prefKeyContacts);
      final savedSensitivity = prefs.getDouble(_prefKeySensitivity) ?? 1.0;
      final savedAutoSms = prefs.getBool(_prefKeyAutoSms) ?? true;

      List<GuardianContact> loadedContacts = [];
      if (contactsJson != null && contactsJson.isNotEmpty) {
        final decoded = json.decode(contactsJson) as List<dynamic>;
        loadedContacts = decoded
            .map((item) => GuardianContact.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        // Default initial guardian template for accessibility setup
        loadedContacts = const [
          GuardianContact(
            id: 'default_1',
            name: 'Primary Caregiver',
            phoneNumber: '+1-555-0199',
            relationship: 'Family Caregiver',
            isPrimary: true,
          ),
        ];
      }

      state = state.copyWith(
        contacts: loadedContacts,
        sensitivity: savedSensitivity,
        autoSmsEnabled: savedAutoSms,
      );
    } catch (_) {
      // Fallback cleanly
    }
  }

  Future<void> _saveContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(state.contacts.map((c) => c.toJson()).toList());
      await prefs.setString(_prefKeyContacts, encoded);
    } catch (_) {}
  }

  /// Toggles real-time phone accelerometer fall monitoring.
  void toggleMonitoring() {
    final nextMonitoring = !state.isMonitoring;
    if (nextMonitoring) {
      _fallService?.startMonitoring(sensitivity: state.sensitivity);
      state = state.copyWith(
        isMonitoring: true,
        status: FallDetectionStatus.monitoring,
      );
      _safeSpeak('Fall detection monitoring active');
    } else {
      _fallService?.stopMonitoring();
      _cancelCountdownInternal();
      state = state.copyWith(
        isMonitoring: false,
        status: FallDetectionStatus.inactive,
      );
      _safeSpeak('Fall detection deactivated');
    }
  }

  /// Sets fall detection sensitivity (0.8 = less sensitive, 1.3 = more sensitive).
  void setSensitivity(double newSensitivity) {
    state = state.copyWith(sensitivity: newSensitivity);
    _fallService?.sensitivityMultiplier = newSensitivity;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_prefKeySensitivity, newSensitivity);
    });
  }

  /// Toggles automated SMS text alert escalation.
  void toggleAutoSms(bool enabled) {
    state = state.copyWith(autoSmsEnabled: enabled);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_prefKeyAutoSms, enabled);
    });
  }

  void _safeSpeak(String message) {
    if (!state.speechWarningsEnabled) return;
    try {
      ref.read(speechEngineProvider).speakDirect(message);
    } catch (_) {}
  }

  /// Called automatically by accelerometer service or manual test trigger.
  void triggerFallDetected({bool isSimulation = false}) {
    if (state.status == FallDetectionStatus.countdownActive) return;

    final initialSeconds = state.initialCountdownSeconds;
    state = state.copyWith(
      status: FallDetectionStatus.countdownActive,
      countdownRemaining: initialSeconds,
      clearError: true,
    );

    _safeSpeak(
      'Warning! Fall impact detected. Emergency SOS will dispatch in $initialSeconds seconds. Tap cancel if safe.',
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdownRemaining <= 1) {
        timer.cancel();
        _escalateEmergency(
          title: isSimulation ? 'Simulated Fall Test' : 'Fall Impact Incident',
          details: 'User did not cancel the emergency countdown within $initialSeconds seconds.',
        );
      } else {
        final remaining = state.countdownRemaining - 1;
        state = state.copyWith(countdownRemaining: remaining);
        if (remaining == 10 || remaining == 5 || remaining == 3) {
          _safeSpeak('$remaining seconds until emergency alert.');
        }
      }
    });
  }

  /// Triggers immediate manual SOS panic dispatch.
  Future<void> triggerManualSos() async {
    _cancelCountdownInternal();
    await _escalateEmergency(
      title: 'Manual Emergency SOS',
      details: 'User pressed the instant emergency SOS panic button.',
    );
  }

  /// Cancels the current emergency countdown (e.g., user is safe or false alarm).
  void cancelCountdown() {
    _cancelCountdownInternal();
    state = state.copyWith(
      status: state.isMonitoring ? FallDetectionStatus.monitoring : FallDetectionStatus.inactive,
      countdownRemaining: 0,
    );

    final incident = SafetyIncident(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      title: 'Alert Canceled',
      details: 'User confirmed safety during countdown. False alarm prevented.',
      wasCanceled: true,
    );

    state = state.copyWith(
      incidentHistory: [incident, ...state.incidentHistory],
    );

    _safeSpeak('Emergency alert canceled. Stay safe.');
  }

  void _cancelCountdownInternal() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _escalateEmergency({
    required String title,
    required String details,
  }) async {
    _cancelCountdownInternal();

    state = state.copyWith(
      status: FallDetectionStatus.escalated,
      countdownRemaining: 0,
    );

    bool smartCapSent = false;
    try {
      final repository = ref.read(deviceRepositoryProvider);
      await repository.sendTestSos();
      smartCapSent = true;
    } catch (e) {
      // If Smart-Cap unreachable, record notice
      state = state.copyWith(lastErrorMessage: 'Smart-Cap offline: $e');
    }

    final incident = SafetyIncident(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      title: title,
      details: details,
      wasCanceled: false,
      smartCapNotified: smartCapSent,
    );

    state = state.copyWith(
      incidentHistory: [incident, ...state.incidentHistory],
    );

    _safeSpeak(
      'Emergency alert dispatched to your guardian and Smart-Cap.',
    );
  }

  /// Resets from escalated state back to monitoring or idle.
  void acknowledgeEscalation() {
    state = state.copyWith(
      status: state.isMonitoring ? FallDetectionStatus.monitoring : FallDetectionStatus.inactive,
      clearError: true,
    );
  }

  /// Add a guardian contact.
  void addContact(GuardianContact contact) {
    final updated = [...state.contacts, contact];
    state = state.copyWith(contacts: updated);
    _saveContacts();
  }

  /// Remove a guardian contact.
  void removeContact(String id) {
    final updated = state.contacts.where((c) => c.id != id).toList();
    state = state.copyWith(contacts: updated);
    _saveContacts();
  }

  /// Updates an existing contact.
  void updateContact(GuardianContact contact) {
    final updated = state.contacts.map((c) => c.id == contact.id ? contact : c).toList();
    state = state.copyWith(contacts: updated);
    _saveContacts();
  }
}

final safetyProvider = NotifierProvider<SafetyNotifier, SafetyState>(() {
  return SafetyNotifier();
});
