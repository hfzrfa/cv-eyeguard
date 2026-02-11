import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _controller.forward();

    // Navigate to home after animation
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.15),
                  colorScheme.surface,
                ],
              ),
            ),
          ),

          // Animated circles background
          ..._buildBackgroundCircles(),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with animation
                _buildLogo(),

                const SizedBox(height: 32),

                // App name
                Text(
                  'SafeDrive',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                )
                    .animate(delay: 600.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 8),

                Text(
                  'MONITOR',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryColor,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w300,
                      ),
                )
                    .animate(delay: 800.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 48),

                // Tagline
                Text(
                  'Drowsiness & distraction detection\nfor safer driving',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                )
                    .animate(delay: 1000.ms)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 64),

                // Loading indicator
                _buildLoadingIndicator(),
              ],
            ),
          ),

          // Version at bottom
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'v1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ).animate(delay: 1200.ms).fadeIn(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.remove_red_eye_outlined,
        size: 56,
        color: Colors.white,
      ),
    )
        .animate()
        .scale(
          duration: 800.ms,
          curve: Curves.elasticOut,
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
        )
        .then()
        .shimmer(
          duration: 1500.ms,
          color: Colors.white.withValues(alpha: 0.3),
        );
  }

  List<Widget> _buildBackgroundCircles() {
    return [
      Positioned(
        top: -100,
        right: -100,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
          ),
        ).animate(delay: 200.ms).scale(
              duration: 1200.ms,
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              curve: Curves.easeOut,
            ),
      ),
      Positioned(
        bottom: -150,
        left: -150,
        child: Container(
          width: 400,
          height: 400,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.secondaryColor.withValues(alpha: 0.05),
          ),
        ).animate(delay: 400.ms).scale(
              duration: 1200.ms,
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              curve: Curves.easeOut,
            ),
      ),
    ];
  }

  Widget _buildLoadingIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    ).animate(delay: 1000.ms).fadeIn(duration: 400.ms);
  }
}
