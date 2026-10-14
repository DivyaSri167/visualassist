import 'dart:async';
import 'dart:math';

import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../domain/user_step_counter_state.dart';

/// Manages phone-based footstep counting for the user.
/// Evaluates native Android hardware pedometer sensor first,
/// seamlessly falling back to a gravity-aware accelerometer peak detector.
class UserStepDetectorService {
  StreamSubscription<StepCount>? _pedometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  Timer? _durationTimer;

  UserStepCounterState _state = const UserStepCounterState();
  final _stateController = StreamController<UserStepCounterState>.broadcast();

  Stream<UserStepCounterState> get stateStream => _stateController.stream;
  UserStepCounterState get currentState => _state;

  // Baseline for native pedometer session calculation
  int? _nativeStepBaseline;

  // Accelerometer algorithm parameters
  final List<double> _magnitudeHistory = [];
  final List<DateTime> _recentStepTimestamps = [];
  double _smoothMagnitude = 0.0;
  bool _peakArmed = false;
  DateTime _lastStepDetectedAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Peak detection constants
  static const double _stepThreshold = 2.1; // m/s^2 above resting gravity baseline
  static const int _refractoryPeriodMs = 280; // minimum ms between consecutive steps

  void _emit(UserStepCounterState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Starts step counting using native pedometer if available, otherwise accelerometer.
  void startTracking() {
    if (_state.isTracking && !_state.isPaused) return;

    if (_state.isPaused) {
      _emit(_state.copyWith(isPaused: false));
      _startDurationTimer();
      return;
    }

    _emit(
      _state.copyWith(
        isTracking: true,
        isPaused: false,
        walkingDuration: Duration.zero,
        sessionSteps: 0,
      ),
    );

    _startDurationTimer();
    _initSensors();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.isTracking && !_state.isPaused) {
        _calculateCadence();
        _emit(
          _state.copyWith(
            walkingDuration: _state.walkingDuration + const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _initSensors() {
    _nativeStepBaseline = null;

    try {
      // Attempt native Android Pedometer stream
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _handleNativeStepCount(event.steps);
        },
        onError: (error) {
          // Hardware step sensor unavailable or permission denied: fallback to accelerometer
          _pedometerSubscription?.cancel();
          _pedometerSubscription = null;
          _startAccelerometerFallback('Native pedometer sensor unavailable ($error). Using phone accelerometer.');
        },
        cancelOnError: true,
      );
    } catch (e) {
      _startAccelerometerFallback('Failed to initialize native step sensor: $e');
    }
  }

  void _handleNativeStepCount(int currentTotalSteps) {
    _nativeStepBaseline ??= currentTotalSteps;

    final sessionSteps = max(0, currentTotalSteps - _nativeStepBaseline!);
    _recentStepTimestamps.add(DateTime.now());

    _emit(
      _state.copyWith(
        sessionSteps: sessionSteps,
        totalSensorSteps: currentTotalSteps,
        sensorSource: StepSensorSource.nativePedometer,
        signalQuality: StepSignalQuality.high,
        sensorDiagnosticMessage: 'Native Android Step Counter Active',
      ),
    );
  }

  void _startAccelerometerFallback(String reason) {
    _sensorSubscription?.cancel();

    _emit(
      _state.copyWith(
        sensorSource: StepSensorSource.accelerometerFallback,
        sensorDiagnosticMessage: reason,
        signalQuality: StepSignalQuality.medium,
      ),
    );

    try {
      _sensorSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          _processAccelerometerEvent(event);
        },
        onError: (error) {
          _emit(
            _state.copyWith(
              sensorSource: StepSensorSource.unavailable,
              signalQuality: StepSignalQuality.idle,
              sensorDiagnosticMessage: 'Accelerometer error: $error',
            ),
          );
        },
      );
    } catch (e) {
      _emit(
        _state.copyWith(
          sensorSource: StepSensorSource.unavailable,
          sensorDiagnosticMessage: 'Motion sensors unavailable: $e',
        ),
      );
    }
  }

  /// Gravity-aware linear acceleration filtering and refractory peak detection
  void _processAccelerometerEvent(UserAccelerometerEvent event) {
    if (_state.isPaused || !_state.isTracking) return;

    // Magnitude of user linear acceleration (gravity is already separated)
    final rawMagnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Exponential moving average filter (alpha = 0.25)
    _smoothMagnitude = 0.25 * rawMagnitude + 0.75 * _smoothMagnitude;

    final now = DateTime.now();

    // Peak detection with refractory suppression
    if (_smoothMagnitude > _stepThreshold) {
      if (!_peakArmed) {
        final elapsedSinceLastStep =
            now.difference(_lastStepDetectedAt).inMilliseconds;

        if (elapsedSinceLastStep >= _refractoryPeriodMs) {
          _lastStepDetectedAt = now;
          _peakArmed = true;

          final newCount = _state.sessionSteps + 1;
          _recentStepTimestamps.add(now);

          _emit(
            _state.copyWith(
              sessionSteps: newCount,
              totalSensorSteps: _state.totalSensorSteps + 1,
              signalQuality: StepSignalQuality.medium,
            ),
          );
        }
      }
    } else if (_smoothMagnitude < _stepThreshold * 0.5) {
      // Reset trigger when acceleration dips below reset threshold
      _peakArmed = false;
    }
  }

  void _calculateCadence() {
    final now = DateTime.now();
    // Rolling 10-second cadence window
    _recentStepTimestamps.removeWhere(
      (t) => now.difference(t).inSeconds > 10,
    );

    final stepsInWindow = _recentStepTimestamps.length;
    final cadence = stepsInWindow * 6.0; // steps per minute

    final quality = cadence > 30.0
        ? (_state.sensorSource == StepSensorSource.nativePedometer
            ? StepSignalQuality.high
            : StepSignalQuality.medium)
        : StepSignalQuality.idle;

    _emit(_state.copyWith(currentCadence: cadence, signalQuality: quality));
  }

  void pauseTracking() {
    _emit(_state.copyWith(isPaused: true));
  }

  void resumeTracking() {
    _emit(_state.copyWith(isPaused: false));
  }

  void reset() {
    _durationTimer?.cancel();
    _nativeStepBaseline = null;
    _recentStepTimestamps.clear();
    _magnitudeHistory.clear();
    _smoothMagnitude = 0.0;
    _peakArmed = false;

    _emit(
      _state.copyWith(
        sessionSteps: 0,
        walkingDuration: Duration.zero,
        isTracking: false,
        isPaused: false,
        currentCadence: 0.0,
      ),
    );
  }

  /// Formatted spoken summary of footsteps taken
  String getSpokenSummary() {
    return 'You have taken approximately ${_state.sessionSteps} steps. This is an estimate, not a verified step count.';
  }

  void dispose() {
    _durationTimer?.cancel();
    _pedometerSubscription?.cancel();
    _sensorSubscription?.cancel();
    _stateController.close();
  }
}
