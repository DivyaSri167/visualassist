/// Status of the active fall detection sensor and emergency escalation.
enum FallDetectionStatus {
  inactive,
  monitoring,
  countdownActive,
  escalated,
}

/// Represents an emergency guardian or caregiver contact.
class GuardianContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String relationship;
  final bool isPrimary;

  const GuardianContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship = 'Caregiver',
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'relationship': relationship,
    'isPrimary': isPrimary,
  };

  factory GuardianContact.fromJson(Map<String, dynamic> json) => GuardianContact(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] as String? ?? 'Guardian',
    phoneNumber: json['phoneNumber'] as String? ?? '',
    relationship: json['relationship'] as String? ?? 'Caregiver',
    isPrimary: json['isPrimary'] as bool? ?? false,
  );

  GuardianContact copyWith({
    String? name,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
  }) {
    return GuardianContact(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

/// Represents a safety occurrence (fall detected, manual SOS, or simulation test).
class SafetyIncident {
  final String id;
  final DateTime timestamp;
  final String title;
  final String details;
  final bool wasCanceled;
  final bool smartCapNotified;

  const SafetyIncident({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.details,
    this.wasCanceled = false,
    this.smartCapNotified = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'title': title,
    'details': details,
    'wasCanceled': wasCanceled,
    'smartCapNotified': smartCapNotified,
  };

  factory SafetyIncident.fromJson(Map<String, dynamic> json) => SafetyIncident(
    id: json['id'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    title: json['title'] as String? ?? 'Safety Event',
    details: json['details'] as String? ?? '',
    wasCanceled: json['wasCanceled'] as bool? ?? false,
    smartCapNotified: json['smartCapNotified'] as bool? ?? false,
  );
}

/// Overall state for the Safety & Guardian Alerts feature.
class SafetyState {
  final bool isMonitoring;
  final FallDetectionStatus status;
  final int countdownRemaining;
  final int initialCountdownSeconds;
  final double sensitivity; // 0.8 to 1.5, default 1.0
  final bool autoSmsEnabled;
  final bool speechWarningsEnabled;
  final List<GuardianContact> contacts;
  final List<SafetyIncident> incidentHistory;
  final String? lastErrorMessage;

  const SafetyState({
    this.isMonitoring = false,
    this.status = FallDetectionStatus.inactive,
    this.countdownRemaining = 0,
    this.initialCountdownSeconds = 15,
    this.sensitivity = 1.0,
    this.autoSmsEnabled = true,
    this.speechWarningsEnabled = true,
    this.contacts = const [],
    this.incidentHistory = const [],
    this.lastErrorMessage,
  });

  bool get isAlarmActive =>
      status == FallDetectionStatus.countdownActive || status == FallDetectionStatus.escalated;

  SafetyState copyWith({
    bool? isMonitoring,
    FallDetectionStatus? status,
    int? countdownRemaining,
    int? initialCountdownSeconds,
    double? sensitivity,
    bool? autoSmsEnabled,
    bool? speechWarningsEnabled,
    List<GuardianContact>? contacts,
    List<SafetyIncident>? incidentHistory,
    String? lastErrorMessage,
    bool clearError = false,
  }) {
    return SafetyState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      status: status ?? this.status,
      countdownRemaining: countdownRemaining ?? this.countdownRemaining,
      initialCountdownSeconds: initialCountdownSeconds ?? this.initialCountdownSeconds,
      sensitivity: sensitivity ?? this.sensitivity,
      autoSmsEnabled: autoSmsEnabled ?? this.autoSmsEnabled,
      speechWarningsEnabled: speechWarningsEnabled ?? this.speechWarningsEnabled,
      contacts: contacts ?? this.contacts,
      incidentHistory: incidentHistory ?? this.incidentHistory,
      lastErrorMessage: clearError ? null : (lastErrorMessage ?? this.lastErrorMessage),
    );
  }
}
