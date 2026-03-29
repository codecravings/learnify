import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

/// The 5 reaction types available on feed posts.
enum ReactionType {
  fire('fire', '🔥'),
  brain('brain', '🧠'),
  clap('clap', '👏'),
  perfect('perfect', '💯'),
  heart('heart', '❤️');

  const ReactionType(this.key, this.emoji);
  final String key;
  final String emoji;
}

/// Horizontal row of emoji reaction buttons with counts.
///
/// Shows each reaction with its count. The currently selected reaction
/// (if any) is highlighted. Tapping toggles the reaction.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.reactions,
    required this.currentUid,
    required this.onReact,
    this.totalCount = 0,
  });

  /// Map of reaction type key -> list of UIDs who reacted.
  final Map<String, List<String>> reactions;

  /// Current user's UID to determine which reaction is active.
  final String? currentUid;

  /// Callback when user taps a reaction.
  final void Function(ReactionType type) onReact;

  /// Total reaction count (for display).
  final int totalCount;

  /// Which reaction the current user has selected (null if none).
  ReactionType? get _myReaction {
    if (currentUid == null) return null;
    for (final type in ReactionType.values) {
      final uids = reactions[type.key] ?? [];
      if (uids.contains(currentUid)) return type;
    }
    return null;
  }

  int _countFor(ReactionType type) => (reactions[type.key] ?? []).length;

  @override
  Widget build(BuildContext context) {
    final myReaction = _myReaction;

    return Row(
      children: [
        // Reaction chips
        for (final type in ReactionType.values) ...[
          _ReactionChip(
            type: type,
            count: _countFor(type),
            isSelected: myReaction == type,
            onTap: () => onReact(type),
          ),
          const SizedBox(width: 6),
        ],
        const Spacer(),
        // Total count
        if (totalCount > 0)
          Text(
            '$totalCount',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiaryOf(context),
            ),
          ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.type,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final ReactionType type;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentCyanOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? accent.withAlpha(25)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? accent.withAlpha(80)
                : AppTheme.glassBorderOf(context),
            width: isSelected ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 14)),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? accent
                      : AppTheme.textTertiaryOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
