import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';
import '../../../models/forum_post_model.dart';
import '../services/peer_help_service.dart';
import '../widgets/tutor_badge.dart';
import 'peer_help_post_screen.dart';

class PeerHelpScreen extends StatefulWidget {
  const PeerHelpScreen({super.key});

  @override
  State<PeerHelpScreen> createState() => _PeerHelpScreenState();
}

class _PeerHelpScreenState extends State<PeerHelpScreen> {
  String _selectedCategory = '';
  final _currentUid = FirebaseAuth.instance.currentUser?.uid;

  static const _categories = ['', ...PeerHelpService.categories];

  String _categoryLabel(String cat) => cat.isEmpty ? 'All' : cat[0].toUpperCase() + cat.substring(1);

  void _showAskSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'general';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final dark = AppTheme.isDark(ctx);
          final accent = AppTheme.accentCyanOf(ctx);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF111827).withAlpha(245) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: accent.withAlpha(60), width: 1.5)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: (dark ? Colors.white : Colors.black).withAlpha(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ask a Question',
                    style: GoogleFonts.orbitron(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(ctx),
                    ),
                  ),
                  Row(
                    children: [
                      Text('+10 XP', style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppTheme.accentGreenOf(ctx),
                      )),
                      Text(' for asking', style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, color: AppTheme.textTertiaryOf(ctx),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Category chips
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: PeerHelpService.categories.map((cat) {
                        final sel = category == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setSheet(() => category = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: sel ? accent.withAlpha(25) : Colors.transparent,
                                border: Border.all(
                                  color: sel ? accent : AppTheme.glassBorderOf(ctx),
                                  width: sel ? 1.2 : 0.5,
                                ),
                              ),
                              child: Text(
                                _categoryLabel(cat),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: sel ? accent : AppTheme.textSecondaryOf(ctx),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.spaceGrotesk(fontSize: 14, color: AppTheme.textPrimaryOf(ctx)),
                    decoration: InputDecoration(
                      hintText: 'Question title...',
                      hintStyle: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.textTertiaryOf(ctx)),
                      filled: true,
                      fillColor: dark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.glassBorderOf(ctx)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.glassBorderOf(ctx)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 4, minLines: 2,
                    style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.textPrimaryOf(ctx)),
                    decoration: InputDecoration(
                      hintText: 'Describe your question in detail...',
                      hintStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTheme.textTertiaryOf(ctx)),
                      filled: true,
                      fillColor: dark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.glassBorderOf(ctx)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.glassBorderOf(ctx)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        await PeerHelpService.instance.askQuestion(
                          title: titleCtrl.text.trim(),
                          content: bodyCtrl.text.trim(),
                          category: category,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('ASK QUESTION  (+10 XP)',
                        style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: Stack(
          children: [
            if (dark) const ParticleBackground(
              particleCount: 20,
              particleColor: AppTheme.accentCyan,
              maxRadius: 1.0,
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.arrow_back_ios_rounded,
                              color: AppTheme.textPrimaryOf(context), size: 20),
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradientOf(context).createShader(bounds),
                          child: Text('Ask & Answer',
                            style: GoogleFonts.orbitron(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _showAskSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: [accent, accent.withAlpha(180)]),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text('ASK', style: GoogleFonts.orbitron(
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 1,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 12),
                  // Category filter
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _categories.length,
                      itemBuilder: (context, i) {
                        final cat = _categories[i];
                        final sel = cat == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: sel ? accent.withAlpha(20) : Colors.transparent,
                                border: Border.all(
                                  color: sel ? accent : AppTheme.glassBorderOf(context),
                                  width: sel ? 1.2 : 0.5,
                                ),
                              ),
                              child: Text(
                                _categoryLabel(cat),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? accent : AppTheme.textSecondaryOf(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Posts list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: PeerHelpService.instance.postsStream(
                        category: _selectedCategory.isEmpty ? null : _selectedCategory,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return Center(child: CircularProgressIndicator(color: accent));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) return _buildEmptyState();

                        return ListView.builder(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 20),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final data = docs[i].data();
                            final post = ForumPostModel.fromJson(data);
                            return _QuestionCard(
                              post: post,
                              isOwn: post.authorId == _currentUid,
                              index: i,
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PeerHelpPostScreen(postId: post.id),
                              )),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final accent = AppTheme.accentCyanOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline_rounded, size: 64,
                color: AppTheme.textTertiaryOf(context).withAlpha(80)),
            const SizedBox(height: 16),
            Text('No questions yet',
              style: GoogleFonts.orbitron(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text('Be the first to ask!',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13, color: AppTheme.textTertiaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _showAskSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [accent, accent.withAlpha(180)]),
                ),
                child: Text('ASK A QUESTION',
                  style: GoogleFonts.orbitron(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 1,
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

// ── Question card ────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.post,
    required this.isOwn,
    required this.index,
    required this.onTap,
  });

  final ForumPostModel post;
  final bool isOwn;
  final int index;
  final VoidCallback onTap;

  String get _timeAgo {
    final diff = DateTime.now().difference(post.createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${post.createdAt.day}/${post.createdAt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentCyanOf(context);
    final green = AppTheme.accentGreenOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          borderColor: post.isResolved ? green.withAlpha(40) : accent.withAlpha(30),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + resolved badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  if (post.isResolved) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: green.withAlpha(20),
                        border: Border.all(color: green.withAlpha(60)),
                      ),
                      child: Text('SOLVED',
                        style: GoogleFonts.orbitron(
                          fontSize: 7, fontWeight: FontWeight.w700,
                          color: green, letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.content,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: AppTheme.textSecondaryOf(context),
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Meta row
              Row(
                children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: accent.withAlpha(15),
                      border: Border.all(color: accent.withAlpha(40), width: 0.5),
                    ),
                    child: Text(
                      post.category.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        fontSize: 7, fontWeight: FontWeight.w700,
                        color: accent, letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Author
                  Text(
                    post.authorUsername,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: accent.withAlpha(15),
                      ),
                      child: Text('YOU',
                        style: GoogleFonts.orbitron(
                          fontSize: 6, fontWeight: FontWeight.w700,
                          color: accent, letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Votes
                  Icon(Icons.arrow_upward_rounded, size: 12,
                      color: AppTheme.textTertiaryOf(context)),
                  const SizedBox(width: 2),
                  Text('${post.score}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Solutions count
                  Icon(Icons.chat_bubble_outline_rounded, size: 12,
                      color: AppTheme.textTertiaryOf(context)),
                  const SizedBox(width: 2),
                  Text('${post.solutionCount}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_timeAgo,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, color: AppTheme.textTertiaryOf(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 30 + index * 30),
      duration: 400.ms,
    ).slideY(begin: 0.04, duration: 400.ms);
  }
}
