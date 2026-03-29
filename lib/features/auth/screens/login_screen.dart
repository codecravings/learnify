import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithGoogle();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- Background gradient ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
              ),
            ),
          ),

          // --- Particle / star field ---
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              painter: _StarFieldPainter(
                progress: _particleController.value,
              ),
              size: MediaQuery.of(context).size,
            ),
          ),

          // --- Content ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // --- Logo / Title ---
                    _buildLogo(),

                    const SizedBox(height: 12),

                    Text(
                      'Learn like a story, remembered forever.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 800.ms),

                    const SizedBox(height: 48),

                    // --- Glass card form ---
                    _buildGlassCard(),

                    const SizedBox(height: 24),

                    // --- Google sign-in ---
                    _buildGoogleButton(),

                    const SizedBox(height: 32),

                    // --- Register link ---
                    _buildRegisterLink(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Neon icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt_rounded,
            size: 52,
            color: Color(0xFF3B82F6),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.easeOutBack),

        const SizedBox(height: 20),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ).createShader(bounds),
          child: const Text(
            'Learnify',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 800.ms)
            .slideY(begin: -0.3, duration: 800.ms, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.05),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildNeonTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildNeonTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: const Color(0xFF3B82F6).withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildLoginButton(),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 800.ms)
        .slideY(begin: 0.15, duration: 800.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildNeonTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF3B82F6),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_esports_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Enter the Arena',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: const Text('G',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            label: const Text(
              'Continue with Google',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.15)),
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 600.ms)
        .slideY(begin: 0.15, duration: 600.ms);
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New warrior? ',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
        GestureDetector(
          onTap: () => context.go('/register'),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            ).createShader(bounds),
            child: const Text(
              'Join the Battle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 900.ms, duration: 600.ms);
  }
}

// ---------------------------------------------------------------------------
// Starfield background painter
// ---------------------------------------------------------------------------
class _StarFieldPainter extends CustomPainter {
  final double progress;

  _StarFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.2 + rng.nextDouble() * 0.8;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.5 + rng.nextDouble() * 1.8;
      final twinkle =
          (sin((progress * 2 * pi) + rng.nextDouble() * 2 * pi) + 1) / 2;

      paint.color = Color.lerp(
        const Color(0xFF3B82F6),
        const Color(0xFF8B5CF6),
        rng.nextDouble(),
      )!
          .withOpacity(0.15 + 0.45 * twinkle);

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Glow for larger stars
      if (radius > 1.4) {
        paint.color = paint.color.withOpacity(0.08);
        canvas.drawCircle(Offset(x, y), radius * 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) => true;
}
