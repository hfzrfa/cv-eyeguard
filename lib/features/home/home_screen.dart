import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/storage_service.dart';
import '../monitor/monitor_screen.dart';
import '../calibration/calibration_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/feature_card.dart';
import 'widgets/stats_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final StorageService _storageService;
  bool _isLoadingStats = true;
  int _sessionsThisMonth = 0;
  double? _avgSafetyScoreThisMonth;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _loadQuickStats();
  }

  Future<void> _loadQuickStats() async {
    await _storageService.initialize();
    final sessions = await _storageService.loadSessionHistory();

    final now = DateTime.now();
    final thisMonthSessions = sessions
        .where((s) =>
            s.startTime.year == now.year && s.startTime.month == now.month)
        .toList();

    final int sessionsThisMonth = thisMonthSessions.length;
    final double? avgSafetyScoreThisMonth = sessionsThisMonth == 0
        ? null
        : thisMonthSessions.map((s) => s.safetyScore).reduce((a, b) => a + b) /
            sessionsThisMonth;

    if (!mounted) return;
    setState(() {
      _sessionsThisMonth = sessionsThisMonth;
      _avgSafetyScoreThisMonth = avgSafetyScoreThisMonth;
      _isLoadingStats = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),

                const SizedBox(height: 32),

                // Main action button
                _buildMainActionButton(),

                const SizedBox(height: 32),

                // Quick stats
                _buildQuickStats(),

                const SizedBox(height: 32),

                // Features grid
                _buildFeaturesSection(),

                const SizedBox(height: 24),

                // Safety tips
                _buildSafetyTips(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SafeDrive',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),
            const SizedBox(height: 4),
            Text(
              'Monitor your driving safety',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
          ],
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Icon(
              Icons.settings_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ).animate(delay: 300.ms).fadeIn().scale(),
      ],
    );
  }

  Widget _buildMainActionButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MonitorScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Monitoring',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enable drowsiness & distraction detection',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    )
        .animate(delay: 400.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0)
        .then()
        .shimmer(
          duration: 2000.ms,
          color: Colors.white.withValues(alpha: 0.1),
        );
  }

  Widget _buildQuickStats() {
    final score = _avgSafetyScoreThisMonth;

    final String safetyValue = _isLoadingStats
        ? '...'
        : (score == null ? '—' : '${score.toStringAsFixed(0)}%');

    final String safetySubtitle = _isLoadingStats
        ? 'Loading'
        : (score == null
            ? 'No sessions'
            : (score >= 90 ? 'Excellent' : (score >= 70 ? 'Good' : 'Warning')));

    final Color safetyColor = _isLoadingStats
        ? AppTheme.primaryColor
        : (score == null
            ? AppTheme.primaryColor
            : (score >= 90
                ? AppTheme.safeColor
                : (score >= 70
                    ? AppTheme.warningColor
                    : AppTheme.dangerColor)));

    final String sessionsValue =
        _isLoadingStats ? '...' : _sessionsThisMonth.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Stats',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ).animate(delay: 500.ms).fadeIn(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Safety Score',
                value: safetyValue,
                icon: Icons.shield_outlined,
                color: safetyColor,
                subtitle: safetySubtitle,
              ).animate(delay: 600.ms).fadeIn().slideX(begin: -0.2, end: 0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                title: 'Total Sessions',
                value: sessionsValue,
                icon: Icons.timer_outlined,
                color: AppTheme.primaryColor,
                subtitle: 'This month',
              ).animate(delay: 700.ms).fadeIn().slideX(begin: 0.2, end: 0),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: Theme.of(context).textTheme.titleLarge,
        ).animate(delay: 800.ms).fadeIn(),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            FeatureCard(
              title: 'Calibration',
              description: 'Tune for your eyes',
              icon: Icons.tune,
              color: AppTheme.secondaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalibrationScreen()),
                );
              },
            ).animate(delay: 900.ms).fadeIn().scale(),
            FeatureCard(
              title: 'History',
              description: 'View session history',
              icon: Icons.history,
              color: AppTheme.warningColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ).animate(delay: 1000.ms).fadeIn().scale(),
            FeatureCard(
              title: 'Phone Detection',
              description: 'Distraction alerts',
              icon: Icons.phone_android,
              color: AppTheme.accentColor,
              onTap: () {
                _showFeatureInfo(
                  'Phone Detection',
                  'This feature warns you when a phone is detected while driving.',
                );
              },
            ).animate(delay: 1100.ms).fadeIn().scale(),
            FeatureCard(
              title: 'Settings',
              description: 'Customize the app',
              icon: Icons.settings,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ).animate(delay: 1200.ms).fadeIn().scale(),
          ],
        ),
      ],
    );
  }

  Widget _buildSafetyTips() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.warningColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Safety Tips',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem('Take a break every 2 hours on long trips'),
          _buildTipItem('Avoid driving when sleepy'),
          _buildTipItem('Keep your phone away while driving'),
          _buildTipItem('Make sure your seating position is comfortable'),
        ],
      ),
    ).animate(delay: 1300.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppTheme.safeColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureInfo(String title, String description) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
