import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/follow_service.dart';
import '../../../core/theme/app_theme.dart';

/// Follow/Unfollow toggle button with glass styling.
class FollowButton extends StatefulWidget {
  const FollowButton({super.key, required this.targetUid});
  final String targetUid;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isFollowing = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final result = await FollowService.instance.isFollowing(widget.targetUid);
    if (mounted) setState(() { _isFollowing = result; _loading = false; });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);

    if (_isFollowing) {
      await FollowService.instance.unfollow(widget.targetUid);
    } else {
      await FollowService.instance.follow(widget.targetUid);
    }

    if (mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 80, height: 32);

    final accent = AppTheme.accentCyanOf(context);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: _isFollowing
              ? null
              : LinearGradient(colors: [accent, accent.withAlpha(180)]),
          color: _isFollowing ? Colors.transparent : null,
          border: Border.all(
            color: _isFollowing ? AppTheme.glassBorderOf(context) : accent,
            width: _isFollowing ? 0.8 : 1.2,
          ),
        ),
        child: _busy
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isFollowing ? AppTheme.textSecondaryOf(context) : Colors.white,
                ),
              )
            : Text(
                _isFollowing ? 'Following' : 'Follow',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isFollowing ? AppTheme.textSecondaryOf(context) : Colors.white,
                ),
              ),
      ),
    );
  }
}
