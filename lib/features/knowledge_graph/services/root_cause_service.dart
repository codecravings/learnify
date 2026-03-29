import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import '../../../core/services/hindsight_service.dart';
import '../data/prerequisite_graph.dart';

/// Result of a root cause analysis.
class RootCauseAnalysis {
  final String topic;
  final ConceptNode? matchedConcept;
  final List<ConceptNode> missingPrerequisites;
  final ConceptNode? rootCauseConcept;
  final String explanation;
  final List<ConceptNode> recommendedPath;
  final String severity; // 'none', 'minor_gap', 'significant_gap', 'foundational_gap'

  const RootCauseAnalysis({
    required this.topic,
    this.matchedConcept,
    this.missingPrerequisites = const [],
    this.rootCauseConcept,
    this.explanation = '',
    this.recommendedPath = const [],
    this.severity = 'none',
  });

  bool get hasGaps => missingPrerequisites.isNotEmpty;

  String get severityLabel {
    switch (severity) {
      case 'foundational_gap':
        return 'Foundational Gap';
      case 'significant_gap':
        return 'Significant Gap';
      case 'minor_gap':
        return 'Minor Gap';
      default:
        return 'No Gaps Detected';
    }
  }
}

/// Diagnoses WHY a student failed by tracing through prerequisite chains.
class RootCauseService {
  RootCauseService._();
  static final instance = RootCauseService._();

  final _hindsight = HindsightService.instance;

  /// Analyze why a student failed a quiz on a topic.
  ///
  /// Combines the prerequisite graph with student performance data
  /// to identify the deepest missing prerequisite (root cause).
  Future<RootCauseAnalysis> analyzeFailure({
    required String topic,
    required int accuracy,
    required List<String> missedQuestions,
    required List<String> conceptsCovered,
  }) async {
    // 1. Match topic to concept node
    final concept = PrerequisiteGraph.findConceptForTopic(topic);
    if (concept == null) {
      // Topic not in our graph — use AI-only analysis
      return _aiOnlyAnalysis(topic, accuracy, missedQuestions, conceptsCovered);
    }

    // 2. Get student's accuracy map from cached data
    final accuracyMap = await _buildAccuracyMap();

    // 3. Find root causes through the prerequisite chain
    final rootCauses = PrerequisiteGraph.getRootCauses(concept.id, accuracyMap);
    final missingPrereqs =
        PrerequisiteGraph.findMissingPrerequisites(concept.id, _getMasteredIds(accuracyMap));
    final studyPath = PrerequisiteGraph.buildStudyPath(concept.id, accuracyMap);

    // 4. Determine severity
    String severity;
    if (rootCauses.isEmpty && accuracy >= 70) {
      severity = 'none';
    } else if (rootCauses.any((c) => c.difficulty == 'foundational')) {
      severity = 'foundational_gap';
    } else if (rootCauses.length >= 2) {
      severity = 'significant_gap';
    } else {
      severity = 'minor_gap';
    }

    // 5. Generate AI explanation (non-blocking, with timeout)
    String explanation = _buildLocalExplanation(
      concept, rootCauses, missingPrereqs, accuracy,
    );

    // Try to get a richer AI explanation (timeout 8s)
    try {
      final aiExplanation = await _hindsight.analyzeRootCause(
        topic: topic,
        missedQuestions: missedQuestions,
        prerequisiteChain: _formatChainForAI(concept, rootCauses),
        prerequisiteAccuracies: _getChainAccuracies(concept, accuracyMap),
      ).timeout(const Duration(seconds: 8), onTimeout: () => '');
      if (aiExplanation.isNotEmpty) {
        explanation = aiExplanation;
      }
    } catch (_) {
      // Use local explanation as fallback
    }

    // 6. Retain analysis to Hindsight (fire-and-forget)
    _retainAnalysis(topic, rootCauses, severity);

    return RootCauseAnalysis(
      topic: topic,
      matchedConcept: concept,
      missingPrerequisites: missingPrereqs,
      rootCauseConcept: rootCauses.isNotEmpty ? rootCauses.first : null,
      explanation: explanation,
      recommendedPath: studyPath,
      severity: severity,
    );
  }

  /// Build accuracy map from local SharedPreferences cache.
  Future<Map<String, double>> _buildAccuracyMap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('user_data_$uid');
      if (cached == null) return {};

      final data = jsonDecode(cached) as Map<String, dynamic>;
      final studiedTopics =
          data['studiedTopics'] as Map<String, dynamic>? ?? {};

      final map = <String, double>{};
      for (final entry in studiedTopics.entries) {
        final topicData = entry.value as Map<String, dynamic>? ?? {};
        final name = (topicData['name'] as String? ?? entry.key).toLowerCase();
        final accuracy = (topicData['accuracy'] as num?)?.toDouble() ?? 0;
        map[entry.key] = accuracy;
        map[name] = accuracy;

        // Also match against concept IDs
        final concept = PrerequisiteGraph.findConceptForTopic(name);
        if (concept != null) {
          map[concept.id] = accuracy;
        }
      }
      return map;
    } catch (e) {
      debugPrint('[RootCause] Failed to build accuracy map: $e');
      return {};
    }
  }

  Set<String> _getMasteredIds(Map<String, double> accuracyMap) {
    return accuracyMap.entries
        .where((e) => e.value >= 80)
        .map((e) => e.key)
        .toSet();
  }

  String _buildLocalExplanation(
    ConceptNode concept,
    List<ConceptNode> rootCauses,
    List<ConceptNode> missing,
    int accuracy,
  ) {
    if (rootCauses.isEmpty && missing.isEmpty) {
      return 'You have a solid foundation for ${concept.name}. '
          'Review the specific questions you missed to improve further.';
    }

    final buffer = StringBuffer();

    if (rootCauses.isNotEmpty) {
      final root = rootCauses.first;
      buffer.write('Your difficulty with ${concept.name} traces back to ');
      buffer.write('gaps in ${root.name}');
      if (rootCauses.length > 1) {
        buffer.write(' and ${rootCauses.length - 1} other prerequisite(s)');
      }
      buffer.writeln('.');
      buffer.writeln();
      buffer.write('${root.name} is a foundational building block — ');
      buffer.write('${root.description} ');
      buffer.write('Strengthening this will unlock your understanding of ${concept.name}.');
    } else if (missing.isNotEmpty) {
      buffer.write('You haven\'t studied some prerequisites for ${concept.name}: ');
      buffer.write(missing.map((c) => c.name).join(', '));
      buffer.write('. Starting with these will help you build a stronger foundation.');
    }

    return buffer.toString();
  }

  String _formatChainForAI(ConceptNode concept, List<ConceptNode> rootCauses) {
    final chain = PrerequisiteGraph.getPrerequisiteChain(concept.id);
    if (chain.isEmpty) return concept.name;

    final parts = chain.map((c) {
      final isRoot = rootCauses.contains(c);
      return '${c.name}${isRoot ? " [WEAK]" : ""}';
    }).toList();
    parts.add(concept.name);
    return parts.join(' → ');
  }

  Map<String, int> _getChainAccuracies(
    ConceptNode concept,
    Map<String, double> accuracyMap,
  ) {
    final chain = PrerequisiteGraph.getPrerequisiteChain(concept.id);
    final result = <String, int>{};
    for (final c in chain) {
      final acc = accuracyMap[c.id] ?? accuracyMap[c.name.toLowerCase()] ?? -1;
      result[c.name] = acc.round();
    }
    return result;
  }

  Future<RootCauseAnalysis> _aiOnlyAnalysis(
    String topic,
    int accuracy,
    List<String> missedQuestions,
    List<String> conceptsCovered,
  ) async {
    String explanation = 'We\'re analyzing your performance on "$topic". '
        'Review the questions you missed and try breaking down the concepts further.';

    try {
      final aiResult = await _hindsight.reflect(
        query: 'The student scored $accuracy% on "$topic". '
            'They missed these questions: ${missedQuestions.join("; ")}. '
            'Concepts covered: ${conceptsCovered.join(", ")}. '
            'In 2-3 sentences, explain the likely root cause of their struggle '
            'and what prerequisite concept they should review first.',
        budget: 'mid',
        maxTokens: 512,
      ).timeout(const Duration(seconds: 8), onTimeout: () => '');
      if (aiResult.isNotEmpty) explanation = aiResult;
    } catch (_) {}

    return RootCauseAnalysis(
      topic: topic,
      explanation: explanation,
      severity: accuracy < 50 ? 'significant_gap' : 'minor_gap',
    );
  }

  void _retainAnalysis(
    String topic,
    List<ConceptNode> rootCauses,
    String severity,
  ) {
    if (rootCauses.isEmpty) return;
    _hindsight.retainRootCauseAnalysis(
      topic: topic,
      rootCause: rootCauses.first.name,
      missingPrereqs: rootCauses.map((c) => c.name).toList(),
      severity: severity,
    );
  }
}
