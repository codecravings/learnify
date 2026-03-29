import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/achievement_card.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bgColor = Color(0xFF111827);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _magenta = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);

  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Study', 'Quiz', 'Streak', 'Special'];

  final List<AchievementData> _achievements = [
    // Study achievements
    AchievementData(
      id: 's1', name: 'First Lesson', description: 'Complete your first lesson',
      icon: Icons.school_rounded, category: 'Study', rarity: AchievementRarity.common,
      xpReward: 50, progress: 1.0, isUnlocked: true, unlockedDate: '2024-01-15',
    ),
    AchievementData(
      id: 's2', name: 'Knowledge Seeker', description: 'Study 5 different topics',
      icon: Icons.explore_rounded, category: 'Study', rarity: AchievementRarity.common,
      xpReward: 100, progress: 0.6, isUnlocked: false,
    ),
    AchievementData(
      id: 's3', name: 'Topic Master', description: 'Study 10 different topics',
      icon: Icons.workspace_premium_rounded, category: 'Study', rarity: AchievementRarity.rare,
      xpReward: 250, progress: 0.3, isUnlocked: false,
    ),
    AchievementData(
      id: 's4', name: 'Scholar Elite', description: 'Study 25 different topics',
      icon: Icons.auto_awesome, category: 'Study', rarity: AchievementRarity.legendary,
      xpReward: 1000, progress: 0.12, isUnlocked: false,
    ),
    // Quiz achievements
    AchievementData(
      id: 'q1', name: 'First Quiz', description: 'Complete your first quiz',
      icon: Icons.quiz_rounded, category: 'Quiz', rarity: AchievementRarity.common,
      xpReward: 50, progress: 1.0, isUnlocked: true, unlockedDate: '2024-01-15',
    ),
    AchievementData(
      id: 'q2', name: 'Perfect Score', description: 'Score 100% on any quiz',
      icon: Icons.stars_rounded, category: 'Quiz', rarity: AchievementRarity.rare,
      xpReward: 200, progress: 0.0, isUnlocked: false,
    ),
    AchievementData(
      id: 'q3', name: 'Advanced Scholar', description: 'Complete an advanced level lesson',
      icon: Icons.psychology_rounded, category: 'Quiz', rarity: AchievementRarity.epic,
      xpReward: 400, progress: 0.0, isUnlocked: false,
    ),
    AchievementData(
      id: 'q4', name: 'Quiz Legend', description: 'Complete 50 quizzes with 70%+ accuracy',
      icon: Icons.emoji_events_rounded, category: 'Quiz', rarity: AchievementRarity.legendary,
      xpReward: 1500, progress: 0.1, isUnlocked: false,
    ),
    // Streak achievements
    AchievementData(
      id: 'st1', name: 'Getting Started', description: 'Maintain a 3-day learning streak',
      icon: Icons.local_fire_department_rounded, category: 'Streak', rarity: AchievementRarity.common,
      xpReward: 75, progress: 0.67, isUnlocked: false,
    ),
    AchievementData(
      id: 'st2', name: 'Week Warrior', description: 'Maintain a 7-day learning streak',
      icon: Icons.whatshot_rounded, category: 'Streak', rarity: AchievementRarity.rare,
      xpReward: 200, progress: 0.28, isUnlocked: false,
    ),
    AchievementData(
      id: 'st3', name: 'Fortnight Focus', description: 'Maintain a 14-day learning streak',
      icon: Icons.local_fire_department, category: 'Streak', rarity: AchievementRarity.epic,
      xpReward: 500, progress: 0.14, isUnlocked: false,
    ),
    AchievementData(
      id: 'st4', name: 'Monthly Master', description: 'Maintain a 30-day learning streak',
      icon: Icons.military_tech_rounded, category: 'Streak', rarity: AchievementRarity.legendary,
      xpReward: 1000, progress: 0.07, isUnlocked: false,
    ),
    // Special achievements
    AchievementData(
      id: 'sp1', name: 'Early Adopter', description: 'Join EduJu in the early days',
      icon: Icons.rocket_launch, category: 'Special', rarity: AchievementRarity.rare,
      xpReward: 500, progress: 1.0, isUnlocked: true, unlockedDate: '2024-01-01',
    ),
    AchievementData(
      id: 'sp2', name: 'Night Owl', description: 'Complete 10 lessons between midnight and 5 AM',
      icon: Icons.nights_stay, category: 'Special', rarity: AchievementRarity.epic,
      xpReward: 350, progress: 0.5, isUnlocked: false,
    ),
    AchievementData(
      id: 'sp3', name: 'XP Legend', description: 'Earn 5000 total XP',
      icon: Icons.bolt_rounded, category: 'Special', rarity: AchievementRarity.legendary,
      xpReward: 2000, progress: 0.1, isUnlocked: false,
    ),
  ];

  List<AchievementData> get _filteredAchievements {
    if (_selectedCategory == 'All') return _achievements;
    return _achievements.where((a) => a.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    final total = _achievements.length;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(unlocked, total),
            const SizedBox(height: 12),
            _buildCategoryTabs(),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _filteredAchievements.length,
                itemBuilder: (context, i) {
                  final a = _filteredAchievements[i];
                  return GestureDetector(
                    onTap: () => _showDetailPopup(a),
                    child: AchievementCard(data: a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int unlocked, int total) {
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
              'Achievements',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _green.withOpacity(0.15),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: Text(
              '$unlocked / $total',
              style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: selected
                    ? const LinearGradient(colors: [_purple, _magenta])
                    : null,
                color: selected ? null : Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: selected ? Colors.transparent : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                cat,
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

  void _showDetailPopup(AchievementData a) {
    final rarityColor = a.rarityColor;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF111827).withOpacity(0.9),
                border: Border.all(color: rarityColor.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: rarityColor.withOpacity(0.2), blurRadius: 30),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          rarityColor.withOpacity(a.isUnlocked ? 0.3 : 0.1),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: a.isUnlocked
                          ? [BoxShadow(color: rarityColor.withOpacity(0.4), blurRadius: 20)]
                          : null,
                    ),
                    child: Icon(
                      a.icon,
                      size: 40,
                      color: a.isUnlocked ? rarityColor : Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Rarity
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: rarityColor.withOpacity(0.15),
                      border: Border.all(color: rarityColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      a.rarity.name.toUpperCase(),
                      style: TextStyle(
                        color: rarityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    a.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.description,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Progress
                  if (!a.isUnlocked) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Progress', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(
                          '${(a.progress * 100).toInt()}%',
                          style: TextStyle(color: rarityColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: a.progress,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation(rarityColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (a.isUnlocked && a.unlockedDate != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, color: _green, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Unlocked: ${a.unlockedDate}',
                          style: const TextStyle(color: _green, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // XP
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: [_cyan, _purple]),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '+${a.xpReward} XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
