import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/challenge_model.dart';

/// Supported AI provider endpoints.
enum AIProvider { openai, gemini, claude }

/// Configuration for connecting to an AI provider.
class AIProviderConfig {
  const AIProviderConfig({
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    this.model = '',
  });

  final AIProvider provider;
  final String apiKey;
  final String baseUrl;
  final String model;

  /// Pre-built configuration for OpenAI.
  factory AIProviderConfig.openai({required String apiKey, String? model}) {
    return AIProviderConfig(
      provider: AIProvider.openai,
      apiKey: apiKey,
      baseUrl: 'https://api.openai.com/v1',
      model: model ?? 'gpt-4o',
    );
  }

  /// Pre-built configuration for Google Gemini.
  factory AIProviderConfig.gemini({required String apiKey, String? model}) {
    return AIProviderConfig(
      provider: AIProvider.gemini,
      apiKey: apiKey,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      model: model ?? 'gemini-pro',
    );
  }

  /// Pre-built configuration for Anthropic Claude.
  factory AIProviderConfig.claude({required String apiKey, String? model}) {
    return AIProviderConfig(
      provider: AIProvider.claude,
      apiKey: apiKey,
      baseUrl: 'https://api.anthropic.com/v1',
      model: model ?? 'claude-sonnet-4-20250514',
    );
  }
}

/// Service that leverages AI APIs to generate challenges, hints, and evaluate
/// answers.
class AIChallengeService {
  AIChallengeService({required AIProviderConfig config})
      : _config = config,
        _dio = Dio(BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  final AIProviderConfig _config;
  final Dio _dio;

  // ---------------------------------------------------------------------------
  // Prompt templates
  // ---------------------------------------------------------------------------

  static const String CHALLENGE_GENERATION_PROMPT = '''
You are an educational challenge creator for Learnify, a competitive learning platform.
Generate a challenge with the following parameters:
- Subject: {{subject}}
- Difficulty: {{difficulty}} (1=easy, 5=expert)
- Type: {{type}} (multiple_choice, short_answer, coding, proof)

Return a JSON object with these fields:
{
  "title": "short descriptive title",
  "description": "full problem statement with clear instructions",
  "subject": "{{subject}}",
  "difficulty": {{difficulty}},
  "type": "{{type}}",
  "answer": "correct answer",
  "options": ["option1", "option2", "option3", "option4"],
  "hints": ["hint1 (vague)", "hint2 (medium)", "hint3 (strong)"],
  "explanation": "detailed solution explanation",
  "xpReward": <integer based on difficulty>,
  "tags": ["relevant", "tags"],
  "searchTerms": ["lowercase", "search", "keywords"]
}

Ensure the challenge is educationally sound, unambiguous, and appropriate for the difficulty level.
Return ONLY valid JSON, no markdown or extra text.
''';

  static const String HINT_GENERATION_PROMPT = '''
You are a helpful tutor on Learnify.
Given the following challenge description, generate a hint at the specified level.

Challenge: {{challengeDescription}}
Hint Level: {{hintLevel}} (1=vague nudge, 2=moderate guidance, 3=strong hint without giving the answer)

Return ONLY the hint text as a plain string, no JSON wrapping.
''';

  static const String ANSWER_EVALUATION_PROMPT = '''
You are an answer evaluator for Learnify.
Evaluate whether the user's answer is correct for the given challenge.

Challenge Title: {{title}}
Challenge Description: {{description}}
Expected Answer: {{expectedAnswer}}
User's Answer: {{userAnswer}}

Return a JSON object:
{
  "isCorrect": true/false,
  "feedback": "detailed feedback explaining why the answer is correct or what went wrong",
  "partialCredit": 0.0 to 1.0
}

Be fair but strict. Return ONLY valid JSON.
''';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates a new challenge via the configured AI provider.
  Future<ChallengeModel> generateChallenge(
    String subject,
    int difficulty,
    String type,
  ) async {
    final prompt = CHALLENGE_GENERATION_PROMPT
        .replaceAll('{{subject}}', subject)
        .replaceAll('{{difficulty}}', difficulty.toString())
        .replaceAll('{{type}}', type);

    final responseText = await _sendPrompt(prompt);
    final json = jsonDecode(responseText) as Map<String, dynamic>;

    // Ensure required metadata is present.
    json['id'] = '';
    json['creatorId'] = 'ai_generated';
    json['createdAt'] = DateTime.now().toIso8601String();
    json['solveCount'] = 0;
    json['attemptCount'] = 0;

    return ChallengeModel.fromJson(json);
  }

  /// Generates a hint for [challengeDescription] at [hintLevel].
  Future<String> generateHint(
    String challengeDescription,
    int hintLevel,
  ) async {
    final prompt = HINT_GENERATION_PROMPT
        .replaceAll('{{challengeDescription}}', challengeDescription)
        .replaceAll('{{hintLevel}}', hintLevel.toString());

    return await _sendPrompt(prompt);
  }

  /// Evaluates whether [userAnswer] correctly answers [challenge].
  /// Returns a map with keys `isCorrect` (bool), `feedback` (String),
  /// and `partialCredit` (double).
  Future<Map<String, dynamic>> evaluateAnswer(
    ChallengeModel challenge,
    String userAnswer,
  ) async {
    final prompt = ANSWER_EVALUATION_PROMPT
        .replaceAll('{{title}}', challenge.title)
        .replaceAll('{{description}}', challenge.description)
        .replaceAll('{{expectedAnswer}}', challenge.answer)
        .replaceAll('{{userAnswer}}', userAnswer);

    final responseText = await _sendPrompt(prompt);
    return jsonDecode(responseText) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Provider-specific request handling
  // ---------------------------------------------------------------------------

  Future<String> _sendPrompt(String prompt) async {
    switch (_config.provider) {
      case AIProvider.openai:
        return _sendOpenAI(prompt);
      case AIProvider.gemini:
        return _sendGemini(prompt);
      case AIProvider.claude:
        return _sendClaude(prompt);
    }
  }

  Future<String> _sendOpenAI(String prompt) async {
    final response = await _dio.post(
      '/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer ${_config.apiKey}',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': _config.model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List;
    return (choices.first['message']['content'] as String).trim();
  }

  Future<String> _sendGemini(String prompt) async {
    final response = await _dio.post(
      '/models/${_config.model}:generateContent?key=${_config.apiKey}',
      options: Options(headers: {'Content-Type': 'application/json'}),
      data: {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
        },
      },
    );

    final data = response.data as Map<String, dynamic>;
    final candidates = data['candidates'] as List;
    final content = candidates.first['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List;
    return (parts.first['text'] as String).trim();
  }

  Future<String> _sendClaude(String prompt) async {
    final response = await _dio.post(
      '/messages',
      options: Options(headers: {
        'x-api-key': _config.apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': _config.model,
        'max_tokens': 2048,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );

    final data = response.data as Map<String, dynamic>;
    final content = data['content'] as List;
    return (content.first['text'] as String).trim();
  }
}
