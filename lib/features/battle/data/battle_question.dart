/// A single battle question used across all 3 game modes.
class BattleQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final String difficulty; // easy, medium, hard
  final String category;

  const BattleQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.difficulty = 'medium',
    this.category = 'general',
  });

  String get correctAnswer => options[correctIndex];
}
