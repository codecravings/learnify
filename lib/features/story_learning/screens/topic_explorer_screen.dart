import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Intermediate screen between "Learn Anything" and Story mode.
///
/// Flow: Enter topic → DeepSeek generates sub-topics → pick difficulty →
/// study each sub-topic → mark done / revise.
class TopicExplorerScreen extends StatefulWidget {
  const TopicExplorerScreen({super.key, required this.topic});

  final String topic;

  @override
  State<TopicExplorerScreen> createState() => _TopicExplorerScreenState();
}

class _TopicExplorerScreenState extends State<TopicExplorerScreen>
    with SingleTickerProviderStateMixin {
  static const _groqKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.groq.com/openai/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Authorization': 'Bearer $_groqKey',
      'Content-Type': 'application/json',
    },
  ));

  List<Map<String, dynamic>> _subtopics = [];
  bool _loading = true;
  String? _error;

  // Difficulty
  String _difficulty = 'beginner'; // beginner | intermediate | pro

  // Track completed/revised per sub-topic index
  final Set<int> _completed = {};

  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _generateSubtopics();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateSubtopics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert educator. Given a topic, generate 6-8 important sub-topics that a student should study to master it. Return ONLY a JSON array. Each element must have: "title" (short 2-5 words), "description" (one sentence), "emoji" (single emoji). Return ONLY the JSON array, no markdown fences, no extra text.',
          },
          {
            'role': 'user',
            'content': 'Topic: ${widget.topic}',
          },
        ],
        'temperature': 0.7,
        'max_tokens': 1024,
      });

      final text = (response.data['choices'][0]['message']['content'] as String).trim();

      final parsed = _parseSubtopics(text);
      if (mounted) {
        setState(() {
          _subtopics = parsed;
          _loading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e, st) {
      debugPrint('[TOPIC_EXPLORER] Error: $e');
      debugPrint('[TOPIC_EXPLORER] Stack: $st');
      if (mounted) {
        setState(() {
          _error = 'Failed to generate topics. Tap to retry.\n($e)';
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _parseSubtopics(String raw) {
    var cleaned = raw.trim();
    // Strip markdown fences
    if (cleaned.startsWith('```')) {
      final firstNl = cleaned.indexOf('\n');
      if (firstNl != -1) cleaned = cleaned.substring(firstNl + 1);
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }
    final list = jsonDecode(cleaned) as List;
    return list.cast<Map<String, dynamic>>();
  }

  void _onSubtopicTap(int index) {
    final sub = _subtopics[index];
    final topicName = '${widget.topic} — ${sub['title']}';

    // Map difficulty to level
    String level;
    switch (_difficulty) {
      case 'pro':
        level = 'advanced';
        break;
      case 'intermediate':
        level = 'intermediate';
        break;
      default:
        level = 'basics';
    }

    context.push('/lesson', extra: {
      'customTopic': topicName,
      'level': level,
    }).then((_) {
      // When user comes back from story, mark as completed
      if (mounted) {
        setState(() => _completed.add(index));
        _saveProgress();
      }
    });
  }

  void _onRevise(int index) {
    // Remove from completed and relaunch
    setState(() => _completed.remove(index));
    _onSubtopicTap(index);
  }

  Future<void> _saveProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final topicKey =
        widget.topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'studiedTopics.$topicKey.subtopicsTotal': _subtopics.length,
        'studiedTopics.$topicKey.subtopicsDone': _completed.length,
        'studiedTopics.$topicKey.lastStudied': FieldValue.serverTimestamp(),
        'studiedTopics.$topicKey.difficulty': _difficulty,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final cyan = AppTheme.accentCyanOf(context);
    final purple = AppTheme.accentPurpleOf(context);

    return Scaffold(
      backgroundColor: dark ? AppTheme.backgroundPrimary : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(cyan, purple),
            if (!_loading && _error == null) _buildDifficultySelector(cyan),
            Expanded(child: _buildBody(cyan, purple, dark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color cyan, Color purple) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(Icons.arrow_back_ios,
                color: AppTheme.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXPLORE',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [cyan, purple],
                  ).createShader(bounds),
                  child: Text(
                    widget.topic,
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Progress indicator
          if (_subtopics.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: cyan.withAlpha(20),
                border: Border.all(color: cyan.withAlpha(60)),
              ),
              child: Text(
                '${_completed.length}/${_subtopics.length}',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cyan,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelector(Color cyan) {
    final levels = [
      {'key': 'beginner', 'label': 'Beginner', 'icon': Icons.school_outlined},
      {
        'key': 'intermediate',
        'label': 'Intermediate',
        'icon': Icons.psychology_outlined,
      },
      {'key': 'pro', 'label': 'Pro', 'icon': Icons.rocket_launch_outlined},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: levels.map((l) {
          final key = l['key'] as String;
          final selected = _difficulty == key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _difficulty = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: selected
                      ? LinearGradient(colors: [
                          cyan.withAlpha(40),
                          AppTheme.accentPurple.withAlpha(20),
                        ])
                      : null,
                  color: selected ? null : Colors.white.withAlpha(8),
                  border: Border.all(
                    color: selected ? cyan : AppTheme.glassBorder,
                    width: selected ? 1.5 : 0.8,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(l['icon'] as IconData,
                        size: 20,
                        color: selected ? cyan : AppTheme.textTertiary),
                    const SizedBox(height: 4),
                    Text(
                      l['label'] as String,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected ? cyan : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(Color cyan, Color purple, bool dark) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(cyan),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Generating sub-topics...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI is breaking down "${widget.topic}"',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: GestureDetector(
          onTap: _generateSubtopics,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, size: 48, color: cyan.withAlpha(120)),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeCtrl,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: _subtopics.length,
        itemBuilder: (context, i) => _buildSubtopicCard(i, cyan, purple, dark),
      ),
    );
  }

  Widget _buildSubtopicCard(int index, Color cyan, Color purple, bool dark) {
    final sub = _subtopics[index];
    final title = sub['title'] as String? ?? 'Topic ${index + 1}';
    final desc = sub['description'] as String? ?? '';
    final emoji = sub['emoji'] as String? ?? '📚';
    final isDone = _completed.contains(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderColor: isDone
            ? AppTheme.accentGreen.withAlpha(80)
            : AppTheme.glassBorder,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Number + emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDone
                    ? LinearGradient(colors: [
                        AppTheme.accentGreen.withAlpha(40),
                        AppTheme.accentGreen.withAlpha(15),
                      ])
                    : RadialGradient(colors: [
                        cyan.withAlpha(30),
                        purple.withAlpha(10),
                      ]),
                border: Border.all(
                  color: isDone
                      ? AppTheme.accentGreen
                      : cyan.withAlpha(60),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? Icon(Icons.check_rounded,
                        color: AppTheme.accentGreen, size: 22)
                    : Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),

            // Title + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${index + 1}.',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDone
                                ? AppTheme.accentGreen
                                : AppTheme.textPrimary,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action button
            isDone
                ? GestureDetector(
                    onTap: () => _onRevise(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Text(
                        'Revise',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => _onSubtopicTap(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(colors: [cyan, purple]),
                      ),
                      child: Text(
                        'Study',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
