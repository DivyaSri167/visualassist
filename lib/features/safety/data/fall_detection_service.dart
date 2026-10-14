import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Service analyzing accelerometer streams for physical human fall impact signatures.
///
/// A typical fall signature comprises:
/// 1. Free-fall phase: Total magnitude drops below ~3.5 m/s^2.
/// 2. Impact phase: High acceleration peak (> 22.0 m/s^2).
/// 3. Immobility/Resting phase: User remains relatively still post-impact.
class FallDetectionService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  final void Function() onFallDetected;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  double sensitivityMultiplier = 1.0;

  // Internal state tracking
  DateTime _lastFreefallTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _cooldownMs = 15000; // prevent multiple triggers in 15 seconds

  FallDetectionService({required this.onFallDetected});

  /// Starts listening to phone accelerometer events.
  void startMonitoring({double sensitivity = 1.0}) {
    if (_isMonitoring) return;
    sensitivityMultiplier = sensitivity;
    _isMonitoring = true;

    try {
      _accelerometerSub = accelerometerEventStream().listen(
        _processAccelerometerEvent,
        onError: (_) {
          stopMonitoring();
        },
        cancelOnError: false,
      );
    } catch (_) {
      _isMonitoring = false;
    }
  }

  /// Stops sensor listener.
  void stopMonitoring() {
    _accelerometerSub?.cancel();
    _accelerometerSub = null;
    _isMonitoring = false;
  }

  void _processAccelerometerEvent(AccelerometerEvent event) {
    if (!_isMonitoring) return;

    final now = DateTime.now();
    if (now.difference(_lastTriggerTime).inMilliseconds < _cooldownMs) {
      return;
    }

    // Standard magnitude: sqrt(x^2 + y^2 + z^2) (Earth gravity baseline is ~9.81 m/s^2)
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Free-fall detection threshold
    final freefallThreshold = 3.8 * (1.0 / sensitivityMultiplier);
    if (magnitude < freefallThreshold) {
      _lastFreefallTime = now;
      return;
    }

    // Impact spike threshold (normal baseline ~9.8, hard drop/impact > 23.0)
    final impactThreshold = 22.5 * (1.0 / sensitivityMultiplier);
    if (magnitude > impactThreshold) {
      final msSinceFreefall = now.difference(_lastFreefallTime).inMilliseconds;
      // If an impact occurred within 1.2s of a freefall, or a massive spike occurred:
      if (msSinceFreefall < 1200 || magnitude > (impactThreshold * 1.35)) {
        _lastTriggerTime = now;
        onFallDetected();
      }
    }
  }

  /// Manually simulates a fall event for testing and accessibility validation.
  void triggerSimulatedFall() {
    onFallDetected();
  }

  void dispose() {
    stopMonitoring();
  }
}
