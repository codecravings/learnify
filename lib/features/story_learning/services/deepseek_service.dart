import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Low-level DeepSeek API client with continuation support.
///
/// Uses the OpenAI-compatible format at https://api.deepseek.com/v1.
/// On web, routes through Firebase Cloud Function proxy to avoid CORS.
class DeepSeekService {
  DeepSeekService({String? apiKey})
      : _apiKey = apiKey ?? _defaultApiKey,
        _dio = Dio(BaseOptions(
          baseUrl: kIsWeb
              ? 'https://us-central1-hire-horizon-c47c7.cloudfunctions.net/apiDeepSeek'
              : 'https://api.deepseek.com/v1',
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 120),
        ));

  final String _apiKey;
  final Dio _dio;

  static const String _defaultApiKey = String.fromEnvironment('DEEPSEEK_API_KEY', defaultValue: '');

  static const int _maxContinuations = 3;

  /// Sends a chat completion request with automatic continuation
  /// when the response is truncated due to token limits.
  ///
  /// Returns the full concatenated response text.
  Future<String> chatCompletion({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.8,
    int maxTokens = 4096,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final buffer = StringBuffer();

    for (int attempt = 0; attempt <= _maxContinuations; attempt++) {
      final response = await _dio.post(
        '/chat/completions',
        options: Options(headers: {
          if (!kIsWeb) 'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'deepseek-chat',
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List;
      final choice = choices.first as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>;
      final content = (message['content'] as String?) ?? '';
      final finishReason = choice['finish_reason'] as String?;

      buffer.write(content);

      // If the model finished naturally, we're done.
      if (finishReason != 'length') break;

      // Response was truncated — ask the model to continue.
      if (attempt < _maxContinuations) {
        messages.add({'role': 'assistant', 'content': content});
        messages.add({
          'role': 'user',
          'content': 'Continue from where you left off. '
              'Do NOT repeat any content. Continue the JSON exactly.',
        });
      }
    }

    return buffer.toString();
  }

  /// Parses a JSON response, stripping markdown fences if present.
  static Map<String, dynamic> parseJsonResponse(String raw) {
    var cleaned = raw.trim();

    // Strip markdown code fences
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }
}
