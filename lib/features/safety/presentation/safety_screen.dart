import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../device_connection/data/device_providers.dart';
import '../data/safety_providers.dart';
import '../domain/safety_state.dart';

class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  static const Color _cardBorderColor = Color(0xFF334155);

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController(text: 'Caregiver');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.primaryAmber, width: 1.5),
        ),
        title: const Text(
          'Add Guardian Contact',
          style: TextStyle(color: AppTheme.highContrastText, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.highContrastText),
                decoration: const InputDecoration(
                  labelText: 'Guardian Name',
                  labelStyle: TextStyle(color: AppTheme.secondaryText),
                  hintText: 'e.g. Jane Doe',
                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryAmber),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppTheme.highContrastText),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: AppTheme.secondaryText),
                  hintText: 'e.g. +1 555 123 4567',
                  prefixIcon: Icon(Icons.phone, color: AppTheme.accentCyan),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                style: const TextStyle(color: AppTheme.highContrastText),
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  labelStyle: TextStyle(color: AppTheme.secondaryText),
                  hintText: 'e.g. Daughter, Spouse, Doctor',
                  prefixIcon: Icon(Icons.favorite, color: AppTheme.errorRed),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isNotEmpty && phone.isNotEmpty) {
                final contact = GuardianContact(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  phoneNumber: phone,
                  relationship: relationshipController.text.trim(),
                  isPrimary: false,
                );
                ref.read(safetyProvider.notifier).addContact(contact);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Guardian', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safetyState = ref.watch(safetyProvider);
    final connectionState = ref.watch(deviceConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Guardian Alerts'),
        actions: [
          IconButton(
            tooltip: 'Add emergency contact',
            icon: const Icon(Icons.person_add, color: AppTheme.primaryAmber),
            onPressed: _showAddContactDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Prominent Active Countdown / Escalated Emergency Card
            if (safetyState.status == FallDetectionStatus.countdownActive)
              _buildActiveCountdownBanner(safetyState)
            else if (safetyState.status == FallDetectionStatus.escalated)
              _buildEscalatedBanner(safetyState),

            // Emergency Panic Button Card
            _buildPanicSosCard(),

            const SizedBox(height: 16),

            // Real-Time Fall Detection Sentinel
            _buildFallDetectionCard(safetyState),

            const SizedBox(height: 16),

            // Hardware Smart-Cap Link SOS Sync
            _buildSmartCapSosCard(connectionState),

            const SizedBox(height: 16),

            // Designated Guardian Contacts
            _buildGuardianContactsCard(safetyState),

            const SizedBox(height: 16),

            // Safety Incident History Log
            _buildIncidentHistoryCard(safetyState),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCountdownBanner(SafetyState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D), // Dark Red
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66EF4444),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
              SizedBox(width: 10),
              Text(
                'FALL DETECTED!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${state.countdownRemaining} SECONDS',
            style: const TextStyle(
              color: AppTheme.primaryAmber,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Emergency alert will dispatch to guardians and Smart-Cap unless canceled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle, size: 26),
                  label: const Text(
                    'I AM OK - CANCEL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => ref.read(safetyProvider.notifier).cancelCountdown(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SEND NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => ref.read(safetyProvider.notifier).triggerManualSos(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEscalatedBanner(SafetyState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed, width: 2),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.emergency, color: AppTheme.errorRed, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Emergency Alert Dispatched',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Automated alerts have been sent to your primary contacts and logged on the Smart-Cap.',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => ref.read(safetyProvider.notifier).acknowledgeEscalation(),
            child: const Text('Dismiss Alert Banner', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPanicSosCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withAlpha(120), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.touch_app, color: AppTheme.errorRed, size: 24),
              SizedBox(width: 10),
              Text(
                'Instant Emergency SOS',
                style: TextStyle(
                  color: AppTheme.highContrastText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Press and hold or tap to immediately dispatch emergency signals to family and hardware.',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 16),
          AccessibleButton(
            label: 'DISPATCH EMERGENCY SOS',
            icon: Icons.emergency_share,
            isPrimary: true,
            semanticHint: 'Triggers emergency alert immediately to all guardian contacts',
            onPressed: () => ref.read(safetyProvider.notifier).triggerManualSos(),
          ),
        ],
      ),
    );
  }

  Widget _buildFallDetectionCard(SafetyState safetyState) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sensors, color: AppTheme.accentCyan, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Fall Sentinel',
                    style: TextStyle(
                      color: AppTheme.highContrastText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Switch(
                value: safetyState.isMonitoring,
                activeThumbColor: AppTheme.primaryAmber,
                onChanged: (_) => ref.read(safetyProvider.notifier).toggleMonitoring(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            safetyState.isMonitoring
                ? 'Monitoring phone accelerometer for freefall and impact spikes.'
                : 'Sensor monitoring is currently idle. Toggle switch to activate.',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Divider(color: _cardBorderColor),
          const SizedBox(height: 8),

          // Sensitivity Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sensitivity Multiplier',
                style: TextStyle(color: AppTheme.highContrastText, fontSize: 15),
              ),
              Text(
                '${safetyState.sensitivity.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: AppTheme.primaryAmber,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Slider(
            value: safetyState.sensitivity,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            activeColor: AppTheme.primaryAmber,
            inactiveColor: _cardBorderColor,
            onChanged: (val) => ref.read(safetyProvider.notifier).setSensitivity(val),
          ),
          const SizedBox(height: 8),

          // Simulation Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentCyan,
              side: const BorderSide(color: AppTheme.accentCyan),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 22),
            label: const Text(
              'Simulate Test Fall Event',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              ref.read(safetyProvider.notifier).triggerFallDetected(isSimulation: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmartCapSosCard(dynamic connectionState) {
    final isConnected = connectionState.isConnected;
    final deviceStatus = connectionState.deviceStatus;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: AppTheme.primaryAmber, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Smart-Cap SOS Sync',
                    style: TextStyle(
                      color: AppTheme.highContrastText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0x2200E676) : const Color(0x22FF5252),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
                  ),
                ),
                child: Text(
                  isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'ESP32-CAM is connected. SOS trigger count: ${deviceStatus?.sosCount ?? 0}.'
                : 'ESP32-CAM is offline. Safety alerts will be handled locally by the phone.',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianContactsCard(SafetyState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.contact_phone, color: AppTheme.primaryAmber, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Guardian Contacts',
                    style: TextStyle(
                      color: AppTheme.highContrastText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Add contact',
                icon: const Icon(Icons.add_circle, color: AppTheme.accentCyan),
                onPressed: _showAddContactDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No guardian contacts configured. Tap + to add emergency family contacts.',
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
              ),
            )
          else
            ...state.contacts.map((contact) => _buildContactTile(contact)),
        ],
      ),
    );
  }

  Widget _buildContactTile(GuardianContact contact) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryAmber.withAlpha(40),
            child: const Icon(Icons.person, color: AppTheme.primaryAmber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    color: AppTheme.highContrastText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${contact.relationship} • ${contact.phoneNumber}',
                  style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove ${contact.name}',
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
            onPressed: () => ref.read(safetyProvider.notifier).removeContact(contact.id),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentHistoryCard(SafetyState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: AppTheme.accentCyan, size: 22),
              SizedBox(width: 10),
              Text(
                'Incident History',
                style: TextStyle(
                  color: AppTheme.highContrastText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.incidentHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No safety incidents logged. Stay safe!',
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
              ),
            )
          else
            ...state.incidentHistory.take(5).map(
              (incident) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      incident.wasCanceled ? Icons.cancel_outlined : Icons.warning,
                      color: incident.wasCanceled ? AppTheme.secondaryText : AppTheme.errorRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${incident.title} (${incident.timestamp.hour.toString().padLeft(2, '0')}:${incident.timestamp.minute.toString().padLeft(2, '0')})',
                        style: TextStyle(
                          color: incident.wasCanceled
                              ? AppTheme.secondaryText
                              : AppTheme.highContrastText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
