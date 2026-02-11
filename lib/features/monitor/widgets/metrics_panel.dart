import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/drowsiness_detector_service.dart';

class MetricsPanel extends StatelessWidget {

  const MetricsPanel({
    super.key,
    required this.state,
    required this.fps,
  });
  final DrowsinessState state;
  final double fps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // FPS
          _buildMetricRow(
            context,
            'FPS',
            fps.toStringAsFixed(1),
            fps >= 25 ? AppTheme.safeColor : AppTheme.warningColor,
          ),
          const SizedBox(height: 8),
          
          // EAR
          _buildMetricRow(
            context,
            'EAR',
            state.ear.toStringAsFixed(3),
            state.ear > 0.2 ? AppTheme.safeColor : AppTheme.dangerColor,
          ),
          const SizedBox(height: 8),
          
          // MAR
          _buildMetricRow(
            context,
            'MAR',
            state.mar.toStringAsFixed(3),
            state.mar < 0.5 ? AppTheme.safeColor : AppTheme.warningColor,
          ),
          const SizedBox(height: 8),
          
          // PERCLOS
          _buildMetricRow(
            context,
            'PERCLOS',
            '${(state.perclos * 100).toStringAsFixed(0)}%',
            state.perclos < 0.3 ? AppTheme.safeColor : AppTheme.dangerColor,
          ),
          
          if (state.headPitch != null || state.headYaw != null) ...[
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.6), height: 20),
            
            // Head Pitch
            if (state.headPitch != null)
              _buildMetricRow(
                context,
                'Pitch',
                '${state.headPitch!.toStringAsFixed(1)}°',
                state.headPitch! > -10 ? AppTheme.safeColor : AppTheme.warningColor,
              ),
            if (state.headPitch != null) const SizedBox(height: 8),
            
            // Head Yaw
            if (state.headYaw != null)
              _buildMetricRow(
                context,
                'Yaw',
                '${state.headYaw!.toStringAsFixed(1)}°',
                state.headYaw!.abs() < 25 ? AppTheme.safeColor : AppTheme.distractedColor,
              ),
          ],
          
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.6), height: 20),
          
          // Face detected status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.faceDetected ? Icons.face : Icons.face_retouching_off,
                size: 16,
                color: state.faceDetected ? AppTheme.safeColor : AppTheme.dangerColor,
              ),
              const SizedBox(width: 8),
              Text(
                  state.faceDetected ? 'Face detected' : 'No face detected',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: state.faceDetected
                          ? AppTheme.safeColor
                          : AppTheme.dangerColor,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
          ),
        ),
      ],
    );
  }
}
