import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const Color _bgPrimary = Color(0xFF111827);
const Color _bgSecondary = Color(0xFF1F2937);
const Color _cyan = Color(0xFF3B82F6);
const Color _purple = Color(0xFF8B5CF6);
const Color _glassFill = Color(0x0FFFFFFF); // white @ 6%
const Color _glassBorder = Color(0x33FFFFFF); // white @ 20%
const Color _textPrimary = Color(0xFFF0F0F0);
const Color _textSecondary = Color(0xB3FFFFFF); // white70
const Color _textTertiary = Color(0x61FFFFFF); // white38

const LinearGradient _neonGradient = LinearGradient(
  colors: [_cyan, _purple],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _bgGradient = LinearGradient(
  colors: [_bgPrimary, _bgSecondary, Color(0xFF1E293B)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.5, 1.0],
);

// ─────────────────────────────────────────────────────────────────────────────
//  ChatListScreen – shows all conversations for the current user
// ─────────────────────────────────────────────────────────────────────────────

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUid => _auth.currentUser?.uid ?? '';

  // ── New-chat dialog ────────────────────────────────────────────────────

  Future<void> _showNewChatDialog() async {
    final searchController = TextEditingController();
    List<QueryDocumentSnapshot> results = [];
    bool searching = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> search(String query) async {
              if (query.trim().isEmpty) {
                setDialogState(() => results = []);
                return;
              }
              setDialogState(() => searching = true);
              try {
                final snap = await _firestore
                    .collection('users')
                    .where('username', isGreaterThanOrEqualTo: query.trim())
                    .where('username',
                        isLessThanOrEqualTo: '${query.trim()}\uf8ff')
                    .limit(10)
                    .get();
                setDialogState(() {
                  results = snap.docs
                      .where((d) => d.id != _currentUid)
                      .toList();
                  searching = false;
                });
              } catch (_) {
                setDialogState(() => searching = false);
              }
            }

            return Dialog(
              backgroundColor: _bgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: _glassBorder, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          _neonGradient.createShader(bounds),
                      child: Text(
                        'NEW CHAT',
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search field
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: TextField(
                          controller: searchController,
                          style: GoogleFonts.spaceGrotesk(
                            color: _textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search username...',
                            hintStyle: GoogleFonts.spaceGrotesk(
                              color: _textTertiary,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _cyan,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: _glassFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _glassBorder,
                                width: 0.8,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _cyan,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: search,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Results
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: _cyan,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (results.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: _glassBorder,
                            height: 1,
                          ),
                          itemBuilder: (_, i) {
                            final data =
                                results[i].data() as Map<String, dynamic>;
                            final uid = results[i].id;
                            final username =
                                data['username'] as String? ?? 'Unknown';

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              leading: _AvatarCircle(
                                letter: username[0].toUpperCase(),
                                size: 36,
                              ),
                              title: Text(
                                username,
                                style: GoogleFonts.spaceGrotesk(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _startChatWith(uid, username);
                              },
                            );
                          },
                        ),
                      )
                    else if (searchController.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No users found',
                          style: GoogleFonts.spaceGrotesk(
                            color: _textTertiary,
                            fontSize: 13,
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

  Future<void> _startChatWith(String otherUid, String otherUsername) async {
    // Check if a chat already exists between these two users
    final existing = await _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUid)
        .get();

    String? existingChatId;
    for (final doc in existing.docs) {
      final participants = List<String>.from(
        doc.data()['participants'] as List<dynamic>? ?? [],
      );
      if (participants.contains(otherUid)) {
        existingChatId = doc.id;
        break;
      }
    }

    if (existingChatId != null) {
      _openChat(existingChatId, otherUsername);
      return;
    }

    // Create new chat document
    final chatDoc = await _firestore.collection('chats').add({
      'participants': [_currentUid, otherUid],
      'participantNames': {
        _currentUid: _auth.currentUser?.displayName ?? 'Me',
        otherUid: otherUsername,
      },
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _openChat(chatDoc.id, otherUsername);
  }

  void _openChat(String chatId, String otherUsername) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          otherUsername: otherUsername,
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  String _otherUsername(Map<String, dynamic> data) {
    final names = data['participantNames'] as Map<String, dynamic>? ?? {};
    for (final entry in names.entries) {
      if (entry.key != _currentUid) {
        return entry.value as String? ?? 'User';
      }
    }
    return 'User';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        }
                      },
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          _neonGradient.createShader(bounds),
                      child: Text(
                        'Messages',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _GlassIconButton(
                      icon: Icons.search_rounded,
                      onTap: _showNewChatDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Chat list ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('chats')
                      .where('participants', arrayContains: _currentUid)
                      .orderBy('lastMessageTime', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _cyan),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFEF4444),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load chats',
                              style: GoogleFonts.spaceGrotesk(
                                color: _textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: _cyan.withOpacity(0.3),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No conversations yet',
                              style: GoogleFonts.spaceGrotesk(
                                color: _textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to start a new chat',
                              style: GoogleFonts.spaceGrotesk(
                                color: _textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data =
                            docs[index].data() as Map<String, dynamic>;
                        final chatId = docs[index].id;
                        final username = _otherUsername(data);
                        final lastMsg =
                            data['lastMessage'] as String? ?? '';
                        final ts =
                            data['lastMessageTime'] as Timestamp?;

                        return _ChatListTile(
                          username: username,
                          lastMessage: lastMsg,
                          timestamp: _formatTimestamp(ts),
                          onTap: () => _openChat(chatId, username),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // ── FAB: New chat ──
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _neonGradient,
          boxShadow: [
            BoxShadow(
              color: _cyan.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: _cyan.withOpacity(0.12),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showNewChatDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.edit_rounded,
            color: _bgPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ChatListTile – a single conversation row with glass styling
// ─────────────────────────────────────────────────────────────────────────────

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.username,
    required this.lastMessage,
    required this.timestamp,
    required this.onTap,
  });

  final String username;
  final String lastMessage;
  final String timestamp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _glassFill,
                border: Border.all(color: _glassBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  // Avatar
                  _AvatarCircle(
                    letter: username.isNotEmpty
                        ? username[0].toUpperCase()
                        : '?',
                    size: 48,
                  ),
                  const SizedBox(width: 14),

                  // Username + last message
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: GoogleFonts.spaceGrotesk(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMessage.isEmpty
                              ? 'Start the conversation...'
                              : lastMessage,
                          style: GoogleFonts.spaceGrotesk(
                            color: lastMessage.isEmpty
                                ? _textTertiary
                                : _textSecondary,
                            fontSize: 13,
                            fontStyle: lastMessage.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Timestamp
                  Text(
                    timestamp,
                    style: GoogleFonts.spaceGrotesk(
                      color: _textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────────────────────
//  ChatDetailScreen – the message thread view
// ─────────────────────────────────────────────────────────────────────────────

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUsername,
  });

  final String chatId;
  final String otherUsername;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String get _currentUid => _auth.currentUser?.uid ?? '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Send message ───────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final timestamp = FieldValue.serverTimestamp();

    // Add message to sub-collection
    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': _currentUid,
      'text': text,
      'timestamp': timestamp,
    });

    // Update chat metadata
    await _firestore.collection('chats').doc(widget.chatId).update({
      'lastMessage': text,
      'lastMessageTime': timestamp,
    });

    // Scroll to bottom after a short delay for the stream to update
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              _buildTopBar(),

              // ── Messages ──
              Expanded(child: _buildMessageList()),

              // ── Input bar ──
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: BoxDecoration(
        color: _glassFill,
        border: const Border(
          bottom: BorderSide(color: _glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Avatar
          _AvatarCircle(
            letter: widget.otherUsername.isNotEmpty
                ? widget.otherUsername[0].toUpperCase()
                : '?',
            size: 38,
          ),
          const SizedBox(width: 12),

          // Username + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUsername,
                  style: GoogleFonts.spaceGrotesk(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online',
                      style: GoogleFonts.spaceGrotesk(
                        color: _textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          _GlassIconButton(
            icon: Icons.more_vert_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _cyan),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.waving_hand_rounded,
                  color: _cyan.withOpacity(0.3),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Say hello!',
                  style: GoogleFonts.spaceGrotesk(
                    color: _textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send the first message to start chatting',
                  style: GoogleFonts.spaceGrotesk(
                    color: _textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        // Auto-scroll when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final senderId = data['senderId'] as String? ?? '';
            final text = data['text'] as String? ?? '';
            final ts = data['timestamp'] as Timestamp?;
            final isSent = senderId == _currentUid;

            // Show date separator if day changes
            Widget? dateSeparator;
            if (index == 0 ||
                _shouldShowDateSeparator(
                  (docs[index - 1].data() as Map<String, dynamic>)['timestamp']
                      as Timestamp?,
                  ts,
                )) {
              dateSeparator = _buildDateSeparator(ts);
            }

            return Column(
              children: [
                if (dateSeparator != null) dateSeparator,
                _MessageBubble(
                  text: text,
                  time: _formatMessageTime(ts),
                  isSent: isSent,
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _shouldShowDateSeparator(Timestamp? prev, Timestamp? current) {
    if (prev == null || current == null) return true;
    final prevDate = prev.toDate();
    final curDate = current.toDate();
    return prevDate.day != curDate.day ||
        prevDate.month != curDate.month ||
        prevDate.year != curDate.year;
  }

  Widget _buildDateSeparator(Timestamp? ts) {
    String label;
    if (ts == null) {
      label = 'Today';
    } else {
      final dt = ts.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0 &&
          dt.day == now.day) {
        label = 'Today';
      } else if (diff.inDays == 1 ||
          (diff.inDays == 0 && dt.day != now.day)) {
        label = 'Yesterday';
      } else {
        const months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        label = '${dt.day} ${months[dt.month]} ${dt.year}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 0.5, color: _glassBorder),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: _textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 0.5, color: _glassBorder),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _glassFill,
        border: const Border(
          top: BorderSide(color: _glassBorder, width: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: _glassBorder, width: 0.5),
            ),
            child: Row(
              children: [
                // Emoji / attachment button
                IconButton(
                  icon: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: _textTertiary,
                    size: 22,
                  ),
                  onPressed: () {},
                ),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    style: GoogleFonts.spaceGrotesk(
                      color: _textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        color: _textTertiary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),

                // Attachment button
                IconButton(
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    color: _textTertiary,
                    size: 22,
                  ),
                  onPressed: () {},
                ),

                // Send button with neon gradient
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _neonGradient,
                        boxShadow: [
                          BoxShadow(
                            color: _cyan.withOpacity(0.35),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: _bgPrimary,
                        size: 18,
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

// ─────────────────────────────────────────────────────────────────────────────
//  _MessageBubble – a single chat message with glass styling
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isSent,
  });

  final String text;
  final String time;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: EdgeInsets.only(
            top: 3,
            bottom: 3,
            left: isSent ? 48 : 0,
            right: isSent ? 0 : 48,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isSent ? 18 : 4),
              bottomRight: Radius.circular(isSent ? 4 : 18),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isSent ? 18 : 4),
                    bottomRight: Radius.circular(isSent ? 4 : 18),
                  ),
                  gradient: isSent
                      ? LinearGradient(
                          colors: [
                            _cyan.withOpacity(0.20),
                            _cyan.withOpacity(0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.10),
                            Colors.white.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(
                    color: isSent
                        ? _cyan.withOpacity(0.25)
                        : Colors.white.withOpacity(0.10),
                    width: 0.5,
                  ),
                  boxShadow: isSent
                      ? [
                          BoxShadow(
                            color: _cyan.withOpacity(0.08),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isSent
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: GoogleFonts.spaceGrotesk(
                        color: _textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: GoogleFonts.spaceGrotesk(
                            color: _textTertiary,
                            fontSize: 10,
                          ),
                        ),
                        if (isSent) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: _cyan.withOpacity(0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.letter,
    this.size = 44,
  });

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _cyan.withOpacity(0.30),
            _purple.withOpacity(0.30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _cyan.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _cyan.withOpacity(0.10),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.orbitron(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
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
            child: Icon(icon, color: _textSecondary, size: 20),
          ),
        ),
      ),
    );
  }
}
