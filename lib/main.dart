import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  // System UI overlay style is set dynamically in MaterialApp.builder
  
  // Enable wakelock to prevent screen from sleeping during monitoring
  await WakelockPlus.enable();
  
  runApp(
    const ProviderScope(
      child: DrowsinessMonitorApp(),
    ),
  );
}

class DrowsinessMonitorApp extends StatelessWidget {
  const DrowsinessMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final mode = ref.watch(themeModeProvider);
        return MaterialApp(
          title: 'Eye Guardian',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final isDark = brightness == Brightness.dark;

            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarColor:
                    isDark ? AppTheme.backgroundColor : Theme.of(context).colorScheme.surface,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
              ),
            );

            return child ?? const SizedBox.shrink();
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
