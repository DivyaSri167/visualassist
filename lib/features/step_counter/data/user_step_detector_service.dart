import 'dart:async';
import 'dart:math';

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final List<double> _magnitudeBuffer = [];
  final List<DateTime> _recentStepTimestamps = [];
  double _prevMagnitude = 0.0;
  double _prevPrevMagnitude = 0.0;
  DateTime _lastStepDetectedAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Peak detection constants
  static const double _minStepPeakThreshold = 1.25; // m/s^2 linear acceleration peak
  static const int _minStepIntervalMs = 260; // minimum ms between consecutive steps (~230 steps/min max)
  static const int _maxStepIntervalMs = 2000; // maximum ms to maintain continuous cadence

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

  Future<void> _initSensors() async {
    _nativeStepBaseline = null;

    bool hasPermission = true;
    try {
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        final requested = await Permission.activityRecognition.request();
        hasPermission = requested.isGranted;
      }
    } catch (_) {
      // In testing environments or desktop, continue gracefully
    }

    if (!hasPermission) {
      _startAccelerometerFallback(
        'Activity recognition permission not granted. Using phone accelerometer fallback.',
      );
      return;
    }

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
          _startAccelerometerFallback(
            'Native pedometer sensor unavailable ($error). Using phone accelerometer.',
          );
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

  /// Gravity-aware linear acceleration filtering and robust peak detection
  void _processAccelerometerEvent(UserAccelerometerEvent event) {
    if (_state.isPaused || !_state.isTracking) return;

    // Magnitude of user linear acceleration (gravity is already separated)
    final rawMagnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Keep circular buffer of last 12 samples to calculate local baseline
    _magnitudeBuffer.add(rawMagnitude);
    if (_magnitudeBuffer.length > 12) {
      _magnitudeBuffer.removeAt(0);
    }

    // Adaptive local peak detection: check if previous sample is a local maximum
    // (i.e. _prevMagnitude is strictly higher than both _prevPrevMagnitude and rawMagnitude)
    final isLocalPeak = _prevMagnitude > _prevPrevMagnitude &&
        _prevMagnitude > rawMagnitude &&
        _prevMagnitude >= _minStepPeakThreshold;

    if (isLocalPeak) {
      final now = DateTime.now();
      final elapsedSinceLastStep =
          now.difference(_lastStepDetectedAt).inMilliseconds;

      if (elapsedSinceLastStep >= _minStepIntervalMs) {
        _lastStepDetectedAt = now;

        final newCount = _state.sessionSteps + 1;
        _recentStepTimestamps.add(now);

        _emit(
          _state.copyWith(
            sessionSteps: newCount,
            totalSensorSteps: _state.totalSensorSteps + 1,
            signalQuality: StepSignalQuality.medium,
            sensorDiagnosticMessage: 'Accelerometer Step Detector Active',
          ),
        );
      }
    }

    _prevPrevMagnitude = _prevMagnitude;
    _prevMagnitude = rawMagnitude;
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
    _magnitudeBuffer.clear();
    _prevMagnitude = 0.0;
    _prevPrevMagnitude = 0.0;

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
