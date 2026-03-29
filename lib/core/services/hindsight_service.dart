import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Hindsight Memory API service — persistent AI memory for each student.
///
/// Three core operations:
/// - [retain] — store learning events (quiz results, mistakes, topics)
/// - [recall] — search past learning memories
/// - [reflect] — AI reasoning over all memories for insights & study plans
class HindsightService {
  HindsightService._();

  static final HindsightService _instance = HindsightService._();
  static HindsightService get instance => _instance;
  factory HindsightService() => _instance;

  static const String _apiKey =
      const String.fromEnvironment('HINDSIGHT_API_KEY', defaultValue: '');
  static const String _baseUrl = 'https://api.hindsight.vectorize.io';
  static const String _proxyUrl =
      'https://us-central1-hire-horizon-c47c7.cloudfunctions.net/apiHindsight';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: kIsWeb ? _proxyUrl : _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      if (!kIsWeb) 'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    },
  ));

  bool _bankReady = false;
  String? _lastBankId;

  /// Memory bank ID scoped to the current user.
  String get _bankId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return 'student-${uid ?? 'anonymous'}';
  }

  /// Ensure the memory bank exists for the current user. Safe to call
  /// multiple times — only creates on first invocation per session.
  Future<void> ensureBank() async {
    // Reset if user changed
    final currentBank = _bankId;
    if (_lastBankId != null && _lastBankId != currentBank) {
      _bankReady = false;
    }
    _lastBankId = currentBank;

    if (_bankReady) return;
    try {
      await _dio.get('/v1/default/banks/$currentBank');
      _bankReady = true;
      debugPrint('[Hindsight] Bank $currentBank exists');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        try {
          await _dio.post('/v1/default/banks', data: {
            'bank_id': currentBank,
            'name': 'EduJu Student Memory',
            'background':
                'Memory bank for a student using the EduJu learning app. '
                    'Tracks topics studied, quiz scores, mistakes made, learning '
                    'style preferences, weak areas, and study patterns. Used to '
                    'generate personalized study plans and revision questions.',
          });
          _bankReady = true;
          debugPrint('[Hindsight] Created bank $currentBank');
        } catch (createErr) {
          debugPrint('[Hindsight] FAILED to create bank: $createErr');
        }
      } else {
        debugPrint('[Hindsight] Bank check failed: ${e.response?.statusCode} ${e.message}');
      }
    } catch (e) {
      debugPrint('[Hindsight] Bank check error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RETAIN — Store learning events
  // ═══════════════════════════════════════════════════════════════════════════

  /// Store a learning event in the student's memory.
  Future<bool> retain({
    required String content,
    String context = 'study_session',
    List<String>? tags,
  }) async {
    try {
      await ensureBank();
      await _dio.post(
        '/v1/default/banks/$_bankId/memories',
        data: {
          'items': [
            {
              'content': content,
              'context': context,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              if (tags != null) 'tags': tags,
            }
          ],
          'async': false,
        },
      );
      debugPrint('[Hindsight] Retained memory: ${content.substring(0, content.length.clamp(0, 80))}...');
      return true;
    } catch (e) {
      debugPrint('[Hindsight] RETAIN FAILED: $e');
      return false;
    }
  }

  /// Convenience: retain quiz results after a story lesson.
  Future<bool> retainQuizResult({
    required String topic,
    required String style,
    required int score,
    required int total,
    required List<String> missedQuestions,
    required List<String> conceptsCovered,
    String level = 'basics',
  }) async {
    final accuracy = total > 0 ? (score / total * 100).round() : 0;
    final buffer = StringBuffer();
    buffer.writeln('Study session completed on topic: "$topic".');
    buffer.writeln('Difficulty level: $level.');
    buffer.writeln('Learning style used: $style.');
    buffer.writeln('Quiz score: $score/$total ($accuracy% accuracy).');

    if (missedQuestions.isNotEmpty) {
      buffer.writeln(
          'Questions answered incorrectly:');
      for (final q in missedQuestions) {
        buffer.writeln('  - $q');
      }
    } else {
      buffer.writeln('Perfect score — no mistakes!');
    }

    if (conceptsCovered.isNotEmpty) {
      buffer.writeln('Concepts covered: ${conceptsCovered.join(", ")}.');
    }

    return retain(
      content: buffer.toString(),
      context: 'quiz_result',
      tags: [
        'topic:${topic.toLowerCase().replaceAll(' ', '_')}',
        'level:$level',
        'accuracy:$accuracy',
        if (accuracy < 70) 'needs_review',
        if (accuracy == 100) 'mastered',
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECALL — Search past memories
  // ═══════════════════════════════════════════════════════════════════════════

  /// Search the student's learning memories.
  Future<List<Map<String, dynamic>>> recall({
    required String query,
    List<String>? types,
    String budget = 'mid',
    int maxTokens = 2048,
  }) async {
    try {
      await ensureBank();
      final response = await _dio.post(
        '/v1/default/banks/$_bankId/memories/recall',
        data: {
          'query': query,
          'budget': budget,
          'max_tokens': maxTokens,
          if (types != null) 'types': types,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];
      debugPrint('[Hindsight] Recall returned ${results.length} results');
      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[Hindsight] RECALL FAILED: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFLECT — AI reasoning over memories
  // ═══════════════════════════════════════════════════════════════════════════

  /// Use AI to reason over the student's entire learning history and produce
  /// insights, study plans, or targeted revision questions.
  Future<String> reflect({
    required String query,
    String budget = 'mid',
    int maxTokens = 2048,
    Map<String, dynamic>? responseSchema,
  }) async {
    try {
      await ensureBank();
      final response = await _dio.post(
        '/v1/default/banks/$_bankId/reflect',
        data: {
          'query': query,
          'budget': budget,
          'max_tokens': maxTokens,
          if (responseSchema != null) 'response_schema': responseSchema,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final text = data['text'] as String? ??
          'No insights yet. Complete some lessons first!';
      debugPrint('[Hindsight] Reflect success: ${text.substring(0, text.length.clamp(0, 60))}...');
      return text;
    } catch (e) {
      debugPrint('[Hindsight] REFLECT FAILED: $e');
      return 'Start learning some topics and I\'ll remember everything '
          'to help you study smarter!';
    }
  }

  /// Structured reflect that returns parsed JSON.
  Future<Map<String, dynamic>?> reflectStructured({
    required String query,
    required Map<String, dynamic> responseSchema,
    String budget = 'mid',
  }) async {
    try {
      await ensureBank();
      final response = await _dio.post(
        '/v1/default/banks/$_bankId/reflect',
        data: {
          'query': query,
          'budget': budget,
          'max_tokens': 4096,
          'response_schema': responseSchema,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final result = data['structured_output'] as Map<String, dynamic>?;
      debugPrint('[Hindsight] Structured reflect success');
      return result;
    } catch (e) {
      debugPrint('[Hindsight] STRUCTURED REFLECT FAILED: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTEXT — Feed memory into AI generation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds a learning context string for a topic by recalling past memories.
  /// This is injected into the DeepSeek story prompt so the AI adapts
  /// to what the student already knows / struggles with.
  ///
  /// Returns empty string if no relevant memories exist (first-time topic).
  Future<String> getStudyContext(String topic) async {
    try {
      await ensureBank();

      // Recall memories related to this topic
      final memories = await recall(
        query: 'What has this student studied about "$topic"? '
            'What did they struggle with? What did they master?',
        budget: 'mid',
        maxTokens: 1024,
      );

      if (memories.isEmpty) return '';

      final buffer = StringBuffer();
      buffer.writeln('## STUDENT LEARNING HISTORY (from persistent memory)');
      buffer.writeln('The following is what we know about this student '
          'from their past study sessions. Use this to PERSONALIZE the '
          'lesson — spend more time on concepts they struggled with, '
          'skip or briefly recap concepts they already mastered.');
      buffer.writeln();

      for (final mem in memories.take(8)) {
        final text = mem['text'] as String? ?? '';
        if (text.isNotEmpty) {
          buffer.writeln('- $text');
        }
      }

      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  /// Retain a companion chat exchange so the AI remembers conversations
  /// across sessions — solving the context window problem.
  Future<bool> retainChatExchange({
    required String userQuery,
    required String aiResponse,
  }) async {
    return retain(
      content: 'Student asked: "$userQuery"\n'
          'AI companion responded with study advice: '
          '${aiResponse.length > 500 ? '${aiResponse.substring(0, 500)}...' : aiResponse}',
      context: 'companion_chat',
      tags: ['type:chat', 'source:companion'],
    );
  }

  /// Retain that the student searched for / started learning a topic.
  /// This builds the "interests over time" graph in Hindsight.
  Future<bool> retainTopicInterest(String topic, {String level = 'basics'}) async {
    return retain(
      content: 'Student expressed interest in learning about "$topic" '
          'and started a study session at the $level level.',
      context: 'topic_interest',
      tags: [
        'topic:${topic.toLowerCase().replaceAll(' ', '_')}',
        'type:interest',
        'level:$level',
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOPIC INTELLIGENCE — Assess level & fetch studied topics
  // ═══════════════════════════════════════════════════════════════════════════

  /// Assess what level the student should start at for a given topic.
  /// Returns a map with: level (basics/intermediate/advanced),
  /// reason (explanation), and hasHistory (bool).
  Future<Map<String, dynamic>> assessTopicLevel(String topic) async {
    try {
      await ensureBank();
      final result = await reflectStructured(
        query: 'Assess this student\'s knowledge level for the topic "$topic". '
            'Based on their learning history, determine if they should study at '
            'basics, intermediate, or advanced level. Consider: have they '
            'studied this topic before? What was their quiz accuracy? Did they '
            'struggle with specific concepts? '
            'If no history exists for this topic, recommend "basics".',
        responseSchema: {
          'type': 'object',
          'properties': {
            'level': {
              'type': 'string',
              'enum': ['basics', 'intermediate', 'advanced'],
              'description': 'Recommended difficulty level',
            },
            'reason': {
              'type': 'string',
              'description':
                  'Short explanation (1-2 sentences) for why this level is recommended',
            },
            'has_history': {
              'type': 'boolean',
              'description': 'Whether the student has studied this topic before',
            },
            'past_accuracy': {
              'type': 'integer',
              'description':
                  'Average quiz accuracy percentage from past sessions (0 if no history)',
            },
          },
          'required': ['level', 'reason', 'has_history', 'past_accuracy'],
        },
        budget: 'mid',
      );

      if (result != null) return result;
    } catch (_) {
      // Fall through to default
    }

    return {
      'level': 'basics',
      'reason': 'Let\'s start from the fundamentals!',
      'has_history': false,
      'past_accuracy': 0,
    };
  }

  /// Fetch topics the student has recently studied.
  /// Returns a list of topic summaries for the home page.
  Future<List<Map<String, dynamic>>> getStudiedTopics() async {
    try {
      await ensureBank();
      final result = await reflectStructured(
        query: 'List ALL topics this student has studied. For each topic, '
            'provide the topic name, their last quiz accuracy percentage, '
            'the recommended next level (basics/intermediate/advanced), and '
            'a one-line summary of their progress. '
            'If the student hasn\'t studied any topics yet, return an empty array.',
        responseSchema: {
          'type': 'object',
          'properties': {
            'topics': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'name': {
                    'type': 'string',
                    'description': 'Topic name',
                  },
                  'accuracy': {
                    'type': 'integer',
                    'description': 'Last quiz accuracy %',
                  },
                  'level': {
                    'type': 'string',
                    'enum': ['basics', 'intermediate', 'advanced'],
                    'description': 'Recommended next level',
                  },
                  'summary': {
                    'type': 'string',
                    'description': 'One-line progress summary',
                  },
                },
                'required': ['name', 'accuracy', 'level', 'summary'],
              },
            },
          },
          'required': ['topics'],
        },
        budget: 'low',
      );

      if (result != null && result['topics'] is List) {
        return (result['topics'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Fall through
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ROOT CAUSE ANALYSIS — Diagnose why a student failed
  // ═══════════════════════════════════════════════════════════════════════════

  /// Use AI to analyze the root cause of a quiz failure by reasoning over
  /// the student's learning history and the prerequisite chain.
  Future<String> analyzeRootCause({
    required String topic,
    required List<String> missedQuestions,
    required String prerequisiteChain,
    required Map<String, int> prerequisiteAccuracies,
  }) async {
    final accSummary = prerequisiteAccuracies.entries
        .map((e) => '${e.key}: ${e.value == -1 ? "never studied" : "${e.value}%"}')
        .join(', ');

    return reflect(
      query: 'ROOT CAUSE ANALYSIS:\n'
          'The student just scored poorly on "$topic".\n'
          'Questions they got wrong: ${missedQuestions.join("; ")}\n\n'
          'Prerequisite chain: $prerequisiteChain\n'
          'Student\'s accuracy on prerequisites: $accSummary\n\n'
          'Based on their learning history and these prerequisite gaps, '
          'explain in 2-3 sentences WHY they struggled. '
          'Identify the specific root cause concept they should study first. '
          'Be specific and encouraging — don\'t just say "study more".',
      budget: 'mid',
      maxTokens: 512,
    );
  }

  /// Fire-and-forget: retain a root cause diagnosis to memory.
  Future<bool> retainRootCauseAnalysis({
    required String topic,
    required String rootCause,
    required List<String> missingPrereqs,
    required String severity,
  }) {
    return retain(
      content: 'Root cause analysis for "$topic":\n'
          'Severity: $severity\n'
          'Root cause: Student has gaps in "$rootCause" which is a prerequisite.\n'
          'Missing prerequisites: ${missingPrereqs.join(", ")}.\n'
          'Recommendation: Study $rootCause first before attempting $topic again.',
      context: 'root_cause_analysis',
      tags: [
        'topic:${topic.toLowerCase().replaceAll(' ', '_')}',
        'root_cause:${rootCause.toLowerCase().replaceAll(' ', '_')}',
        'severity:$severity',
        'type:diagnosis',
      ],
    );
  }
}
