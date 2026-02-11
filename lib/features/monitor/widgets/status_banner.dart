import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/drowsiness_detector_service.dart';

class StatusBanner extends StatelessWidget {

  const StatusBanner({
    super.key,
    required this.status,
    required this.message,
  });
  final DriverStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            config.color,
            config.color.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon with pulse animation for danger states
          _buildStatusIcon(config),
          const SizedBox(width: 16),
          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(_StatusConfig config) {
    Widget icon = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        config.icon,
        color: Colors.white,
        size: 28,
      ),
    );

    // Add pulse animation for danger/drowsy states
    if (status == DriverStatus.drowsy || 
        status == DriverStatus.danger ||
        status == DriverStatus.distracted) {
      icon = icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.1, 1.1),
            duration: 600.ms,
          );
    }

    return icon;
  }

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case DriverStatus.safe:
        return _StatusConfig(
          color: AppTheme.safeColor,
          icon: Icons.check_circle_outline,
          title: 'SAFE',
        );
      case DriverStatus.drowsy:
        return _StatusConfig(
          color: AppTheme.drowsyColor,
          icon: Icons.warning_amber_rounded,
          title: 'DROWSY',
        );
      case DriverStatus.distracted:
        return _StatusConfig(
          color: AppTheme.distractedColor,
          icon: Icons.visibility_off_outlined,
          title: 'DISTRACTED',
        );
      case DriverStatus.danger:
        return _StatusConfig(
          color: AppTheme.dangerColor,
          icon: Icons.dangerous_outlined,
          title: 'DANGER',
        );
    }
  }
}

class _StatusConfig {

  _StatusConfig({
    required this.color,
    required this.icon,
    required this.title,
  });
  final Color color;
  final IconData icon;
  final String title;
}
