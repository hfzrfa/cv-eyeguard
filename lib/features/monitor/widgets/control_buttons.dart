import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ControlButtons extends StatelessWidget {
  const ControlButtons({
    super.key,
    required this.isMonitoring,
    required this.showDebug,
    required this.onToggleMonitoring,
    required this.onToggleDebug,
    required this.onSwitchCamera,
    required this.onCalibrate,
    required this.onClose,
  });
  final bool isMonitoring;
  final bool showDebug;
  final VoidCallback onToggleMonitoring;
  final VoidCallback onToggleDebug;
  final VoidCallback onSwitchCamera;
  final VoidCallback onCalibrate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Debug toggle
            _buildControlButton(
              context: context,
              icon: showDebug ? Icons.bug_report : Icons.bug_report_outlined,
              label: 'Debug',
              isActive: showDebug,
              onTap: onToggleDebug,
            ),

            // Switch camera
            _buildControlButton(
              context: context,
              icon: Icons.cameraswitch_outlined,
              label: 'Camera',
              onTap: onSwitchCamera,
            ),

            // Main monitoring button
            _buildMainButton(context),

            // Reset / Calibrate
            _buildControlButton(
              context: context,
              icon: Icons.tune,
              label: 'Calibrate',
              onTap: onCalibrate,
            ),

            // Close
            _buildControlButton(
              context: context,
              icon: Icons.close,
              label: 'Close',
              color: AppTheme.dangerColor,
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    bool isActive = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonColor = color ??
        (isActive ? AppTheme.primaryColor : colorScheme.onSurfaceVariant);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? buttonColor.withValues(alpha: 0.2)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? buttonColor
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: buttonColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: buttonColor,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(BuildContext context) {
    return GestureDetector(
      onTap: onToggleMonitoring,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isMonitoring
              ? AppTheme.safeGradient
              : const LinearGradient(
                  colors: [AppTheme.warningColor, AppTheme.distractedColor]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isMonitoring ? AppTheme.safeColor : AppTheme.warningColor)
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isMonitoring ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
