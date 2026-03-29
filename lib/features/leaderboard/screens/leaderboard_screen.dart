import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/podium_widget.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bgColor = Color(0xFF111827);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _magenta = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);

  late TabController _tabController;
  String _timeFilter = 'All Time';
  final int _currentUserId = 7;

  final List<String> _tabs = [
    'Battle Ranking',
    'XP Champions',
    'Puzzle Creators',
    'Speed Demons',
  ];

  final List<String> _timeFilters = ['All Time', 'Monthly', 'Weekly'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_LeaderboardEntry> _getEntries() {
    final tab = _tabController.index;
    final List<List<_LeaderboardEntry>> data = [
      // Battle Ranking
      [
        _LeaderboardEntry(1, 'DragonSlayer', 'assets/av1.png', 'Diamond', 342, 'Battles Won'),
        _LeaderboardEntry(2, 'CodeNinja', 'assets/av2.png', 'Diamond', 310, 'Battles Won'),
        _LeaderboardEntry(3, 'ByteQueen', 'assets/av3.png', 'Platinum', 298, 'Battles Won'),
        _LeaderboardEntry(4, 'AlgoKing', 'assets/av4.png', 'Platinum', 275, 'Battles Won'),
        _LeaderboardEntry(5, 'PixelWitch', 'assets/av5.png', 'Gold', 260, 'Battles Won'),
        _LeaderboardEntry(6, 'BugHunter', 'assets/av6.png', 'Gold', 245, 'Battles Won'),
        _LeaderboardEntry(7, 'You', 'assets/av7.png', 'Gold', 230, 'Battles Won'),
        _LeaderboardEntry(8, 'StackOverlord', 'assets/av8.png', 'Silver', 218, 'Battles Won'),
        _LeaderboardEntry(9, 'RecursionPro', 'assets/av9.png', 'Silver', 200, 'Battles Won'),
        _LeaderboardEntry(10, 'BinaryBoss', 'assets/av10.png', 'Silver', 190, 'Battles Won'),
        _LeaderboardEntry(11, 'LoopMaster', 'assets/av11.png', 'Bronze', 178, 'Battles Won'),
        _LeaderboardEntry(12, 'HashHero', 'assets/av12.png', 'Bronze', 165, 'Battles Won'),
      ],
      // XP Champions
      [
        _LeaderboardEntry(1, 'CodeNinja', 'assets/av2.png', 'Diamond', 98500, 'XP'),
        _LeaderboardEntry(2, 'DragonSlayer', 'assets/av1.png', 'Diamond', 92300, 'XP'),
        _LeaderboardEntry(3, 'AlgoKing', 'assets/av4.png', 'Platinum', 87100, 'XP'),
        _LeaderboardEntry(4, 'ByteQueen', 'assets/av3.png', 'Platinum', 81000, 'XP'),
        _LeaderboardEntry(5, 'BugHunter', 'assets/av6.png', 'Gold', 74200, 'XP'),
        _LeaderboardEntry(6, 'PixelWitch', 'assets/av5.png', 'Gold', 68900, 'XP'),
        _LeaderboardEntry(7, 'You', 'assets/av7.png', 'Gold', 63500, 'XP'),
        _LeaderboardEntry(8, 'RecursionPro', 'assets/av9.png', 'Silver', 58000, 'XP'),
        _LeaderboardEntry(9, 'StackOverlord', 'assets/av8.png', 'Silver', 52100, 'XP'),
        _LeaderboardEntry(10, 'BinaryBoss', 'assets/av10.png', 'Silver', 47000, 'XP'),
      ],
      // Puzzle Creators
      [
        _LeaderboardEntry(1, 'PixelWitch', 'assets/av5.png', 'Diamond', 156, 'Puzzles'),
        _LeaderboardEntry(2, 'ByteQueen', 'assets/av3.png', 'Platinum', 134, 'Puzzles'),
        _LeaderboardEntry(3, 'AlgoKing', 'assets/av4.png', 'Platinum', 121, 'Puzzles'),
        _LeaderboardEntry(4, 'CodeNinja', 'assets/av2.png', 'Gold', 108, 'Puzzles'),
        _LeaderboardEntry(5, 'DragonSlayer', 'assets/av1.png', 'Gold', 95, 'Puzzles'),
        _LeaderboardEntry(6, 'BugHunter', 'assets/av6.png', 'Gold', 82, 'Puzzles'),
        _LeaderboardEntry(7, 'You', 'assets/av7.png', 'Silver', 70, 'Puzzles'),
        _LeaderboardEntry(8, 'RecursionPro', 'assets/av9.png', 'Silver', 58, 'Puzzles'),
      ],
      // Speed Demons
      [
        _LeaderboardEntry(1, 'RecursionPro', 'assets/av9.png', 'Diamond', 12, 'sec avg'),
        _LeaderboardEntry(2, 'DragonSlayer', 'assets/av1.png', 'Diamond', 15, 'sec avg'),
        _LeaderboardEntry(3, 'CodeNinja', 'assets/av2.png', 'Platinum', 18, 'sec avg'),
        _LeaderboardEntry(4, 'ByteQueen', 'assets/av3.png', 'Platinum', 21, 'sec avg'),
        _LeaderboardEntry(5, 'AlgoKing', 'assets/av4.png', 'Gold', 24, 'sec avg'),
        _LeaderboardEntry(6, 'PixelWitch', 'assets/av5.png', 'Gold', 27, 'sec avg'),
        _LeaderboardEntry(7, 'You', 'assets/av7.png', 'Gold', 30, 'sec avg'),
        _LeaderboardEntry(8, 'BugHunter', 'assets/av6.png', 'Silver', 33, 'sec avg'),
      ],
    ];
    return data[tab];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _getEntries();
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    final maxScore = entries.first.score.toDouble();

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildTabBar(),
            const SizedBox(height: 8),
            _buildTimeFilter(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  PodiumWidget(
                    first: _podiumData(top3[0]),
                    second: _podiumData(top3[1]),
                    third: _podiumData(top3[2]),
                  ),
                  const SizedBox(height: 24),
                  ...rest.map(
                    (e) => _buildRankCard(e, maxScore),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PodiumData _podiumData(_LeaderboardEntry e) => PodiumData(
        username: e.username,
        avatarPath: e.avatarPath,
        score: e.score,
        statLabel: e.statLabel,
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_cyan, _purple],
            ).createShader(bounds),
            child: const Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          _glassIconButton(Icons.info_outline),
        ],
      ),
    );
  }

  Widget _glassIconButton(IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        itemBuilder: (context, i) {
          final selected = _tabController.index == i;
          return GestureDetector(
            onTap: () => _tabController.animateTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: selected
                    ? const LinearGradient(colors: [_cyan, _purple])
                    : null,
                color: selected ? null : Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: selected ? Colors.transparent : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                _tabs[i],
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _timeFilters.map((f) {
        final selected = _timeFilter == f;
        return GestureDetector(
          onTap: () => setState(() => _timeFilter = f),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected ? _magenta.withOpacity(0.25) : Colors.transparent,
              border: Border.all(
                color: selected ? _magenta : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Text(
              f,
              style: TextStyle(
                color: selected ? _magenta : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRankCard(_LeaderboardEntry entry, double maxScore) {
    final isCurrentUser = entry.rank == _currentUserId;
    final isTop10 = entry.rank <= 10;
    final scoreRatio = entry.score / maxScore;

    Color rankColor;
    if (entry.rank <= 3) {
      rankColor = const Color(0xFFF59E0B);
    } else if (isTop10) {
      rankColor = _cyan;
    } else {
      rankColor = Colors.white38;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + entry.rank * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isCurrentUser
                      ? [_cyan.withOpacity(0.15), _purple.withOpacity(0.1)]
                      : [
                          Colors.white.withOpacity(0.07),
                          Colors.white.withOpacity(0.03),
                        ],
                ),
                border: Border.all(
                  color: isCurrentUser ? _cyan.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                  width: isCurrentUser ? 1.5 : 1,
                ),
                boxShadow: isCurrentUser
                    ? [BoxShadow(color: _cyan.withOpacity(0.15), blurRadius: 16)]
                    : null,
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 32,
                    child: Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_cyan.withOpacity(0.3), _purple.withOpacity(0.3)],
                      ),
                      border: Border.all(
                        color: isCurrentUser ? _cyan : Colors.white.withOpacity(0.15),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        entry.username[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + league + bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.username,
                              style: TextStyle(
                                color: isCurrentUser ? _cyan : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _leagueBadge(entry.league),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Animated bar
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: scoreRatio),
                          duration: Duration(milliseconds: 800 + entry.rank * 80),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, _) {
                            return Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: Colors.white.withOpacity(0.06),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: val.clamp(0, 1),
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      gradient: const LinearGradient(
                                        colors: [_cyan, _purple],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _cyan.withOpacity(0.4),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatScore(entry.score),
                        style: TextStyle(
                          color: isTop10 ? _cyan : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        entry.statLabel,
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leagueBadge(String league) {
    Color color;
    switch (league) {
      case 'Diamond':
        color = _cyan;
        break;
      case 'Platinum':
        color = _purple;
        break;
      case 'Gold':
        color = const Color(0xFFF59E0B);
        break;
      case 'Silver':
        color = const Color(0xFFC0C0C0);
        break;
      default:
        color = const Color(0xFFCD7F32);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        league,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatScore(int score) {
    if (score >= 1000) {
      return '${(score / 1000).toStringAsFixed(1)}K';
    }
    return score.toString();
  }
}

class _LeaderboardEntry {
  final int rank;
  final String username;
  final String avatarPath;
  final String league;
  final int score;
  final String statLabel;

  _LeaderboardEntry(
    this.rank,
    this.username,
    this.avatarPath,
    this.league,
    this.score,
    this.statLabel,
  );
}
