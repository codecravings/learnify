import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/follow_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../profile/widgets/follow_button.dart';

/// Horizontal scrolling card showing suggested users to follow.
class SuggestedUsersCard extends StatefulWidget {
  const SuggestedUsersCard({super.key});

  @override
  State<SuggestedUsersCard> createState() => _SuggestedUsersCardState();
}

class _SuggestedUsersCardState extends State<SuggestedUsersCard> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await FollowService.instance.getSuggestedUsers(limit: 6);
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _users.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SUGGESTED FOR YOU',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textTertiaryOf(context),
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _SuggestedUserChip(user: _users[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedUserChip extends StatelessWidget {
  const _SuggestedUserChip({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentCyanOf(context);
    final uid = user['uid'] as String? ?? '';
    final name = (user['displayName'] ?? user['username'] ?? 'Learner') as String;
    final photo = user['photoUrl'] as String?;
    final xp = (user['xp'] as num?)?.toInt() ?? 0;

    return GlassContainer(
      borderColor: accent.withAlpha(25),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withAlpha(20),
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? NetworkImage(photo) : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.orbitron(
                        fontSize: 14, fontWeight: FontWeight.w700, color: accent,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            Text(
              '$xp XP',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9, color: AppTheme.textTertiaryOf(context),
              ),
            ),
            const Spacer(),
            if (uid.isNotEmpty) FollowButton(targetUid: uid),
          ],
        ),
      ),
    );
  }
}
