class ForumPostModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String category;
  final List<String> tags;
  final List<String> searchTerms;
  final int upvotes;
  final int downvotes;
  final int solutionCount;
  final bool isResolved;
  final String? acceptedSolutionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ForumPostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.category,
    this.tags = const [],
    this.searchTerms = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    this.solutionCount = 0,
    this.isResolved = false,
    this.acceptedSolutionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumPostModel.fromJson(Map<String, dynamic> json) {
    return ForumPostModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      searchTerms: List<String>.from(json['searchTerms'] ?? []),
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      solutionCount: json['solutionCount'] as int? ?? 0,
      isResolved: json['isResolved'] as bool? ?? false,
      acceptedSolutionId: json['acceptedSolutionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'category': category,
      'tags': tags,
      'searchTerms': searchTerms,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'solutionCount': solutionCount,
      'isResolved': isResolved,
      'acceptedSolutionId': acceptedSolutionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
