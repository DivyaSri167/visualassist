enum StepSensorSource {
  nativePedometer,
  accelerometerFallback,
  unavailable,
}

enum StepSignalQuality {
  high,
  medium,
  low,
  idle,
}

class UserStepCounterState {
  final int sessionSteps;
  final int totalSensorSteps;
  final Duration walkingDuration;
  final bool isTracking;
  final bool isPaused;
  final StepSensorSource sensorSource;
  final StepSignalQuality signalQuality;
  final double currentCadence; // steps per minute
  final String? sensorDiagnosticMessage;

  const UserStepCounterState({
    this.sessionSteps = 0,
    this.totalSensorSteps = 0,
    this.walkingDuration = Duration.zero,
    this.isTracking = false,
    this.isPaused = false,
    this.sensorSource = StepSensorSource.accelerometerFallback,
    this.signalQuality = StepSignalQuality.idle,
    this.currentCadence = 0.0,
    this.sensorDiagnosticMessage,
  });

  bool get isReliable =>
      signalQuality == StepSignalQuality.high ||
      signalQuality == StepSignalQuality.medium;

  UserStepCounterState copyWith({
    int? sessionSteps,
    int? totalSensorSteps,
    Duration? walkingDuration,
    bool? isTracking,
    bool? isPaused,
    StepSensorSource? sensorSource,
    StepSignalQuality? signalQuality,
    double? currentCadence,
    String? sensorDiagnosticMessage,
  }) {
    return UserStepCounterState(
      sessionSteps: sessionSteps ?? this.sessionSteps,
      totalSensorSteps: totalSensorSteps ?? this.totalSensorSteps,
      walkingDuration: walkingDuration ?? this.walkingDuration,
      isTracking: isTracking ?? this.isTracking,
      isPaused: isPaused ?? this.isPaused,
      sensorSource: sensorSource ?? this.sensorSource,
      signalQuality: signalQuality ?? this.signalQuality,
      currentCadence: currentCadence ?? this.currentCadence,
      sensorDiagnosticMessage:
          sensorDiagnosticMessage ?? this.sensorDiagnosticMessage,
    );
  }
}
