import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../models/forum_post_model.dart';
import '../services/peer_help_service.dart';
import '../widgets/tutor_badge.dart';

/// Detail screen for a single peer help question, showing the question
/// and a stream of answers with voting/accept functionality.
class PeerHelpPostScreen extends StatefulWidget {
  const PeerHelpPostScreen({super.key, required this.postId});
  final String postId;

  @override
  State<PeerHelpPostScreen> createState() => _PeerHelpPostScreenState();
}

class _PeerHelpPostScreenState extends State<PeerHelpPostScreen> {
  final _answerCtrl = TextEditingController();
  final _currentUid = FirebaseAuth.instance.currentUser?.uid;
  ForumPostModel? _post;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    final post = await PeerHelpService.instance.getPost(widget.postId);
    if (mounted) setState(() { _post = post; _loading = false; });
  }

  Future<void> _submitAnswer() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await PeerHelpService.instance.submitAnswer(widget.postId, text);
    _answerCtrl.clear();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _acceptAnswer(String solutionId, String authorId) async {
    await PeerHelpService.instance.acceptAnswer(
      postId: widget.postId,
      solutionId: solutionId,
      answerAuthorId: authorId,
    );
    _loadPost(); // Refresh
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final accent = AppTheme.accentCyanOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: AppTheme.scaffoldDecorationOf(context),
        child: SafeArea(
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
                    Text('Question', style: GoogleFonts.orbitron(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Content
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _post == null
                        ? Center(child: Text('Question not found',
                            style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondaryOf(context))))
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final accent = AppTheme.accentCyanOf(context);
    final dark = AppTheme.isDark(context);
    final green = AppTheme.accentGreenOf(context);
    final isAuthor = _post!.authorId == _currentUid;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Question card
              GlassContainer(
                borderColor: accent.withAlpha(40),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_post!.title,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        ),
                        if (_post!.isResolved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: green.withAlpha(20),
                              border: Border.all(color: green.withAlpha(60)),
                            ),
                            child: Text('SOLVED', style: GoogleFonts.orbitron(
                              fontSize: 8, fontWeight: FontWeight.w700,
                              color: green, letterSpacing: 0.8,
                            )),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_post!.content,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, color: AppTheme.textSecondaryOf(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: accent.withAlpha(15),
                            border: Border.all(color: accent.withAlpha(40), width: 0.5),
                          ),
                          child: Text(_post!.category.toUpperCase(),
                            style: GoogleFonts.orbitron(
                              fontSize: 7, fontWeight: FontWeight.w700,
                              color: accent, letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('by ${_post!.authorUsername}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, color: AppTheme.textTertiaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
              // Answers header
              Row(
                children: [
                  Text('ANSWERS', style: GoogleFonts.orbitron(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryOf(context), letterSpacing: 1.5,
                  )),
                  const SizedBox(width: 8),
                  Text('+25 XP for accepted answer', style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppTheme.accentGreenOf(context),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              // Solutions stream
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PeerHelpService.instance.solutionsStream(widget.postId),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text(
                        'No answers yet — be the first to help!',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, color: AppTheme.textTertiaryOf(context),
                        ),
                      )),
                    );
                  }
                  return Column(
                    children: docs.asMap().entries.map((entry) {
                      final data = entry.value.data();
                      final solId = data['id'] as String? ?? entry.value.id;
                      final authorId = data['authorId'] as String? ?? '';
                      final authorName = (data['authorName'] ?? data['authorUsername'] ?? 'Learner') as String;
                      final content = data['content'] as String? ?? '';
                      final isAccepted = data['isAccepted'] as bool? ?? false;
                      final upvotes = (data['upvotes'] as num?)?.toInt() ?? 0;

                      return _AnswerCard(
                        content: content,
                        authorName: authorName,
                        authorId: authorId,
                        isAccepted: isAccepted,
                        upvotes: upvotes,
                        canAccept: isAuthor && !_post!.isResolved,
                        onAccept: () => _acceptAnswer(solId, authorId),
                        index: entry.key,
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        // Answer input
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF111827).withAlpha(240) : Colors.white.withAlpha(240),
            border: Border(top: BorderSide(color: AppTheme.glassBorderOf(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerCtrl,
                  maxLines: 3, minLines: 1,
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    hintText: 'Write your answer...',
                    hintStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppTheme.textTertiaryOf(context)),
                    filled: true,
                    fillColor: dark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.glassBorderOf(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.glassBorderOf(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent, width: 1.5),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submitAnswer(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitAnswer,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [accent, accent.withAlpha(180)]),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.content,
    required this.authorName,
    required this.authorId,
    required this.isAccepted,
    required this.upvotes,
    required this.canAccept,
    required this.onAccept,
    required this.index,
  });

  final String content;
  final String authorName;
  final String authorId;
  final bool isAccepted;
  final int upvotes;
  final bool canAccept;
  final VoidCallback onAccept;
  final int index;

  @override
  Widget build(BuildContext context) {
    final green = AppTheme.accentGreenOf(context);
    final accent = AppTheme.accentCyanOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        borderColor: isAccepted ? green.withAlpha(50) : AppTheme.glassBorderOf(context),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accent.withAlpha(20),
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: GoogleFonts.orbitron(
                      fontSize: 11, fontWeight: FontWeight.w700, color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(authorName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(width: 6),
                // Tutor badge will show if they have accepted answers
                FutureBuilder<Map<String, int>>(
                  future: PeerHelpService.instance.getTutorStats(authorId),
                  builder: (_, snap) {
                    final accepted = snap.data?['answersAccepted'] ?? 0;
                    return TutorBadge(acceptedCount: accepted);
                  },
                ),
                const Spacer(),
                if (isAccepted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: green.withAlpha(20),
                      border: Border.all(color: green.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: green, size: 10),
                        const SizedBox(width: 3),
                        Text('ACCEPTED', style: GoogleFonts.orbitron(
                          fontSize: 7, fontWeight: FontWeight.w700,
                          color: green, letterSpacing: 0.6,
                        )),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Answer content
            Text(content,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13, color: AppTheme.textPrimaryOf(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            // Action row
            Row(
              children: [
                Icon(Icons.arrow_upward_rounded, size: 14,
                    color: AppTheme.textTertiaryOf(context)),
                const SizedBox(width: 2),
                Text('$upvotes', style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiaryOf(context),
                )),
                const Spacer(),
                if (canAccept && !isAccepted)
                  GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: green.withAlpha(15),
                        border: Border.all(color: green.withAlpha(50)),
                      ),
                      child: Text('Accept Answer (+25 XP)',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: green,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 50 + index * 40),
      duration: 400.ms,
    );
  }
}
