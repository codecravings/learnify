import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The narrative style for AI-generated stories.
enum StoryStyle {
  practical,
  movieTv;

  String get label {
    switch (this) {
      case StoryStyle.practical:
        return 'Practical';
      case StoryStyle.movieTv:
        return 'Movie / TV';
    }
  }

  String get description {
    switch (this) {
      case StoryStyle.practical:
        return 'Hands-on real-world approach — see how concepts work in actual life';
      case StoryStyle.movieTv:
        return 'Learn through your favorite movie, TV serial, anime, or cartoon';
    }
  }

  IconData get icon {
    switch (this) {
      case StoryStyle.practical:
        return Icons.build_circle;
      case StoryStyle.movieTv:
        return Icons.live_tv;
    }
  }

  Color get color {
    switch (this) {
      case StoryStyle.practical:
        return AppTheme.accentGreen;
      case StoryStyle.movieTv:
        return AppTheme.accentCyan;
    }
  }

  /// Prompt instructions for preset styles.
  /// For movieTv, use [franchisePromptInstructions] with the show name.
  String get promptInstructions {
    switch (this) {
      case StoryStyle.practical:
        return '''Write in a PRACTICAL / REAL-WORLD style.
- Every single concept MUST be shown working in a real scenario
- Use step-by-step demonstrations: "Let's actually build/calculate/measure this..."
- Reference real objects, tools, machines, experiments students can try at home
- Walk through actual numbers: "If you throw a ball at 20 m/s at 45 degrees..."
- Show cause and effect: "Change this variable and watch what happens..."
- Connect to careers: "Engineers use this when...", "Doctors need this because..."
- Use lab/workshop/kitchen/playground as settings
- Characters should physically demonstrate concepts, not just lecture
- Include "Try this yourself" moments where students can verify the concept''';
      case StoryStyle.movieTv:
        return ''; // Use franchisePromptInstructions instead
    }
  }

  /// Build prompt instructions for movie/TV franchise style.
  static String franchisePromptInstructions(String franchiseName) {
    return '''Write the story set in the universe of "$franchiseName".
- Use ACTUAL characters from "$franchiseName" — real names, real personalities, real catchphrases
- Reference real plot points, iconic scenes, and memorable moments as analogies
- Dialogue must sound authentic — fans should instantly recognize who's speaking
- Use the show's settings, conflicts, and relationships to frame concepts
- Example: If "Breaking Bad" — Walter White explains chemistry through his meth lab logic, Jesse reacts with street-smart analogies
- Example: If "Naruto" — Kakashi teaches with ninja training analogies, Naruto learns through shadow clone trial-and-error
- Cover as many parts of "$franchiseName" as relevant — not just one scene
- Be accurate to source material — wrong characterization breaks immersion
- Still include practical real-world examples alongside the franchise references''';
  }
}
