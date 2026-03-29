import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/forum_post_model.dart';

// ─── State ──────────────────────────────────────────────────────────────

class _PostDetailState {
  final ForumPostModel post;
  final bool isLoading;
  final String solutionDraft;
  final bool isSubmitting;

  const _PostDetailState({
    required this.post,
    this.isLoading = false,
    this.solutionDraft = '',
    this.isSubmitting = false,
  });

  _PostDetailState copyWith({
    ForumPostModel? post,
    bool? isLoading,
    String? solutionDraft,
    bool? isSubmitting,
  }) {
    return _PostDetailState(
      post: post ?? this.post,
      isLoading: isLoading ?? this.isLoading,
      solutionDraft: solutionDraft ?? this.solutionDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────

class ForumPostScreen extends StatefulWidget {
  const ForumPostScreen({super.key, required this.post});

  final ForumPostModel post;

  @override
  State<ForumPostScreen> createState() => _ForumPostScreenState();
}

class _ForumPostScreenState extends State<ForumPostScreen> {
  late _PostDetailState _state;
  final _solutionController = TextEditingController();
  final _scrollController = ScrollController();

  // TODO: Replace with actual current user ID from auth service
  final String _currentUserId = 'current_user';

  @override
  void initState() {
    super.initState();
    _state = _PostDetailState(post: widget.post);
  }

  @override
  void dispose() {
    _solutionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _vote(bool isUpvote) {
    setState(() {
      _state = _state.copyWith(
        post: _state.post.copyWith(
          upvotes: isUpvote ? _state.post.upvotes + 1 : _state.post.upvotes,
          downvotes:
              !isUpvote ? _state.post.downvotes + 1 : _state.post.downvotes,
        ),
      );
    });
    // TODO: Call vote service
  }

  void _voteSolution(String solutionId, bool isUpvote) {
    setState(() {
      final updated = _state.post.solutions.map((s) {
        if (s.id != solutionId) return s;
        return s.copyWith(
          upvotes: isUpvote ? s.upvotes + 1 : s.upvotes,
          downvotes: !isUpvote ? s.downvotes + 1 : s.downvotes,
        );
      }).toList();
      _state = _state.copyWith(
        post: _state.post.copyWith(solutions: updated),
      );
    });
  }

  void _acceptSolution(String solutionId) {
    setState(() {
      final updated = _state.post.solutions.map((s) {
        return s.copyWith(isAccepted: s.id == solutionId);
      }).toList();
      _state = _state.copyWith(
        post: _state.post.copyWith(
          solutions: updated,
          isResolved: true,
          bestSolutionId: solutionId,
        ),
      );
    });
    // TODO: Call accept service
  }

  Future<void> _submitSolution() async {
    if (_state.solutionDraft.trim().isEmpty) return;
    setState(() => _state = _state.copyWith(isSubmitting: true));
    try {
      // TODO: Replace with actual service call
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final newSolution = ForumSolution(
        id: 'sol_new_${DateTime.now().millisecondsSinceEpoch}',
        content: _state.solutionDraft.trim(),
        authorId: _currentUserId,
        authorUsername: 'You',
        createdAt: DateTime.now(),
      );
      setState(() {
        _state = _state.copyWith(
          post: _state.post.copyWith(
            solutions: [..._state.post.solutions, newSolution],
          ),
          solutionDraft: '',
          isSubmitting: false,
        );
      });
      _solutionController.clear();
      // Scroll to bottom to show new solution
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() => _state = _state.copyWith(isSubmitting: false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: AppTheme.accentMagenta,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _state.post;
    final isAuthor = post.authorId == _currentUserId;
    // Sort solutions: accepted first, then by score
    final sortedSolutions = List<ForumSolution>.from(post.solutions)
      ..sort((a, b) {
        if (a.isAccepted && !b.isAccepted) return -1;
        if (!a.isAccepted && b.isAccepted) return 1;
        return b.score.compareTo(a.score);
      });

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
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
                    if (post.isResolved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.accentGreen.withAlpha(70)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.accentGreen, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Resolved',
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentGreen,
                              ),
                            ),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Post card ──
                      _PostContentCard(
                        post: post,
                        onUpvote: () => _vote(true),
                        onDownvote: () => _vote(false),
                      ),
                      const SizedBox(height: 16),

                      // ── Author info ──
                      _AuthorInfoCard(
                        username: post.authorUsername,
                        createdAt: post.createdAt,
                      ),
                      const SizedBox(height: 24),

                      // ── Solutions header ──
                      Row(
                        children: [
                          Text(
                            'Solutions (${post.solutionCount})',
                            style: AppTheme.headerStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          if (post.solutionCount > 0)
                            Text(
                              'Sorted by votes',
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Solutions list ──
                      if (sortedSolutions.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(Icons.question_answer_outlined,
                                    color: AppTheme.textDisabled, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'No solutions yet. Be the first!',
                                  style: AppTheme.bodyStyle(
                                      color: AppTheme.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...sortedSolutions.map((solution) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SolutionCard(
                                solution: solution,
                                isPostAuthor: isAuthor,
                                onUpvote: () =>
                                    _voteSolution(solution.id, true),
                                onDownvote: () =>
                                    _voteSolution(solution.id, false),
                                onAccept: isAuthor && !solution.isAccepted
                                    ? () => _acceptSolution(solution.id)
                                    : null,
                              ),
                            )),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Add solution input (bottom) ──
              _SolutionInput(
                controller: _solutionController,
                isSubmitting: _state.isSubmitting,
                onChanged: (v) =>
                    setState(() => _state = _state.copyWith(solutionDraft: v)),
                onSubmit: _submitSolution,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Private widgets ────────────────────────────────────────────────────

class _PostContentCard extends StatelessWidget {
  const _PostContentCard({
    required this.post,
    required this.onUpvote,
    required this.onDownvote,
  });

  final ForumPostModel post;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  @override
  Widget build(BuildContext context) {
    final isPositive = post.score > 0;
    final isNegative = post.score < 0;
    final scoreColor = isPositive
        ? AppTheme.accentCyan
        : isNegative
            ? AppTheme.accentMagenta
            : AppTheme.textTertiary;

    return GlassMorphism(
      borderRadius: 18,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            post.title,
            style: AppTheme.headerStyle(fontSize: 18),
          ),
          const SizedBox(height: 4),
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              post.category.toUpperCase(),
              style: AppTheme.bodyStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentPurple,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content (markdown-like)
          Text(
            post.content,
            style: AppTheme.bodyStyle(
              color: AppTheme.textSecondary,
              height: 1.7,
            ),
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.tags.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.glassFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Text(
                    '#$tag',
                    style: AppTheme.bodyStyle(
                      fontSize: 10,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          // Vote row
          Row(
            children: [
              GestureDetector(
                onTap: onUpvote,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.accentCyan.withAlpha(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded,
                          color: AppTheme.accentCyan, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${post.upvotes}',
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${post.score}',
                style: AppTheme.bodyStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDownvote,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentMagenta.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.accentMagenta.withAlpha(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded,
                          color: AppTheme.accentMagenta, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${post.downvotes}',
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentMagenta,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthorInfoCard extends StatelessWidget {
  const _AuthorInfoCard({required this.username, required this.createdAt});
  final String username;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism.subtle(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: AppTheme.headerStyle(
                  fontSize: 14,
                  color: AppTheme.backgroundPrimary,
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
                  username,
                  style: AppTheme.bodyStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _timeAgo(createdAt),
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // League badge placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentGold, AppTheme.accentOrange],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: AppTheme.backgroundPrimary, size: 12),
                const SizedBox(width: 3),
                Text(
                  'Gold',
                  style: AppTheme.bodyStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.backgroundPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionCard extends StatelessWidget {
  const _SolutionCard({
    required this.solution,
    required this.isPostAuthor,
    required this.onUpvote,
    required this.onDownvote,
    this.onAccept,
  });

  final ForumSolution solution;
  final bool isPostAuthor;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism(
      borderRadius: 16,
      borderColor: solution.isAccepted
          ? AppTheme.accentGreen
          : AppTheme.glassBorder,
      borderWidth: solution.isAccepted ? 1.5 : 0.8,
      glowColor: solution.isAccepted ? AppTheme.accentGreen : null,
      glowBlurRadius: solution.isAccepted ? 12 : 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: author, accepted badge
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentPurple.withAlpha(30),
                ),
                child: Center(
                  child: Text(
                    solution.authorUsername.isNotEmpty
                        ? solution.authorUsername[0].toUpperCase()
                        : '?',
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentPurple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                solution.authorUsername,
                style: AppTheme.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeAgo(solution.createdAt),
                style: AppTheme.bodyStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
              const Spacer(),
              if (solution.isAccepted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.accentGreen.withAlpha(70)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accentGreen, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        'Accepted',
                        style: AppTheme.bodyStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Solution content
          Text(
            solution.content,
            style: AppTheme.bodyStyle(
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          // Bottom: votes + accept button
          Row(
            children: [
              // Upvote
              GestureDetector(
                onTap: onUpvote,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withAlpha(12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded,
                          color: AppTheme.accentCyan, size: 15),
                      const SizedBox(width: 2),
                      Text(
                        '${solution.upvotes}',
                        style: AppTheme.bodyStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${solution.score}',
                style: AppTheme.bodyStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: solution.score >= 0
                      ? AppTheme.accentCyan
                      : AppTheme.accentMagenta,
                ),
              ),
              const SizedBox(width: 6),
              // Downvote
              GestureDetector(
                onTap: onDownvote,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentMagenta.withAlpha(12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded,
                          color: AppTheme.accentMagenta, size: 15),
                      const SizedBox(width: 2),
                      Text(
                        '${solution.downvotes}',
                        style: AppTheme.bodyStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentMagenta,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Accept button
              if (onAccept != null)
                GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.accentGreen.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: AppTheme.accentGreen, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Accept',
                          style: AppTheme.bodyStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SolutionInput extends StatelessWidget {
  const _SolutionInput({
    required this.controller,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism.subtle(
      borderRadius: 0,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Formatting toolbar hint
          Row(
            children: [
              Text(
                'Supports markdown formatting',
                style: AppTheme.bodyStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
              const Spacer(),
              Icon(Icons.format_bold_rounded,
                  size: 16, color: AppTheme.textDisabled),
              const SizedBox(width: 8),
              Icon(Icons.format_italic_rounded,
                  size: 16, color: AppTheme.textDisabled),
              const SizedBox(width: 8),
              Icon(Icons.code_rounded,
                  size: 16, color: AppTheme.textDisabled),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: GlassMorphism(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    maxLines: 4,
                    minLines: 1,
                    style: AppTheme.bodyStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Write your solution...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow:
                      AppTheme.neonGlow(AppTheme.accentCyan, blur: 8),
                ),
                child: IconButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.backgroundPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: AppTheme.backgroundPrimary, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}
