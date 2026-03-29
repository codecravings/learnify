import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Category data model
// ---------------------------------------------------------------------------
class _SubjectCategory {
  const _SubjectCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final IconData icon;
  final Color color;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const _kMinSelections = 3;

const _kCategories = <_SubjectCategory>[
  _SubjectCategory(
    name: 'Artificial Intelligence',
    icon: Icons.psychology_rounded,
    color: Color(0xFF3B82F6),
  ),
  _SubjectCategory(
    name: 'Data Structures & Algo',
    icon: Icons.account_tree_rounded,
    color: Color(0xFF22C55E),
  ),
  _SubjectCategory(
    name: 'Physics',
    icon: Icons.science_rounded,
    color: Color(0xFF8B5CF6),
  ),
  _SubjectCategory(
    name: 'Cybersecurity',
    icon: Icons.security_rounded,
    color: Color(0xFFEF4444),
  ),
  _SubjectCategory(
    name: 'Mathematics',
    icon: Icons.functions_rounded,
    color: Color(0xFFF59E0B),
  ),
  _SubjectCategory(
    name: 'Web Development',
    icon: Icons.web_rounded,
    color: Color(0xFFFF8C00),
  ),
  _SubjectCategory(
    name: 'Machine Learning',
    icon: Icons.model_training_rounded,
    color: Color(0xFF39FF14),
  ),
  _SubjectCategory(
    name: 'Blockchain',
    icon: Icons.link_rounded,
    color: Color(0xFF00BFFF),
  ),
  _SubjectCategory(
    name: 'Chemistry',
    icon: Icons.biotech_rounded,
    color: Color(0xFFFF6B6B),
  ),
  _SubjectCategory(
    name: 'Biology',
    icon: Icons.eco_rounded,
    color: Color(0xFF7CFC00),
  ),
  _SubjectCategory(
    name: 'Electronics',
    icon: Icons.memory_rounded,
    color: Color(0xFFFFAA00),
  ),
  _SubjectCategory(
    name: 'Cloud Computing',
    icon: Icons.cloud_rounded,
    color: Color(0xFF87CEEB),
  ),
];

// ---------------------------------------------------------------------------
// Onboarding Screen
// ---------------------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final Set<String> _selectedInterests = {};
  bool _isSaving = false;

  late AnimationController _particleController;
  late AnimationController _pulseController;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _firstName {
    final displayName = _currentUser?.displayName;
    if (displayName == null || displayName.isEmpty) return 'Explorer';
    return displayName.split(' ').first;
  }

  bool get _canContinue => _selectedInterests.length >= _kMinSelections;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleInterest(String name) {
    setState(() {
      if (_selectedInterests.contains(name)) {
        _selectedInterests.remove(name);
      } else {
        _selectedInterests.add(name);
      }
    });
  }

  Future<void> _handleContinue() async {
    if (!_canContinue || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final uid = _currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'interests': _selectedInterests.toList(),
        'onboardingComplete': true,
      }, SetOptions(merge: true));

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.withAlpha(200),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF111827),
                  Color(0xFF1F2937),
                  Color(0xFF1E293B),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Ambient glow orbs
          _buildAmbientGlows(),

          // Particle star field
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              painter: _OnboardingParticlePainter(
                progress: _particleController.value,
              ),
              size: MediaQuery.of(context).size,
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _buildHeader(),
                ),

                const SizedBox(height: 8),

                // Selection counter
                _buildSelectionCounter(),

                const SizedBox(height: 16),

                // Scrollable grid
                Expanded(
                  child: _buildCategoryGrid(),
                ),

                // Continue button
                _buildContinueButton(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome message
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withAlpha(150),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Welcome, $_firstName',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withAlpha(180),
                letterSpacing: 0.5,
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideX(begin: -0.15, duration: 600.ms, curve: Curves.easeOutCubic),

        const SizedBox(height: 16),

        // Main question
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ).createShader(bounds),
          child: Text(
            'What do you\nwant to master?',
            style: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
              letterSpacing: 1.0,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 800.ms)
            .slideY(
                begin: -0.2, duration: 800.ms, curve: Curves.easeOutCubic),

        const SizedBox(height: 10),

        Text(
          'Choose at least $_kMinSelections topics that excite you',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: Colors.white.withAlpha(100),
            letterSpacing: 0.3,
          ),
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 600.ms),
      ],
    );
  }

  // ─── Selection Counter ──────────────────────────────────────────────────────

  Widget _buildSelectionCounter() {
    final count = _selectedInterests.length;
    final isComplete = count >= _kMinSelections;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseAlpha =
              isComplete ? 255 : (80 + (40 * _pulseController.value)).round();
          return Row(
            children: [
              // Progress dots
              ...List.generate(_kMinSelections, (i) {
                final filled = i < count;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 6),
                  width: filled ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: filled
                        ? const Color(0xFF3B82F6)
                        : Colors.white.withAlpha(40),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFF3B82F6).withAlpha(pulseAlpha),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                );
              }),

              const Spacer(),

              // Counter text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Text(
                  '$count/$_kMinSelections minimum selected',
                  key: ValueKey(count),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isComplete
                        ? const Color(0xFF22C55E)
                        : Colors.white.withAlpha(120),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 600.ms);
  }

  // ─── Category Grid ──────────────────────────────────────────────────────────

  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.15,
        ),
        itemCount: _kCategories.length,
        itemBuilder: (context, index) {
          final category = _kCategories[index];
          final isSelected = _selectedInterests.contains(category.name);

          return _CategoryCard(
            category: category,
            isSelected: isSelected,
            onTap: () => _toggleInterest(category.name),
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 500 + (index * 80)),
                duration: 500.ms,
              )
              .slideY(
                begin: 0.2,
                delay: Duration(milliseconds: 500 + (index * 80)),
                duration: 500.ms,
                curve: Curves.easeOutCubic,
              )
              .scale(
                begin: const Offset(0.9, 0.9),
                delay: Duration(milliseconds: 500 + (index * 80)),
                duration: 500.ms,
                curve: Curves.easeOutCubic,
              );
        },
      ),
    );
  }

  // ─── Continue Button ────────────────────────────────────────────────────────

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final glowAlpha =
              _canContinue ? (60 + (40 * _pulseController.value)).round() : 0;
          return GestureDetector(
            onTap: _canContinue ? _handleContinue : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _canContinue ? 1.0 : 0.35,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _canContinue
                      ? const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withAlpha(20),
                            Colors.white.withAlpha(10),
                          ],
                        ),
                  border: _canContinue
                      ? null
                      : Border.all(
                          color: Colors.white.withAlpha(30),
                          width: 1,
                        ),
                  boxShadow: _canContinue
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF3B82F6).withAlpha(glowAlpha),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color:
                                const Color(0xFF8B5CF6).withAlpha(glowAlpha),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rocket_launch_rounded,
                            color: _canContinue
                                ? Colors.white
                                : Colors.white.withAlpha(80),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Launch Your Journey',
                            style: GoogleFonts.orbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _canContinue
                                  ? Colors.white
                                  : Colors.white.withAlpha(80),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    )
        .animate()
        .fadeIn(delay: 1200.ms, duration: 600.ms)
        .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  // ─── Ambient Glow Orbs ──────────────────────────────────────────────────────

  Widget _buildAmbientGlows() {
    return Stack(
      children: [
        // Top-right cyan orb
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF3B82F6).withAlpha(25),
                  const Color(0xFF3B82F6).withAlpha(0),
                ],
              ),
            ),
          ),
        ),
        // Bottom-left purple orb
        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withAlpha(20),
                  const Color(0xFF8B5CF6).withAlpha(0),
                ],
              ),
            ),
          ),
        ),
        // Center magenta orb (faint)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width * 0.3,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFEF4444).withAlpha(12),
                  const Color(0xFFEF4444).withAlpha(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category Card Widget
// ---------------------------------------------------------------------------
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _SubjectCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? category.color.withAlpha(200)
                : Colors.white.withAlpha(25),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: category.color.withAlpha(50),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: category.color.withAlpha(25),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [
                          category.color.withAlpha(30),
                          category.color.withAlpha(10),
                        ]
                      : [
                          Colors.white.withAlpha(15),
                          Colors.white.withAlpha(5),
                        ],
                ),
              ),
              child: Stack(
                children: [
                  // Background glow circle (top-right)
                  Positioned(
                    top: -15,
                    right: -15,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            category.color
                                .withAlpha(isSelected ? 40 : 12),
                            category.color.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Card content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected
                                ? category.color.withAlpha(35)
                                : Colors.white.withAlpha(12),
                            border: Border.all(
                              color: isSelected
                                  ? category.color.withAlpha(80)
                                  : Colors.white.withAlpha(15),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            category.icon,
                            color: isSelected
                                ? category.color
                                : Colors.white.withAlpha(160),
                            size: 24,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Category name
                        Text(
                          category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withAlpha(180),
                            height: 1.25,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Checkmark overlay (selected)
                  if (isSelected)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              category.color,
                              category.color.withAlpha(180),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: category.color.withAlpha(100),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0, 0),
                            duration: 300.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(duration: 200.ms),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Particle background painter
// ---------------------------------------------------------------------------
class _OnboardingParticlePainter extends CustomPainter {
  _OnboardingParticlePainter({required this.progress});

  final double progress;

  static final _rng = Random(99);
  static final List<_ParticleData> _particles = List.generate(100, (i) {
    return _ParticleData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      radius: 0.4 + _rng.nextDouble() * 1.6,
      speed: 0.15 + _rng.nextDouble() * 0.6,
      colorIndex: _rng.nextInt(5),
      twinklePhase: _rng.nextDouble() * 2 * pi,
    );
  });

  static const _colors = [
    Color(0xFF3B82F6), // cyan
    Color(0xFF8B5CF6), // purple
    Color(0xFFEF4444), // magenta
    Color(0xFFF59E0B), // gold
    Color(0xFF22C55E), // green
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _particles) {
      final baseColor = _colors[p.colorIndex];
      final px = p.x * size.width;
      final py = ((p.y + progress * p.speed) % 1.0) * size.height;

      final twinkle =
          (sin(progress * 2 * pi * 2 + p.twinklePhase) + 1) / 2;
      final alpha = (0.12 + 0.35 * twinkle).clamp(0.0, 1.0);

      paint.color = baseColor.withAlpha((alpha * 255).round());
      canvas.drawCircle(Offset(px, py), p.radius, paint);

      // Glow on larger particles
      if (p.radius > 1.2) {
        paint.color = baseColor.withAlpha((alpha * 50).round());
        canvas.drawCircle(Offset(px, py), p.radius * 2.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingParticlePainter old) => true;
}

class _ParticleData {
  const _ParticleData({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.colorIndex,
    required this.twinklePhase,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final int colorIndex;
  final double twinklePhase;
}
