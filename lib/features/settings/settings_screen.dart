import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/drowsiness_detector_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../calibration/calibration_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final StorageService _storageService;

  AppSettings _settings = AppSettings();
  CalibrationData _calibration = CalibrationData();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _storageService = StorageService();
    await _storageService.initialize();

    final settings = await _storageService.loadSettings();
    final calibration = await _storageService.loadCalibration();

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _calibration = calibration;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _storageService.saveSettings(_settings);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCalibrationCard(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Alerts'),
                    _buildSettingSwitch(
                      title: 'Text-to-Speech',
                      subtitle: 'Voice alert when drowsiness is detected',
                      icon: Icons.volume_up_outlined,
                      value: _settings.ttsEnabled,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(ttsEnabled: value));
                        _saveSettings();
                      },
                    ),
                    _buildSettingSwitch(
                      title: 'Vibration',
                      subtitle: 'Vibrate for critical alerts',
                      icon: Icons.vibration,
                      value: _settings.vibrationEnabled,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(vibrationEnabled: value));
                        _saveSettings();
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Display'),
                    _buildThemeModeSetting(),
                    _buildSettingSwitch(
                      title: 'Debug Info',
                      subtitle: 'Show EAR, MAR, FPS metrics',
                      icon: Icons.bug_report_outlined,
                      value: _settings.showDebugInfo,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(showDebugInfo: value));
                        _saveSettings();
                      },
                    ),
                    _buildSettingSwitch(
                      title: 'Face Mesh',
                      subtitle: 'Show face detection overlay',
                      icon: Icons.face_outlined,
                      value: _settings.showFaceMesh,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(showFaceMesh: value));
                        _saveSettings();
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Detection Sensitivity'),
                    _buildSliderSetting(
                      title: 'Eye Threshold (EAR)',
                      subtitle: 'Lower = more sensitive',
                      value: _settings.earThreshold,
                      min: 0.10,
                      max: 0.35,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(earThreshold: value));
                        _saveSettings();
                      },
                      valueDecimals: 2,
                    ),
                    _buildSliderSetting(
                      title: 'Yawn Threshold (MAR)',
                      subtitle: 'Lower = more sensitive',
                      value: _settings.marThreshold,
                      min: 0.30,
                      max: 0.80,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(marThreshold: value));
                        _saveSettings();
                      },
                      valueDecimals: 2,
                    ),
                    _buildSliderSetting(
                      title: 'Looking Away Threshold',
                      subtitle: 'Angle in degrees',
                      value: _settings.yawThreshold,
                      min: 10,
                      max: 45,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(yawThreshold: value));
                        _saveSettings();
                      },
                      suffix: '°',
                      divisions: 35,
                      valueDecimals: 0,
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Performance'),
                    _buildSliderSetting(
                      title: 'Alert Cooldown',
                      subtitle: 'Delay between voice alerts',
                      value: _settings.ttsCooldown,
                      min: 2,
                      max: 15,
                      onChanged: (value) {
                        setState(() => _settings = _settings.copyWith(ttsCooldown: value));
                        _saveSettings();
                      },
                      suffix: ' sec',
                      divisions: 13,
                      valueDecimals: 0,
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('About'),
                    _buildInfoCard(),
                    const SizedBox(height: 24),

                    _buildResetButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildThemeModeSetting() {
    final colorScheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);

    String labelFor(ThemeMode mode) {
      return switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Choose the app appearance',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<ThemeMode>(
              value: mode,
              items: ThemeMode.values
                  .map(
                    (m) => DropdownMenuItem<ThemeMode>(
                      value: m,
                      child: Text(labelFor(m)),
                    ),
                  )
                  .toList(),
              onChanged: (newMode) {
                if (newMode == null) return;
                ref.read(themeModeProvider.notifier).setThemeMode(newMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = _calibration.calibrated ? AppTheme.safeColor : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _calibration.calibrated ? Icons.check_circle : Icons.warning_amber,
              color: baseColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _calibration.calibrated ? 'Calibrated' : 'Not calibrated',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _calibration.calibrated
                      ? 'Threshold: ${_calibration.computeThreshold().toStringAsFixed(3)}'
                      : 'Calibrate for better accuracy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                if (_calibration.calibrationDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last: ${_formatDate(_calibration.calibrationDate!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalibrationScreen()),
              );
            },
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildSectionTitle(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String suffix = '',
    int? divisions,
    int valueDecimals = 2,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(
                '${value.toStringAsFixed(valueDecimals)}$suffix',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.remove_red_eye,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Eye Guardian', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'AI-based drowsiness and distraction detection for safer driving. Uses ML Kit for real-time face analysis.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmReset,
        icon: const Icon(Icons.refresh),
        label: const Text('Reset Settings'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.warningColor,
          side: const BorderSide(color: AppTheme.warningColor),
        ),
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset settings?'),
        content: const Text('All settings will be restored to default.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              setState(() => _settings = AppSettings());
              await _saveSettings();
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
