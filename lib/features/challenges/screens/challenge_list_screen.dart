import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/challenge_model.dart';
import 'package:vidyasetu/features/challenges/widgets/challenge_card.dart';

// ─── State notifier (minimal; swap for Riverpod/Bloc as needed) ─────────

class _ChallengeListState {
  final List<ChallengeModel> challenges;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final ChallengeType? selectedType;
  final int? selectedDifficulty;

  const _ChallengeListState({
    this.challenges = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedType,
    this.selectedDifficulty,
  });

  _ChallengeListState copyWith({
    List<ChallengeModel>? challenges,
    bool? isLoading,
    String? error,
    String? searchQuery,
    ChallengeType? selectedType,
    int? selectedDifficulty,
    bool clearType = false,
    bool clearDifficulty = false,
    bool clearError = false,
  }) {
    return _ChallengeListState(
      challenges: challenges ?? this.challenges,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
      selectedDifficulty: clearDifficulty
          ? null
          : (selectedDifficulty ?? this.selectedDifficulty),
    );
  }

  List<ChallengeModel> get filtered {
    var result = challenges;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              c.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    if (selectedType != null) {
      result = result.where((c) => c.type == selectedType).toList();
    }
    if (selectedDifficulty != null) {
      result = result.where((c) => c.difficulty == selectedDifficulty).toList();
    }
    return result;
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────

class ChallengeListScreen extends StatefulWidget {
  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  final _searchController = TextEditingController();
  var _state = const _ChallengeListState();

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() => _state = _state.copyWith(isLoading: true, clearError: true));
    try {
      // TODO: Replace with actual service call
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final mockChallenges = List.generate(12, (i) {
        final types = ChallengeType.values;
        return ChallengeModel(
          id: 'ch_$i',
          title: [
            'Binary Search Puzzle',
            'SQL Injection Hunt',
            'Pattern Matrix',
            'Recursive Riddle',
            'Crypto Cipher',
            'Graph Traversal',
            'Logic Gate Master',
            'Stack Overflow Fix',
            'Prime Sequence',
            'Network Probe',
            'Sort Race',
            'Memory Leak Hunt',
          ][i],
          description: 'Solve this ${types[i % types.length].name} challenge.',
          difficulty: (i % 5) + 1,
          type: types[i % types.length],
          solution: 'solution_$i',
          hints: ['Think carefully', 'Use recursion', 'Check edge cases'],
          tags: [types[i % types.length].name, 'featured'],
          creatorId: 'user_$i',
          creatorUsername: 'guru_$i',
          solveCount: 50 + i * 7,
          attemptCount: 120 + i * 13,
          avgSolveTime: 180 + i * 20,
          xpReward: 20 + i * 5,
          createdAt: DateTime.now().subtract(Duration(days: i)),
        );
      });
      setState(() => _state = _state.copyWith(
            challenges: mockChallenges,
            isLoading: false,
          ));
    } catch (e) {
      setState(() => _state = _state.copyWith(
            isLoading: false,
            error: e.toString(),
          ));
    }
  }

  void _setSearch(String query) {
    setState(() => _state = _state.copyWith(searchQuery: query));
  }

  void _setType(ChallengeType? type) {
    setState(() {
      if (type == _state.selectedType) {
        _state = _state.copyWith(clearType: true);
      } else {
        _state = _state.copyWith(selectedType: type, clearType: type == null);
      }
    });
  }

  void _setDifficulty(int? diff) {
    setState(() {
      if (diff == _state.selectedDifficulty) {
        _state = _state.copyWith(clearDifficulty: true);
      } else {
        _state = _state.copyWith(
          selectedDifficulty: diff,
          clearDifficulty: diff == null,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _state.filtered;

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar area ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'CHALLENGES',
                      style: AppTheme.headerStyle(fontSize: 20),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded,
                          color: AppTheme.accentCyan),
                      onPressed: () => _showDifficultyPicker(context),
                      tooltip: 'Difficulty filter',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassMorphism(
                  borderRadius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _setSearch,
                    style: AppTheme.bodyStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search challenges...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _setSearch('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Type filter chips ──
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _TypeChip(
                      label: 'All',
                      icon: Icons.grid_view_rounded,
                      color: AppTheme.accentCyan,
                      isSelected: _state.selectedType == null,
                      onTap: () => _setType(null),
                    ),
                    ...ChallengeType.values.map((type) {
                      final s = ChallengeTypeStyle.fromType(type);
                      return _TypeChip(
                        label: type.name[0].toUpperCase() +
                            type.name.substring(1),
                        icon: s.icon,
                        color: s.color,
                        isSelected: _state.selectedType == type,
                        onTap: () => _setType(type),
                      );
                    }),
                  ],
                ),
              ),

              // ── Difficulty indicator ──
              if (_state.selectedDifficulty != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        'Difficulty: ',
                        style: AppTheme.bodyStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      ...List.generate(
                        _state.selectedDifficulty!,
                        (i) => const Icon(Icons.star_rounded,
                            size: 14, color: AppTheme.accentGold),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _setDifficulty(null),
                        child: Text(
                          'Clear',
                          style: AppTheme.bodyStyle(
                            fontSize: 12,
                            color: AppTheme.accentMagenta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 4),

              // ── Challenge list ──
              Expanded(
                child: _state.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accentCyan,
                        ),
                      )
                    : _state.error != null
                        ? _ErrorView(
                            message: _state.error!,
                            onRetry: _loadChallenges,
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No challenges found',
                                  style: AppTheme.bodyStyle(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                color: AppTheme.accentCyan,
                                backgroundColor: AppTheme.backgroundSecondary,
                                onRefresh: _loadChallenges,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 90),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final challenge = filtered[index];
                                    return ChallengeCard(
                                      challenge: challenge,
                                      onTap: () =>
                                          _navigateToDetail(challenge),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),

      // ── FAB: Create challenge ──
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppTheme.primaryGradient,
          boxShadow: AppTheme.neonGlow(AppTheme.accentCyan, blur: 14),
        ),
        child: FloatingActionButton(
          onPressed: _navigateToCreate,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded,
              color: AppTheme.backgroundPrimary, size: 28),
        ),
      ),
    );
  }

  // ── Navigation ──

  void _navigateToDetail(ChallengeModel challenge) {
    // TODO: Navigator.push to ChallengeDetailScreen
  }

  void _navigateToCreate() {
    // TODO: Navigator.push to CreateChallengeScreen
  }

  // ── Difficulty picker bottom sheet ──

  void _showDifficultyPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassMorphism(
          blur: 20,
          borderRadius: 24,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filter by Difficulty',
                  style: AppTheme.headerStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ...List.generate(5, (i) {
                final diff = i + 1;
                final selected = _state.selectedDifficulty == diff;
                return ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      diff,
                      (_) => const Icon(Icons.star_rounded,
                          size: 18, color: AppTheme.accentGold),
                    ),
                  ),
                  title: Text(
                    ['Beginner', 'Easy', 'Medium', 'Hard', 'Expert'][i],
                    style: AppTheme.bodyStyle(
                      color: selected
                          ? AppTheme.accentCyan
                          : AppTheme.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accentCyan, size: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    _setDifficulty(diff);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _setDifficulty(null);
                  Navigator.pop(ctx);
                },
                child: const Text('Clear Filter'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Private widgets ─────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(35) : AppTheme.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : AppTheme.glassBorder,
              width: isSelected ? 1.2 : 0.5,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withAlpha(30), blurRadius: 8)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: isSelected ? color : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.bodyStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.accentMagenta, size: 48),
          const SizedBox(height: 12),
          Text(message,
              style: AppTheme.bodyStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
