class BattleModel {
  final String id;
  final String mode;
  final String player1Id;
  final String player2Id;
  final String status; // waiting, in_progress, completed
  final int player1Score;
  final int player2Score;
  final int currentRound;
  final int totalRounds;
  final Map<String, dynamic> answers;
  final String? winnerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BattleModel({
    required this.id,
    required this.mode,
    required this.player1Id,
    required this.player2Id,
    required this.status,
    required this.player1Score,
    required this.player2Score,
    required this.currentRound,
    required this.totalRounds,
    required this.answers,
    this.winnerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BattleModel.fromJson(Map<String, dynamic> json) {
    return BattleModel(
      id: json['id'] as String,
      mode: json['mode'] as String,
      player1Id: json['player1Id'] as String,
      player2Id: json['player2Id'] as String? ?? '',
      status: json['status'] as String,
      player1Score: json['player1Score'] as int? ?? 0,
      player2Score: json['player2Score'] as int? ?? 0,
      currentRound: json['currentRound'] as int? ?? 0,
      totalRounds: json['totalRounds'] as int? ?? 5,
      answers: Map<String, dynamic>.from(json['answers'] ?? {}),
      winnerId: json['winnerId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mode': mode,
      'player1Id': player1Id,
      'player2Id': player2Id,
      'status': status,
      'player1Score': player1Score,
      'player2Score': player2Score,
      'currentRound': currentRound,
      'totalRounds': totalRounds,
      'answers': answers,
      'winnerId': winnerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  BattleModel copyWith({
    String? id,
    String? mode,
    String? player1Id,
    String? player2Id,
    String? status,
    int? player1Score,
    int? player2Score,
    int? currentRound,
    int? totalRounds,
    Map<String, dynamic>? answers,
    String? winnerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BattleModel(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      status: status ?? this.status,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      answers: answers ?? this.answers,
      winnerId: winnerId ?? this.winnerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
