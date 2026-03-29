import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Generates character portrait images for story mode.
/// Primary: DiceBear (instant stylized avatars, always works, no API key).
/// Fallback: Pollinations.ai (free AI image gen, no key, less reliable).
/// Caches in memory keyed by "characterName|franchiseName".
class OpenAIImageService {
  OpenAIImageService._();
  static final instance = OpenAIImageService._();

  final _diceBearDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    followRedirects: true,
    maxRedirects: 5,
  ));

  final _pollinationsDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    followRedirects: true,
    maxRedirects: 5,
  ));

  /// In-memory cache: key = "characterName|franchiseName"
  final Map<String, Uint8List> _cache = {};

  /// Generate a character portrait.
  /// Returns raw image bytes or null on failure.
  /// Primary: Pollinations AI (better quality). Fallback: DiceBear (instant).
  Future<Uint8List?> generatePortrait({
    required String characterName,
    required String franchiseName,
    String? role,
  }) async {
    final cacheKey = '$characterName|$franchiseName';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    // Primary: Pollinations AI (better quality portraits)
    final bytes =
        await _pollinationsPortrait(characterName, franchiseName, role);
    if (bytes != null) {
      _cache[cacheKey] = bytes;
      return bytes;
    }

    // Fallback: DiceBear (instant, always works)
    final fallback = await _diceBearPortrait(characterName, franchiseName);
    if (fallback != null) {
      _cache[cacheKey] = fallback;
      return fallback;
    }

    return null;
  }

  /// DiceBear — instant stylized avatar, always works, no API key.
  /// Uses "adventurer-neutral" style for nice character-like portraits.
  Future<Uint8List?> _diceBearPortrait(
    String characterName,
    String franchiseName,
  ) async {
    try {
      final seed = Uri.encodeComponent('$characterName $franchiseName');
      final url = 'https://api.dicebear.com/9.x/adventurer-neutral/png'
          '?seed=$seed&size=256&backgroundColor=transparent';

      final response = await _diceBearDio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'image/png'},
        ),
      );

      if (response.data == null || response.data!.length < 500) return null;

      final bytes = Uint8List.fromList(response.data!);
      debugPrint(
          '[ImageGen] DiceBear OK $characterName (${bytes.length} bytes)');
      return bytes;
    } catch (e) {
      debugPrint('[ImageGen] DiceBear FAIL $characterName: $e');
      return null;
    }
  }

  /// Pollinations.ai — free AI image generation, no API key.
  Future<Uint8List?> _pollinationsPortrait(
    String characterName,
    String franchiseName,
    String? role,
  ) async {
    try {
      final roleHint = role != null && role.isNotEmpty ? ' ($role)' : '';
      final context =
          franchiseName.isNotEmpty ? ' from $franchiseName' : '';
      final prompt = 'Digital portrait of $characterName$context$roleHint, '
          'single character centered, face clearly visible, '
          'cinematic lighting, sharp focus, detailed face, '
          'dark moody background with subtle glow, '
          'professional concept art style, 4k quality, '
          'no text no watermark no border';
      final encodedPrompt = Uri.encodeComponent(prompt);
      final seed = characterName.hashCode.abs();
      final url = 'https://image.pollinations.ai/prompt/$encodedPrompt'
          '?width=512&height=512&model=flux&nologo=true&seed=$seed';

      final response = await _pollinationsDio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'image/*'},
        ),
      );

      if (response.data == null || response.data!.length < 1000) return null;

      final bytes = Uint8List.fromList(response.data!);
      debugPrint(
          '[ImageGen] Pollinations OK $characterName (${bytes.length} bytes)');
      return bytes;
    } catch (e) {
      debugPrint('[ImageGen] Pollinations FAIL $characterName: $e');
      return null;
    }
  }

  /// Generate portraits for multiple characters in parallel.
  Future<Map<String, Uint8List>> generateAll({
    required List<({String id, String name, String role})> characters,
    required String franchiseName,
  }) async {
    final entries = await Future.wait(
      characters.map((c) async {
        final bytes = await generatePortrait(
          characterName: c.name,
          franchiseName: franchiseName,
          role: c.role,
        );
        return MapEntry(c.id, bytes);
      }),
    );

    return Map.fromEntries(
      entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(e.key, e.value!)),
    );
  }
}
