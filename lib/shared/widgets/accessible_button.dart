import 'package:flutter/material.dart';

/// Large touch target button with explicit accessibility semantics and high contrast.
class AccessibleButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final String? semanticHint;
  final double minHeight;
  final Color? customColor;
  final Color? customTextColor;

  const AccessibleButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.semanticHint,
    this.minHeight = 58.0,
    this.customColor,
    this.customTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      hint: semanticHint,
      child: SizedBox(
        width: double.infinity,
        height: minHeight,
        child: isPrimary
            ? ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: customColor != null
                    ? ElevatedButton.styleFrom(
                        backgroundColor: customColor,
                        foregroundColor: customTextColor ?? Colors.black,
                      )
                    : null,
                child: _buildChild(theme),
              )
            : OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                style: customColor != null
                    ? OutlinedButton.styleFrom(
                        side: BorderSide(color: customColor!, width: 2),
                        foregroundColor: customTextColor ?? customColor,
                      )
                    : null,
                child: _buildChild(theme),
              ),
      ),
    );
  }

  Widget _buildChild(ThemeData theme) {
    if (isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary ? Colors.black : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Connecting...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }
}
