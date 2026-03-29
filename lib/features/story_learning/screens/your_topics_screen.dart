import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/hindsight_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';

/// Dedicated screen showing all topics the user has studied,
/// powered by Firestore data + Hindsight AI insights.
class YourTopicsScreen extends StatefulWidget {
  const YourTopicsScreen({super.key});

  @override
  State<YourTopicsScreen> createState() => _YourTopicsScreenState();
}

class _YourTopicsScreenState extends State<YourTopicsScreen> {
  List<Map<String, dynamic>> _firestoreTopics = [];
  List<Map<String, dynamic>> _aiTopics = [];
  bool _loadingFirestore = true;
  bool _loadingAI = true;
  String? _aiInsight;

  @override
  void initState() {
    super.initState();
    _loadFirestoreTopics();
    _loadAITopics();
  }

  Future<void> _loadFirestoreTopics() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingFirestore = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      final raw = data?['studiedTopics'];
      if (raw is Map && mounted) {
        final topics = <Map<String, dynamic>>[];
        for (final entry in raw.entries) {
          if (entry.value is Map) {
            final t = Map<String, dynamic>.from(entry.value as Map);
            t['key'] = entry.key;
            topics.add(t);
          }
        }
        topics.sort((a, b) {
          final aTime = a['lastStudied'];
          final bTime = b['lastStudied'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });
        setState(() {
          _firestoreTopics = topics;
          _loadingFirestore = false;
        });
      } else {
        if (mounted) setState(() => _loadingFirestore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFirestore = false);
    }
  }

  Future<void> _loadAITopics() async {
    try {
      // Get AI-powered topic analysis from Hindsight
      final topics = await HindsightService.instance
          .getStudiedTopics()
          .timeout(const Duration(seconds: 12));
      final insight = await HindsightService.instance
          .reflect(
            query:
                'In one sentence, summarize this student\'s learning journey so far. '
                'Mention their strongest topic and what they should revisit.',
            budget: 'low',
            maxTokens: 200,
          )
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _aiTopics = topics;
          _aiInsight = insight;
          _loadingAI = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTopics =
        _firestoreTopics.isNotEmpty || _aiTopics.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Stack(
        children: [
          const ParticleBackground(
            particleCount: 30,
            particleColor: AppTheme.accentPurple,
            maxRadius: 1.0,
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _loadingFirestore && _loadingAI
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accentCyan))
                      : hasTopics
                          ? _buildTopicsList()
                          : _buildEmptyState(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white70, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradientOf(context).createShader(bounds),
            child: Text(
              'YOUR TOPICS',
              style: AppTheme.headerStyle(fontSize: 18, letterSpacing: 2),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.accentPurple.withAlpha(20),
              border:
                  Border.all(color: AppTheme.accentPurple.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology_rounded,
                    color: AppTheme.accentPurple, size: 14),
                const SizedBox(width: 4),
                Text(
                  'AI MEMORY',
                  style: GoogleFonts.orbitron(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentPurple,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsList() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadFirestoreTopics(), _loadAITopics()]);
      },
      color: AppTheme.accentCyan,
      backgroundColor: AppTheme.surfaceDark,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // AI Insight card
          if (_aiInsight != null && _aiInsight!.isNotEmpty)
            GlassContainer(
              borderColor: AppTheme.accentPurple.withAlpha(60),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI LEARNING INSIGHT',
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentPurple,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _aiInsight!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.05, duration: 500.ms),

          if (_aiInsight != null) const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _buildStatChip(
                '${_firestoreTopics.length}',
                'Topics',
                AppTheme.accentCyan,
              ),
              const SizedBox(width: 10),
              _buildStatChip(
                '${_firestoreTopics.where((t) => ((t['accuracy'] as num?)?.toInt() ?? 0) >= 70).length}',
                'Mastered',
                AppTheme.accentGreen,
              ),
              const SizedBox(width: 10),
              _buildStatChip(
                '${_firestoreTopics.where((t) => ((t['accuracy'] as num?)?.toInt() ?? 0) < 70).length}',
                'Review',
                AppTheme.accentOrange,
              ),
            ],
          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

          const SizedBox(height: 20),

          // Topics from Firestore
          ..._firestoreTopics.asMap().entries.map((entry) {
            final i = entry.key;
            final topic = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTopicCard(topic)
                  .animate()
                  .fadeIn(
                      delay: Duration(milliseconds: 150 + i * 80),
                      duration: 400.ms)
                  .slideX(begin: 0.06, duration: 400.ms),
            );
          }),

          // AI-only topics (from Hindsight but not in Firestore)
          if (_aiTopics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.memory_rounded,
                    color: AppTheme.accentPurple.withAlpha(150), size: 16),
                const SizedBox(width: 6),
                Text(
                  'FROM YOUR AI MEMORY',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentPurple.withAlpha(150),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._aiTopics
                .where((ai) => !_firestoreTopics.any((fs) =>
                    (fs['name'] as String?)?.toLowerCase() ==
                    (ai['name'] as String?)?.toLowerCase()))
                .map((topic) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildAITopicCard(topic),
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: GlassContainer(
        borderColor: color.withAlpha(40),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final name = topic['name'] as String? ?? 'Topic';
    final level = topic['level'] as String? ?? 'basics';
    final accuracy = (topic['accuracy'] as num?)?.toInt() ?? 0;
    final stars = (topic['stars'] as num?)?.toInt() ?? 0;
    final lastStudied = topic['lastStudied'];

    String dateStr = '';
    if (lastStudied is Timestamp) {
      final dt = lastStudied.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) {
        dateStr = 'Today';
      } else if (diff.inDays == 1) {
        dateStr = 'Yesterday';
      } else if (diff.inDays < 7) {
        dateStr = '${diff.inDays}d ago';
      } else {
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
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
      borderColor: color.withAlpha(50),
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/lesson', extra: {
        'customTopic': name,
        'level': nextLevel,
      }),
      child: Row(
        children: [
          // Level color bar
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: color.withAlpha(20),
                        border: Border.all(
                            color: color.withAlpha(60), width: 0.5),
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
                    const SizedBox(width: 10),
                    ...List.generate(
                        3,
                        (i) => Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                i < stars ? Icons.star : Icons.star_border,
                                size: 14,
                                color: i < stars
                                    ? AppTheme.accentGold
                                    : AppTheme.textTertiary,
                              ),
                            )),
                    if (dateStr.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        dateStr,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Accuracy circle
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: accuracy / 100,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withAlpha(15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    accuracy >= 70 ? AppTheme.accentGreen : AppTheme.accentOrange,
                  ),
                ),
                Text(
                  '$accuracy%',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accuracy >= 70
                        ? AppTheme.accentGreen
                        : AppTheme.accentOrange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded,
              color: color.withAlpha(100), size: 14),
        ],
      ),
    );
  }

  Widget _buildAITopicCard(Map<String, dynamic> topic) {
    final name = topic['name'] as String? ?? 'Topic';
    final level = topic['level'] as String? ?? 'basics';
    final summary = topic['summary'] as String? ?? '';
    final accuracy = (topic['accuracy'] as num?)?.toInt() ?? 0;

    final color = switch (level) {
      'intermediate' => AppTheme.accentCyan,
      'advanced' => AppTheme.accentPurple,
      _ => AppTheme.accentGreen,
    };

    return GlassContainer(
      borderColor: AppTheme.accentPurple.withAlpha(40),
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/lesson', extra: {
        'customTopic': name,
        'level': level,
      }),
      child: Row(
        children: [
          Icon(Icons.memory_rounded,
              color: AppTheme.accentPurple.withAlpha(150), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: color.withAlpha(20),
              border: Border.all(color: color.withAlpha(60), width: 0.5),
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
          if (accuracy > 0) ...[
            const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentPurple.withAlpha(20),
              ),
              child: Icon(Icons.school_rounded,
                  color: AppTheme.accentPurple.withAlpha(100), size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'No topics yet',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a lesson and your topics will show here!\n'
              'Your AI memory will track everything.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textTertiary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
