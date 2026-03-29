import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';

// ---------------------------------------------------------------------------
// Profile Screen — Fully theme-aware, real data from Firestore
// ---------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading && _userData != null) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load local cache first for instant UI
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('user_data_${user.uid}');
      if (cached != null && _userData == null) {
        if (mounted) {
          setState(() {
            _userData = jsonDecode(cached) as Map<String, dynamic>;
            _loading = false;
          });
        }
      }
    } catch (_) {}

    // Then merge with Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        final firestoreData = doc.data() ?? <String, dynamic>{};

        final prefs = await SharedPreferences.getInstance();
        final cachedStr = prefs.getString('user_data_${user.uid}');
        final localData = cachedStr != null
            ? (jsonDecode(cachedStr) as Map<String, dynamic>)
            : <String, dynamic>{};

        // Merge studiedTopics
        final localTopics =
            (localData['studiedTopics'] as Map<String, dynamic>?) ?? {};
        final firestoreTopics =
            (firestoreData['studiedTopics'] as Map?) ?? {};
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

        // Use higher values
        final localXp = (localData['xp'] as num?)?.toInt() ?? 0;
        final firestoreXp = (firestoreData['xp'] as num?)?.toInt() ?? 0;
        firestoreData['xp'] = localXp > firestoreXp ? localXp : firestoreXp;

        final localQuizzes =
            (localData['totalQuizzes'] as num?)?.toInt() ?? 0;
        final firestoreQuizzes =
            (firestoreData['totalQuizzes'] as num?)?.toInt() ?? 0;
        firestoreData['totalQuizzes'] =
            localQuizzes > firestoreQuizzes ? localQuizzes : firestoreQuizzes;

        final localStreak =
            (localData['currentStreak'] as num?)?.toInt() ?? 0;
        final firestoreStreak =
            (firestoreData['currentStreak'] as num?)?.toInt() ?? 0;
        firestoreData['currentStreak'] =
            localStreak > firestoreStreak ? localStreak : firestoreStreak;

        setState(() {
          _userData = firestoreData;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  // --------------- Real data helpers ---------------
  String get _username =>
      _userData?['username'] ??
      _userData?['displayName'] ??
      FirebaseAuth.instance.currentUser?.displayName ??
      'Explorer';

  String? get _avatarUrl => FirebaseAuth.instance.currentUser?.photoURL;

  int get _xp => (_userData?['xp'] as num?)?.toInt() ?? 0;

  int get _streak => (_userData?['currentStreak'] as num?)?.toInt() ?? 0;

  League get _currentLeague {
    final leagues = AppConstants.leagues;
    for (int i = leagues.length - 1; i >= 0; i--) {
      if (_xp >= leagues[i].minXP) return leagues[i];
    }
    return leagues.first;
  }

  League? get _nextLeague {
    final leagues = AppConstants.leagues;
    for (int i = leagues.length - 1; i >= 0; i--) {
      if (_xp >= leagues[i].minXP) {
        return i + 1 < leagues.length ? leagues[i + 1] : null;
      }
    }
    return leagues.length > 1 ? leagues[1] : null;
  }

  double get _leagueProgress {
    final next = _nextLeague;
    if (next == null) return 1.0;
    final current = _currentLeague;
    return ((_xp - current.minXP) / (next.minXP - current.minXP))
        .clamp(0.0, 1.0);
  }

  List<String> get _interests {
    final raw = _userData?['interests'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  List<Map<String, dynamic>> get _studiedTopics {
    final raw = _userData?['studiedTopics'];
    if (raw is! Map) return [];
    final topics = <Map<String, dynamic>>[];
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        topics.add(Map<String, dynamic>.from(entry.value as Map));
      }
    }
    topics.sort((a, b) {
      final aTime = a['lastStudied'];
      final bTime = b['lastStudied'];
      if (aTime is String && bTime is String) return bTime.compareTo(aTime);
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });
    return topics;
  }

  int get _totalQuizzes =>
      (_userData?['totalQuizzes'] as num?)?.toInt() ?? _studiedTopics.length;

  int get _avgAccuracy {
    if (_studiedTopics.isEmpty) return 0;
    int sum = 0;
    for (final t in _studiedTopics) {
      sum += (t['accuracy'] as num?)?.toInt() ?? 0;
    }
    return (sum / _studiedTopics.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);

    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.scaffoldDecorationOf(context),
          child: Center(
            child: CircularProgressIndicator(
              color: AppTheme.accentCyanOf(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.scaffoldDecorationOf(context)),
          if (dark)
            const ParticleBackground(
              particleCount: 30,
              particleColor: AppTheme.accentCyan,
              maxRadius: 1.0,
            ),
          SafeArea(
            bottom: false,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(child: _buildProfileHeader()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    tabBar: _buildTabBar(),
                    dark: dark,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildAchievementsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // HEADER — Avatar, name, league, XP, streak, settings
  // =======================================================================
  Widget _buildProfileHeader() {
    final dark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          // Top row: settings + theme toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => ThemeProvider.instance.toggleTheme(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (dark ? Colors.white : Colors.black).withAlpha(12),
                    border: Border.all(
                      color: (AppTheme.accentCyanOf(context))
                          .withAlpha(50),
                    ),
                  ),
                  child: Icon(
                    dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: dark ? AppTheme.accentGold : AppTheme.accentPurple,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showSettingsBottomSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (dark ? Colors.white : Colors.black).withAlpha(12),
                    border: Border.all(
                      color: AppTheme.glassBorderOf(context),
                    ),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: AppTheme.textSecondaryOf(context),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Avatar with glow ring
          _buildAvatar(radius: 40)
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(
                  begin: const Offset(0.7, 0.7),
                  duration: 600.ms,
                  curve: Curves.easeOutBack),

          const SizedBox(height: 12),

          // Username
          Text(
            _username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: AppTheme.textPrimaryOf(context),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

          // Bio
          if ((_userData?['bio'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              _userData!['bio'] as String,
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textTertiaryOf(context),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
          ],

          const SizedBox(height: 16),

          // League card
          _buildLeagueCard()
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideY(begin: 0.08, duration: 500.ms),

          const SizedBox(height: 12),

          // Stats row: XP, Streak, Quizzes, Accuracy
          _buildStatsRow()
              .animate()
              .fadeIn(delay: 350.ms, duration: 500.ms),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLeagueCard() {
    final dark = AppTheme.isDark(context);
    final league = _currentLeague;
    final next = _nextLeague;

    return GlassContainer(
      borderColor: AppTheme.accentPurple.withAlpha(50),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // League icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPurple.withAlpha(50),
                  AppTheme.accentCyan.withAlpha(50),
                ],
              ),
              border: Border.all(
                color: AppTheme.accentPurple.withAlpha(80),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppTheme.accentPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      league.name,
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentPurple,
                        letterSpacing: 1,
                      ),
                    ),
                    if (next != null) ...[
                      const Spacer(),
                      Text(
                        '${(_leagueProgress * 100).round()}%',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _leagueProgress,
                    backgroundColor: dark
                        ? Colors.white.withAlpha(15)
                        : Colors.black.withAlpha(15),
                    color: AppTheme.accentPurple,
                    minHeight: 4,
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${next.minXP - _xp} XP to ${next.name}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatChip(Icons.bolt_rounded, '$_xp XP', AppTheme.accentGold),
        const SizedBox(width: 8),
        _buildStatChip(Icons.local_fire_department_rounded,
            '$_streak Day', AppTheme.accentOrange),
        const SizedBox(width: 8),
        _buildStatChip(
            Icons.quiz_rounded, '$_totalQuizzes Quiz', AppTheme.accentCyan),
        const SizedBox(width: 8),
        _buildStatChip(
            Icons.gps_fixed_rounded, '$_avgAccuracy%', AppTheme.accentGreen),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Expanded(
      child: GlassContainer(
        borderColor: color.withAlpha(40),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({double radius = 42}) {
    final dark = AppTheme.isDark(context);
    final glowColor = AppTheme.accentCyanOf(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: glowColor.withAlpha(dark ? 120 : 60),
              blurRadius: 24,
              spreadRadius: 4),
        ],
        border: Border.all(color: glowColor, width: 3),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor:
            dark ? AppTheme.surfaceDark : AppTheme.lightSurface,
        backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
            ? NetworkImage(_avatarUrl!)
            : null,
        child: (_avatarUrl == null || _avatarUrl!.isEmpty)
            ? Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: radius * 0.78,
                  fontWeight: FontWeight.w900,
                  color: glowColor,
                ),
              )
            : null,
      ),
    );
  }

  // =======================================================================
  // TAB BAR
  // =======================================================================
  Widget _buildTabBar() {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);

    return TabBar(
      controller: _tabController,
      isScrollable: true,
      indicatorColor: accent,
      indicatorWeight: 3,
      labelColor: accent,
      unselectedLabelColor: AppTheme.textTertiaryOf(context),
      labelStyle: GoogleFonts.orbitron(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1,
      ),
      unselectedLabelStyle: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      tabAlignment: TabAlignment.center,
      tabs: const [
        Tab(text: 'OVERVIEW'),
        Tab(text: 'ACHIEVEMENTS'),
      ],
    );
  }

  // =======================================================================
  // OVERVIEW TAB
  // =======================================================================
  Widget _buildOverviewTab() {
    final dark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Studied Topics
        GestureDetector(
          onTap: () => context.push('/topics'),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded,
                  color: AppTheme.accentCyanOf(context),
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Studied Topics',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentCyanOf(context),
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (_studiedTopics.isNotEmpty)
                Text(
                  '${_studiedTopics.length}',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textTertiaryOf(context), size: 14),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_studiedTopics.isNotEmpty) ...[
          ..._studiedTopics.take(6).toList().asMap().entries.map(
                (e) => _buildTopicTile(e.value)
                    .animate()
                    .fadeIn(
                        delay: Duration(milliseconds: 80 + e.key * 50),
                        duration: 400.ms)
                    .slideX(begin: 0.04, duration: 400.ms),
              ),
          if (_studiedTopics.length > 6) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => context.push('/topics'),
              child: Text(
                'View all ${_studiedTopics.length} topics →',
                style: GoogleFonts.spaceGrotesk(
                  color: (AppTheme.accentCyanOf(context))
                      .withAlpha(180),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ] else
          GlassContainer(
            borderColor: AppTheme.textTertiaryOf(context).withAlpha(30),
            padding: const EdgeInsets.all(20),
            onTap: () => context.go('/home'),
            child: Column(
              children: [
                Icon(Icons.school_rounded,
                    color: AppTheme.textTertiaryOf(context), size: 36),
                const SizedBox(height: 8),
                Text(
                  'No topics yet',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete a lesson to see your progress here!',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Interests
        if (_interests.isNotEmpty) ...[
          _buildInterestsSectionTitle(context),
          const SizedBox(height: 12),
          _buildInterestsChips(),
          const SizedBox(height: 24),
        ],

        // Concept Map link
        GlassContainer(
          borderColor: AppTheme.accentPurple.withAlpha(40),
          padding: const EdgeInsets.all(14),
          onTap: () => context.push('/concept-map'),
          child: Row(
            children: [
              Icon(Icons.hub_rounded,
                  color: AppTheme.accentPurple, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View Concept Map',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentPurple,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See how your knowledge connects',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: AppTheme.textTertiaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.accentPurple.withAlpha(100), size: 14),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
      ],
    );
  }

  Widget _buildTopicTile(Map<String, dynamic> topic) {
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
      } else {
        dateStr =
            '${studiedDate.day}/${studiedDate.month}/${studiedDate.year}';
      }
    }

    final levelColor = switch (level) {
      'intermediate' => AppTheme.accentCyan,
      'advanced' => AppTheme.accentPurple,
      _ => AppTheme.accentGreen,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        borderColor: levelColor.withAlpha(30),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Level indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: levelColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: levelColor.withAlpha(25),
                          border: Border.all(
                              color: levelColor.withAlpha(60), width: 0.5),
                        ),
                        child: Text(
                          level.toUpperCase(),
                          style: GoogleFonts.orbitron(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: levelColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(
                          3,
                          (i) => Icon(
                                i < stars ? Icons.star : Icons.star_border,
                                size: 14,
                                color: i < stars
                                    ? AppTheme.accentGold
                                    : AppTheme.textTertiaryOf(context),
                              )),
                      if (dateStr.isNotEmpty) ...[
                        const Spacer(),
                        Text(dateStr,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.textTertiaryOf(context),
                              fontSize: 11,
                            )),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$accuracy%',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accuracy >= 70
                    ? AppTheme.accentGreen
                    : AppTheme.accentOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // ACHIEVEMENTS TAB
  // =======================================================================
  Widget _buildAchievementsTab() {
    final dark = AppTheme.isDark(context);

    final all = <_AchievementItem>[
      // Study
      _AchievementItem('First Step', 'Complete your first lesson',
          Icons.school_rounded, AppTheme.accentGreen, _studiedTopics.isNotEmpty),
      _AchievementItem('Knowledge Seeker', 'Study 5 different topics',
          Icons.explore_rounded, AppTheme.accentCyan, _studiedTopics.length >= 5),
      _AchievementItem('Topic Master', 'Study 10 topics',
          Icons.workspace_premium_rounded, AppTheme.accentGold, _studiedTopics.length >= 10),
      _AchievementItem('Scholar Elite', 'Study 25 topics',
          Icons.diamond_rounded, AppTheme.accentPurple, _studiedTopics.length >= 25),

      // Quiz
      _AchievementItem(
          'Perfect Score', 'Score 100% on a quiz', Icons.stars_rounded,
          AppTheme.accentGold,
          _studiedTopics.any((t) => ((t['accuracy'] as num?)?.toInt() ?? 0) == 100)),
      _AchievementItem(
          'Advanced Scholar', 'Complete an advanced lesson',
          Icons.psychology_rounded, AppTheme.accentPurple,
          _studiedTopics.any((t) => (t['level'] as String?) == 'advanced')),

      // Streak
      _AchievementItem('Getting Started', '3-day streak',
          Icons.local_fire_department_rounded, AppTheme.accentOrange, _streak >= 3),
      _AchievementItem('Week Warrior', '7-day streak',
          Icons.whatshot_rounded, AppTheme.accentOrange, _streak >= 7),
      _AchievementItem('Monthly Master', '30-day streak',
          Icons.auto_awesome, AppTheme.accentGold, _streak >= 30),

      // XP
      _AchievementItem('XP Hunter', 'Earn 500 XP',
          Icons.bolt_rounded, AppTheme.accentGold, _xp >= 500),
      _AchievementItem('XP Legend', 'Earn 5000 XP',
          Icons.flash_on_rounded, AppTheme.accentCyan, _xp >= 5000),

      // Special
      _AchievementItem('Early Adopter', 'Join Learnify',
          Icons.rocket_launch_rounded, AppTheme.accentPurple, true),
    ];

    final unlocked = all.where((a) => a.unlocked).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                'Progress',
                style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textTertiaryOf(context),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.accentGreen.withAlpha(25),
                  border: Border.all(
                      color: AppTheme.accentGreen.withAlpha(60)),
                ),
                child: Text(
                  '$unlocked / ${all.length}',
                  style: GoogleFonts.orbitron(
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: all.asMap().entries.map((e) {
              final a = e.value;
              return GestureDetector(
                onTap: () => _showAchievementDetail(a),
                child: GlassContainer(
                  borderColor: a.unlocked
                      ? a.color.withAlpha(50)
                      : AppTheme.glassBorderOf(context),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: a.unlocked
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: a.color.withAlpha(dark ? 100 : 60),
                                      blurRadius: 14),
                                ],
                              )
                            : null,
                        child: Icon(a.icon,
                            color: a.unlocked
                                ? a.color
                                : AppTheme.textTertiaryOf(context).withAlpha(60),
                            size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: a.unlocked
                              ? AppTheme.textSecondaryOf(context)
                              : AppTheme.textTertiaryOf(context).withAlpha(100),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                      delay: Duration(milliseconds: 80 + e.key * 40),
                      duration: 400.ms)
                  .scale(
                      begin: const Offset(0.85, 0.85), duration: 400.ms);
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showAchievementDetail(_AchievementItem a) {
    final dark = AppTheme.isDark(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: dark
                    ? AppTheme.backgroundPrimary.withAlpha(230)
                    : AppTheme.lightBg.withAlpha(240),
                border: Border.all(
                    color: (a.unlocked
                            ? a.color
                            : AppTheme.textTertiaryOf(context))
                        .withAlpha(100),
                    width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        (a.unlocked
                                ? a.color
                                : AppTheme.textTertiaryOf(context))
                            .withAlpha(60),
                        Colors.transparent,
                      ]),
                    ),
                    child: Icon(a.icon,
                        size: 36,
                        color: a.unlocked
                            ? a.color
                            : AppTheme.textTertiaryOf(context)),
                  ),
                  const SizedBox(height: 16),
                  Text(a.title,
                      style: GoogleFonts.orbitron(
                          color: AppTheme.textPrimaryOf(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(a.description,
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textSecondaryOf(context),
                          fontSize: 14),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: a.unlocked
                          ? AppTheme.accentGreen.withAlpha(25)
                          : AppTheme.textTertiaryOf(context).withAlpha(15),
                    ),
                    child: Text(
                      a.unlocked ? 'UNLOCKED' : 'LOCKED',
                      style: GoogleFonts.orbitron(
                        color: a.unlocked
                            ? AppTheme.accentGreen
                            : AppTheme.textTertiaryOf(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =======================================================================
  // EDIT PROFILE BOTTOM SHEET
  // =======================================================================
  void _showEditProfileSheet(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final usernameCtrl =
        TextEditingController(text: _userData?['username'] ?? '');
    final bioCtrl = TextEditingController(text: _userData?['bio'] ?? '');
    final displayNameCtrl = TextEditingController(
      text: _userData?['displayName'] ??
          FirebaseAuth.instance.currentUser?.displayName ??
          '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  color: dark
                      ? AppTheme.surfaceDark.withAlpha(240)
                      : AppTheme.lightSurface.withAlpha(245),
                  border:
                      Border.all(color: AppTheme.glassBorderOf(context)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiaryOf(context).withAlpha(60),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text('Edit Profile',
                          style: GoogleFonts.orbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryOf(context))),
                      const SizedBox(height: 20),
                      _buildEditField('Display Name', displayNameCtrl,
                          Icons.person_rounded),
                      const SizedBox(height: 12),
                      _buildEditField('Username', usernameCtrl,
                          Icons.alternate_email_rounded),
                      const SizedBox(height: 12),
                      _buildEditField(
                          'Bio', bioCtrl, Icons.edit_note_rounded,
                          maxLines: 3),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dark
                                ? AppTheme.accentCyan
                                : AppTheme.accentPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final uid =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update({
                                'username': usernameCtrl.text.trim(),
                                'bio': bioCtrl.text.trim(),
                                'displayName':
                                    displayNameCtrl.text.trim(),
                              });
                              _loadProfile();
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text('Save Changes',
                              style: GoogleFonts.orbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);

    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.spaceGrotesk(
        color: AppTheme.textPrimaryOf(context),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: AppTheme.textTertiaryOf(context),
        ),
        prefixIcon: Icon(icon, color: accent.withAlpha(150), size: 20),
        filled: true,
        fillColor: dark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.glassBorderOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.glassBorderOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }

  // =======================================================================
  // INTERESTS
  // =======================================================================
  Widget _buildInterestsSectionTitle(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.interests_rounded,
            color: AppTheme.accentGold, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Interests',
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentGold,
              letterSpacing: 1,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _showEditInterestsDialog(context),
          child: Icon(
            Icons.edit_rounded,
            color: AppTheme.textTertiaryOf(context),
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildInterestsChips() {
    const chipColors = [
      AppTheme.accentCyan,
      AppTheme.accentPurple,
      AppTheme.accentOrange,
      AppTheme.accentGold,
      AppTheme.accentGreen,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _interests.asMap().entries.map((e) {
        final color = chipColors[e.key % chipColors.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withAlpha(20),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Text(
            e.value,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 80 + e.key * 50),
                duration: 400.ms)
            .slideX(begin: 0.08, duration: 400.ms);
      }).toList(),
    );
  }

  // =======================================================================
  // EDIT INTERESTS DIALOG
  // =======================================================================
  void _showEditInterestsDialog(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final allInterests = [
      'Math', 'Physics', 'Chemistry', 'Biology', 'Computer Science',
      'English', 'History', 'Geography', 'Economics', 'Art',
      'Music', 'Literature', 'Philosophy', 'Psychology', 'Engineering',
    ];
    final selected = Set<String>.from(_interests);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                    color: dark
                        ? AppTheme.surfaceDark.withAlpha(240)
                        : AppTheme.lightSurface.withAlpha(245),
                    border: Border.all(
                        color: AppTheme.glassBorderOf(context)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.textTertiaryOf(context)
                                .withAlpha(60),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text('Edit Interests',
                            style: GoogleFonts.orbitron(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color:
                                    AppTheme.textPrimaryOf(context))),
                        const SizedBox(height: 16),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children:
                                  allInterests.map((interest) {
                                final isSelected =
                                    selected.contains(interest);
                                final accent = dark
                                    ? AppTheme.accentCyan
                                    : AppTheme.accentPurple;
                                return GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      if (isSelected) {
                                        selected.remove(interest);
                                      } else {
                                        selected.add(interest);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        horizontal: 14,
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      color: isSelected
                                          ? accent.withAlpha(30)
                                          : AppTheme.surfaceDarkOf(
                                                  context)
                                              .withAlpha(40),
                                      border: Border.all(
                                        color: isSelected
                                            ? accent.withAlpha(120)
                                            : AppTheme
                                                    .glassBorderOf(
                                                        context)
                                                .withAlpha(80),
                                      ),
                                    ),
                                    child: Text(
                                      interest,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: isSelected
                                            ? accent
                                            : AppTheme
                                                .textSecondaryOf(
                                                    context),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dark
                                  ? AppTheme.accentCyan
                                  : AppTheme.accentPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              final uid = FirebaseAuth
                                  .instance.currentUser?.uid;
                              if (uid != null) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .update({
                                  'interests': selected.toList(),
                                });
                                _loadProfile();
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text('Save Interests',
                                style: GoogleFonts.orbitron(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =======================================================================
  // SETTINGS BOTTOM SHEET
  // =======================================================================
  void _showSettingsBottomSheet(BuildContext context) {
    final dark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                color: dark
                    ? AppTheme.surfaceDark.withAlpha(230)
                    : AppTheme.lightSurface.withAlpha(240),
                border:
                    Border.all(color: AppTheme.glassBorderOf(context)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.textTertiaryOf(context).withAlpha(60),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Settings',
                      style: GoogleFonts.orbitron(
                        color: AppTheme.textPrimaryOf(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSettingsOption(
                      icon: Icons.edit_rounded,
                      iconColor: dark
                          ? AppTheme.accentCyan
                          : AppTheme.accentPurple,
                      label: 'Edit Profile',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEditProfileSheet(context);
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildSettingsOption(
                      icon: Icons.interests_rounded,
                      iconColor: AppTheme.accentGreen,
                      label: 'Edit Interests',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showEditInterestsDialog(context);
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildSettingsOption(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppTheme.accentPurple,
                      label: 'About Learnify',
                      onTap: () {
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 6),
                    Divider(
                      color: AppTheme.glassBorderOf(context),
                      height: 24,
                    ),
                    _buildSettingsOption(
                      icon: Icons.swap_horiz_rounded,
                      iconColor: AppTheme.accentGold,
                      label: 'Switch Account',
                      onTap: () async {
                        Navigator.pop(ctx);
                        await GoogleSignIn().signOut();
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildSettingsOption(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.redAccent,
                      label: 'Sign Out',
                      labelColor: Colors.redAccent,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await GoogleSignIn().disconnect();
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: iconColor.withAlpha(20),
        highlightColor: iconColor.withAlpha(10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppTheme.surfaceDarkOf(context).withAlpha(40),
            border: Border.all(color: AppTheme.glassBorderOf(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withAlpha(20),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: labelColor ??
                        AppTheme.textPrimaryOf(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textTertiaryOf(context), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  final bool dark;
  const _TabBarDelegate({required this.tabBar, required this.dark});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: dark
              ? AppTheme.backgroundPrimary.withAlpha(200)
              : AppTheme.lightBg.withAlpha(220),
          child: tabBar,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      dark != oldDelegate.dark;
}

class _AchievementItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
  const _AchievementItem(
      this.title, this.description, this.icon, this.color, this.unlocked);
}
