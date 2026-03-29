import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  // Username availability
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  Timer? _usernameDebounce;

  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _particleController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }
    setState(() {
      _isCheckingUsername = false;
      _isUsernameAvailable = true; // Skip server check for now
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept the terms to continue'),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _usernameController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
              ),
            ),
          ),

          // Stars
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              painter: _StarFieldPainter(progress: _particleController.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildGlassForm(),
                        const SizedBox(height: 28),
                        _buildLoginLink(),
                        const SizedBox(height: 40),
                      ],
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.shield_rounded,
              color: Color(0xFF8B5CF6), size: 44),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
                begin: const Offset(0.5, 0.5),
                duration: 500.ms,
                curve: Curves.easeOutBack),

        const SizedBox(height: 20),

        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          ).createShader(bounds),
          child: const Text(
            'Choose Your Path',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 700.ms)
            .slideY(begin: -0.25, duration: 700.ms, curve: Curves.easeOutCubic),

        const SizedBox(height: 8),
        Text(
          'Create your warrior profile',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildGlassForm() {
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
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Username with availability indicator
                _buildNeonTextField(
                  controller: _usernameController,
                  label: 'Username',
                  icon: Icons.person_outline_rounded,
                  suffixIcon: _buildUsernameStatus(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (v.trim().length < 3) return 'Minimum 3 characters';
                    if (_isUsernameAvailable == false) {
                      return 'Username is taken';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Email
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
                const SizedBox(height: 18),

                // Password
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
                const SizedBox(height: 18),

                // Confirm password
                _buildNeonTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Icons.lock_rounded,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Terms checkbox
                _buildTermsCheckbox(),

                const SizedBox(height: 24),

                // Register button
                _buildRegisterButton(),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 350.ms, duration: 800.ms)
        .slideY(begin: 0.12, duration: 800.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildUsernameStatus() {
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF3B82F6),
          ),
        ),
      );
    }
    if (_isUsernameAvailable == true) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.check_circle_rounded,
            color: Color(0xFF22C55E), size: 22),
      );
    }
    if (_isUsernameAvailable == false) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
      );
    }
    return const SizedBox.shrink();
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

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            activeColor: const Color(0xFF3B82F6),
            checkColor: const Color(0xFF111827),
            side: BorderSide(
              color: _acceptedTerms
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'I accept the ',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 13),
              children: [
                TextSpan(
                  text: 'Arena Rules & Terms',
                  style: TextStyle(
                    color: const Color(0xFF3B82F6).withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
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
                    Icon(Icons.rocket_launch_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Begin Your Journey',
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

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already a warrior? ',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
        GestureDetector(
          onTap: () => context.go('/login'),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            ).createShader(bounds),
            child: const Text(
              'Enter the Arena',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms, duration: 600.ms);
  }
}

// ---------------------------------------------------------------------------
// Star field painter (shared pattern)
// ---------------------------------------------------------------------------
class _StarFieldPainter extends CustomPainter {
  final double progress;
  _StarFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(99);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 100; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.2 + rng.nextDouble() * 0.8;
      final y = (baseY + progress * speed * size.height) % size.height;
      final radius = 0.5 + rng.nextDouble() * 1.6;
      final twinkle =
          (sin((progress * 2 * pi) + rng.nextDouble() * 2 * pi) + 1) / 2;

      paint.color = Color.lerp(
        const Color(0xFF8B5CF6),
        const Color(0xFF3B82F6),
        rng.nextDouble(),
      )!
          .withOpacity(0.15 + 0.4 * twinkle);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) => true;
}
