import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/challenge_model.dart';

/// Maps each [ChallengeType] to its icon and accent color.
class ChallengeTypeStyle {
  final IconData icon;
  final Color color;

  const ChallengeTypeStyle({required this.icon, required this.color});

  static ChallengeTypeStyle fromType(ChallengeType type) {
    switch (type) {
      case ChallengeType.logic:
        return const ChallengeTypeStyle(
          icon: Icons.psychology_outlined,
          color: AppTheme.accentCyan,
        );
      case ChallengeType.coding:
        return const ChallengeTypeStyle(
          icon: Icons.code_rounded,
          color: AppTheme.accentGreen,
        );
      case ChallengeType.reasoning:
        return const ChallengeTypeStyle(
          icon: Icons.lightbulb_outline_rounded,
          color: AppTheme.accentPurple,
        );
      case ChallengeType.cybersecurity:
        return const ChallengeTypeStyle(
          icon: Icons.security_rounded,
          color: AppTheme.accentMagenta,
        );
      case ChallengeType.math:
        return const ChallengeTypeStyle(
          icon: Icons.functions_rounded,
          color: AppTheme.accentGold,
        );
    }
  }
}

/// Reusable challenge card with glassmorphism, type-colored glow,
/// difficulty stars, XP badge, solve count, creator, and tags.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    this.onTap,
  });

  final ChallengeModel challenge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = ChallengeTypeStyle.fromType(challenge.type);
    final successRate = challenge.attemptCount > 0
        ? (challenge.solveCount / challenge.attemptCount * 100).toStringAsFixed(0)
        : '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassMorphism.glow(
        glowColor: style.color,
        glowBlurRadius: 16,
        borderRadius: 18,
        borderColor: style.color.withAlpha(60),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: icon, title, XP badge ──
                  Row(
                    children: [
                      // Type icon with colored glow
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: style.color.withAlpha(30),
                          boxShadow: [
                            BoxShadow(
                              color: style.color.withAlpha(50),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(style.icon, color: style.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      // Title + difficulty
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              style: AppTheme.bodyStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            _DifficultyStars(
                              difficulty: challenge.difficulty,
                              color: style.color,
                            ),
                          ],
                        ),
                      ),
                      // XP badge
                      _XpBadge(xp: challenge.xpReward),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Bottom row: solve count, creator, tags ──
                  Row(
                    children: [
                      // Solve count
                      _StatChip(
                        icon: Icons.check_circle_outline_rounded,
                        label: '${challenge.solveCount} solves',
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(width: 10),
                      // Success rate
                      _StatChip(
                        icon: Icons.percent_rounded,
                        label: '$successRate%',
                        color: AppTheme.accentCyan,
                      ),
                      const Spacer(),
                      // Creator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            challenge.creatorUsername,
                            style: AppTheme.bodyStyle(
                              fontSize: 11,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Tags row
                  if (challenge.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: challenge.tags.take(4).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.glassFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.glassBorder,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: AppTheme.bodyStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private helper widgets ──────────────────────────────────────────────

class _DifficultyStars extends StatelessWidget {
  const _DifficultyStars({required this.difficulty, required this.color});
  final int difficulty;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < difficulty;
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14,
            color: filled ? color : AppTheme.textDisabled,
          ),
        );
      }),
    );
  }
}

class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentGold, AppTheme.accentOrange],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withAlpha(50),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        '+$xp XP',
        style: AppTheme.bodyStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.backgroundPrimary,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTheme.bodyStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}
