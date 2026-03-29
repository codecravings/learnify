import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/user_model.dart';

/// Glassmorphism opponent display card with avatar, league border,
/// username, win rate, skill rating, and a mini XP bar.
class OpponentCard extends StatelessWidget {
  /// The opponent user data (nullable for loading / empty state).
  final UserModel? user;

  /// Subject key for which to display the skill rating.
  final String subject;

  /// Neon border / glow accent color.
  final Color accentColor;

  /// Whether to show a compact variant (used in battle screen).
  final bool compact;

  const OpponentCard({
    super.key,
    required this.user,
    this.subject = 'general',
    this.accentColor = AppTheme.accentMagenta,
    this.compact = false,
  });

  // League color mapping
  static const _leagueColors = {
    'Bronze': Color(0xFFCD7F32),
    'Silver': Color(0xFFC0C0C0),
    'Gold': Color(0xFFF59E0B),
    'Platinum': Color(0xFF3B82F6),
    'Diamond': Color(0xFF8B5CF6),
    'Master': Color(0xFFEF4444),
  };

  Color get _leagueBorderColor {
    if (user == null) return AppTheme.glassBorder;
    return _leagueColors[user!.league] ?? AppTheme.glassBorder;
  }

  int get _skillRating {
    if (user == null) return 0;
    return user!.skillRatings[subject] ?? 1000;
  }

  String get _winRate {
    if (user == null) return '0%';
    final total = user!.totalBattlesWon + user!.totalBattlesLost;
    if (total == 0) return 'N/A';
    final rate = (user!.totalBattlesWon / total * 100).round();
    return '$rate%';
  }

  /// XP progress within current "level" (every 1000 XP).
  double get _xpProgress {
    if (user == null) return 0;
    return (user!.xp % 1000) / 1000;
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  // ─── Full Card ─────────────────────────────────────────────────────

  Widget _buildFull(BuildContext context) {
    return GlassMorphism.glow(
      glowColor: accentColor,
      glowBlurRadius: 18,
      borderColor: accentColor.withAlpha(80),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(size: 64, borderWidth: 3),
          const SizedBox(height: 14),
          // Username
          Text(
            user?.username ?? '???',
            style: AppTheme.headerStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // League badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _leagueBorderColor.withAlpha(20),
              border: Border.all(color: _leagueBorderColor.withAlpha(80)),
            ),
            child: Text(
              user?.league ?? 'Unranked',
              style: AppTheme.bodyStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _leagueBorderColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('Win Rate', _winRate),
              Container(
                width: 1,
                height: 30,
                color: AppTheme.glassBorder,
              ),
              _buildStat('Skill', '$_skillRating'),
              Container(
                width: 1,
                height: 30,
                color: AppTheme.glassBorder,
              ),
              _buildStat('XP', '${user?.xp ?? 0}'),
            ],
          ),
          const SizedBox(height: 14),
          // Mini XP bar
          _buildXpBar(),
        ],
      ),
    );
  }

  // ─── Compact Card ──────────────────────────────────────────────────

  Widget _buildCompact(BuildContext context) {
    return GlassMorphism(
      borderRadius: 14,
      borderColor: accentColor.withAlpha(60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(size: 36, borderWidth: 2),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user?.username ?? '???',
                style: AppTheme.headerStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user?.league ?? 'Unranked',
                    style: AppTheme.bodyStyle(
                      fontSize: 9,
                      color: _leagueBorderColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ELO $_skillRating',
                    style: AppTheme.bodyStyle(
                      fontSize: 9,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ────────────────────────────────────────────────

  Widget _buildAvatar({required double size, required double borderWidth}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _leagueBorderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: _leagueBorderColor.withAlpha(50),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipOval(
        child: user?.photoUrl.isNotEmpty == true
            ? Image.network(
                user!.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(size),
              )
            : _buildAvatarPlaceholder(size),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(double size) {
    return Container(
      color: accentColor.withAlpha(20),
      child: Icon(
        Icons.person_rounded,
        color: accentColor.withAlpha(150),
        size: size * 0.55,
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTheme.bodyStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.bodyStyle(
            fontSize: 9,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildXpBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL ${(user?.xp ?? 0) ~/ 1000 + 1}',
              style: AppTheme.bodyStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.textTertiary,
              ),
            ),
            Text(
              '${user?.xp ?? 0} / ${((user?.xp ?? 0) ~/ 1000 + 1) * 1000} XP',
              style: AppTheme.bodyStyle(
                fontSize: 9,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: LinearProgressIndicator(
              value: _xpProgress,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation(accentColor.withAlpha(200)),
            ),
          ),
        ),
      ],
    );
  }
}
