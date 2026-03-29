import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/features/battle/services/battle_service.dart';
import 'package:vidyasetu/features/battle/models/battle_model.dart';

/// Spectator mode screen -- an esports-inspired live battle browser.
///
/// Shows a list of in-progress battles with LIVE indicators, player names,
/// mode badges, time remaining, and spectator counts. Tapping opens a
/// read-only battle view. Includes a concept reactions sidebar.
class SpectatorScreen extends StatefulWidget {
  const SpectatorScreen({super.key});

  @override
  State<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends State<SpectatorScreen>
    with TickerProviderStateMixin {
  final _battleService = BattleService();

  late final AnimationController _liveDotController;
  late final Animation<double> _liveDot;
  late final AnimationController _headerGlowController;

  @override
  void initState() {
    super.initState();

    _liveDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _liveDot = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _liveDotController, curve: Curves.easeInOut),
    );

    _headerGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _liveDotController.dispose();
    _headerGlowController.dispose();
    super.dispose();
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'speed_solve':
        return 'Speed Solve';
      case 'mind_trap':
        return 'Mind Trap';
      case 'scenario_battle':
        return 'Scenario';
      case 'ranked':
        return 'Ranked';
      default:
        return mode;
    }
  }

  Color _modeColor(String mode) {
    switch (mode) {
      case 'speed_solve':
        return AppTheme.accentCyan;
      case 'mind_trap':
        return AppTheme.accentPurple;
      case 'scenario_battle':
        return AppTheme.accentMagenta;
      default:
        return AppTheme.accentCyan;
    }
  }

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'speed_solve':
        return Icons.bolt_rounded;
      case 'mind_trap':
        return Icons.psychology_rounded;
      case 'scenario_battle':
        return Icons.shield_rounded;
      default:
        return Icons.sports_esports_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'SPECTATOR',
              style: AppTheme.headerStyle(fontSize: 16, letterSpacing: 3),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildHeaderBanner(),
              const SizedBox(height: 16),
              // Live battles stream
              Expanded(
                child: StreamBuilder(
                  stream: _battleService.getSpectatorBattles(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    final battles = snapshot.data ?? [];
                    if (battles.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildBattleList(battles);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header Banner ─────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _headerGlowController,
        builder: (context, _) {
          return GlassMorphism(
            borderRadius: 16,
            borderColor: AppTheme.accentCyan.withAlpha(
              (40 + 40 * _headerGlowController.value).round(),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accentCyan.withAlpha(40),
                        AppTheme.accentCyan.withAlpha(10),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.stadium_rounded,
                    color: AppTheme.accentCyan,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Battle Arena',
                        style: AppTheme.headerStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Watch top players compete in real-time',
                        style: AppTheme.bodyStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Battle List ───────────────────────────────────────────────────

  Widget _buildBattleList(List<BattleModel> battles) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: battles.length,
      itemBuilder: (context, index) {
        final battle = battles[index];
        return _buildBattleCard(battle);
      },
    );
  }

  Widget _buildBattleCard(BattleModel battle) {
    final color = _modeColor(battle.mode);
    final timeElapsed = DateTime.now().difference(battle.createdAt).inSeconds;
    // Estimate remaining time (default 5 min battles)
    final remaining = max(0, 300 - timeElapsed);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    return GestureDetector(
      onTap: () => _openSpectatorView(battle),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassMorphism(
          borderRadius: 16,
          borderColor: color.withAlpha(50),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top row: mode badge + LIVE indicator + spectator count
              Row(
                children: [
                  // Mode badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: color.withAlpha(20),
                      border: Border.all(color: color.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_modeIcon(battle.mode), color: color, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _modeLabel(battle.mode),
                          style: AppTheme.bodyStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // LIVE indicator
                  AnimatedBuilder(
                    animation: _liveDot,
                    builder: (context, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.red.withAlpha(30),
                          border: Border.all(
                            color: Colors.red.withAlpha(
                              (100 * _liveDot.value).round(),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withAlpha(
                                  (255 * _liveDot.value).round(),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withAlpha(
                                      (100 * _liveDot.value).round(),
                                    ),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: AppTheme.bodyStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  // Spectator count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded,
                          color: AppTheme.textTertiary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_pseudoSpectatorCount(battle.id)}',
                        style: AppTheme.bodyStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Player vs Player
              Row(
                children: [
                  // Player 1
                  Expanded(
                    child: _buildPlayerChip(
                      name: battle.player1Id.isNotEmpty
                          ? 'Player 1'
                          : '???',
                      score: battle.player1Score,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                  // VS badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentOrange, AppTheme.accentMagenta],
                        ),
                      ),
                      child: Text(
                        'VS',
                        style: AppTheme.headerStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  // Player 2
                  Expanded(
                    child: _buildPlayerChip(
                      name: battle.player2Id.isNotEmpty
                          ? 'Player 2'
                          : 'Waiting...',
                      score: battle.player2Score,
                      color: AppTheme.accentMagenta,
                      alignRight: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Bottom row: time remaining + watch button
              Row(
                children: [
                  Icon(Icons.timer_rounded, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${minutes}m ${seconds.toString().padLeft(2, '0')}s remaining',
                    style: AppTheme.bodyStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: color.withAlpha(20),
                      border: Border.all(color: color.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: color, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'WATCH',
                          style: AppTheme.bodyStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerChip({
    required String name,
    required int score,
    required Color color,
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignRight)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(20),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Icon(Icons.person_rounded, color: color, size: 16),
              ),
            if (!alignRight) const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: AppTheme.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (alignRight) const SizedBox(width: 8),
            if (alignRight)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(20),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Icon(Icons.person_rounded, color: color, size: 16),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Score: $score',
          style: AppTheme.bodyStyle(
            fontSize: 10,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  // ─── Reactions Sidebar Concept (shown in spectator view) ───────────

  void _openSpectatorView(BattleModel battle) {
    final color = _modeColor(battle.mode);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SpectatorViewSheet(
        battle: battle,
        modeColor: color,
        modeName: _modeLabel(battle.mode),
      ),
    );
  }

  // ─── States ────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation(AppTheme.accentCyan.withAlpha(150)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading live battles...',
            style: AppTheme.bodyStyle(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_esports_outlined,
            size: 64,
            color: AppTheme.textTertiary.withAlpha(80),
          ),
          const SizedBox(height: 16),
          Text(
            'No live battles right now',
            style: AppTheme.headerStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a battle or check back later!',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// Deterministic pseudo-random spectator count from battle ID.
  int _pseudoSpectatorCount(String id) {
    return (id.hashCode.abs() % 45) + 3;
  }
}

// ─── Spectator View Bottom Sheet ─────────────────────────────────────

class _SpectatorViewSheet extends StatefulWidget {
  final BattleModel battle;
  final Color modeColor;
  final String modeName;

  const _SpectatorViewSheet({
    required this.battle,
    required this.modeColor,
    required this.modeName,
  });

  @override
  State<_SpectatorViewSheet> createState() => _SpectatorViewSheetState();
}

class _SpectatorViewSheetState extends State<_SpectatorViewSheet> {
  final _chatController = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage('SpectatorPro', 'This is intense!', AppTheme.accentCyan),
    _ChatMessage('CodeFan42', 'Player 1 is so fast', AppTheme.accentGold),
    _ChatMessage('ByteWatcher', 'GG incoming', AppTheme.accentGreen),
  ];

  // Reaction emojis
  static const _reactions = ['🔥', '👏', '😮', '💪', '🎯', '💡'];

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundPrimary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: widget.modeColor.withAlpha(40)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: AppTheme.bodyStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.modeName,
                      style: AppTheme.headerStyle(
                        fontSize: 14,
                        color: widget.modeColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.visibility_rounded,
                        color: AppTheme.textTertiary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${(widget.battle.id.hashCode.abs() % 45) + 3}',
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Battle view (read-only placeholder)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassMorphism(
                    borderRadius: 16,
                    borderColor: widget.modeColor.withAlpha(40),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Score display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Player 1',
                                  style: AppTheme.bodyStyle(
                                    fontSize: 12,
                                    color: AppTheme.accentCyan,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.battle.player1Score}',
                                  style: AppTheme.headerStyle(
                                    fontSize: 28,
                                    color: AppTheme.accentCyan,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(colors: [
                                AppTheme.accentOrange,
                                AppTheme.accentMagenta,
                              ]).createShader(bounds),
                              child: Text(
                                'VS',
                                style: AppTheme.headerStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  'Player 2',
                                  style: AppTheme.bodyStyle(
                                    fontSize: 12,
                                    color: AppTheme.accentMagenta,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.battle.player2Score}',
                                  style: AppTheme.headerStyle(
                                    fontSize: 28,
                                    color: AppTheme.accentMagenta,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Round 1 / 3',
                          style: AppTheme.bodyStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: 1 / 3,
                            backgroundColor: AppTheme.surfaceLight,
                            valueColor:
                                AlwaysStoppedAnimation(widget.modeColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quick reactions
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _reactions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _messages.add(_ChatMessage(
                            'You',
                            _reactions[index],
                            widget.modeColor,
                          ));
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.glassFill,
                          border: Border.all(color: AppTheme.glassBorder),
                        ),
                        child: Center(
                          child: Text(
                            _reactions[index],
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Chat messages
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassMorphism.subtle(
                    borderRadius: 14,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        // Chat header
                        Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: AppTheme.textTertiary, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE CHAT',
                              style: AppTheme.bodyStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            reverse: true,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[
                                  _messages.length - 1 - index];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${msg.username}: ',
                                        style: AppTheme.bodyStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: msg.color,
                                        ),
                                      ),
                                      TextSpan(
                                        text: msg.text,
                                        style: AppTheme.bodyStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Chat input
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _chatController,
                                  style: AppTheme.bodyStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'Send a message...',
                                    hintStyle: AppTheme.bodyStyle(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.surfaceDark,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 0),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (_chatController.text.trim().isEmpty) {
                                  return;
                                }
                                setState(() {
                                  _messages.add(_ChatMessage(
                                    'You',
                                    _chatController.text.trim(),
                                    widget.modeColor,
                                  ));
                                  _chatController.clear();
                                });
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.modeColor.withAlpha(30),
                                  border: Border.all(
                                    color: widget.modeColor.withAlpha(80),
                                  ),
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  color: widget.modeColor,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ChatMessage {
  final String username;
  final String text;
  final Color color;

  const _ChatMessage(this.username, this.text, this.color);
}
