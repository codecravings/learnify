import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

/// Small badge showing tutor rank based on accepted answer count.
class TutorBadge extends StatelessWidget {
  const TutorBadge({super.key, required this.acceptedCount});

  final int acceptedCount;

  String get _label {
    if (acceptedCount >= 50) return 'EXPERT';
    if (acceptedCount >= 15) return 'MENTOR';
    if (acceptedCount >= 5) return 'TUTOR';
    if (acceptedCount >= 1) return 'HELPER';
    return '';
  }

  Color _color(BuildContext context) {
    if (acceptedCount >= 50) return AppTheme.accentGoldOf(context);
    if (acceptedCount >= 15) return AppTheme.accentPurpleOf(context);
    if (acceptedCount >= 5) return AppTheme.accentCyanOf(context);
    return AppTheme.accentGreenOf(context);
  }

  @override
  Widget build(BuildContext context) {
    if (acceptedCount < 1) return const SizedBox.shrink();

    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withAlpha(20),
        border: Border.all(color: color.withAlpha(60), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            _label,
            style: GoogleFonts.orbitron(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
