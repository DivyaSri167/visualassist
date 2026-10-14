import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Accessible diagnostic card communicating errors and recovery instructions.
class ErrorBanner extends StatelessWidget {
  final String title;
  final String message;
  final String? troubleshootingGuide;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorBanner({
    super.key,
    this.title = 'Connection Notice',
    required this.message,
    this.troubleshootingGuide,
    this.onRetry,
    this.retryLabel = 'Retry Connection',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Error Alert: $title. $message. $troubleshootingGuide',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorRed, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.errorRed,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.highContrastText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (troubleshootingGuide != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.help_outline,
                      color: AppTheme.primaryAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        troubleshootingGuide!,
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 22),
                  label: Text(retryLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
