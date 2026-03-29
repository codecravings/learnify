import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/neon_button.dart';
import '../services/root_cause_service.dart';
import 'prerequisite_chain_widget.dart';

/// Card shown on the quiz results screen after failure.
/// Shows root cause analysis with prerequisite chain visualization.
class RootCauseCard extends StatefulWidget {
  const RootCauseCard({
    super.key,
    required this.topic,
    required this.accuracy,
    required this.missedQuestions,
    required this.conceptsCovered,
  });

  final String topic;
  final int accuracy;
  final List<String> missedQuestions;
  final List<String> conceptsCovered;

  @override
  State<RootCauseCard> createState() => _RootCauseCardState();
}

class _RootCauseCardState extends State<RootCauseCard> {
  RootCauseAnalysis? _analysis;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final result = await RootCauseService.instance.analyzeFailure(
        topic: widget.topic,
        accuracy: widget.accuracy,
        missedQuestions: widget.missedQuestions,
        conceptsCovered: widget.conceptsCovered,
      );
      if (mounted) setState(() { _analysis = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_analysis == null) return const SizedBox.shrink();

    // Perfect score — all good
    if (widget.accuracy >= 100 || _analysis!.severity == 'none') {
      return _buildAllGood();
    }

    return _buildAnalysisCard();
  }

  Widget _buildLoading() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: AppTheme.accentPurple.withAlpha(40),
      child: Shimmer.fromColors(
        baseColor: AppTheme.textTertiary.withAlpha(50),
        highlightColor: AppTheme.accentCyan.withAlpha(80),
        child: Column(
          children: [
            Container(
              height: 12,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 8,
              width: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllGood() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: AppTheme.accentGreen.withAlpha(60),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentGreen.withAlpha(30),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppTheme.accentGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREREQUISITES STRONG',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentGreen,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your foundation for this topic is solid!',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final a = _analysis!;
    final severityColor = switch (a.severity) {
      'foundational_gap' => const Color(0xFFEF4444),
      'significant_gap' => const Color(0xFFF97316),
      _ => AppTheme.accentCyan,
    };

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: severityColor.withAlpha(50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: severityColor.withAlpha(30),
                    boxShadow: [
                      BoxShadow(
                        color: severityColor.withAlpha(40),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology_alt,
                    color: severityColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KNOWLEDGE GAP DETECTED',
                        style: GoogleFonts.orbitron(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: severityColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.severityLabel,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Root cause highlight
          if (a.rootCauseConcept != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: severityColor.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: severityColor.withAlpha(40),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed, color: severityColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                        children: [
                          const TextSpan(text: 'Root cause: '),
                          TextSpan(
                            text: a.rootCauseConcept!.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: severityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Prerequisite chain visualization
          if (a.missingPrerequisites.isNotEmpty) ...[
            Text(
              'PREREQUISITE CHAIN',
              style: GoogleFonts.orbitron(
                fontSize: 8,
                color: AppTheme.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            PrerequisiteChainWidget(
              chain: a.missingPrerequisites,
              accuracyMap: const {}, // Will be populated from service
              targetConcept: a.matchedConcept,
              rootCauseId: a.rootCauseConcept?.id,
            ),
            const SizedBox(height: 12),
          ],

          // Expanded: AI explanation + actions
          if (_expanded || a.missingPrerequisites.isEmpty) ...[
            // Explanation
            if (a.explanation.isNotEmpty) ...[
              Text(
                a.explanation,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                if (a.rootCauseConcept != null)
                  Expanded(
                    child: NeonButton(
                      label: 'STUDY ${a.rootCauseConcept!.name.toUpperCase()}',
                      icon: Icons.school,
                      height: 36,
                      fontSize: 9,
                      colors: [severityColor, AppTheme.accentPurple],
                      onTap: () {
                        context.push('/lesson', extra: {
                          'customTopic': a.rootCauseConcept!.name,
                          'level': 'basics',
                        });
                      },
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonButton(
                    label: 'CONCEPT MAP',
                    icon: Icons.hub,
                    height: 36,
                    fontSize: 9,
                    colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                    onTap: () {
                      context.push('/concept-map', extra: {
                        'focusConcept': a.matchedConcept?.id ?? '',
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            // Collapsed: tap to expand hint
            Center(
              child: Text(
                'Tap to see full analysis',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
