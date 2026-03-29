import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/daily_challenge_service.dart';
import '../../../core/services/hindsight_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';
import '../../../core/widgets/particle_background.dart';
import '../../courses/data/course_data.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — Shell with glass bottom nav
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.child});
  final Widget child;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _tabs = <_NavTab>[
    _NavTab(icon: Icons.dashboard_rounded, label: 'Home', path: '/home'),
    _NavTab(
        icon: Icons.dynamic_feed_rounded,
        label: 'Feed',
        path: '/home/feed'),
    _NavTab(
        icon: Icons.psychology_rounded,
        label: 'Companion',
        path: '/home/companion'),
    _NavTab(
        icon: Icons.person_rounded, label: 'Profile', path: '/home/profile'),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient.
          Container(decoration: AppTheme.scaffoldDecorationOf(context)),

          // The routed child page.
          widget.child,

          // Glass bottom nav bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 8,
            bottom: bottomPadding + 8,
            left: 4,
            right: 4,
          ),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context)
                ? AppTheme.backgroundPrimary.withAlpha(180)
                : AppTheme.lightBg.withAlpha(220),
            border: Border(
              top: BorderSide(color: AppTheme.glassBorderOf(context), width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final isSelected = i == _currentIndex;
              return _buildNavItem(_tabs[i], isSelected, () => _onTabTap(i));
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavTab tab, bool isSelected, VoidCallback onTap) {
    final dark = AppTheme.isDark(context);
    final color = isSelected
        ? (AppTheme.accentCyanOf(context))
        : AppTheme.textTertiaryOf(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with neon glow when selected.
            Container(
              decoration: isSelected
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withAlpha(90),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Icon(tab.icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final String label;
  final String path;
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeDashboard — Story-learning-first home screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  final _topicCtrl = TextEditingController();

  // AI recommendation from Hindsight
  String? _aiRecommendation;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure profile exists in Firestore (repairs if missing)
    AuthService().ensureProfileExists();
    _loadUserData();
    _loadAIRecommendation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _topicCtrl.dispose();
    super.dispose();
  }

  /// Reload data every time the user returns to this screen
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserData();
    }
  }

  /// Reload when navigating back to this tab
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when tab becomes visible again
    if (!_loading && _userData != null) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Try loading cached data first for instant UI
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('user_data_${user.uid}');
      if (cached != null && _userData == null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userData = data;
            _loading = false;
          });
        }
      }
    } catch (_) {}

    // Then fetch fresh data from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        final firestoreData = doc.data() ?? <String, dynamic>{};

        // ── MERGE: preserve local studiedTopics/stats if Firestore is missing them ──
        final prefs = await SharedPreferences.getInstance();
        final cachedStr = prefs.getString('user_data_${user.uid}');
        final localData = cachedStr != null
            ? (jsonDecode(cachedStr) as Map<String, dynamic>)
            : <String, dynamic>{};

        // Merge studiedTopics: local wins for topics Firestore doesn't have
        final localTopics = (localData['studiedTopics'] as Map<String, dynamic>?) ?? {};
        final firestoreTopics = (firestoreData['studiedTopics'] as Map?) ?? {};
        final mergedTopics = <String, dynamic>{...localTopics};
        for (final entry in firestoreTopics.entries) {
          final key = entry.key as String;
          final val = entry.value;
          if (val is Map) {
            final t = Map<String, dynamic>.from(val);
            if (t['lastStudied'] is Timestamp) {
              t['lastStudied'] =
                  (t['lastStudied'] as Timestamp).toDate().toIso8601String();
            }
            mergedTopics[key] = t;
          }
        }
        firestoreData['studiedTopics'] = mergedTopics;

        // Use higher value for xp, totalQuizzes, streak
        final localXp = (localData['xp'] as num?)?.toInt() ?? 0;
        final firestoreXp = (firestoreData['xp'] as num?)?.toInt() ?? 0;
        firestoreData['xp'] = localXp > firestoreXp ? localXp : firestoreXp;

        final localQuizzes = (localData['totalQuizzes'] as num?)?.toInt() ?? 0;
        final firestoreQuizzes = (firestoreData['totalQuizzes'] as num?)?.toInt() ?? 0;
        firestoreData['totalQuizzes'] = localQuizzes > firestoreQuizzes ? localQuizzes : firestoreQuizzes;

        final localStreak = (localData['currentStreak'] as num?)?.toInt() ?? 0;
        final firestoreStreak = (firestoreData['currentStreak'] as num?)?.toInt() ?? 0;
        firestoreData['currentStreak'] = localStreak > firestoreStreak ? localStreak : firestoreStreak;

        setState(() {
          _userData = firestoreData;
          _loading = false;
        });

        // Cache merged data
        try {
          final cacheable = Map<String, dynamic>.from(firestoreData);
          // Convert any remaining Timestamps
          if (cacheable['lastActive'] is Timestamp) {
            cacheable['lastActive'] =
                (cacheable['lastActive'] as Timestamp).toDate().toIso8601String();
          }
          await prefs.setString(
              'user_data_${user.uid}', jsonEncode(cacheable));
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAIRecommendation() async {
    if (!mounted) return;
    setState(() => _aiLoading = true);
    try {
      final insight = await HindsightService.instance
          .reflect(
            query:
                'In one short sentence, suggest what this student should study next '
                'based on their learning history. If no history exists, suggest an '
                'interesting topic to start with. Be encouraging and specific.',
            budget: 'low',
            maxTokens: 256,
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _aiRecommendation = insight;
          _aiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiRecommendation =
              'Try studying a topic you\'re curious about — I\'ll remember your progress!';
          _aiLoading = false;
        });
      }
    }
  }

  String get _displayName {
    return _userData?['displayName'] as String? ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'Learner';
  }

  int get _xp => (_userData?['xp'] as num?)?.toInt() ?? 0;
  int get _currentStreak => (_userData?['currentStreak'] as num?)?.toInt() ?? 0;

  /// Topics the user has studied (saved to Firestore after each quiz).
  List<Map<String, dynamic>> get _studiedTopics {
    final raw = _userData?['studiedTopics'];
    if (raw is! Map) return [];
    final topics = <Map<String, dynamic>>[];
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        topics.add(Map<String, dynamic>.from(entry.value as Map));
      }
    }
    // Sort by last studied (most recent first)
    // Handles both Timestamp (Firestore) and String (cached)
    topics.sort((a, b) {
      final aTime = a['lastStudied'];
      final bTime = b['lastStudied'];
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      if (aTime is String && bTime is String) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });
    return topics;
  }

  Map<String, dynamic> get _courseProgress {
    final raw = _userData?['courseProgress'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }




  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
        ),
      );
    }

    final dark = AppTheme.isDark(context);
    return Stack(
      children: [
        if (dark)
          const ParticleBackground(
            particleCount: 40,
            particleColor: AppTheme.accentPurple,
            maxRadius: 1.2,
          ),
        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadUserData,
            color: AppTheme.accentCyanOf(context),
            backgroundColor: AppTheme.surfaceDarkOf(context),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
              children: [
                // ── Welcome ──
                _buildWelcomeHeader()
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideX(begin: -0.05, duration: 600.ms),

                const SizedBox(height: 16),

                // ── Streak + League Row ──
                _buildStreakLeagueRow()
                    .animate()
                    .fadeIn(delay: 80.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 16),

                // ── Daily Challenge ──
                _buildDailyChallengeCard()
                    .animate()
                    .fadeIn(delay: 90.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 16),

                // ── Battle Arena ──
                _buildBattleArenaCard()
                    .animate()
                    .fadeIn(delay: 95.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 16),

                // ── Peer Help (Ask & Answer) ──
                _buildPeerHelpCard()
                    .animate()
                    .fadeIn(delay: 97.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 20),

                // ── Hero: Start Learning (THE main CTA) ──
                _buildHeroCard()
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 700.ms)
                    .slideY(begin: 0.06, duration: 700.ms),

                const SizedBox(height: 20),

                // ── Learn Anything ──
                _buildLearnAnythingCard()
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 20),

                // ── Explore Subjects ──
                _buildSubjectsSection()
                    .animate()
                    .fadeIn(delay: 160.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 16),

                // ── Concept Map (Knowledge Graph) ──
                _buildConceptMapCard()
                    .animate()
                    .fadeIn(delay: 175.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 16),

                // ── Skill Tree ──
                _buildSkillTreeCard()
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 16),

                // ── Coding Arena ──
                _buildCodingArenaCard()
                    .animate()
                    .fadeIn(delay: 185.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                const SizedBox(height: 16),

                // ── AI Recommendation (Hindsight Memory) ──
                _buildAIRecommendationCard()
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 600.ms)
                    .slideY(begin: 0.04, duration: 600.ms),

                // ── Your Topics (from Hindsight + Firestore) ──
                const SizedBox(height: 20),
                _buildStudiedTopicsSection()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 600.ms),

                const SizedBox(height: 24),

                // ── Streak ──
                _buildStreakCard()
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Welcome Header ────────────────────────────────────────────────────

  Widget _buildWelcomeHeader() {
    final dark = AppTheme.isDark(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey, $_displayName',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradientOf(context).createShader(bounds),
                child: Text(
                  'What do you want\nto learn today?',
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search + Theme toggle + Stats
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => context.push('/search'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (dark ? Colors.white : Colors.black).withAlpha(15),
                      border: Border.all(
                        color: (AppTheme.accentCyanOf(context)).withAlpha(60),
                      ),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: AppTheme.accentCyanOf(context),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ThemeProvider.instance.toggleTheme(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (dark ? Colors.white : Colors.black).withAlpha(15),
                      border: Border.all(
                        color: (AppTheme.accentCyanOf(context)).withAlpha(60),
                      ),
                    ),
                    child: Icon(
                      dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: dark ? AppTheme.accentGold : AppTheme.accentPurple,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildStatChip(
              icon: Icons.bolt_rounded,
              label: '$_xp XP',
              color: AppTheme.accentGold,
            ),
            const SizedBox(height: 6),
            _buildStatChip(
              icon: Icons.local_fire_department_rounded,
              label: '$_currentStreak day',
              color: AppTheme.accentOrange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Card: 2 learning styles ──────────────────────────────────────

  Widget _buildHeroCard() {
    return GlassContainer(
      borderColor: AppTheme.accentPurple.withAlpha(60),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 2 style cards side by side
          Row(
            children: [
              Expanded(
                child: _buildStylePill(
                  'Practical\nApproach',
                  Icons.build_circle,
                  AppTheme.accentGreen,
                  () => context.push('/courses'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStylePill(
                  'Movie /\nTV Serial',
                  Icons.live_tv,
                  AppTheme.accentCyan,
                  () => context.push('/courses'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Main CTA
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: 'BROWSE COURSES',
              icon: Icons.play_arrow_rounded,
              colors: const [AppTheme.accentPurple, AppTheme.accentCyan],
              height: 46,
              fontSize: 12,
              onTap: () => context.push('/courses'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStylePill(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withAlpha(18),
          border: Border.all(color: color.withAlpha(60), width: 0.8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Explore Subjects Section ──────────────────────────────────────

  Widget _buildSubjectsSection() {
    final courses = CourseData.allCourses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, color: AppTheme.accentCyan, size: 18),
            const SizedBox(width: 8),
            Text(
              'Explore Subjects',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentCyan,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/courses'),
              child: Text(
                'See All',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: AppTheme.accentCyan.withAlpha(180),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final course = courses[index];
              return _buildSubjectCard(course);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(CourseSubject course) {
    final lessonCount = course.chapters.fold<int>(
      0, (total, ch) => total + ch.lessons.length,
    );
    final progress =
        (_courseProgress[course.id] as num?)?.toDouble() ?? 0.0;
    final color = course.accentColor;

    return GestureDetector(
      onTap: () {
        if (course.chapters.isNotEmpty &&
            course.chapters.first.lessons.isNotEmpty) {
          final chapter = course.chapters.first;
          final lesson = chapter.lessons.first;
          context.push('/lesson', extra: {
            'subjectId': course.id,
            'chapterId': chapter.id,
            'lessonId': lesson.id,
          });
        } else {
          // No static chapters — launch AI-generated lesson for this subject
          context.push('/lesson', extra: {
            'customTopic': course.name,
          });
        }
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withAlpha(15),
          border: Border.all(color: color.withAlpha(50), width: 0.8),
          boxShadow: [
            BoxShadow(color: color.withAlpha(15), blurRadius: 12),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(30),
                  ),
                  child: Icon(
                    course.id == 'physics'
                        ? Icons.blur_circular
                        : course.id == 'math'
                            ? Icons.functions
                            : Icons.school,
                    color: color,
                    size: 18,
                  ),
                ),
                const Spacer(),
                if (course.chapters.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'AI',
                      style: GoogleFonts.orbitron(
                        fontSize: 7,
                        color: AppTheme.accentCyan,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              course.name,
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${course.chapters.length} chapters  ·  $lessonCount lessons',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                color: AppTheme.textTertiary,
              ),
            ),
            const Spacer(),
            if (course.chapters.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  backgroundColor: Colors.white.withAlpha(10),
                  color: color,
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${(progress * 100).round()}% complete',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 8,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Concept Map Card ───────────────────────────────────────────────

  Widget _buildConceptMapCard() {
    return GestureDetector(
      onTap: () => context.push('/concept-map'),
      child: GlassContainer(
        borderColor: AppTheme.accentPurple.withAlpha(50),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentCyan.withAlpha(40),
                    AppTheme.accentPurple.withAlpha(40),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.accentPurple.withAlpha(60),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.hub,
                color: AppTheme.accentPurple,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Concept Map',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentPurple,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Visualize how concepts connect across subjects',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.accentPurple.withAlpha(120),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── Learn Anything ──────────────────────────────────────────────────

  Widget _buildLearnAnythingCard() {
    return GlassContainer(
      borderColor: AppTheme.accentCyan.withAlpha(50),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Learn Anything',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type any topic and we\'ll create a story for you',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _topicCtrl,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Photosynthesis, WW2, Blockchain...',
                    hintStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(8),
                    prefixIcon: Icon(Icons.search,
                        color: AppTheme.accentCyan.withAlpha(120), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.accentCyan.withAlpha(50)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.accentCyan.withAlpha(50)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _launchCustomTopic(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _launchCustomTopic,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.accentCyan],
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _launchCustomTopic() {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    context.push('/topic-explorer', extra: {'topic': topic});
    _topicCtrl.clear();
  }

  // ── Studied Topics (Saved from Hindsight) ──────────────────────────────

  Widget _buildStudiedTopicsSection() {
    final topics = _studiedTopics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.push('/topics'),
          child: Row(
            children: [
              Icon(Icons.psychology_rounded,
                  color: AppTheme.accentPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Topics',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.accentPurple.withAlpha(120), size: 14),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          topics.isEmpty
              ? 'Topics you study will appear here'
              : '${topics.length} topic${topics.length == 1 ? '' : 's'} studied',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        if (topics.isEmpty)
          GlassContainer(
            borderColor: AppTheme.accentPurple.withAlpha(40),
            padding: const EdgeInsets.all(20),
            onTap: () => context.push('/topics'),
            child: Row(
              children: [
                Icon(Icons.school_rounded,
                    color: AppTheme.accentPurple.withAlpha(100), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No topics yet',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Use "Learn Anything" above to start studying — your history will show here!',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: () => context.push('/topics'),
            child: SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  return _buildTopicCard(topics[i]);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final name = topic['name'] as String? ?? 'Topic';
    final level = topic['level'] as String? ?? 'basics';
    final accuracy = (topic['accuracy'] as num?)?.toInt() ?? 0;
    final stars = (topic['stars'] as num?)?.toInt() ?? 0;
    final lastStudied = topic['lastStudied'];

    String dateStr = '';
    DateTime? studiedDate;
    if (lastStudied is Timestamp) {
      studiedDate = lastStudied.toDate();
    } else if (lastStudied is String) {
      studiedDate = DateTime.tryParse(lastStudied);
    }
    if (studiedDate != null) {
      final diff = DateTime.now().difference(studiedDate);
      if (diff.inDays == 0) {
        dateStr = 'Today';
      } else if (diff.inDays == 1) {
        dateStr = 'Yesterday';
      } else if (diff.inDays < 7) {
        dateStr = '${diff.inDays}d ago';
      }
    }

    final color = switch (level) {
      'intermediate' => AppTheme.accentCyan,
      'advanced' => AppTheme.accentPurple,
      _ => AppTheme.accentGreen,
    };

    final nextLevel = switch (level) {
      'basics' => accuracy >= 70 ? 'intermediate' : 'basics',
      'intermediate' => accuracy >= 70 ? 'advanced' : 'intermediate',
      _ => 'advanced',
    };

    return GlassContainer(
      width: 160,
      borderColor: color.withAlpha(50),
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/lesson', extra: {
        'customTopic': name,
        'level': nextLevel,
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            name,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (dateStr.isNotEmpty)
            Text(
              dateStr,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                color: AppTheme.textTertiary,
              ),
            ),
          const Spacer(),
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: color.withAlpha(20),
              border: Border.all(color: color.withAlpha(50), width: 0.5),
            ),
            child: Text(
              level.toUpperCase(),
              style: GoogleFonts.orbitron(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Stars + accuracy
          Row(
            children: [
              ...List.generate(3, (i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 14,
                color: i < stars ? AppTheme.accentGold : AppTheme.textTertiary,
              )),
              const Spacer(),
              Text(
                '$accuracy%',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accuracy >= 70
                      ? AppTheme.accentGreen
                      : AppTheme.accentOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI Recommendation (Hindsight Memory) ──────────────────────────────

  Widget _buildAIRecommendationCard() {
    return GlassContainer(
      borderColor: AppTheme.accentPurple.withAlpha(50),
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/home/companion'),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [AppTheme.accentCyan, AppTheme.accentPurple],
              ),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI RECOMMENDS',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentPurple,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: AppTheme.accentCyan.withAlpha(20),
                        border: Border.all(
                            color: AppTheme.accentCyan.withAlpha(50),
                            width: 0.5),
                      ),
                      child: Text(
                        'MEMORY',
                        style: GoogleFonts.orbitron(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCyan,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_aiLoading)
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                else
                  Text(
                    _aiRecommendation ?? 'Tap to get personalized study advice',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: AppTheme.accentPurple.withAlpha(100), size: 14),
        ],
      ),
    );
  }

  // ── Streak + League Row ──────────────────────────────────────────────

  Widget _buildStreakLeagueRow() {
    // Determine current league
    final leagues = AppConstants.leagues;
    League currentLeague = leagues.first;
    League? nextLeague;
    for (int i = leagues.length - 1; i >= 0; i--) {
      if (_xp >= leagues[i].minXP) {
        currentLeague = leagues[i];
        nextLeague = i + 1 < leagues.length ? leagues[i + 1] : null;
        break;
      }
    }
    final progress = nextLeague != null
        ? ((_xp - currentLeague.minXP) /
                (nextLeague.minXP - currentLeague.minXP))
            .clamp(0.0, 1.0)
        : 1.0;

    final dark = AppTheme.isDark(context);

    return Row(
      children: [
        // Streak chip
        Expanded(
          child: GlassContainer(
            borderColor: AppTheme.accentOrange.withAlpha(50),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: AppTheme.accentOrange, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_currentStreak day streak',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentStreak > 0 ? 'Keep going!' : 'Start today!',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          color: AppTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // League chip
        Expanded(
          child: GlassContainer(
            borderColor: AppTheme.accentPurple.withAlpha(50),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.shield_rounded,
                    color: AppTheme.accentPurple, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentLeague.name,
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor:
                              dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15),
                          color: AppTheme.accentPurple,
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Battle Arena Card ────────────────────────────────────────────

  Widget _buildSkillTreeCard() {
    final accent = AppTheme.accentGreenOf(context);
    return GestureDetector(
      onTap: () => context.push('/skill-tree'),
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        borderColor: accent.withAlpha(40),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent.withAlpha(40), accent.withAlpha(15)],
                ),
                border: Border.all(color: accent.withAlpha(60)),
              ),
              child: Icon(Icons.account_tree_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Skill Tree',
                    style: GoogleFonts.orbitron(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Visualize your learning journey & mastery',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent.withAlpha(150), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCodingArenaCard() {
    const accent = Color(0xFF00FF88);
    return GestureDetector(
      onTap: () => context.push('/coding-arena'),
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        borderColor: accent.withAlpha(40),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent.withAlpha(40), accent.withAlpha(15)],
                ),
                border: Border.all(color: accent.withAlpha(60)),
              ),
              child: const Icon(Icons.terminal_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coding Arena',
                    style: GoogleFonts.orbitron(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Solve Python challenges • No copy-paste',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent.withAlpha(150), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerHelpCard() {
    final accent = AppTheme.accentPurpleOf(context);
    return GestureDetector(
      onTap: () => context.push('/peer-help'),
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        borderColor: accent.withAlpha(40),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent.withAlpha(40), accent.withAlpha(15)],
                ),
                border: Border.all(color: accent.withAlpha(60)),
              ),
              child: Icon(Icons.people_alt_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask & Answer',
                    style: GoogleFonts.orbitron(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Help peers, earn XP — ask doubts or share knowledge',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent.withAlpha(150), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleArenaCard() {
    return GestureDetector(
      onTap: () => context.push('/battle/lobby'),
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        borderColor: AppTheme.accentOrange.withAlpha(40),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentOrange.withAlpha(40),
                    AppTheme.accentOrange.withAlpha(15),
                  ],
                ),
                border: Border.all(
                    color: AppTheme.accentOrange.withAlpha(60)),
              ),
              child: const Icon(Icons.flash_on_rounded,
                  color: AppTheme.accentOrange, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Battle Arena',
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Challenge others in real-time knowledge battles',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.accentOrange.withAlpha(150), size: 24),
          ],
        ),
      ),
    );
  }

  // ── Daily Challenge Card ────────────────────────────────────────────

  Widget _buildDailyChallengeCard() {
    final challenge = DailyChallengeService.instance.getTodayChallenge();
    final diffColor = switch (challenge.difficulty) {
      'Easy' => AppTheme.accentGreen,
      'Medium' => AppTheme.accentCyan,
      'Hard' => AppTheme.accentOrange,
      'Expert' => AppTheme.accentPurple,
      _ => AppTheme.accentCyan,
    };

    return GlassContainer(
      borderColor: diffColor.withAlpha(50),
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/lesson', extra: {
        'customTopic': challenge.topicName,
      }),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: diffColor.withAlpha(25),
              border: Border.all(color: diffColor.withAlpha(60), width: 0.8),
            ),
            child: Icon(Icons.today_rounded, color: diffColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'DAILY CHALLENGE',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: diffColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: diffColor.withAlpha(20),
                        border: Border.all(
                            color: diffColor.withAlpha(50), width: 0.5),
                      ),
                      child: Text(
                        challenge.difficulty.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: diffColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  challenge.topicName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '+${challenge.xpReward}',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentGold,
                ),
              ),
              Text(
                'XP',
                style: GoogleFonts.orbitron(
                  fontSize: 8,
                  color: AppTheme.accentGold.withAlpha(180),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Streak Card ────────────────────────────────────────────────────────

  Widget _buildStreakCard() {
    return GlassContainer(
      borderColor: AppTheme.accentOrange.withAlpha(40),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: AppTheme.accentOrange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_currentStreak Day Streak',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentStreak > 0 ? 'Keep it going!' : 'Complete a lesson to start!',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$_xp XP',
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentGold,
            ),
          ),
        ],
      ),
    );
  }
}
