import 'package:equatable/equatable.dart';

class UserTestInteraction extends Equatable {
  final String userId;
  final String testId;
  final bool hasViewed;
  final bool hasRated;
  final double? rating;
  final DateTime? viewedAt;
  final DateTime? ratedAt;
  final int completionCount;

  const UserTestInteraction({
    required this.userId,
    required this.testId,
    this.hasViewed = false,
    this.hasRated = false,
    this.rating,
    this.viewedAt,
    this.ratedAt,
    this.completionCount = 0,
  });

  UserTestInteraction copyWith({
    String? userId,
    String? testId,
    bool? hasViewed,
    bool? hasRated,
    double? rating,
    DateTime? viewedAt,
    DateTime? ratedAt,
    int? completionCount,
  }) {
    return UserTestInteraction(
      userId: userId ?? this.userId,
      testId: testId ?? this.testId,
      hasViewed: hasViewed ?? this.hasViewed,
      hasRated: hasRated ?? this.hasRated,
      rating: rating ?? this.rating,
      viewedAt: viewedAt ?? this.viewedAt,
      ratedAt: ratedAt ?? this.ratedAt,
      completionCount: completionCount ?? this.completionCount,
    );
  }

  factory UserTestInteraction.fromJson(Map<String, dynamic> json) {
    DateTime? viewedAt;
    if (json['viewedAt'] != null) {
      if (json['viewedAt'] is int) {
        viewedAt = DateTime.fromMillisecondsSinceEpoch(json['viewedAt']);
      } else if (json['viewedAt'] is Map) {
        final seconds = json['viewedAt']['_seconds'] as int?;
        if (seconds != null) {
          viewedAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }

    DateTime? ratedAt;
    if (json['ratedAt'] != null) {
      if (json['ratedAt'] is int) {
        ratedAt = DateTime.fromMillisecondsSinceEpoch(json['ratedAt']);
      } else if (json['ratedAt'] is Map) {
        final seconds = json['ratedAt']['_seconds'] as int?;
        if (seconds != null) {
          ratedAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }

    return UserTestInteraction(
      userId: json['userId'] as String,
      testId: json['testId'] as String,
      hasViewed: json['hasViewed'] as bool? ?? false,
      hasRated: json['hasRated'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble(),
      viewedAt: viewedAt,
      ratedAt: ratedAt,
      completionCount: json['completionCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'testId': testId,
      'hasViewed': hasViewed,
      'hasRated': hasRated,
      'rating': rating,
      'viewedAt': viewedAt?.millisecondsSinceEpoch,
      'ratedAt': ratedAt?.millisecondsSinceEpoch,
      'completionCount': completionCount,
    };
  }

  @override
  List<Object?> get props => [
        userId,
        testId,
        hasViewed,
        hasRated,
        rating,
        viewedAt,
        ratedAt,
        completionCount,
      ];
}