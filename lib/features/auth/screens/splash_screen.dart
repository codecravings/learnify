import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/particle_background.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _letterController;
  late AnimationController _taglineController;
  late AnimationController _loadingController;

  static const String _logoText = 'Learnify';
  static const String _tagline = 'Learn. Play. Grow.';

  @override
  void initState() {
    super.initState();

    _letterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Sequence: letters -> tagline -> loader -> navigate.
    _letterController.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _taglineController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _loadingController.forward();
    });
    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    // Ensure profile exists in Firestore on every app launch
    try {
      await AuthService().ensureProfileExists();
    } catch (_) {}

    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _letterController.dispose();
    _taglineController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Atmospheric particles.
          const ParticleBackground(
            particleCount: 60,
            particleColor: AppTheme.accentCyan,
            maxRadius: 1.5,
          ),

          // Centered content.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated Logo Letters ──
                AnimatedBuilder(
                  animation: _letterController,
                  builder: (context, _) => _buildAnimatedLogo(),
                ),

                const SizedBox(height: 20),

                // ── Tagline ──
                FadeTransition(
                  opacity: _taglineController,
                  child: Text(
                    _tagline,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Loading indicator ──
                FadeTransition(
                  opacity: _loadingController,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.accentCyan.withAlpha(180),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_logoText.length, (index) {
        // Stagger each letter.
        final start = index / _logoText.length;
        final end = (index + 1) / _logoText.length;
        final letterProgress = Interval(start, end, curve: Curves.easeOut)
            .transform(_letterController.value);

        return Opacity(
          opacity: letterProgress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - letterProgress)),
            child: Text(
              _logoText[index],
              style: GoogleFonts.orbitron(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: AppTheme.accentCyan.withAlpha(
                      (200 * letterProgress).round(),
                    ),
                    blurRadius: 20 * letterProgress,
                  ),
                  Shadow(
                    color: AppTheme.accentCyan.withAlpha(
                      (100 * letterProgress).round(),
                    ),
                    blurRadius: 40 * letterProgress,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
