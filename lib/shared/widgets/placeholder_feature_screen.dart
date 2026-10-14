import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Screen displayed for future AI features that are pending camera hardware verification.
class PlaceholderFeatureScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String featureDescription;
  final String requirementsNote;

  const PlaceholderFeatureScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.featureDescription,
    this.requirementsNote = 'This feature requires a verified, stable camera feed from the ESP32-CAM before on-device/edge inference can be activated. Simulated results are strictly omitted.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryAmber, width: 2),
              ),
              child: Icon(icon, size: 64, color: AppTheme.primaryAmber),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x33FFC107),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryAmber, width: 1.5),
              ),
              child: const Text(
                'Coming in Next Milestone',
                style: TextStyle(
                  color: AppTheme.primaryAmber,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.accentCyan,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Feature Roadmap',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.highContrastText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      featureDescription,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Divider(height: 32, color: Color(0xFF334155)),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppTheme.warningOrange,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Hardware Prerequisite',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      requirementsNote,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
