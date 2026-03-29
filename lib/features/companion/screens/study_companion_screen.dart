import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/hindsight_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/particle_background.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Study Companion — Hindsight-powered AI study assistant
// ─────────────────────────────────────────────────────────────────────────────

class StudyCompanionScreen extends StatefulWidget {
  const StudyCompanionScreen({super.key});

  @override
  State<StudyCompanionScreen> createState() => _StudyCompanionScreenState();
}

class _StudyCompanionScreenState extends State<StudyCompanionScreen>
    with TickerProviderStateMixin {
  final _hindsight = HindsightService.instance;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────
  String? _studyPulse;
  bool _pulseLoading = true;
  bool _isThinking = false;
  final List<_ChatMessage> _messages = [];

  late AnimationController _pulseGlowCtrl;

  @override
  void initState() {
    super.initState();
    _pulseGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadStudyPulse();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _pulseGlowCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data loading
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadStudyPulse() async {
    setState(() => _pulseLoading = true);
    final insight = await _hindsight.reflect(
      query:
          'Give me a brief study pulse for this student. What topics have they '
          'studied recently? Where are they strong and weak? What should they '
          'focus on next? Keep it concise (3-4 sentences), encouraging, and '
          'actionable. If no learning data exists yet, welcome them warmly and '
          'encourage them to start learning.',
      budget: 'mid',
    );
    if (mounted) {
      setState(() {
        _studyPulse = insight;
        _pulseLoading = false;
      });
    }
  }

  Future<void> _askCompanion(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: query, isUser: true));
      _isThinking = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    final response = await _hindsight.reflect(
      query: query,
      budget: 'mid',
      maxTokens: 3072,
    );

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
        _isThinking = false;
      });
      _scrollToBottom();

      // Retain this exchange in Hindsight so it remembers across sessions
      _hindsight.retainChatExchange(
        userQuery: query,
        aiResponse: response,
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80;

    return Stack(
      children: [
        const ParticleBackground(
          particleCount: 35,
          particleColor: AppTheme.accentCyan,
          maxRadius: 1.0,
          speed: 0.3,
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header ──
              _buildHeader()
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: -0.05, duration: 500.ms),

              // ── Body ──
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                  children: [
                    // Study Pulse
                    _buildStudyPulse()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 600.ms)
                        .slideY(begin: 0.04, duration: 600.ms),
                    const SizedBox(height: 16),

                    // Quick Actions
                    _buildQuickActions()
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 600.ms),
                    const SizedBox(height: 20),

                    // Memory indicator
                    _buildMemoryBadge()
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms),
                    const SizedBox(height: 12),

                    // Chat messages
                    ..._messages.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildMessageBubble(entry.value)
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.05, duration: 300.ms),
                      );
                    }),

                    // Thinking indicator
                    if (_isThinking)
                      _buildThinkingIndicator()
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(
                            duration: 1200.ms,
                            color: AppTheme.accentCyan.withAlpha(40),
                          ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // ── Input Bar ──
              _buildInputBar(),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Header
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // Brain icon with glow
          AnimatedBuilder(
            animation: _pulseGlowCtrl,
            builder: (context, _) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentCyan
                          .withAlpha((40 + 30 * _pulseGlowCtrl.value).round()),
                      AppTheme.accentPurple.withAlpha(10),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.accentCyan
                        .withAlpha((80 + 80 * _pulseGlowCtrl.value).round()),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan
                          .withAlpha((30 + 40 * _pulseGlowCtrl.value).round()),
                      blurRadius: 12 + 8 * _pulseGlowCtrl.value,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppTheme.accentCyan,
                  size: 22,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradientOf(context).createShader(bounds),
                  child: Text(
                    'STUDY COMPANION',
                    style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Text(
                  'Powered by Hindsight Memory',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: _loadStudyPulse,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(10),
                border:
                    Border.all(color: AppTheme.glassBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: AppTheme.textSecondary,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Study Pulse Card
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStudyPulse() {
    return GlassContainer(
      borderColor: AppTheme.accentCyan.withAlpha(60),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded,
                  color: AppTheme.accentCyan, size: 18),
              const SizedBox(width: 8),
              Text(
                'STUDY PULSE',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _pulseLoading ? AppTheme.accentOrange : AppTheme.accentGreen,
                  boxShadow: [
                    BoxShadow(
                      color: (_pulseLoading
                              ? AppTheme.accentOrange
                              : AppTheme.accentGreen)
                          .withAlpha(120),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_pulseLoading)
            _buildShimmerLines()
          else
            Text(
              _studyPulse ?? 'Welcome! Start learning to see your study pulse.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i < 2 ? 8 : 0),
          child: Container(
            height: 14,
            width: i == 2 ? 180 : double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                delay: Duration(milliseconds: i * 200),
                duration: 1200.ms,
                color: AppTheme.accentCyan.withAlpha(25),
              ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Quick Actions
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ASK YOUR COMPANION',
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.track_changes_rounded,
                label: 'What should\nI study?',
                color: AppTheme.accentCyan,
                query:
                    'Based on my learning history, what topics should I study '
                    'today? Prioritize areas where I\'m weakest or haven\'t '
                    'reviewed recently. Give me a focused plan for today.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.quiz_rounded,
                label: 'Quiz me on\nweak spots',
                color: AppTheme.accentPurple,
                query:
                    'Based on my past quiz mistakes and weak areas, generate '
                    'exactly 3 MCQ revision questions. You MUST format each as:\n\n'
                    '### Q1: [question text]\n'
                    '- **A)** option\n- **B)** option\n- **C)** option\n- **D)** option\n\n'
                    '**Answer:** [letter]\n\n**Explanation:** [why]\n\n'
                    'Focus on concepts I previously got wrong or scored low on. '
                    'If I have no history yet, pick common fundamentals.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.calendar_month_rounded,
                label: 'Study plan\nfor this week',
                color: AppTheme.accentGreen,
                query:
                    'Create a personalized study plan for this week based on '
                    'my learning history. Include which topics to review, '
                    'new topics to explore, and how to space my revision for '
                    'maximum retention. Keep it realistic and encouraging.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                icon: Icons.analytics_rounded,
                label: 'Where am I\nstruggling?',
                color: AppTheme.accentOrange,
                query:
                    'Analyze my learning history and identify patterns in my '
                    'mistakes. Which specific concepts or topics am I '
                    'struggling with the most? What common errors do I make? '
                    'Give me specific, actionable advice to improve.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required String query,
  }) {
    return GlassContainer(
      borderColor: color.withAlpha(40),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      onTap: () => _askCompanion(query),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withAlpha(20),
              border: Border.all(color: color.withAlpha(50), width: 0.8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Memory badge
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMemoryBadge() {
    if (_messages.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.accentPurple.withAlpha(15),
          border: Border.all(
            color: AppTheme.accentPurple.withAlpha(40),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.memory_rounded,
                color: AppTheme.accentPurple.withAlpha(180), size: 14),
            const SizedBox(width: 6),
            Text(
              'Answers powered by your learning memory',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: AppTheme.accentPurple.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Chat messages
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMessageBubble(_ChatMessage message) {
    if (message.isUser) {
      return _buildUserBubble(message);
    }
    return _buildAIBubble(message);
  }

  Widget _buildUserBubble(_ChatMessage message) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPurple.withAlpha(30),
                  AppTheme.accentCyan.withAlpha(15),
                ],
              ),
              border: Border.all(
                color: AppTheme.accentPurple.withAlpha(50),
                width: 0.8,
              ),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIBubble(_ChatMessage message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI avatar
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.accentCyan, AppTheme.accentPurple],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentCyan.withAlpha(40),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentCyan.withAlpha(15),
                      Colors.white.withAlpha(8),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.accentCyan.withAlpha(40),
                    width: 0.8,
                  ),
                ),
                child: MarkdownBody(
                  data: message.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                      height: 1.5,
                    ),
                    h1: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                    h2: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                    h3: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                    strong: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                    em: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                    code: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.accentCyanOf(context),
                      backgroundColor: AppTheme.isDark(context)
                          ? Colors.white.withAlpha(10)
                          : Colors.black.withAlpha(8),
                    ),
                    listBullet: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                    blockSpacing: 8,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildThinkingIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.accentCyan, AppTheme.accentPurple],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentCyan.withAlpha(40),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        GlassContainer(
          borderColor: AppTheme.accentCyan.withAlpha(30),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.memory_rounded,
                  color: AppTheme.accentCyan.withAlpha(150), size: 14),
              const SizedBox(width: 8),
              Text(
                'Searching memories...',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Input bar
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding),
          decoration: BoxDecoration(
            color: AppTheme.backgroundPrimary.withAlpha(200),
            border: const Border(
              top: BorderSide(color: AppTheme.glassBorder, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask about your learning...',
                    hintStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(8),
                    prefixIcon: Icon(Icons.psychology_alt_rounded,
                        color: AppTheme.accentCyan.withAlpha(100), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: AppTheme.accentCyan.withAlpha(40)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: AppTheme.accentCyan.withAlpha(40)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                          color: AppTheme.accentCyan, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _askCompanion,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _askCompanion(_inputCtrl.text),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withAlpha(50),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat message model
// ─────────────────────────────────────────────────────────────────────────────

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;
  final bool isUser;
  final DateTime timestamp;
}
