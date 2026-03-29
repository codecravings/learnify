import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/follow_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../auth/services/auth_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _followService = FollowService.instance;
  final _users = FirebaseFirestore.instance.collection('users');

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _suggested = [];
  Set<String> _followingSet = {};
  bool _loading = false;
  bool _loadingSuggested = true;
  String? _error;
  Timer? _debounce;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_onSearchChanged);
  }

  Future<void> _init() async {
    // Make sure current user's profile exists in Firestore first
    await AuthService().ensureProfileExists();
    _loadFollowing();
    _loadSuggested();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    try {
      final list = await _followService.getFollowingList();
      if (mounted) setState(() => _followingSet = list.toSet());
    } catch (e) {
      debugPrint('[SEARCH] Error loading following: $e');
    }
  }

  Future<void> _loadSuggested() async {
    try {
      final uid = _myUid;

      final snap = await _users.limit(50).get();
      debugPrint('[SEARCH] Found ${snap.docs.length} users, myUid=$uid');

      final users = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        if (d.id == uid) continue;
        final data = d.data();
        users.add({'uid': d.id, ...data});
      }

      // If no other users found and we haven't retried yet, wait and retry
      // (profile creation might still be in progress)
      if (users.isEmpty && _retryCount < 2) {
        _retryCount++;
        debugPrint('[SEARCH] No users found, retry $_retryCount in 2s...');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) return _loadSuggested();
      }

      if (mounted) setState(() {
        _suggested = users;
        _loadingSuggested = false;
      });
    } catch (e) {
      debugPrint('[SEARCH] Error loading users: $e');
      if (mounted) setState(() {
        _loadingSuggested = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final lower = query.toLowerCase();
      // Firestore doesn't support full-text search, so we fetch and filter locally
      final snap = await _users.limit(50).get();
      final matches = snap.docs
          .where((d) => d.id != _myUid)
          .where((d) {
            final data = d.data();
            final name = (data['username'] as String? ?? '').toLowerCase();
            final email = (data['email'] as String? ?? '').toLowerCase();
            final bio = (data['bio'] as String? ?? '').toLowerCase();
            return name.contains(lower) ||
                email.contains(lower) ||
                bio.contains(lower);
          })
          .map((d) => {'uid': d.id, ...d.data()})
          .toList();

      if (mounted) setState(() {
        _results = matches;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String uid) async {
    final isFollowing = _followingSet.contains(uid);
    // Optimistic update
    setState(() {
      if (isFollowing) {
        _followingSet.remove(uid);
      } else {
        _followingSet.add(uid);
      }
    });
    try {
      if (isFollowing) {
        await _followService.unfollow(uid);
      } else {
        await _followService.follow(uid);
      }
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() {
        if (isFollowing) {
          _followingSet.add(uid);
        } else {
          _followingSet.remove(uid);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildSearchBar(),
              const SizedBox(height: 8),
              Expanded(
                child: hasQuery
                    ? _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accentCyan,
                            ))
                        : _results.isEmpty
                            ? _buildNoResults()
                            : _buildUserList(_results, 'Results')
                    : _buildSuggestedSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios,
                color: AppTheme.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.accentCyan, AppTheme.accentPurple],
            ).createShader(bounds),
            child: Text(
              'Find People',
              style: AppTheme.headerStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        borderColor: _focusNode.hasFocus
            ? AppTheme.accentCyan.withAlpha(100)
            : AppTheme.glassBorder,
        padding: EdgeInsets.zero,
        child: TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          style: AppTheme.bodyStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search by name or email...',
            hintStyle: AppTheme.bodyStyle(
                fontSize: 14, color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.search,
                color: AppTheme.accentCyan, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _focusNode.unfocus();
                    },
                    child: const Icon(Icons.close,
                        color: AppTheme.textTertiary, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedSection() {
    if (_loadingSuggested) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off,
                  size: 64, color: AppTheme.accentMagenta.withAlpha(120)),
              const SizedBox(height: 16),
              Text('Firestore Error',
                  style: AppTheme.bodyStyle(color: AppTheme.textSecondary, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_error!,
                  style: AppTheme.bodyStyle(color: AppTheme.textTertiary, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _error = null;
                    _loadingSuggested = true;
                  });
                  _loadSuggested();
                },
                child: Text('TAP TO RETRY',
                    style: AppTheme.bodyStyle(color: AppTheme.accentCyan, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }
    if (_suggested.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: AppTheme.accentCyan.withAlpha(80)),
            const SizedBox(height: 16),
            Text('No users found yet',
                style: AppTheme.bodyStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return _buildUserList(_suggested, 'People on VidyaSetu');
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, String title) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: users.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: AppTheme.headerStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                letterSpacing: 2,
              ),
            ),
          );
        }
        return _buildUserCard(users[i - 1]);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final uid = user['uid'] as String? ?? '';
    final name = user['username'] as String? ?? user['displayName'] as String? ?? 'User';
    final email = user['email'] as String? ?? '';
    final xp = (user['xp'] as num?)?.toInt() ?? 0;
    final streak = (user['currentStreak'] as num?)?.toInt() ?? 0;
    final isFollowing = _followingSet.contains(uid);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        borderColor: isFollowing
            ? AppTheme.accentCyan.withAlpha(60)
            : AppTheme.glassBorder,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentCyan.withAlpha(40),
                    AppTheme.accentPurple.withAlpha(15),
                  ],
                ),
                border: Border.all(
                  color: isFollowing
                      ? AppTheme.accentCyan
                      : AppTheme.glassBorder,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTheme.headerStyle(
                    fontSize: 18,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTheme.bodyStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppTheme.bodyStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bolt, size: 12, color: AppTheme.accentGold),
                      const SizedBox(width: 2),
                      Text(
                        '$xp XP',
                        style: AppTheme.bodyStyle(
                          fontSize: 10,
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (streak > 0) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.local_fire_department,
                            size: 12, color: AppTheme.accentOrange),
                        const SizedBox(width: 2),
                        Text(
                          '$streak day streak',
                          style: AppTheme.bodyStyle(
                            fontSize: 10,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Follow button
            GestureDetector(
              onTap: () => _toggleFollow(uid),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: isFollowing
                      ? null
                      : const LinearGradient(
                          colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                        ),
                  color: isFollowing ? Colors.white.withAlpha(10) : null,
                  border: isFollowing
                      ? Border.all(color: AppTheme.glassBorder)
                      : null,
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: AppTheme.bodyStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isFollowing
                        ? AppTheme.textSecondary
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64, color: AppTheme.accentCyan.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: AppTheme.bodyStyle(
                fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different name or email',
            style: AppTheme.bodyStyle(
                fontSize: 13, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}
