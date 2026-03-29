import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/feed_service.dart';
import '../../../core/services/follow_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/suggested_users_card.dart';

// ---------------------------------------------------------------------------
// Social Feed — Instagram/Twitter-style activity feed
// ---------------------------------------------------------------------------
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _currentUid = FirebaseAuth.instance.currentUser?.uid;
  final _composeCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  bool _isPosting = false;
  bool _showFollowing = false;
  List<String> _followingUids = [];

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final uids = await FollowService.instance.getFollowingList();
    if (mounted) setState(() => _followingUids = uids);
  }

  @override
  void dispose() {
    _composeCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  void _showComposeSheet() {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);
    _composeCtrl.clear();
    _imageUrlCtrl.clear();
    bool showImageField = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF0D1229).withAlpha(245)
                    : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: accent.withAlpha(60), width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: (dark ? Colors.white : Colors.black)
                            .withAlpha(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Text field + send row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Image attach toggle
                      GestureDetector(
                        onTap: () =>
                            setSheetState(() => showImageField = !showImageField),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Icon(
                            Icons.image_rounded,
                            color: showImageField
                                ? accent
                                : AppTheme.textTertiaryOf(ctx),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Text field
                      Expanded(
                        child: TextField(
                          controller: _composeCtrl,
                          autofocus: true,
                          maxLines: 4,
                          minLines: 1,
                          maxLength: 500,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            color: AppTheme.textPrimaryOf(ctx),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Share a thought...',
                            hintStyle: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              color: AppTheme.textTertiaryOf(ctx),
                            ),
                            filled: true,
                            fillColor: dark
                                ? Colors.white.withAlpha(8)
                                : Colors.black.withAlpha(5),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: AppTheme.glassBorderOf(ctx)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: AppTheme.glassBorderOf(ctx)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: accent, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Send button
                      GestureDetector(
                        onTap: _isPosting
                            ? null
                            : () async {
                                final text = _composeCtrl.text.trim();
                                final imageUrl = _imageUrlCtrl.text.trim();
                                if (text.isEmpty && imageUrl.isEmpty) return;
                                setSheetState(() => _isPosting = true);
                                final hasImage = imageUrl.isNotEmpty;
                                FeedService.instance.post(
                                  action: hasImage ? 'image_post' : 'text_post',
                                  detail: text.isNotEmpty ? text : 'Shared an image',
                                  imageUrl: hasImage ? imageUrl : null,
                                );
                                await Future.delayed(
                                    const Duration(milliseconds: 400));
                                if (mounted) {
                                  setState(() => _isPosting = false);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [accent, accent.withAlpha(180)],
                            ),
                          ),
                          child: Center(
                            child: _isPosting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Image URL field (togglable)
                  if (showImageField) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _imageUrlCtrl,
                      maxLines: 1,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: AppTheme.textPrimaryOf(ctx),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste image URL...',
                        hintStyle: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: AppTheme.textTertiaryOf(ctx),
                        ),
                        prefixIcon: Icon(Icons.link_rounded,
                            color: AppTheme.textTertiaryOf(ctx), size: 18),
                        filled: true,
                        fillColor: dark
                            ? Colors.white.withAlpha(8)
                            : Colors.black.withAlpha(5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: AppTheme.glassBorderOf(ctx)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: AppTheme.glassBorderOf(ctx)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: accent, width: 1.5),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);

    return Stack(
      children: [
        if (dark)
          const ParticleBackground(
            particleCount: 25,
            particleColor: AppTheme.accentCyan,
            maxRadius: 1.0,
          ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppTheme.primaryGradientOf(context).createShader(bounds),
                      child: Text(
                        'Activity Feed',
                        style: GoogleFonts.orbitron(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Compose button
                    GestureDetector(
                      onTap: _showComposeSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [accent, accent.withAlpha(180)],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'POST',
                              style: GoogleFonts.orbitron(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              // All / Following tab toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: Row(
                  children: [
                    _FeedTab(
                      label: 'All',
                      isSelected: !_showFollowing,
                      onTap: () => setState(() => _showFollowing = false),
                    ),
                    const SizedBox(width: 8),
                    _FeedTab(
                      label: 'Following',
                      isSelected: _showFollowing,
                      onTap: () => setState(() => _showFollowing = true),
                    ),
                  ],
                ),
              ),

              // Feed list
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _showFollowing
                      ? FeedService.instance.followingFeedStream(_followingUids, limit: 30)
                      : FeedService.instance.feedStream(limit: 30),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: accent),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // Header items: compose card + optional suggested users
                    final headerCount = _showFollowing ? 1 : 2; // compose + suggested

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          16, 8, 16,
                          MediaQuery.of(context).padding.bottom + 90),
                      itemCount: docs.length + headerCount,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildComposeCard();
                        if (!_showFollowing && index == 1) {
                          return const SuggestedUsersCard();
                        }
                        final docIndex = index - headerCount;
                        if (docIndex < 0 || docIndex >= docs.length) {
                          return const SizedBox.shrink();
                        }
                        final doc = docs[docIndex];
                        return _FeedCard(
                          postId: doc.id,
                          data: doc.data(),
                          currentUid: _currentUid,
                          index: docIndex,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Floating compose button
        Positioned(
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 90,
          child: GestureDetector(
            onTap: _showComposeSheet,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, accent.withAlpha(180)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white, size: 24),
            ),
          ).animate().scale(
              delay: 600.ms,
              duration: 400.ms,
              curve: Curves.elasticOut),
        ),
      ],
    );
  }

  Widget _buildComposeCard() {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderColor: accent.withAlpha(30),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text input
            TextField(
              controller: _composeCtrl,
              maxLines: 3,
              minLines: 1,
              maxLength: 500,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: AppTheme.textPrimaryOf(context),
              ),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: AppTheme.textTertiaryOf(context),
                ),
                filled: true,
                fillColor: dark
                    ? Colors.white.withAlpha(6)
                    : Colors.black.withAlpha(4),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppTheme.glassBorderOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppTheme.glassBorderOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            // Action row
            Row(
              children: [
                // Image toggle
                GestureDetector(
                  onTap: () {
                    _showComposeSheet();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_rounded,
                          color: AppTheme.textTertiaryOf(context), size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Image',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: AppTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Post button
                GestureDetector(
                  onTap: _isPosting
                      ? null
                      : () async {
                          final text = _composeCtrl.text.trim();
                          if (text.isEmpty) return;
                          setState(() => _isPosting = true);
                          FeedService.instance.post(
                            action: 'text_post',
                            detail: text,
                          );
                          _composeCtrl.clear();
                          await Future.delayed(
                              const Duration(milliseconds: 500));
                          if (mounted) setState(() => _isPosting = false);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [accent, accent.withAlpha(180)],
                      ),
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'POST',
                            style: GoogleFonts.orbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEmptyState() {
    final accent = AppTheme.accentCyanOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dynamic_feed_rounded,
              size: 64,
              color: AppTheme.textTertiaryOf(context).withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share something!',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textTertiaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _showComposeSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [accent, accent.withAlpha(180)],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'CREATE POST',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual Feed Card — social media post style
// ---------------------------------------------------------------------------
class _FeedCard extends StatefulWidget {
  const _FeedCard({
    required this.postId,
    required this.data,
    required this.currentUid,
    required this.index,
  });

  final String postId;
  final Map<String, dynamic> data;
  final String? currentUid;
  final int index;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _showComments = false;
  final _commentCtrl = TextEditingController();
  bool _isReacting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String get _action => widget.data['action'] as String? ?? '';
  String get _detail => widget.data['detail'] as String? ?? '';
  String get _displayName =>
      widget.data['displayName'] as String? ?? 'Learner';
  String? get _photoURL => widget.data['photoURL'] as String?;
  String? get _imageUrl => widget.data['imageUrl'] as String?;
  String get _uid => widget.data['uid'] as String? ?? '';
  int get _commentCount =>
      (widget.data['commentCount'] as num?)?.toInt() ?? 0;
  bool get _isOwnPost => _uid == widget.currentUid;

  /// Build reactions map from Firestore data, with legacy likes fallback.
  Map<String, List<String>> get _reactions {
    final reactionsRaw = widget.data['reactions'] as Map<String, dynamic>?;
    if (reactionsRaw != null) {
      return {
        for (final key in FeedService.reactionTypes)
          key: List<String>.from(reactionsRaw[key] ?? []),
      };
    }
    // Legacy: convert likes array to heart reactions
    return {
      'fire': <String>[],
      'brain': <String>[],
      'clap': <String>[],
      'perfect': <String>[],
      'heart': List<String>.from(widget.data['likes'] ?? []),
    };
  }

  int get _reactionCount {
    final count = (widget.data['reactionCount'] as num?)?.toInt();
    if (count != null) return count;
    // Legacy fallback
    return (widget.data['likeCount'] as num?)?.toInt() ?? 0;
  }

  // Action styling
  _ActionStyle get _actionStyle => switch (_action) {
        'completed_lesson' => _ActionStyle(
            Icons.menu_book_rounded,
            AppTheme.accentCyan,
            'completed a lesson',
          ),
        'perfect_score' => _ActionStyle(
            Icons.stars_rounded,
            AppTheme.accentGold,
            'scored 100%!',
          ),
        'earned_achievement' => _ActionStyle(
            Icons.emoji_events_rounded,
            AppTheme.accentPurple,
            'unlocked an achievement',
          ),
        'streak_milestone' => _ActionStyle(
            Icons.local_fire_department_rounded,
            AppTheme.accentOrange,
            'hit a streak milestone',
          ),
        'text_post' => _ActionStyle(
            Icons.chat_rounded,
            AppTheme.isDark(context)
                ? AppTheme.accentCyan
                : AppTheme.accentPurple,
            'shared a thought',
          ),
        'image_post' => _ActionStyle(
            Icons.image_rounded,
            AppTheme.accentGold,
            'shared an image',
          ),
        _ => _ActionStyle(
            Icons.school_rounded,
            AppTheme.accentGreen,
            'was active',
          ),
      };

  String get _timeAgo {
    final ts = widget.data['createdAt'];
    if (ts == null) return 'just now';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      return 'just now';
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  Future<void> _handleReaction(ReactionType type) async {
    if (_isReacting) return;
    setState(() => _isReacting = true);
    await FeedService.instance.toggleReaction(widget.postId, type.key);
    if (mounted) setState(() => _isReacting = false);
  }

  Future<void> _handleComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    await FeedService.instance.addComment(widget.postId, text);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final style = _actionStyle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderColor: style.color.withAlpha(40),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: avatar + name + action + time ──
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: style.color.withAlpha(30),
                  backgroundImage:
                      _photoURL != null ? NetworkImage(_photoURL!) : null,
                  child: _photoURL == null
                      ? Text(
                          _displayName.isNotEmpty
                              ? _displayName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.orbitron(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: style.color,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                          if (_isOwnPost) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: style.color.withAlpha(20),
                              ),
                              child: Text(
                                'YOU',
                                style: GoogleFonts.orbitron(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: style.color,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        style.label,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: AppTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Time + action icon
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(style.icon, color: style.color, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: AppTheme.textTertiaryOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Detail text ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: dark
                    ? style.color.withAlpha(10)
                    : style.color.withAlpha(8),
                border:
                    Border.all(color: style.color.withAlpha(25), width: 0.5),
              ),
              child: Text(
                _detail,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryOf(context),
                  height: 1.4,
                ),
              ),
            ),

            // ── Image (if present) ──
            if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: style.color.withAlpha(10),
                      border: Border.all(
                          color: style.color.withAlpha(25), width: 0.5),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded,
                              color: AppTheme.textTertiaryOf(context),
                              size: 28),
                          const SizedBox(height: 4),
                          Text(
                            'Image failed to load',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: AppTheme.textTertiaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Reactions bar ──
            ReactionBar(
              reactions: _reactions,
              currentUid: widget.currentUid,
              totalCount: _reactionCount,
              onReact: _handleReaction,
            ),
            const SizedBox(height: 6),
            // ── Comment toggle + action badge ──
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showComments = !_showComments),
                  child: Row(
                    children: [
                      Icon(
                        _showComments
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        color: _showComments
                            ? AppTheme.accentCyanOf(context)
                            : AppTheme.textTertiaryOf(context),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _commentCount > 0 ? '$_commentCount comments' : 'Comment',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _showComments
                              ? AppTheme.accentCyanOf(context)
                              : AppTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: style.color.withAlpha(15),
                    border:
                        Border.all(color: style.color.withAlpha(40), width: 0.5),
                  ),
                  child: Text(
                    _action.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: style.color,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),

            // ── Comments section (expandable) ──
            if (_showComments) ...[
              const SizedBox(height: 10),
              Divider(
                color: AppTheme.glassBorderOf(context),
                height: 1,
              ),
              const SizedBox(height: 8),
              _buildCommentsSection(),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 50 + widget.index * 40),
            duration: 400.ms)
        .slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _buildCommentsSection() {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comments stream
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FeedService.instance.commentsStream(widget.postId),
          builder: (context, snapshot) {
            final comments = snapshot.data?.docs ?? [];
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No comments yet — be the first!',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                ),
              );
            }
            return Column(
              children: comments.map((doc) {
                final c = doc.data();
                return _buildCommentTile(c);
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        // Comment input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentCtrl,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: AppTheme.textPrimaryOf(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.textTertiaryOf(context),
                  ),
                  filled: true,
                  fillColor: dark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppTheme.glassBorderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppTheme.glassBorderOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _handleComment(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleComment,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [accent, accent.withAlpha(180)],
                  ),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final name = comment['displayName'] as String? ?? 'Learner';
    final text = comment['text'] as String? ?? '';
    final photo = comment['photoURL'] as String?;

    String timeAgo = '';
    final ts = comment['createdAt'];
    if (ts is Timestamp) {
      final diff = DateTime.now().difference(ts.toDate());
      if (diff.inMinutes < 1) {
        timeAgo = 'now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h';
      } else {
        timeAgo = '${diff.inDays}d';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.accentPurple.withAlpha(30),
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentPurple,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    if (timeAgo.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        timeAgo,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          color: AppTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  text,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.textPrimaryOf(context),
                    height: 1.3,
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

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentCyanOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? accent.withAlpha(20) : Colors.transparent,
          border: Border.all(
            color: isSelected ? accent : AppTheme.glassBorderOf(context),
            width: isSelected ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? accent : AppTheme.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _ActionStyle {
  final IconData icon;
  final Color color;
  final String label;
  const _ActionStyle(this.icon, this.color, this.label);
}
