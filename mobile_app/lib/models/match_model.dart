class MatchModel {
  final String id;
  final String title;
  final String category;
  final double entryFee;
  final int totalSpots;
  final int filledSpots;
  final double prizePool;
  final String status;
  final String? roomId;
  final String? roomPassword;
  final DateTime? startTime;
  final DateTime? resultSubmissionDeadline;

  const MatchModel({
    required this.id,
    required this.title,
    required this.category,
    required this.entryFee,
    required this.totalSpots,
    this.filledSpots = 0,
    required this.prizePool,
    required this.status,
    this.roomId,
    this.roomPassword,
    this.startTime,
    this.resultSubmissionDeadline,
  });

  // Immutability Rule: copyWith
  MatchModel copyWith({
    String? id,
    String? title,
    String? category,
    double? entryFee,
    int? totalSpots,
    int? filledSpots,
    double? prizePool,
    String? status,
    String? roomId,
    String? roomPassword,
    DateTime? startTime,
    DateTime? resultSubmissionDeadline,
  }) {
    return MatchModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      entryFee: entryFee ?? this.entryFee,
      totalSpots: totalSpots ?? this.totalSpots,
      filledSpots: filledSpots ?? this.filledSpots,
      prizePool: prizePool ?? this.prizePool,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      roomPassword: roomPassword ?? this.roomPassword,
      startTime: startTime ?? this.startTime,
      resultSubmissionDeadline: resultSubmissionDeadline ?? this.resultSubmissionDeadline,
    );
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      entryFee: (json['entry_fee'] as num).toDouble(),
      totalSpots: json['total_spots'] as int,
      filledSpots: json['filled_spots'] as int? ?? 0,
      prizePool: (json['prize_pool'] as num).toDouble(),
      status: json['status'] as String,
      roomId: json['room_id'] as String?,
      roomPassword: json['room_password'] as String?,
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      resultSubmissionDeadline: json['result_submission_deadline'] != null ? DateTime.parse(json['result_submission_deadline']) : null,
    );
  }
}
