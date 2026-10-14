import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/device_connection/domain/connection_state.dart';

/// Accessible badge presenting hardware connectivity using distinct icon, text, and color.
class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionStatus status;
  final bool showLabel;

  const ConnectionStatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final info = _getStatusInfo(status);

    return Semantics(
      label: 'Connection Status: ${info.text}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: info.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: info.borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info.icon, size: 18, color: info.textColor),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  info.text,
                  style: TextStyle(
                    color: info.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StatusDisplayInfo _getStatusInfo(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return const _StatusDisplayInfo(
          text: 'Connected',
          icon: Icons.check_circle_outline,
          textColor: AppTheme.successGreen,
          borderColor: AppTheme.successGreen,
          backgroundColor: Color(0x2200E676),
        );
      case ConnectionStatus.streaming:
        return const _StatusDisplayInfo(
          text: 'Live Streaming',
          icon: Icons.videocam,
          textColor: AppTheme.accentCyan,
          borderColor: AppTheme.accentCyan,
          backgroundColor: Color(0x2200E5FF),
        );
      case ConnectionStatus.connecting:
        return const _StatusDisplayInfo(
          text: 'Connecting...',
          icon: Icons.sync,
          textColor: AppTheme.primaryAmber,
          borderColor: AppTheme.primaryAmber,
          backgroundColor: Color(0x22FFC107),
        );
      case ConnectionStatus.reconnecting:
        return const _StatusDisplayInfo(
          text: 'Reconnecting...',
          icon: Icons.sync_problem,
          textColor: AppTheme.warningOrange,
          borderColor: AppTheme.warningOrange,
          backgroundColor: Color(0x22FF9100),
        );
      case ConnectionStatus.cameraUnavailable:
        return const _StatusDisplayInfo(
          text: 'Camera Sensor Error',
          icon: Icons.warning_amber_rounded,
          textColor: AppTheme.warningOrange,
          borderColor: AppTheme.warningOrange,
          backgroundColor: Color(0x22FF9100),
        );
      case ConnectionStatus.error:
        return const _StatusDisplayInfo(
          text: 'Connection Error',
          icon: Icons.error_outline,
          textColor: AppTheme.errorRed,
          borderColor: AppTheme.errorRed,
          backgroundColor: Color(0x22FF5252),
        );
      case ConnectionStatus.disconnected:
        return const _StatusDisplayInfo(
          text: 'Disconnected',
          icon: Icons.cloud_off,
          textColor: AppTheme.secondaryText,
          borderColor: Color(0xFF64748B),
          backgroundColor: Color(0x2264748B),
        );
    }
  }
}

class _StatusDisplayInfo {
  final String text;
  final IconData icon;
  final Color textColor;
  final Color borderColor;
  final Color backgroundColor;

  const _StatusDisplayInfo({
    required this.text,
    required this.icon,
    required this.textColor,
    required this.borderColor,
    required this.backgroundColor,
  });
}
