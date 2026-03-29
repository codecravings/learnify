import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load saved theme preference before building the widget tree.
  await ThemeProvider.instance.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: LearnifyApp()));
}

class LearnifyApp extends ConsumerStatefulWidget {
  const LearnifyApp({super.key});

  @override
  ConsumerState<LearnifyApp> createState() => _LearnifyAppState();
}

class _LearnifyAppState extends ConsumerState<LearnifyApp> {
  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
    // Update system chrome to match theme.
    final isDark = ThemeProvider.instance.themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDark ? AppTheme.backgroundPrimary : AppTheme.lightBg,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ThemeProvider.instance.themeMode;

    // Set initial system chrome.
    final isDark = themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDark ? AppTheme.backgroundPrimary : AppTheme.lightBg,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp.router(
      title: 'Learnify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
