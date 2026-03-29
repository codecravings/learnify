import 'dart:convert';
import 'dart:math' show pi, sin, cos, Random;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/services/feed_service.dart';
import '../../../core/services/hindsight_service.dart';
import '../../../core/services/openai_image_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';
import '../../../core/widgets/particle_background.dart';
import '../../../features/courses/data/course_data.dart';
import '../models/story_response.dart';
import '../models/story_style.dart';
import '../services/story_generator_service.dart';
import '../../knowledge_graph/widgets/root_cause_card.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/story_progress_bar.dart';
import '../widgets/style_selector.dart';

/// Main story-based learning screen with 6 phases:
/// LEVEL_SELECT → STYLE_SELECT → LOADING → STORY → QUIZ → RESULTS
///
/// For custom topics, the AI assesses the student's level via Hindsight
/// and recommends Basics / Intermediate / Advanced before proceeding.
class StoryScreen extends StatefulWidget {
  const StoryScreen({
    super.key,
    this.lessonId = '',
    this.subjectId = '',
    this.chapterId = '',
    this.customTopic,
    this.preselectedLevel,
  });

  final String lessonId;
  final String subjectId;
  final String chapterId;

  /// If set, generates a story from this topic instead of lesson data.
  final String? customTopic;

  /// If set, skips level selection (used when continuing from home page).
  final String? preselectedLevel;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

enum _Phase { levelSelect, styleSelect, loading, story, quiz, results }

class _StoryScreenState extends State<StoryScreen>
    with TickerProviderStateMixin {
  // ── Phase state ─────────────────────────────────────────────────────
  _Phase _phase = _Phase.levelSelect;
  StoryStyle? _selectedStyle;
  String? _franchiseName;
  StoryResponse? _storyResponse;
  String? _errorMessage;

  // ── Level selection state ──────────────────────────────────────────
  String _selectedLevel = 'basics';
  Map<String, dynamic>? _levelAssessment;
  bool _levelLoading = true;

  // ── Story playback state ────────────────────────────────────────────
  int _currentSceneIndex = 0;
  int _visibleCharCount = 0;
  bool _typewriterComplete = false;

  // Current speaker info (resolved from AI-generated characters array)
  String _speakerName = '';
  String _speakerRole = '';
  Color _speakerColor = AppTheme.accentCyan;

  // ── Quiz state ──────────────────────────────────────────────────────
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _answerRevealed = false;
  int _correctCount = 0;
  final List<String> _missedQuestions = [];

  // ── Results state ───────────────────────────────────────────────────
  int _xpEarned = 0;
  int _stars = 0;
  bool _resultsSaved = false;

  // ── Animation controllers ───────────────────────────────────────────
  late AnimationController _typewriterCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _xpCountCtrl;
  late AnimationController _portraitCtrl;
  late AnimationController _sceneSlideCtrl;
  late AnimationController _quizFeedbackCtrl;
  late AnimationController _starCtrl;
  late AnimationController _celebrationCtrl;

  // ── Character image state (Movie/TV portraits via OpenAI) ──────────
  final Map<String, Uint8List> _characterImages = {};

  // ── Services ────────────────────────────────────────────────────────
  final _storyService = StoryGeneratorService();

  // ── Lesson data ─────────────────────────────────────────────────────
  Lesson? _lesson;
  String _chapterTitle = '';

  @override
  void initState() {
    super.initState();
    _loadLessonData();
    _initAnimationControllers();

    // Always skip level select — go straight to style select
    _phase = _Phase.styleSelect;
    _levelLoading = false;
    if (widget.preselectedLevel != null) {
      _selectedLevel = widget.preselectedLevel!;
    }
  }

  void _initAnimationControllers() {
    _typewriterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Reset per scene
    )..addListener(_onTypewriterTick);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _xpCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _portraitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _sceneSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _quizFeedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  bool get _isCustomTopic =>
      widget.customTopic != null && widget.customTopic!.trim().isNotEmpty;

  void _loadLessonData() {
    if (_isCustomTopic) return; // No lesson data needed for custom topics
    for (final subject in CourseData.allCourses) {
      if (subject.id == widget.subjectId) {
        for (final chapter in subject.chapters) {
          if (chapter.id == widget.chapterId) {
            _chapterTitle = chapter.title;
            for (final lesson in chapter.lessons) {
              if (lesson.id == widget.lessonId) {
                _lesson = lesson;
                return;
              }
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _typewriterCtrl.dispose();
    _fadeCtrl.dispose();
    _shimmerCtrl.dispose();
    _xpCountCtrl.dispose();
    _starCtrl.dispose();
    _celebrationCtrl.dispose();
    _portraitCtrl.dispose();
    _sceneSlideCtrl.dispose();
    _quizFeedbackCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Phase transitions
  // ═══════════════════════════════════════════════════════════════════════

  void _onLevelConfirmed() {
    setState(() => _phase = _Phase.styleSelect);
  }

  void _onStyleSelected(StoryStyle style, {String? franchiseName}) {
    setState(() {
      _selectedStyle = style;
      _franchiseName = franchiseName;
      _phase = _Phase.loading;
      _errorMessage = null;
    });
    _generateStory();
  }

  Future<void> _generateStory() async {
    if (!_isCustomTopic && _lesson == null) {
      setState(() {
        _errorMessage = 'Lesson data not found';
      });
      return;
    }

    try {
      final StoryResponse response;
      if (_isCustomTopic) {
        response = await _storyService.generateStoryFromTopic(
          topic: widget.customTopic!,
          style: _selectedStyle!,
          franchiseName: _franchiseName,
          level: _selectedLevel,
        );
      } else {
        response = await _storyService.generateStory(
          lesson: _lesson!,
          subjectId: widget.subjectId,
          chapterTitle: _chapterTitle,
          style: _selectedStyle!,
          franchiseName: _franchiseName,
        );
      }

      if (!mounted) return;

      if (response.scenes.isEmpty) {
        setState(() {
          _errorMessage = 'Story generation returned empty. Try again!';
        });
        return;
      }

      setState(() {
        _storyResponse = response;
        _phase = _Phase.story;
        _currentSceneIndex = 0;
      });
      _startScene(0);

      // Generate character portraits for all styles (fire-and-forget)
      if (response.franchiseCharacters.isNotEmpty) {
        _generateCharacterImages(response);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate story. Check your connection.';
      });
    }
  }

  void _startScene(int index) {
    if (_storyResponse == null) return;
    final scene = _storyResponse!.scenes[index];

    // Resolve the speaking character from AI-generated characters array
    final character =
        _storyResponse!.getFranchiseCharacter(scene.characterId);

    // Fade out old scene first, then update and fade in
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;

      setState(() {
        _currentSceneIndex = index;
        if (character != null) {
          _speakerName = character.name;
          _speakerRole = character.role;
          _speakerColor = character.color;
        } else {
          _speakerName = scene.characterId;
          _speakerRole = '';
          _speakerColor = AppTheme.accentCyan;
        }
        _visibleCharCount = 0;
        _typewriterComplete = false;
      });

      // Calculate duration: ~30ms per character
      final charCount = scene.dialogue.length;
      final duration = Duration(milliseconds: charCount * 30);

      _typewriterCtrl
        ..reset()
        ..duration = duration
        ..forward();

      _fadeCtrl.forward();

      // Character portrait entrance bounce
      _portraitCtrl
        ..reset()
        ..forward();

      // Scene slide-in
      _sceneSlideCtrl
        ..reset()
        ..forward();
    });
  }

  void _onTypewriterTick() {
    if (_storyResponse == null || _phase != _Phase.story) return;
    final scene = _storyResponse!.scenes[_currentSceneIndex];
    final newCount =
        (_typewriterCtrl.value * scene.dialogue.length).round();

    if (newCount != _visibleCharCount) {
      setState(() {
        _visibleCharCount = newCount;
        if (_visibleCharCount >= scene.dialogue.length) {
          _typewriterComplete = true;
        }
      });
    }
  }

  void _onStoryTap() {
    if (_storyResponse == null) return;

    if (!_typewriterComplete) {
      // Complete typewriter instantly
      _typewriterCtrl.value = 1.0;
      setState(() {
        _visibleCharCount =
            _storyResponse!.scenes[_currentSceneIndex].dialogue.length;
        _typewriterComplete = true;
      });
      return;
    }

    // Advance to next scene
    if (_currentSceneIndex < _storyResponse!.scenes.length - 1) {
      _startScene(_currentSceneIndex + 1);
    } else {
      // Story complete → quiz
      _startQuiz();
    }
  }

  void _startQuiz() {
    setState(() {
      _phase = _Phase.quiz;
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _answerRevealed = false;
      _correctCount = 0;
    });
    // Reset scene slide for quiz option staggered entrance
    _sceneSlideCtrl
      ..reset()
      ..forward();
  }

  void _onAnswerSelected(int index) {
    if (_answerRevealed) return;
    final question = _storyResponse!.quiz[_currentQuestionIndex];
    final correct = index == question.correctIndex;

    setState(() {
      _selectedAnswerIndex = index;
      _answerRevealed = true;
      if (correct) {
        _correctCount++;
      } else {
        _missedQuestions.add(question.question);
      }
    });

    // Trigger feedback animation
    _quizFeedbackCtrl
      ..reset()
      ..forward();
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _storyResponse!.quiz.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answerRevealed = false;
      });
      // Re-trigger staggered entrance for new question options
      _sceneSlideCtrl
        ..reset()
        ..forward();
    } else {
      _showResults();
    }
  }

  void _showResults() {
    final totalQuestions = _storyResponse!.quiz.length;
    final accuracy = totalQuestions > 0 ? _correctCount / totalQuestions : 0.0;

    // Star rating
    if (accuracy >= 1.0) {
      _stars = 3;
    } else if (accuracy >= 0.66) {
      _stars = 2;
    } else {
      _stars = 1;
    }

    // XP calculation
    _xpEarned = AppConstants.xpCompleteStory;
    if (_stars == 3) {
      _xpEarned += 15; // Perfect bonus
    }

    setState(() {
      _phase = _Phase.results;
    });

    _xpCountCtrl.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _starCtrl.forward();
    });
    if (_stars == 3) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _celebrationCtrl.forward();
      });
    }

    _saveProgress();
  }

  Future<void> _saveProgress() async {
    if (_resultsSaved) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final topic = _isCustomTopic
        ? widget.customTopic!
        : (_lesson?.title ?? widget.subjectId);

    final topicKey =
        topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final total = _storyResponse?.quiz.length ?? 0;
    final accuracy =
        total > 0 ? (_correctCount / total * 100).round() : 0;
    final now = DateTime.now().toIso8601String();

    final topicData = {
      'name': topic,
      'level': _selectedLevel,
      'accuracy': accuracy,
      'stars': _stars,
      'lastStudied': now,
    };

    // ── 1. Save locally FIRST (always works, instant) ──
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'user_data_$uid';
      final cached = prefs.getString(cacheKey);
      final localData = cached != null
          ? (jsonDecode(cached) as Map<String, dynamic>)
          : <String, dynamic>{};

      // Calculate streak BEFORE updating lastActive
      final lastActive = localData['lastActive'] as String?;

      // Update local stats
      localData['xp'] = ((localData['xp'] as num?)?.toInt() ?? 0) + _xpEarned;
      localData['totalQuizzes'] =
          ((localData['totalQuizzes'] as num?)?.toInt() ?? 0) + 1;
      localData['lastActive'] = now;
      final currentStreak =
          (localData['currentStreak'] as num?)?.toInt() ?? 0;
      int newStreak = 1;
      if (lastActive != null) {
        final lastDate = DateTime.tryParse(lastActive);
        if (lastDate != null) {
          final todayStart =
              DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final lastStart =
              DateTime(lastDate.year, lastDate.month, lastDate.day);
          final diffDays = todayStart.difference(lastStart).inDays;
          if (diffDays <= 1) {
            newStreak = diffDays == 0
                ? (currentStreak < 1 ? 1 : currentStreak)
                : currentStreak + 1;
          }
        }
      }
      localData['currentStreak'] = newStreak;

      // Save topic
      final studiedTopics = (localData['studiedTopics'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v)) ??
          <String, dynamic>{};
      studiedTopics[topicKey] = topicData;
      localData['studiedTopics'] = studiedTopics;

      await prefs.setString(cacheKey, jsonEncode(localData));
      _resultsSaved = true;

      // ── 2. Save to Firestore in background (backup/sync) ──
      _saveToFirestore(uid, topicKey, topicData, newStreak);
    } catch (_) {
      // Local save failed — try Firestore directly
      _saveToFirestore(uid, topicKey, topicData, 1);
    }

    // ── 3. Retain learning data in Hindsight Memory ──
    _retainToHindsight();

    // ── 4. Check achievements (fire-and-forget) ──
    _checkAchievements();

    // ── 5. Post to activity feed ──
    final feedTotal = _storyResponse?.quiz.length ?? 0;
    final feedAccuracy = feedTotal > 0 ? (_correctCount / feedTotal * 100).round() : 0;
    if (feedAccuracy == 100) {
      FeedService.instance.post(action: 'perfect_score', detail: 'Scored 100% on $topic');
    } else {
      FeedService.instance.post(action: 'completed_lesson', detail: 'Completed $topic ($feedAccuracy%)');
    }
  }

  void _checkAchievements() async {
    final unlocked = await AchievementService.instance.checkAndAward();
    if (unlocked.isNotEmpty && mounted) {
      for (final a in unlocked) {
        FeedService.instance.post(
          action: 'earned_achievement',
          detail: 'Unlocked "${a.name}" — ${a.description}',
        );
      }
    }
  }

  /// Fire-and-forget Firestore backup save.
  void _saveToFirestore(
    String uid,
    String topicKey,
    Map<String, dynamic> topicData,
    int newStreak,
  ) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final updates = <String, dynamic>{
        'xp': FieldValue.increment(_xpEarned),
        'lastActive': FieldValue.serverTimestamp(),
        'currentStreak': newStreak,
        'totalQuizzes': FieldValue.increment(1),
        'studiedTopics.$topicKey': {
          ...topicData,
          'lastStudied': FieldValue.serverTimestamp(),
        },
      };
      if (!_isCustomTopic) {
        updates['courseProgress.${widget.subjectId}'] =
            FieldValue.increment(0.05);
      }
      await userRef.set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  void _retainToHindsight() {
    if (_storyResponse == null) return;
    final topic = _isCustomTopic
        ? widget.customTopic!
        : (_lesson?.title ?? widget.subjectId);
    final style = _selectedStyle?.label ?? 'unknown';
    final total = _storyResponse!.quiz.length;

    // Collect concept summaries from quiz questions
    final concepts = <String>[];
    for (int i = 0; i < total; i++) {
      final q = _storyResponse!.quiz[i];
      concepts.add(q.question.split('?').first);
    }

    // Collect concept tags from scenes
    final sceneConcepts = _storyResponse!.scenes
        .where((s) => s.conceptTag != null && s.conceptTag!.isNotEmpty)
        .map((s) => s.conceptTag!)
        .toSet()
        .toList();

    HindsightService.instance.retainQuizResult(
      topic: topic,
      style: style,
      score: _correctCount,
      total: total,
      missedQuestions: _missedQuestions,
      conceptsCovered: sceneConcepts.isNotEmpty ? sceneConcepts : concepts,
      level: _selectedLevel,
    );
  }

  /// Generate AI portraits for story characters in parallel (fire-and-forget).
  void _generateCharacterImages(StoryResponse response) async {
    final context = _franchiseName ??
        widget.customTopic ??
        _lesson?.title ??
        'educational story';
    final chars = response.franchiseCharacters
        .map((c) => (id: c.id, name: c.name, role: c.role))
        .toList();
    final results = await OpenAIImageService.instance.generateAll(
      characters: chars,
      franchiseName: context,
    );
    if (mounted && results.isNotEmpty) {
      setState(() => _characterImages.addAll(results));
    }
  }

  void _navigateBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _fallbackToClassicLesson() {
    // Pop back and the router will show the default LessonScreen
    _navigateBack();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ParticleBackground(
                particleCount: 50,
                particleColor: AppTheme.accentPurple,
                speed: 0.2,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(child: _buildPhaseContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _navigateBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
                border: Border.all(color: AppTheme.glassBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lesson?.title ?? widget.customTopic ?? 'Story',
                  style: AppTheme.headerStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _phaseLabel,
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _phaseLabel {
    switch (_phase) {
      case _Phase.levelSelect:
        return 'Choose your level';
      case _Phase.styleSelect:
        return 'Choose a style';
      case _Phase.loading:
        return 'Generating story...';
      case _Phase.story:
        return 'Scene ${_currentSceneIndex + 1} of ${_storyResponse?.scenes.length ?? 0}';
      case _Phase.quiz:
        return 'Question ${_currentQuestionIndex + 1} of ${_storyResponse?.quiz.length ?? 0}';
      case _Phase.results:
        return 'Lesson complete!';
    }
  }

  Widget _buildPhaseContent() {
    Widget child;
    switch (_phase) {
      case _Phase.levelSelect:
        child = _buildLevelSelect();
        break;
      case _Phase.styleSelect:
        child = _buildStyleSelect();
        break;
      case _Phase.loading:
        child = _buildLoading();
        break;
      case _Phase.story:
        child = _buildStory();
        break;
      case _Phase.quiz:
        child = _buildQuiz();
        break;
      case _Phase.results:
        child = _buildResults();
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideIn = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: slideIn,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_phase),
        child: child,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Phase -1: Level Select (Custom topics only)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLevelSelect() {
    final topic = widget.customTopic ?? 'Topic';
    final hasHistory = _levelAssessment?['has_history'] as bool? ?? false;
    final reason = _levelAssessment?['reason'] as String? ??
        'Let\'s start from the fundamentals!';
    final pastAccuracy = _levelAssessment?['past_accuracy'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Topic title
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradientOf(context).createShader(bounds),
            child: Text(
              topic.toUpperCase(),
              style: AppTheme.headerStyle(
                fontSize: 20,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // AI assessment card
          GlassContainer(
            borderColor: AppTheme.accentCyan.withAlpha(50),
            padding: const EdgeInsets.all(16),
            child: _levelLoading
                ? Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentCyan),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Checking your memory...',
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasHistory
                                ? Icons.psychology_rounded
                                : Icons.auto_awesome,
                            color: AppTheme.accentCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasHistory
                                ? 'I REMEMBER YOU'
                                : 'NEW TOPIC DETECTED',
                            style: AppTheme.headerStyle(
                              fontSize: 11,
                              color: AppTheme.accentCyan,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        reason,
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      if (hasHistory && pastAccuracy > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.analytics_rounded,
                                color: AppTheme.accentGold, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Past accuracy: $pastAccuracy%',
                              style: AppTheme.bodyStyle(
                                fontSize: 12,
                                color: AppTheme.accentGold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // Level options
          Text(
            'START FROM',
            style: AppTheme.headerStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildLevelCard(
                  level: 'basics',
                  label: 'Basics',
                  icon: Icons.school_rounded,
                  description: 'Start from\nfundamentals',
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLevelCard(
                  level: 'intermediate',
                  label: 'Intermediate',
                  icon: Icons.trending_up_rounded,
                  description: 'Build on\nexisting knowledge',
                  color: AppTheme.accentCyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLevelCard(
                  level: 'advanced',
                  label: 'Advanced',
                  icon: Icons.rocket_launch_rounded,
                  description: 'Deep dive &\nexpert level',
                  color: AppTheme.accentPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Continue button
          if (!_levelLoading)
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                label: 'CONTINUE',
                icon: Icons.arrow_forward_rounded,
                onTap: _onLevelConfirmed,
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLevelCard({
    required String level,
    required String label,
    required IconData icon,
    required String description,
    required Color color,
  }) {
    final isSelected = _selectedLevel == level;
    final isRecommended = _levelAssessment?['level'] == level;

    return GestureDetector(
      onTap: () => setState(() => _selectedLevel = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? color.withAlpha(25) : Colors.white.withAlpha(5),
          border: Border.all(
            color: isSelected ? color : AppTheme.glassBorder,
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: isSelected ? AppTheme.neonGlow(color, blur: 12) : null,
        ),
        child: Column(
          children: [
            if (isRecommended && !_levelLoading) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppTheme.accentGold.withAlpha(25),
                  border: Border.all(
                      color: AppTheme.accentGold.withAlpha(60), width: 0.5),
                ),
                child: Text(
                  'AI PICK',
                  style: AppTheme.headerStyle(
                    fontSize: 7,
                    color: AppTheme.accentGold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Icon(icon, color: isSelected ? color : AppTheme.textTertiary,
                size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.headerStyle(
                fontSize: 10,
                color: isSelected ? color : AppTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 9,
                color: AppTheme.textTertiary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Phase 0: Style Select
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStyleSelect() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StyleSelector(
        onStyleSelected: (style, {franchiseName}) =>
            _onStyleSelected(style, franchiseName: franchiseName),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Phase 1: Loading
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLoading() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, _) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      AppTheme.accentPurple,
                      AppTheme.accentCyan,
                      AppTheme.accentPurple,
                    ],
                    stops: [
                      (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                      _shimmerCtrl.value,
                      (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: Icon(
                  Icons.auto_stories,
                  size: 64,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Crafting your story...',
            style: AppTheme.headerStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _franchiseName != null
                ? 'Summoning characters from $_franchiseName'
                : 'Recalling your learning history...',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.surfaceLight,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.accentPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 56,
              color: AppTheme.accentMagenta.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: AppTheme.bodyStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            NeonButton(
              label: 'RETRY',
              icon: Icons.refresh,
              onTap: () {
                setState(() {
                  _errorMessage = null;
                });
                _generateStory();
              },
            ),
            const SizedBox(height: 12),
            NeonButton(
              label: 'CLASSIC LESSON',
              icon: Icons.menu_book,
              colors: const [AppTheme.accentOrange, AppTheme.accentMagenta],
              onTap: _fallbackToClassicLesson,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Phase 2: Story (Visual Novel)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStory() {
    if (_storyResponse == null) return const SizedBox.shrink();
    final scene = _storyResponse!.scenes[_currentSceneIndex];

    return GestureDetector(
      onTap: _onStoryTap,
      behavior: HitTestBehavior.opaque,
      child: FadeTransition(
        opacity: _fadeCtrl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Progress bar
              StoryProgressBar(
                totalScenes: _storyResponse!.scenes.length,
                currentScene: _currentSceneIndex,
                accentColor: _speakerColor,
              ),
              const SizedBox(height: 16),

              // Story title
              if (_storyResponse!.title.isNotEmpty) ...[
                Text(
                  _storyResponse!.title,
                  style: AppTheme.headerStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Character portrait with entrance animation
              Expanded(
                flex: 2,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _portraitCtrl,
                    builder: (context, _) {
                      final bounceProgress =
                          Curves.elasticOut.transform(_portraitCtrl.value);
                      return Transform.scale(
                        scale: 0.3 + 0.7 * bounceProgress,
                        child: Opacity(
                          opacity: _portraitCtrl.value.clamp(0.0, 1.0),
                          child: _buildCharacterPortrait(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Speech bubble with slide-in
              Expanded(
                flex: 3,
                child: AnimatedBuilder(
                  animation: _sceneSlideCtrl,
                  builder: (context, _) {
                    final slideProgress =
                        Curves.easeOutCubic.transform(_sceneSlideCtrl.value);
                    return Transform.translate(
                      offset: Offset(30 * (1 - slideProgress), 0),
                      child: Opacity(
                        opacity: slideProgress,
                        child: SingleChildScrollView(
                          child: SpeechBubble(
                            text: scene.dialogue,
                            visibleCharCount: _visibleCharCount,
                            narration: scene.narration,
                            accentColor: _speakerColor,
                            isComplete: _typewriterComplete,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Scene counter with pulse hint
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _currentSceneIndex ==
                            _storyResponse!.scenes.length - 1 &&
                        _typewriterComplete
                    ? 1.0
                    : 0.0,
                child: Text(
                  'Tap to start quiz',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: AppTheme.accentCyan.withAlpha(150),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Character portrait with pulsing glow ring and floating orbs.
  Widget _buildCharacterPortrait() {
    String? currentCharId;
    if (_storyResponse != null &&
        _currentSceneIndex < _storyResponse!.scenes.length) {
      currentCharId = _storyResponse!.scenes[_currentSceneIndex].characterId;
    }

    final imageBytes = currentCharId != null
        ? _characterImages[currentCharId]
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing glow ring
              AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (context, _) {
                  final pulse = sin(_shimmerCtrl.value * pi * 2);
                  return Container(
                    width: 150 + pulse * 6,
                    height: 150 + pulse * 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _speakerColor.withAlpha((60 + pulse * 30).round()),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _speakerColor.withAlpha((40 + pulse * 25).round()),
                          blurRadius: 20 + pulse * 8,
                          spreadRadius: 2 + pulse * 3,
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Orbiting dots
              AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(160, 160),
                    painter: _OrbitingDotsPainter(
                      progress: _shimmerCtrl.value,
                      color: _speakerColor,
                      dotCount: 5,
                    ),
                  );
                },
              ),
              // Main portrait
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _speakerColor, width: 2.5),
                ),
                child: ClipOval(
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes,
                          width: 130,
                          height: 130,
                          fit: BoxFit.cover,
                        )
                      : AnimatedBuilder(
                          animation: _shimmerCtrl,
                          builder: (context, _) {
                            final angle = _shimmerCtrl.value * pi * 2;
                            return Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  startAngle: angle,
                                  endAngle: angle + pi * 2,
                                  colors: [
                                    _speakerColor.withAlpha(60),
                                    _speakerColor.withAlpha(15),
                                    AppTheme.accentPurple.withAlpha(30),
                                    _speakerColor.withAlpha(15),
                                    _speakerColor.withAlpha(60),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      _speakerColor,
                                      Colors.white.withAlpha(220),
                                      _speakerColor,
                                    ],
                                    stops: [
                                      0.0,
                                      (0.3 + _shimmerCtrl.value * 0.4).clamp(0.0, 1.0),
                                      1.0,
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    _speakerName.isNotEmpty
                                        ? _speakerName[0].toUpperCase()
                                        : '?',
                                    style: AppTheme.headerStyle(
                                      fontSize: 52,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Name with shimmer
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, _) {
            return ShaderMask(
              shaderCallback: (bounds) {
                final shift = _shimmerCtrl.value * bounds.width * 2;
                return LinearGradient(
                  colors: [
                    _speakerColor,
                    _speakerColor.withAlpha(180),
                    Colors.white,
                    _speakerColor.withAlpha(180),
                    _speakerColor,
                  ],
                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                  transform: GradientRotation(shift / bounds.width),
                ).createShader(bounds);
              },
              child: Text(
                _speakerName,
                style: AppTheme.headerStyle(
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            );
          },
        ),
        if (_speakerRole.isNotEmpty)
          Text(
            _speakerRole,
            style: AppTheme.bodyStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Phase 3: Quiz
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildQuiz() {
    if (_storyResponse == null || _storyResponse!.quiz.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No quiz questions generated',
              style: AppTheme.bodyStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            NeonButton(
              label: 'FINISH',
              onTap: _showResults,
            ),
          ],
        ),
      );
    }

    final question = _storyResponse!.quiz[_currentQuestionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_storyResponse!.quiz.length, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i <= _currentQuestionIndex
                      ? AppTheme.accentCyan
                      : AppTheme.surfaceLight,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Question
          Text(
            'QUESTION ${_currentQuestionIndex + 1}',
            style: AppTheme.headerStyle(
              fontSize: 12,
              color: AppTheme.accentCyan,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: AppTheme.bodyStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Options with feedback animation
          ...List.generate(question.options.length, (i) {
            final isSelected = _selectedAnswerIndex == i;
            final isCorrect = i == question.correctIndex;

            Color borderColor = AppTheme.glassBorder;
            Color bgColor = Colors.transparent;

            if (_answerRevealed) {
              if (isCorrect) {
                borderColor = AppTheme.accentGreen;
                bgColor = AppTheme.accentGreen.withAlpha(20);
              } else if (isSelected && !isCorrect) {
                borderColor = AppTheme.accentMagenta;
                bgColor = AppTheme.accentMagenta.withAlpha(20);
              }
            } else if (isSelected) {
              borderColor = AppTheme.accentCyan;
              bgColor = AppTheme.accentCyan.withAlpha(15);
            }

            // Apply shake or glow animation on the selected/correct option
            Widget optionWidget = GlassContainer(
              borderColor: borderColor,
              onTap: _answerRevealed
                  ? null
                  : () => _onAnswerSelected(i),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Container(
                color: bgColor,
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: borderColor,
                          width: 1.5,
                        ),
                        color: bgColor,
                      ),
                      child: Center(
                        child: _answerRevealed && isCorrect
                            ? const Icon(Icons.check,
                                color: AppTheme.accentGreen, size: 16)
                            : _answerRevealed && isSelected && !isCorrect
                                ? const Icon(Icons.close,
                                    color: AppTheme.accentMagenta, size: 16)
                                : Text(
                                    String.fromCharCode(65 + i), // A, B, C, D
                                    style: AppTheme.headerStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? AppTheme.accentCyan
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question.options[i],
                        style: AppTheme.bodyStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            // Wrap selected wrong answer with shake, correct with scale pulse
            if (_answerRevealed && isSelected && !isCorrect) {
              optionWidget = AnimatedBuilder(
                animation: _quizFeedbackCtrl,
                builder: (context, child) {
                  final shake = sin(_quizFeedbackCtrl.value * pi * 4) *
                      6 *
                      (1 - _quizFeedbackCtrl.value);
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: child,
                  );
                },
                child: optionWidget,
              );
            } else if (_answerRevealed && isCorrect) {
              optionWidget = AnimatedBuilder(
                animation: _quizFeedbackCtrl,
                builder: (context, child) {
                  final pulse = 1.0 +
                      sin(_quizFeedbackCtrl.value * pi) * 0.04;
                  return Transform.scale(
                    scale: pulse,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGreen
                                .withAlpha((80 * (1 - _quizFeedbackCtrl.value)).round()),
                            blurRadius: 16 * (1 - _quizFeedbackCtrl.value),
                            spreadRadius: 2 * (1 - _quizFeedbackCtrl.value),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: optionWidget,
              );
            }

            // Staggered slide-up entrance for each option
            return AnimatedBuilder(
              animation: _sceneSlideCtrl,
              builder: (context, child) {
                final delay = i * 0.15;
                final progress = ((_sceneSlideCtrl.value - delay) / (1.0 - delay))
                    .clamp(0.0, 1.0);
                final eased = Curves.easeOutBack.transform(progress);
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - eased)),
                  child: Opacity(
                    opacity: progress,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: optionWidget,
              ),
            );
          }),

          // Explanation
          if (_answerRevealed) ...[
            const SizedBox(height: 8),
            GlassContainer(
              borderColor: AppTheme.accentGold.withAlpha(60),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: AppTheme.accentGold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Explanation',
                        style: AppTheme.headerStyle(
                          fontSize: 12,
                          color: AppTheme.accentGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: AppTheme.bodyStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: NeonButton(
                label: _currentQuestionIndex < _storyResponse!.quiz.length - 1
                    ? 'NEXT QUESTION'
                    : 'SEE RESULTS',
                icon: Icons.arrow_forward,
                onTap: _nextQuestion,
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Phase 4: Results
  // ═══════════════════════════════════════════════════════════════════════

  Widget _xpRow(String label, int xp, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: bold ? AppTheme.accentGold : AppTheme.textSecondary,
            ),
          ),
          Text(
            '+$xp XP',
            style: GoogleFonts.orbitron(
              fontSize: bold ? 13 : 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.accentGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final totalQuestions = _storyResponse?.quiz.length ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated shimmer title
            AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (context, _) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    final shift = _shimmerCtrl.value * bounds.width * 3;
                    return LinearGradient(
                      colors: [
                        AppTheme.accentGold,
                        Colors.white,
                        AppTheme.accentGold,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      begin: Alignment(-1.0 + shift / bounds.width, 0),
                      end: Alignment(1.0 + shift / bounds.width, 0),
                    ).createShader(bounds);
                  },
                  child: Text(
                    'STORY COMPLETE',
                    style: AppTheme.headerStyle(
                      fontSize: 22,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            if (_storyResponse != null)
              Text(
                _storyResponse!.title,
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),

            // Stars
            AnimatedBuilder(
              animation: _starCtrl,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final delay = i * 0.25;
                    final progress =
                        ((_starCtrl.value - delay) / (1 - delay))
                            .clamp(0.0, 1.0);
                    final filled = i < _stars;

                    return Transform.scale(
                      scale: filled ? 0.5 + 0.5 * Curves.elasticOut.transform(progress) : 1.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          filled ? Icons.star : Icons.star_border,
                          size: 48,
                          color: filled
                              ? AppTheme.accentGold
                              : AppTheme.textTertiary,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 24),

            // Score
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderColor: AppTheme.accentCyan.withAlpha(50),
              child: Column(
                children: [
                  Text(
                    'QUIZ SCORE',
                    style: AppTheme.headerStyle(
                      fontSize: 11,
                      color: AppTheme.accentCyan,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_correctCount / $totalQuestions',
                    style: GoogleFonts.orbitron(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, color: AppTheme.accentGold, size: 22),
                      const SizedBox(width: 6),
                      AnimatedCounter(
                        value: _xpEarned,
                        suffix: ' XP',
                        style: GoogleFonts.orbitron(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentGold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Celebration for perfect score
            if (_stars == 3) ...[
              AnimatedBuilder(
                animation: _celebrationCtrl,
                builder: (context, _) {
                  if (_celebrationCtrl.value == 0) {
                    return const SizedBox.shrink();
                  }
                  final scale = Curves.elasticOut
                      .transform((_celebrationCtrl.value * 3).clamp(0.0, 1.0));
                  return Column(
                    children: [
                      // Confetti burst
                      SizedBox(
                        height: 60,
                        width: 200,
                        child: CustomPaint(
                          painter: _ConfettiPainter(
                            progress: _celebrationCtrl.value,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: scale,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppTheme.accentGold, AppTheme.accentOrange],
                          ).createShader(bounds),
                          child: Text(
                            'PERFECT SCORE!',
                            style: AppTheme.headerStyle(
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // XP Breakdown
            GlassContainer(
              padding: const EdgeInsets.all(14),
              borderColor: AppTheme.accentGold.withAlpha(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'XP BREAKDOWN',
                    style: AppTheme.headerStyle(
                      fontSize: 9,
                      color: AppTheme.accentGold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _xpRow('Lesson completed', AppConstants.xpCompleteStory),
                  if (_stars == 3)
                    _xpRow('Perfect bonus', 15),
                  _xpRow(
                    'TOTAL',
                    _xpEarned,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Root Cause Analysis
            RootCauseCard(
              topic: _isCustomTopic
                  ? widget.customTopic!
                  : (_lesson?.title ?? widget.subjectId),
              accuracy: totalQuestions > 0
                  ? (_correctCount / totalQuestions * 100).round()
                  : 0,
              missedQuestions: _missedQuestions,
              conceptsCovered: _storyResponse?.scenes
                      .where((s) => s.conceptTag != null && s.conceptTag!.isNotEmpty)
                      .map((s) => s.conceptTag!)
                      .toSet()
                      .toList() ??
                  [],
            ),
            const SizedBox(height: 24),

            NeonButton(
              label: 'DONE',
              icon: Icons.check_circle,
              onTap: _navigateBack,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Paints falling confetti particles for the perfect score celebration.
class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter({required this.progress});

  static final _rng = Random(42);
  static final List<_ConfettiParticle> _particles = List.generate(30, (i) {
    return _ConfettiParticle(
      x: _rng.nextDouble(),
      speed: 0.3 + _rng.nextDouble() * 0.7,
      size: 3 + _rng.nextDouble() * 4,
      color: [
        AppTheme.accentGold,
        AppTheme.accentCyan,
        AppTheme.accentGreen,
        AppTheme.accentMagenta,
        AppTheme.accentPurple,
        AppTheme.accentOrange,
      ][i % 6],
      angle: _rng.nextDouble() * pi * 2,
      drift: (_rng.nextDouble() - 0.5) * 0.3,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress * p.speed).clamp(0.0, 1.0);
      final fadeOut = (1 - progress).clamp(0.0, 1.0);
      final x = size.width * p.x + sin(t * pi * 2) * 20 * p.drift;
      final y = -10 + size.height * 1.2 * t;
      final rotation = p.angle + progress * pi * 3;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color.withAlpha((200 * fadeOut).round());
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _ConfettiParticle {
  final double x, speed, size, angle, drift;
  final Color color;
  const _ConfettiParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.angle,
    required this.drift,
  });
}

/// Paints small glowing dots orbiting around the character portrait.
class _OrbitingDotsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int dotCount;

  _OrbitingDotsPainter({
    required this.progress,
    required this.color,
    this.dotCount = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    for (int i = 0; i < dotCount; i++) {
      final baseAngle = (i / dotCount) * pi * 2;
      // Each dot orbits at slightly different speed
      final speed = 1.0 + i * 0.3;
      final angle = baseAngle + progress * pi * 2 * speed;

      // Varying orbit radius for depth
      final orbitRadius = radius + sin(progress * pi * 2 + i) * 4;

      final x = center.dx + cos(angle) * orbitRadius;
      final y = center.dy + sin(angle) * orbitRadius;

      // Dot size pulses
      final dotSize = 2.0 + sin(progress * pi * 4 + i * 1.5) * 1.0;

      // Fade based on position (fainter when behind)
      final alpha = (0.3 + 0.7 * ((sin(angle) + 1) / 2)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withAlpha((alpha * 180).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), dotSize, paint);

      // Small trail
      final trailAngle = angle - 0.3;
      final tx = center.dx + cos(trailAngle) * orbitRadius;
      final ty = center.dy + sin(trailAngle) * orbitRadius;
      canvas.drawCircle(
        Offset(tx, ty),
        dotSize * 0.5,
        Paint()..color = color.withAlpha((alpha * 60).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitingDotsPainter old) => old.progress != progress;
}
