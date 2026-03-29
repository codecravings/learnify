import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/challenge_model.dart';
import 'package:vidyasetu/features/challenges/widgets/challenge_card.dart';

// ─── State ──────────────────────────────────────────────────────────────

class _DetailState {
  final bool isLoading;
  final bool isSolved;
  final bool showSolution;
  final int? selectedHintLevel; // null = no hint shown
  final String answer;
  final String? submitError;
  final bool submitting;
  final List<_Comment> comments;

  const _DetailState({
    this.isLoading = false,
    this.isSolved = false,
    this.showSolution = false,
    this.selectedHintLevel,
    this.answer = '',
    this.submitError,
    this.submitting = false,
    this.comments = const [],
  });

  _DetailState copyWith({
    bool? isLoading,
    bool? isSolved,
    bool? showSolution,
    int? selectedHintLevel,
    String? answer,
    String? submitError,
    bool? submitting,
    List<_Comment>? comments,
    bool clearHint = false,
    bool clearError = false,
  }) {
    return _DetailState(
      isLoading: isLoading ?? this.isLoading,
      isSolved: isSolved ?? this.isSolved,
      showSolution: showSolution ?? this.showSolution,
      selectedHintLevel:
          clearHint ? null : (selectedHintLevel ?? this.selectedHintLevel),
      answer: answer ?? this.answer,
      submitError:
          clearError ? null : (submitError ?? this.submitError),
      submitting: submitting ?? this.submitting,
      comments: comments ?? this.comments,
    );
  }
}

class _Comment {
  final String id;
  final String username;
  final String text;
  final DateTime createdAt;

  const _Comment({
    required this.id,
    required this.username,
    required this.text,
    required this.createdAt,
  });
}

// ─── Screen ─────────────────────────────────────────────────────────────

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key, this.challenge});

  final dynamic challenge;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final _answerController = TextEditingController();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  var _state = const _DetailState();

  ChallengeModel get challenge => widget.challenge is ChallengeModel
      ? widget.challenge as ChallengeModel
      : ChallengeModel(
          id: 'demo',
          title: 'Demo Challenge',
          description: 'This is a placeholder challenge for demonstration purposes.',
          difficulty: 2,
          type: ChallengeType.logic,
          solution: 'demo',
          hints: ['Think logically', 'Break it down', 'Try step by step'],
          tags: ['demo', 'placeholder'],
          creatorId: 'system',
          creatorUsername: 'System',
          xpReward: 10,
          createdAt: DateTime.now(),
        );

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    // TODO: Replace with actual service call
    setState(() => _state = _state.copyWith(
          comments: List.generate(
            3,
            (i) => _Comment(
              id: 'c_$i',
              username: 'user_$i',
              text: 'Great challenge! Took me a while to figure out the edge case.',
              createdAt: DateTime.now().subtract(Duration(hours: i * 3)),
            ),
          ),
        ));
  }

  Future<void> _submit() async {
    if (_state.answer.trim().isEmpty) return;
    setState(() => _state = _state.copyWith(submitting: true, clearError: true));
    try {
      // TODO: Replace with actual validation service
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final correct =
          _state.answer.trim().toLowerCase() == challenge.solution.toLowerCase();
      if (correct) {
        setState(() => _state = _state.copyWith(
              isSolved: true,
              showSolution: true,
              submitting: false,
            ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.celebration_rounded,
                      color: AppTheme.accentGreen),
                  const SizedBox(width: 8),
                  Text('Correct! +${challenge.xpReward} XP earned',
                      style: AppTheme.bodyStyle(
                          fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: AppTheme.surfaceLight,
            ),
          );
        }
      } else {
        setState(() => _state = _state.copyWith(
              submitError: 'Incorrect answer. Try again!',
              submitting: false,
            ));
      }
    } catch (e) {
      setState(() => _state = _state.copyWith(
            submitError: e.toString(),
            submitting: false,
          ));
    }
  }

  void _showHintSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassMorphism(
          blur: 20,
          borderRadius: 24,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Hint Level',
                  style: AppTheme.headerStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.accentOrange.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppTheme.accentOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using hints reduces XP reward.',
                        style: AppTheme.bodyStyle(
                          fontSize: 12,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                challenge.hints.length.clamp(0, 3),
                (i) {
                  final xpReduction = ['10%', '25%', '50%'];
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentPurple.withAlpha(30),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: AppTheme.headerStyle(
                            fontSize: 14,
                            color: AppTheme.accentPurple,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      'Hint ${i + 1}',
                      style: AppTheme.bodyStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '-${xpReduction[i]} XP',
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        color: AppTheme.accentMagenta,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      setState(() => _state =
                          _state.copyWith(selectedHintLevel: i + 1));
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeStyle = ChallengeTypeStyle.fromType(challenge.type);
    final successRate = challenge.attemptCount > 0
        ? (challenge.solveCount / challenge.attemptCount * 100)
            .toStringAsFixed(1)
        : '--';
    final avgTimeMin = (challenge.avgSolveTime / 60).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ── Custom app bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.accentCyan, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (_state.isSolved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.accentGreen.withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.accentGreen, size: 14),
                            const SizedBox(width: 4),
                            Text('Solved',
                                style: AppTheme.bodyStyle(
                                  fontSize: 12,
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero header ──
                      _HeroHeader(
                        challenge: challenge,
                        typeStyle: typeStyle,
                      ),
                      const SizedBox(height: 20),

                      // ── Stats row ──
                      _StatsRow(
                        attempts: challenge.attemptCount,
                        solves: challenge.solveCount,
                        successRate: successRate,
                        avgTime: avgTimeMin,
                      ),
                      const SizedBox(height: 20),

                      // ── Description ──
                      GlassMorphism(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Description',
                                style: AppTheme.headerStyle(fontSize: 14)),
                            const SizedBox(height: 10),
                            Text(
                              challenge.description,
                              style: AppTheme.bodyStyle(
                                color: AppTheme.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Hint area ──
                      if (_state.selectedHintLevel != null &&
                          _state.selectedHintLevel! <= challenge.hints.length)
                        _HintDisplay(
                          hintLevel: _state.selectedHintLevel!,
                          hintText:
                              challenge.hints[_state.selectedHintLevel! - 1],
                        ),

                      // ── Answer input ──
                      if (!_state.isSolved) ...[
                        const SizedBox(height: 16),
                        _AnswerSection(
                          controller: _answerController,
                          isCoding: challenge.type == ChallengeType.coding,
                          error: _state.submitError,
                          onChanged: (v) =>
                              setState(() => _state = _state.copyWith(answer: v)),
                          onHint: challenge.hints.isNotEmpty
                              ? _showHintSelector
                              : null,
                          onSubmit: _submit,
                          isSubmitting: _state.submitting,
                        ),
                      ],

                      // ── Solution reveal ──
                      if (_state.showSolution) ...[
                        const SizedBox(height: 20),
                        GlassMorphism.glow(
                          glowColor: AppTheme.accentGreen,
                          glowBlurRadius: 12,
                          borderRadius: 16,
                          borderColor: AppTheme.accentGreen.withAlpha(80),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events_rounded,
                                      color: AppTheme.accentGold, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Solution',
                                      style: AppTheme.headerStyle(
                                        fontSize: 14,
                                        color: AppTheme.accentGreen,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundPrimary
                                      .withAlpha(180),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  challenge.solution,
                                  style: AppTheme.bodyStyle(
                                    color: AppTheme.accentGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Creator info ──
                      const SizedBox(height: 20),
                      _CreatorCard(
                        username: challenge.creatorUsername,
                        xpReward: challenge.xpReward,
                      ),

                      // ── Comments ──
                      const SizedBox(height: 20),
                      _CommentsSection(
                        comments: _state.comments,
                        controller: _commentController,
                        onPost: () {
                          if (_commentController.text.trim().isEmpty) return;
                          setState(() {
                            _state = _state.copyWith(
                              comments: [
                                ..._state.comments,
                                _Comment(
                                  id: 'c_${_state.comments.length}',
                                  username: 'You',
                                  text: _commentController.text.trim(),
                                  createdAt: DateTime.now(),
                                ),
                              ],
                            );
                          });
                          _commentController.clear();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Private widgets ────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.challenge, required this.typeStyle});
  final ChallengeModel challenge;
  final ChallengeTypeStyle typeStyle;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism.glow(
      glowColor: typeStyle.color,
      glowBlurRadius: 20,
      borderRadius: 20,
      borderColor: typeStyle.color.withAlpha(60),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: typeStyle.color.withAlpha(30),
                  boxShadow: [
                    BoxShadow(
                      color: typeStyle.color.withAlpha(60),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child:
                    Icon(typeStyle.icon, color: typeStyle.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.type.name.toUpperCase(),
                      style: AppTheme.bodyStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: typeStyle.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.title,
                      style: AppTheme.headerStyle(fontSize: 18),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Difficulty stars with glow
          Row(
            children: [
              ...List.generate(5, (i) {
                final filled = i < challenge.difficulty;
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 22,
                    color: filled ? AppTheme.accentGold : AppTheme.textDisabled,
                    shadows: filled
                        ? [
                            Shadow(
                              color: AppTheme.accentGold.withAlpha(100),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentGold, AppTheme.accentOrange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${challenge.xpReward} XP',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.backgroundPrimary,
                  ),
                ),
              ),
            ],
          ),
          // Tags
          if (challenge.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: challenge.tags.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeStyle.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: typeStyle.color.withAlpha(50)),
                  ),
                  child: Text(
                    tag,
                    style: AppTheme.bodyStyle(
                      fontSize: 11,
                      color: typeStyle.color,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.attempts,
    required this.solves,
    required this.successRate,
    required this.avgTime,
  });
  final int attempts;
  final int solves;
  final String successRate;
  final String avgTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: Icons.people_outline_rounded,
          label: 'Attempts',
          value: '$attempts',
          color: AppTheme.accentCyan,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.check_circle_outline_rounded,
          label: 'Solves',
          value: '$solves ($successRate%)',
          color: AppTheme.accentGreen,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.timer_outlined,
          label: 'Avg Time',
          value: '${avgTime}m',
          color: AppTheme.accentPurple,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassMorphism(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.bodyStyle(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintDisplay extends StatelessWidget {
  const _HintDisplay({required this.hintLevel, required this.hintText});
  final int hintLevel;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GlassMorphism(
        borderRadius: 14,
        borderColor: AppTheme.accentPurple.withAlpha(60),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_rounded,
                    color: AppTheme.accentPurple, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Hint Level $hintLevel',
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentOrange.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.accentOrange, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'XP reward reduced by ${[10, 25, 50][hintLevel - 1]}%',
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hintText,
              style: AppTheme.bodyStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerSection extends StatelessWidget {
  const _AnswerSection({
    required this.controller,
    required this.isCoding,
    this.error,
    required this.onChanged,
    this.onHint,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final TextEditingController controller;
  final bool isCoding;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback? onHint;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Answer',
              style: AppTheme.headerStyle(fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: isCoding ? 8 : 3,
            style: isCoding
                ? AppTheme.bodyStyle(fontSize: 13).copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  )
                : AppTheme.bodyStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: isCoding
                  ? '// Write your code here...'
                  : 'Type your answer...',
              filled: true,
              fillColor: isCoding
                  ? AppTheme.backgroundPrimary.withAlpha(200)
                  : AppTheme.glassFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: error != null
                      ? AppTheme.accentMagenta
                      : AppTheme.glassBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: error != null
                      ? AppTheme.accentMagenta
                      : AppTheme.glassBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.accentCyan, width: 1.5),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.accentMagenta, size: 14),
                const SizedBox(width: 4),
                Text(
                  error!,
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: AppTheme.accentMagenta,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              // Hint button
              if (onHint != null)
                OutlinedButton.icon(
                  onPressed: onHint,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentPurple,
                    side: const BorderSide(color: AppTheme.accentPurple),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                  label: const Text('Hint'),
                ),
              const Spacer(),
              // Submit button
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.neonGlow(AppTheme.accentCyan, blur: 10),
                ),
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.backgroundPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(isSubmitting ? 'Checking...' : 'Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.username, required this.xpReward});
  final String username;
  final int xpReward;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism(
      borderRadius: 14,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.secondaryGradient,
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: AppTheme.headerStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created by',
                  style: AppTheme.bodyStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
                Text(
                  username,
                  style: AppTheme.bodyStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Challenge Creator',
              style: AppTheme.bodyStyle(
                fontSize: 10,
                color: AppTheme.accentCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.controller,
    required this.onPost,
  });

  final List<_Comment> comments;
  final TextEditingController controller;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments (${comments.length})',
            style: AppTheme.headerStyle(fontSize: 14)),
        const SizedBox(height: 12),
        // Comment input
        GlassMorphism(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTheme.bodyStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: AppTheme.accentCyan, size: 20),
                onPressed: onPost,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Comment list
        ...comments.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassMorphism.subtle(
                borderRadius: 12,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c.username,
                          style: AppTheme.bodyStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(c.createdAt),
                          style: AppTheme.bodyStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.text,
                      style: AppTheme.bodyStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
