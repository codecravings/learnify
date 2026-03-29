import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/forum_post_model.dart';

/// Reusable forum post card with glassmorphism, neon vote buttons,
/// solution count, resolved indicator, and time-ago display.
class ForumPostCard extends StatelessWidget {
  const ForumPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onUpvote,
    this.onDownvote,
  });

  final ForumPostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassMorphism(
        borderRadius: 16,
        borderColor: post.isResolved
            ? AppTheme.accentGreen.withAlpha(50)
            : AppTheme.glassBorder,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Vote column ──
                  _VoteColumn(
                    score: post.score,
                    onUpvote: onUpvote,
                    onDownvote: onDownvote,
                  ),
                  const SizedBox(width: 12),
                  // ── Content column ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with resolved badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.title,
                                style: AppTheme.bodyStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (post.isResolved)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.accentGreen.withAlpha(70),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppTheme.accentGreen, size: 12),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Resolved',
                                      style: AppTheme.bodyStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Preview text
                        Text(
                          post.content,
                          style: AppTheme.bodyStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Bottom row: author, time, solution count
                        Row(
                          children: [
                            // Author
                            Icon(Icons.person_outline_rounded,
                                size: 13, color: AppTheme.textTertiary),
                            const SizedBox(width: 3),
                            Text(
                              post.authorUsername,
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Time
                            Icon(Icons.access_time_rounded,
                                size: 12, color: AppTheme.textTertiary),
                            const SizedBox(width: 3),
                            Text(
                              _timeAgo(post.createdAt),
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                            const Spacer(),
                            // Solution count
                            Icon(Icons.question_answer_outlined,
                                size: 13, color: AppTheme.accentCyan),
                            const SizedBox(width: 3),
                            Text(
                              '${post.solutionCount}',
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                color: AppTheme.accentCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

/// Neon-styled upvote/downvote column a la Reddit.
class _VoteColumn extends StatelessWidget {
  const _VoteColumn({
    required this.score,
    this.onUpvote,
    this.onDownvote,
  });

  final int score;
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;

  @override
  Widget build(BuildContext context) {
    final isPositive = score > 0;
    final isNegative = score < 0;
    final scoreColor = isPositive
        ? AppTheme.accentCyan
        : isNegative
            ? AppTheme.accentMagenta
            : AppTheme.textTertiary;

    return Column(
      children: [
        // Upvote
        GestureDetector(
          onTap: onUpvote,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: AppTheme.accentCyan,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Score
        Text(
          '$score',
          style: AppTheme.bodyStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: scoreColor,
          ),
        ),
        const SizedBox(height: 4),
        // Downvote
        GestureDetector(
          onTap: onDownvote,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentMagenta.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: AppTheme.accentMagenta,
            ),
          ),
        ),
      ],
    );
  }
}
