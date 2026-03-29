import '../../../core/services/hindsight_service.dart';
import '../../../features/courses/data/course_data.dart';
import '../models/story_response.dart';
import '../models/story_style.dart';
import 'deepseek_service.dart';

/// Builds prompts from lesson data, calls DeepSeek, and parses the response
/// into a structured [StoryResponse].
///
/// **Hindsight integration**: Before generating a story, recalls the student's
/// past learning history for the topic and injects it into the prompt. This
/// means the AI adapts — spending more time on weak areas and skipping what
/// the student already mastered. Solves the "context limit" problem because
/// Hindsight stores unlimited history and only retrieves what's relevant.
class StoryGeneratorService {
  StoryGeneratorService({DeepSeekService? deepSeek})
      : _deepSeek = deepSeek ?? DeepSeekService();

  final DeepSeekService _deepSeek;
  final _hindsight = HindsightService.instance;

  /// Generates a story for the given lesson and style.
  /// Recalls past learning context from Hindsight to personalize the lesson.
  Future<StoryResponse> generateStory({
    required Lesson lesson,
    required String subjectId,
    required String chapterTitle,
    required StoryStyle style,
    String? franchiseName,
  }) async {
    // Fetch student's past learning context for this topic from Hindsight
    final memoryContext = await _hindsight.getStudyContext(lesson.title);

    final systemPrompt =
        _buildSystemPrompt(style, franchiseName, memoryContext);
    final userPrompt = _buildUserPrompt(
      lesson: lesson,
      subjectId: subjectId,
      chapterTitle: chapterTitle,
    );

    final raw = await _deepSeek.chatCompletion(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );

    final json = DeepSeekService.parseJsonResponse(raw);
    return StoryResponse.fromJson(json);
  }

  /// Generates a story for a custom topic (user-typed, no lesson data).
  /// Recalls past learning context from Hindsight to personalize the lesson.
  Future<StoryResponse> generateStoryFromTopic({
    required String topic,
    required StoryStyle style,
    String? franchiseName,
    String level = 'basics',
  }) async {
    // Track topic interest + fetch past context in parallel
    _hindsight.retainTopicInterest(topic, level: level);
    final memoryContext = await _hindsight.getStudyContext(topic);

    final systemPrompt =
        _buildSystemPrompt(style, franchiseName, memoryContext);
    final userPrompt = _buildTopicUserPrompt(topic, level: level);

    final raw = await _deepSeek.chatCompletion(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );

    final json = DeepSeekService.parseJsonResponse(raw);
    return StoryResponse.fromJson(json);
  }

  /// Unified system prompt — AI always generates its own characters.
  /// Now includes [memoryContext] from Hindsight when available.
  String _buildSystemPrompt(
      StoryStyle style, String? franchiseName, String memoryContext) {
    final isMovieTv = style == StoryStyle.movieTv && franchiseName != null;

    final characterRules = isMovieTv
        ? _franchiseCharacterRules(franchiseName)
        : _practicalCharacterRules;

    final styleInstructions = isMovieTv
        ? StoryStyle.franchisePromptInstructions(franchiseName)
        : style.promptInstructions;

    return '''
You are a creative educational storyteller for Learnify, a learning app.
You create visual novel stories where characters teach concepts through dialogue.

$characterRules

## Story Rules
1. Use 2-4 characters. Each must be defined in the "characters" array.
2. Create 5-8 scenes. More scenes = better coverage. Each scene has ONE character speaking.
3. Generate exactly 3 quiz questions about the concepts taught.
4. Each quiz question has 4 options with one correct answer (0-indexed).
5. Weave educational content naturally — characters explain concepts through dialogue.
6. EVERY concept MUST be covered. Do not skip any.
7. Characters must stay in character — match their personality and speech style.

$_practicalRules

## Story Style
$styleInstructions

${memoryContext.isNotEmpty ? '''
$memoryContext

IMPORTANT: Use the student's learning history above to ADAPT this lesson:
- If they struggled with specific concepts before, explain those MORE thoroughly with extra examples
- If they mastered certain concepts, briefly recap them and go deeper into advanced aspects
- Reference their past mistakes in quiz questions to reinforce weak areas
- Make the lesson feel personalized — the student should feel the AI "knows" them
''' : ''}

## Output Format
Return ONLY valid JSON, no markdown fences, no extra text:
{
  "title": "Story title",
  "characters": [
    {
      "id": "character_id_lowercase_no_spaces",
      "name": "Character's Display Name",
      "role": "Brief role description",
      "color": "#HEX_COLOR that fits the character"
    }
  ],
  "scenes": [
    {
      "characterId": "character_id_matching_characters_array",
      "emotion": "excited",
      "dialogue": "Character's dialogue — must include practical examples",
      "narration": "Optional narrator description of the scene",
      "conceptTag": "The specific concept being taught in this scene"
    }
  ],
  "quiz": [
    {
      "question": "Question text — preferably scenario-based or practical",
      "options": ["A", "B", "C", "D"],
      "correctIndex": 0,
      "explanation": "Why this answer is correct — with practical reasoning"
    }
  ]
}
''';
  }

  static const String _practicalCharacterRules = '''
## CHARACTER RULES — CRITICAL
- Create 2-4 original characters who are REAL-WORLD professionals or mentors relevant to the topic.
- Examples: A lab scientist, a factory engineer, a doctor explaining biology, a chef for chemistry,
  a sports coach for physics, a carpenter for geometry, a programmer for CS topics.
- Each character should have a distinct personality and teaching approach.
- Characters must physically demonstrate and explain — not just lecture.
- You MUST include a "characters" array in your response defining who you used.''';

  static String _franchiseCharacterRules(String franchiseName) => '''
## CHARACTER RULES — CRITICAL
- Do NOT use generic or made-up characters.
- Use 2-4 ACTUAL characters from "$franchiseName" that fans will recognize.
- Match each character's real personality, speech patterns, and catchphrases.
- Each character's dialogue must sound like something they would actually say in "$franchiseName".
- Reference actual plot points, settings, and iconic moments from "$franchiseName" as analogies.
- Be faithful to the source material — fans should feel the authenticity.
- You MUST include a "characters" array in your response defining who you used.''';

  static const String _practicalRules = '''
## PRACTICAL EXPLANATIONS — CRITICAL
Every concept MUST be explained with practical, real-world examples:
- Show HOW the concept works in everyday life (cooking, sports, driving, building things)
- Give concrete numbers and scenarios a student can visualize
- Explain WHY it matters practically — "You use this when..." / "This is why..."
- Use analogies from real objects, machines, nature, or daily activities
- If a formula is involved, walk through a real calculation with actual values
- Connect abstract ideas to things students can see, touch, or experience
- Characters should say things like "Imagine you're...", "Think about when...", "In real life this means..."
''';

  String _buildUserPrompt({
    required Lesson lesson,
    required String subjectId,
    required String chapterTitle,
  }) {
    final conceptSummaries = lesson.content
        .map((c) => '- [${c.type}] ${c.title}: ${c.body}')
        .join('\n');

    return '''
Create a story for this lesson:

Subject: $subjectId
Chapter: $chapterTitle
Lesson: ${lesson.title}
Description: ${lesson.description}

Concepts to teach (COVER ALL OF THEM — do not skip any):
$conceptSummaries

Requirements:
- Every concept above must appear in at least one scene
- Each concept must include a practical, real-world example or analogy
- Quiz questions should test understanding through practical scenarios, not just memorization
- Use enough scenes (5-8) to cover everything thoroughly
''';
  }

  String _buildTopicUserPrompt(String topic, {String level = 'basics'}) {
    final levelGuide = switch (level) {
      'intermediate' =>
        'This student already knows the fundamentals. Skip basic definitions '
            'and focus on deeper understanding, connections between concepts, '
            'and more challenging applications. Use more technical vocabulary.',
      'advanced' =>
        'This student has strong existing knowledge. Focus on expert-level '
            'nuances, edge cases, common misconceptions, cutting-edge research, '
            'and complex real-world applications. Challenge them with '
            'non-obvious insights.',
      _ =>
        'This student is new to this topic. Start from the very basics with '
            'simple language, lots of analogies, and build up step by step. '
            'Assume no prior knowledge.',
    };

    return '''
Create an educational story about the following topic:

Topic: $topic
Difficulty Level: ${level.toUpperCase()}

Level guidance: $levelGuide

Requirements:
- Break the topic into 4-6 key concepts appropriate for this difficulty level
- Each concept must include a practical, real-world example or analogy
- Create 5-8 scenes — enough to cover everything thoroughly
- Quiz questions should match the $level difficulty — ${level == 'basics' ? 'test core understanding' : level == 'intermediate' ? 'test application and deeper reasoning' : 'test expert-level analysis and edge cases'}
- Make it engaging and easy to understand for a student
''';
  }
}
