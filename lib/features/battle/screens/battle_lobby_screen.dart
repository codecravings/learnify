import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/features/battle/screens/battle_screen.dart';
import 'package:vidyasetu/features/battle/services/battle_service.dart';
import 'package:vidyasetu/features/battle/services/bot_service.dart';

/// The main entry point for the Battle Arena feature.
///
/// Displays three battle mode cards (Speed Solve, Mind Trap, Scenario Battle),
/// a pulsing "Find Opponent" button, active-battle count, and recent results.
class BattleLobbyScreen extends StatefulWidget {
  const BattleLobbyScreen({super.key});

  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _headerGlowController;
  late final AnimationController _pulseController;
  late final AnimationController _cardEntryController;
  late final Animation<double> _headerGlow;
  late final Animation<double> _pulse;
  late final Animation<double> _cardEntry;

  int _selectedMode = -1;
  int _activeBattleCount = 0;

  final _battleService = BattleService();

  // Mode definitions
  static const _modes = [
    _BattleModeData(
      title: 'Speed Solve',
      subtitle: 'Same challenge, fastest wins',
      icon: Icons.bolt_rounded,
      glowColor: AppTheme.accentCyan,
      time: '3 min',
      xp: '50 XP',
      mode: 'speed_solve',
    ),
    _BattleModeData(
      title: 'Mind Trap',
      subtitle: 'Create a trap for your opponent',
      icon: Icons.psychology_rounded,
      glowColor: AppTheme.accentPurple,
      time: '5 min',
      xp: '75 XP',
      mode: 'mind_trap',
    ),
    _BattleModeData(
      title: 'Scenario Battle',
      subtitle: 'Real-world problem solving',
      icon: Icons.shield_rounded,
      glowColor: AppTheme.accentMagenta,
      time: '7 min',
      xp: '100 XP',
      mode: 'scenario_battle',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _headerGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _headerGlow =
        Tween<double>(begin: 0.4, end: 1.0).animate(_headerGlowController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _cardEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardEntry = CurvedAnimation(
      parent: _cardEntryController,
      curve: Curves.easeOutBack,
    );
    _cardEntryController.forward();

    _loadActiveBattleCount();
  }

  Future<void> _loadActiveBattleCount() async {
    try {
      _battleService.getActiveBattles().listen((battles) {
        if (mounted) {
          setState(() => _activeBattleCount = battles.length);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _headerGlowController.dispose();
    _pulseController.dispose();
    _cardEntryController.dispose();
    super.dispose();
  }

  void _onPlayWithBot() {
    if (_selectedMode < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a battle mode first')),
      );
      return;
    }
    final mode = _modes[_selectedMode];
    final bot = BotService.instance;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          battleId: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          mode: mode.mode,
          modeColor: mode.glowColor,
          isBot: true,
          opponentName: bot.randomBotName,
        ),
      ),
    );
  }

  void _onPlayWithFriend() {
    if (_selectedMode < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a battle mode first')),
      );
      return;
    }
    _showLobbyDialog();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  void _showLobbyDialog() {
    final mode = _modes[_selectedMode];
    final codeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.backgroundPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: AppTheme.glassBorder),
                left: BorderSide(color: AppTheme.glassBorder),
                right: BorderSide(color: AppTheme.glassBorder),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'PLAY WITH FRIEND',
                  style: AppTheme.headerStyle(
                    fontSize: 16, color: mode.glowColor, letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),

                // Create Lobby
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx); // close bottom sheet
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) _createLobby();
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [mode.glowColor, mode.glowColor.withAlpha(180)],
                      ),
                      boxShadow: AppTheme.neonGlow(mode.glowColor, blur: 8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline, color: Colors.black, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'CREATE LOBBY',
                          style: AppTheme.headerStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: Colors.black, letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.glassBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR', style: AppTheme.bodyStyle(
                        fontSize: 11, color: AppTheme.textTertiary,
                      )),
                    ),
                    Expanded(child: Divider(color: AppTheme.glassBorder)),
                  ],
                ),
                const SizedBox(height: 16),

                // Join with Code
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: AppTheme.headerStyle(
                          fontSize: 20, letterSpacing: 6, color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'ENTER CODE',
                          hintStyle: AppTheme.bodyStyle(
                            fontSize: 14, color: AppTheme.textTertiary, letterSpacing: 3,
                          ),
                          filled: true,
                          fillColor: Colors.white.withAlpha(8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: mode.glowColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        final code = codeCtrl.text.trim().toUpperCase();
                        if (code.length < 4) return;
                        Navigator.pop(ctx);
                        _joinLobby(code);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: mode.glowColor),
                        ),
                        child: Text(
                          'JOIN',
                          style: AppTheme.headerStyle(
                            fontSize: 13, color: mode.glowColor, letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _createLobby() {
    final mode = _modes[_selectedMode];
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final code = _generateCode();
    final battles = FirebaseFirestore.instance.collection('battles');
    final docRef = battles.doc();

    debugPrint('[LOBBY] Creating lobby code=$code, uid=$uid, mode=${mode.mode}');

    // Show waiting dialog IMMEDIATELY so user sees feedback
    _showWaitingForFriend(code, docRef.id, mode);

    // Then create the Firestore doc in background
    () async {
      try {
        final questions = BotService.instance.getQuestions(mode.mode, count: 7);
        final questionsData = questions.map((q) => <String, dynamic>{
          'question': q.question,
          'options': q.options,
          'correctIndex': q.correctIndex,
          'explanation': q.explanation ?? '',
          'difficulty': q.difficulty,
          'category': q.category,
        }).toList();

        await docRef.set({
          'id': docRef.id,
          'mode': mode.mode,
          'lobbyCode': code,
          'player1Id': uid,
          'player2Id': '',
          'status': 'waiting',
          'player1Score': 0,
          'player2Score': 0,
          'player1Answered': 0,
          'player2Answered': 0,
          'currentRound': 0,
          'totalRounds': 7,
          'questions': questionsData,
          'answers': <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('[LOBBY] Battle created: ${docRef.id}');
      } catch (e) {
        debugPrint('[LOBBY] Error creating lobby: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create lobby: $e')),
          );
        }
      }
    }();
  }

  void _showWaitingForFriend(String code, String battleId, _BattleModeData mode) {
    final battles = FirebaseFirestore.instance.collection('battles');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: battles.doc(battleId).snapshots(),
          builder: (context, snap) {
            // Check if opponent joined
            if (snap.hasData && snap.data != null) {
              final data = snap.data!.data() as Map<String, dynamic>? ?? {};
              final status = data['status'] as String? ?? '';
              final p2 = data['player2Id'] as String? ?? '';
              if (status == 'in_progress' && p2.isNotEmpty) {
                // Opponent joined! Close dialog and start battle
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(ctx).pop();
                  Navigator.of(this.context).push(
                    MaterialPageRoute(
                      builder: (_) => BattleScreen(
                        battleId: battleId,
                        mode: mode.mode,
                        modeColor: mode.glowColor,
                        isBot: false,
                        opponentName: 'Friend',
                      ),
                    ),
                  );
                });
              }
            }

            return Dialog(
              backgroundColor: AppTheme.backgroundPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: mode.glowColor.withAlpha(60)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SHARE THIS CODE',
                      style: AppTheme.headerStyle(
                        fontSize: 12, color: AppTheme.textTertiary, letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: mode.glowColor.withAlpha(15),
                          border: Border.all(color: mode.glowColor.withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              code,
                              style: AppTheme.headerStyle(
                                fontSize: 32, color: mode.glowColor, letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.copy_rounded, color: mode.glowColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: mode.glowColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Waiting for friend to join...',
                      style: AppTheme.bodyStyle(
                        fontSize: 13, color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        // Cancel — delete battle
                        battles.doc(battleId).delete();
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        'CANCEL',
                        style: AppTheme.headerStyle(
                          fontSize: 12, color: AppTheme.accentMagenta, letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _joinLobby(String code) async {
    final mode = _modes[_selectedMode];
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final battles = FirebaseFirestore.instance.collection('battles');

    debugPrint('[LOBBY] Joining lobby code=$code, uid=$uid');

    try {
      // Query without composite index — just lobbyCode, then filter locally
      final snap = await battles
          .where('lobbyCode', isEqualTo: code)
          .get();

      debugPrint('[LOBBY] Found ${snap.docs.length} battles with code=$code');

      final waitingDocs = snap.docs.where((d) {
        final data = d.data();
        return data['status'] == 'waiting';
      }).toList();

      debugPrint('[LOBBY] ${waitingDocs.length} are waiting');

      if (waitingDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No lobby found with that code')),
          );
        }
        return;
      }

      final doc = waitingDocs.first;
      debugPrint('[LOBBY] Joining battle ${doc.id}');
      await doc.reference.update({
        'player2Id': uid,
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[LOBBY] Joined! Navigating to battle');

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BattleScreen(
            battleId: doc.id,
            mode: mode.mode,
            modeColor: mode.glowColor,
            isBot: false,
            opponentName: 'Friend',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[LOBBY] Join error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
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
        actions: [
          // Active battles indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentGreen.withAlpha(80),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$_activeBattleCount LIVE',
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildModeCards(),
                const SizedBox(height: 32),
                _buildFindOpponentButton(),
                const SizedBox(height: 32),
                _buildRecentResults(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerGlow,
      builder: (context, child) {
        return Column(
          children: [
            // Glow backdrop
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    AppTheme.accentCyan.withAlpha(
                      (255 * _headerGlow.value).round(),
                    ),
                    AppTheme.accentPurple.withAlpha(
                      (255 * _headerGlow.value).round(),
                    ),
                    AppTheme.accentMagenta.withAlpha(
                      (255 * _headerGlow.value).round(),
                    ),
                  ],
                ).createShader(bounds),
                child: Text(
                  'BATTLE ARENA',
                  style: AppTheme.headerStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Prove your skills in real-time combat',
              style: AppTheme.bodyStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Mode Cards ────────────────────────────────────────────────────

  Widget _buildModeCards() {
    return AnimatedBuilder(
      animation: _cardEntry,
      builder: (context, _) {
        return Column(
          children: List.generate(_modes.length, (i) {
            final delay = i * 0.2;
            final progress =
                (_cardEntry.value - delay).clamp(0.0, 1.0 - delay) /
                    (1.0 - delay);
            return Transform.translate(
              offset: Offset(0, 40 * (1 - progress)),
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: _buildModeCard(i),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildModeCard(int index) {
    final mode = _modes[index];
    final isSelected = _selectedMode == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        child: GlassMorphism.glow(
          glowColor: isSelected ? mode.glowColor : Colors.transparent,
          glowBlurRadius: isSelected ? 28 : 0,
          borderColor: isSelected
              ? mode.glowColor.withAlpha(150)
              : AppTheme.glassBorder,
          borderWidth: isSelected ? 1.5 : 0.8,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mode.glowColor.withAlpha(25),
                  border: Border.all(
                    color: mode.glowColor.withAlpha(isSelected ? 180 : 60),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: mode.glowColor.withAlpha(60),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  mode.icon,
                  color: mode.glowColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      style: AppTheme.headerStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? mode.glowColor : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.subtitle,
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _infoChip(Icons.timer_outlined, mode.time, mode.glowColor),
                        const SizedBox(width: 12),
                        _infoChip(Icons.star_rounded, mode.xp, mode.glowColor),
                      ],
                    ),
                  ],
                ),
              ),
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? mode.glowColor : AppTheme.textTertiary,
                    width: 2,
                  ),
                  color: isSelected ? mode.glowColor : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withAlpha(180)),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTheme.bodyStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.withAlpha(200),
          ),
        ),
      ],
    );
  }

  // ─── Play Buttons ──────────────────────────────────────────

  Widget _buildFindOpponentButton() {
    final active = _selectedMode >= 0;
    final modeColor = active ? _modes[_selectedMode].glowColor : AppTheme.surfaceLight;

    return Column(
      children: [
        // Play with Bot
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            return Transform.scale(
              scale: active ? _pulse.value : 1.0,
              child: GestureDetector(
                onTap: _onPlayWithBot,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: active
                        ? LinearGradient(
                            colors: [modeColor, modeColor.withAlpha(180)],
                          )
                        : const LinearGradient(
                            colors: [AppTheme.surfaceLight, AppTheme.surfaceDark],
                          ),
                    boxShadow: active ? AppTheme.neonGlow(modeColor) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.smart_toy_rounded,
                        color: active ? Colors.black : AppTheme.textTertiary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'PLAY WITH BOT',
                        style: AppTheme.headerStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.black : AppTheme.textTertiary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Play with Friend
        GestureDetector(
          onTap: _onPlayWithFriend,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: active ? Colors.white.withAlpha(8) : Colors.white.withAlpha(5),
              border: Border.all(
                color: active ? modeColor.withAlpha(100) : AppTheme.glassBorder,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_rounded,
                  color: active ? modeColor : AppTheme.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'LOBBY CODE',
                  style: AppTheme.headerStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: active ? modeColor : AppTheme.textTertiary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Recent Results ────────────────────────────────────────────────

  Widget _buildRecentResults() {
    // Placeholder recent results for demonstration
    final results = [
      _RecentResult('Speed Solve', 'vs AlgoKing', true, '+50 XP', AppTheme.accentCyan),
      _RecentResult('Mind Trap', 'vs CodeNinja', false, '+10 XP', AppTheme.accentPurple),
      _RecentResult('Scenario Battle', 'vs ByteWizard', true, '+100 XP', AppTheme.accentMagenta),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT BATTLES',
          style: AppTheme.headerStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final r = results[index];
              return GlassMorphism(
                borderRadius: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderColor: r.color.withAlpha(60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: r.won
                                ? AppTheme.accentGreen.withAlpha(30)
                                : AppTheme.accentMagenta.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.won ? 'WIN' : 'LOSS',
                            style: AppTheme.bodyStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: r.won
                                  ? AppTheme.accentGreen
                                  : AppTheme.accentMagenta,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r.xp,
                          style: AppTheme.bodyStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.mode,
                      style: AppTheme.bodyStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      r.opponent,
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Data classes ──────────────────────────────────────────────────────

class _BattleModeData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color glowColor;
  final String time;
  final String xp;
  final String mode;

  const _BattleModeData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.glowColor,
    required this.time,
    required this.xp,
    required this.mode,
  });
}

class _RecentResult {
  final String mode;
  final String opponent;
  final bool won;
  final String xp;
  final Color color;

  const _RecentResult(this.mode, this.opponent, this.won, this.xp, this.color);
}
