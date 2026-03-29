class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String subject;
  final int difficulty;
  final String type; // multiple_choice, short_answer, coding, proof
  final String answer;
  final List<String> options;
  final List<String> hints;
  final String explanation;
  final int xpReward;
  final String creatorId;
  final List<String> tags;
  final List<String> searchTerms;
  final int solveCount;
  final int attemptCount;
  final DateTime createdAt;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.difficulty,
    required this.type,
    required this.answer,
    this.options = const [],
    this.hints = const [],
    this.explanation = '',
    this.xpReward = 10,
    required this.creatorId,
    this.tags = const [],
    this.searchTerms = const [],
    this.solveCount = 0,
    this.attemptCount = 0,
    required this.createdAt,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String,
      subject: json['subject'] as String,
      difficulty: json['difficulty'] as int,
      type: json['type'] as String,
      answer: json['answer'] as String,
      options: List<String>.from(json['options'] ?? []),
      hints: List<String>.from(json['hints'] ?? []),
      explanation: json['explanation'] as String? ?? '',
      xpReward: json['xpReward'] as int? ?? 10,
      creatorId: json['creatorId'] as String? ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      searchTerms: List<String>.from(json['searchTerms'] ?? []),
      solveCount: json['solveCount'] as int? ?? 0,
      attemptCount: json['attemptCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'difficulty': difficulty,
      'type': type,
      'answer': answer,
      'options': options,
      'hints': hints,
      'explanation': explanation,
      'xpReward': xpReward,
      'creatorId': creatorId,
      'tags': tags,
      'searchTerms': searchTerms,
      'solveCount': solveCount,
      'attemptCount': attemptCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ChallengeModel copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    int? difficulty,
    String? type,
    String? answer,
    List<String>? options,
    List<String>? hints,
    String? explanation,
    int? xpReward,
    String? creatorId,
    List<String>? tags,
    List<String>? searchTerms,
    int? solveCount,
    int? attemptCount,
    DateTime? createdAt,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      answer: answer ?? this.answer,
      options: options ?? this.options,
      hints: hints ?? this.hints,
      explanation: explanation ?? this.explanation,
      xpReward: xpReward ?? this.xpReward,
      creatorId: creatorId ?? this.creatorId,
      tags: tags ?? this.tags,
      searchTerms: searchTerms ?? this.searchTerms,
      solveCount: solveCount ?? this.solveCount,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
