import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/forum_post_model.dart';
import 'package:vidyasetu/features/forum/widgets/forum_post_card.dart';

// ─── Sort mode ──────────────────────────────────────────────────────────

enum ForumSortMode { hot, recent, unsolved }

extension ForumSortModeX on ForumSortMode {
  String get label {
    switch (this) {
      case ForumSortMode.hot:
        return 'Hot';
      case ForumSortMode.recent:
        return 'New';
      case ForumSortMode.unsolved:
        return 'Unsolved';
    }
  }

  IconData get icon {
    switch (this) {
      case ForumSortMode.hot:
        return Icons.local_fire_department_rounded;
      case ForumSortMode.recent:
        return Icons.schedule_rounded;
      case ForumSortMode.unsolved:
        return Icons.help_outline_rounded;
    }
  }
}

// ─── State ──────────────────────────────────────────────────────────────

class _ForumState {
  final List<ForumPostModel> posts;
  final bool isLoading;
  final String? error;
  final String selectedCategory;
  final ForumSortMode sortMode;

  const _ForumState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory = 'all',
    this.sortMode = ForumSortMode.hot,
  });

  _ForumState copyWith({
    List<ForumPostModel>? posts,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    ForumSortMode? sortMode,
    bool clearError = false,
  }) {
    return _ForumState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortMode: sortMode ?? this.sortMode,
    );
  }

  List<ForumPostModel> get filtered {
    var result = posts;
    if (selectedCategory != 'all') {
      result = result
          .where((p) => p.category.toLowerCase() == selectedCategory)
          .toList();
    }
    switch (sortMode) {
      case ForumSortMode.hot:
        result = List.from(result)..sort((a, b) => b.score.compareTo(a.score));
        break;
      case ForumSortMode.recent:
        result = List.from(result)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ForumSortMode.unsolved:
        result = result.where((p) => !p.isResolved).toList();
        break;
    }
    return result;
  }
}

// ─── Categories ─────────────────────────────────────────────────────────

const _categories = <String, IconData>{
  'all': Icons.grid_view_rounded,
  'logic': Icons.psychology_outlined,
  'coding': Icons.code_rounded,
  'cybersecurity': Icons.security_rounded,
  'math': Icons.functions_rounded,
  'general': Icons.forum_outlined,
};

const _categoryColors = <String, Color>{
  'all': AppTheme.accentCyan,
  'logic': AppTheme.accentCyan,
  'coding': AppTheme.accentGreen,
  'cybersecurity': AppTheme.accentMagenta,
  'math': AppTheme.accentGold,
  'general': AppTheme.accentPurple,
};

// ─── Screen ─────────────────────────────────────────────────────────────

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  var _state = const _ForumState();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _state = _state.copyWith(isLoading: true, clearError: true));
    try {
      // TODO: Replace with actual service call
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final mockPosts = List.generate(10, (i) {
        final cats = ['logic', 'coding', 'cybersecurity', 'math', 'general'];
        return ForumPostModel(
          id: 'fp_$i',
          title: [
            'How to approach binary tree problems?',
            'Best resources for CTF beginners',
            'Stuck on recursive backtracking',
            'Understanding Big-O notation',
            'Tips for competitive math Olympiads',
            'XSS prevention strategies',
            'Dynamic programming roadmap',
            'Help with graph coloring',
            'Efficient sorting for large datasets',
            'Proof techniques for number theory',
          ][i],
          content: 'I have been trying to understand this concept '
              'and would love some guidance from the community. '
              'Any tips or resources would be greatly appreciated.',
          authorId: 'user_$i',
          authorUsername: 'learner_$i',
          tags: [cats[i % cats.length], 'help'],
          category: cats[i % cats.length],
          upvotes: 15 + i * 3,
          downvotes: i,
          solutions: i < 6
              ? List.generate(
                  i + 1,
                  (j) => ForumSolution(
                    id: 'sol_${i}_$j',
                    content: 'Solution content $j',
                    authorId: 'user_$j',
                    authorUsername: 'helper_$j',
                    upvotes: 5 + j,
                    createdAt:
                        DateTime.now().subtract(Duration(hours: j * 2)),
                    isAccepted: j == 0 && i % 3 == 0,
                  ),
                )
              : [],
          createdAt: DateTime.now().subtract(Duration(hours: i * 5)),
          isResolved: i % 3 == 0,
          bestSolutionId: i % 3 == 0 ? 'sol_${i}_0' : null,
        );
      });
      setState(
          () => _state = _state.copyWith(posts: mockPosts, isLoading: false));
    } catch (e) {
      setState(() =>
          _state = _state.copyWith(isLoading: false, error: e.toString()));
    }
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
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text('FORUM',
                        style: AppTheme.headerStyle(fontSize: 20)),
                    const Spacer(),
                    _SortDropdown(
                      current: _state.sortMode,
                      onChanged: (m) =>
                          setState(() => _state = _state.copyWith(sortMode: m)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Category tabs ──
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _categories.entries.map((entry) {
                    final selected =
                        _state.selectedCategory == entry.key;
                    final color =
                        _categoryColors[entry.key] ?? AppTheme.accentCyan;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _state =
                            _state.copyWith(selectedCategory: entry.key)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withAlpha(35)
                                : AppTheme.glassFill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? color : AppTheme.glassBorder,
                              width: selected ? 1.2 : 0.5,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color: color.withAlpha(30),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(entry.value,
                                  size: 15,
                                  color: selected
                                      ? color
                                      : AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                entry.key[0].toUpperCase() +
                                    entry.key.substring(1),
                                style: AppTheme.bodyStyle(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? color
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // ── Post list ──
              Expanded(
                child: _state.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accentCyan),
                      )
                    : _state.error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppTheme.accentMagenta, size: 48),
                                const SizedBox(height: 12),
                                Text(_state.error!,
                                    style: AppTheme.bodyStyle(
                                        color: AppTheme.textSecondary)),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _loadPosts,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No posts found',
                                  style: AppTheme.bodyStyle(
                                      color: AppTheme.textTertiary),
                                ),
                              )
                            : RefreshIndicator(
                                color: AppTheme.accentCyan,
                                backgroundColor:
                                    AppTheme.backgroundSecondary,
                                onRefresh: _loadPosts,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                      top: 4, bottom: 90),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final post = filtered[index];
                                    return ForumPostCard(
                                      post: post,
                                      onTap: () => _navigateToPost(post),
                                      onUpvote: () => _vote(post, true),
                                      onDownvote: () => _vote(post, false),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),

      // ── FAB: Create post ──
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppTheme.primaryGradient,
          boxShadow: AppTheme.neonGlow(AppTheme.accentCyan, blur: 14),
        ),
        child: FloatingActionButton(
          onPressed: _navigateToCreatePost,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.edit_rounded,
              color: AppTheme.backgroundPrimary, size: 24),
        ),
      ),
    );
  }

  void _vote(ForumPostModel post, bool isUpvote) {
    setState(() {
      final updated = _state.posts.map((p) {
        if (p.id != post.id) return p;
        return p.copyWith(
          upvotes: isUpvote ? p.upvotes + 1 : p.upvotes,
          downvotes: !isUpvote ? p.downvotes + 1 : p.downvotes,
        );
      }).toList();
      _state = _state.copyWith(posts: updated);
    });
    // TODO: Call vote service
  }

  void _navigateToPost(ForumPostModel post) {
    // TODO: Navigator.push to ForumPostScreen
  }

  void _navigateToCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreatePostSheet(
        onPostCreated: () {
          _loadPosts();
        },
      ),
    );
  }
}

// ─── Create Post Bottom Sheet ────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.onPostCreated});
  final VoidCallback onPostCreated;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final tagsRaw = _tagsController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be signed in to post');
      }

      final tags = tagsRaw.isEmpty
          ? <String>[]
          : tagsRaw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();

      await FirebaseFirestore.instance.collection('forum_posts').add({
        'title': title,
        'body': body,
        'tags': tags,
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'downvotes': 0,
        'solutionCount': 0,
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPostCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: GlassMorphism(
        blur: 18,
        borderRadius: 24,
        opacity: 0.14,
        borderColor: AppTheme.accentCyan.withAlpha(60),
        borderWidth: 1.0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: AppTheme.backgroundSecondary.withAlpha(220),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.glassBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Title ──
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradientOf(context).createShader(bounds),
                  child: Text(
                    'CREATE POST',
                    style: AppTheme.headerStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title field ──
                TextField(
                  controller: _titleController,
                  style: AppTheme.bodyStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Post title',
                    hintStyle: AppTheme.bodyStyle(color: AppTheme.textTertiary),
                    prefixIcon: const Icon(Icons.title_rounded,
                        color: AppTheme.accentCyan, size: 20),
                    filled: true,
                    fillColor: AppTheme.glassFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.glassBorder, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.accentCyan, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Body / description field ──
                TextField(
                  controller: _bodyController,
                  style: AppTheme.bodyStyle(fontSize: 14),
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe your question or topic...',
                    hintStyle: AppTheme.bodyStyle(color: AppTheme.textTertiary),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: Icon(Icons.notes_rounded,
                          color: AppTheme.accentCyan, size: 20),
                    ),
                    filled: true,
                    fillColor: AppTheme.glassFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.glassBorder, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.accentCyan, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Tags field ──
                TextField(
                  controller: _tagsController,
                  style: AppTheme.bodyStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tags (comma separated, e.g. math, logic)',
                    hintStyle: AppTheme.bodyStyle(color: AppTheme.textTertiary),
                    prefixIcon: const Icon(Icons.label_outline_rounded,
                        color: AppTheme.accentCyan, size: 20),
                    filled: true,
                    fillColor: AppTheme.glassFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.glassBorder, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.accentCyan, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Post button ──
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AppTheme.primaryGradient,
                    boxShadow: AppTheme.neonGlow(AppTheme.accentCyan, blur: 10),
                  ),
                  child: ElevatedButton(
                    onPressed: _isPosting ? null : _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.backgroundPrimary,
                            ),
                          )
                        : Text(
                            'POST',
                            style: AppTheme.headerStyle(
                              fontSize: 14,
                              color: AppTheme.backgroundPrimary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sort dropdown ──────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.current, required this.onChanged});
  final ForumSortMode current;
  final ValueChanged<ForumSortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism.subtle(
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ForumSortMode>(
          value: current,
          dropdownColor: AppTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.expand_more_rounded,
              color: AppTheme.accentCyan, size: 18),
          style: AppTheme.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600),
          items: ForumSortMode.values.map((mode) {
            return DropdownMenuItem(
              value: mode,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon, size: 14, color: AppTheme.accentCyan),
                  const SizedBox(width: 6),
                  Text(mode.label),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
