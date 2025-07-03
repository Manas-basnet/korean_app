import 'package:equatable/equatable.dart';

class UserBookInteraction extends Equatable {
  final String userId;
  final String bookId;
  final bool hasViewed;
  final bool hasRated;
  final double? rating;
  final DateTime? viewedAt;
  final DateTime? ratedAt;
  final int readingCount;
  final double readingProgress; // 0.0 to 1.0
  final String? lastChapterId;
  final DateTime? lastReadAt;

  const UserBookInteraction({
    required this.userId,
    required this.bookId,
    this.hasViewed = false,
    this.hasRated = false,
    this.rating,
    this.viewedAt,
    this.ratedAt,
    this.readingCount = 0,
    this.readingProgress = 0.0,
    this.lastChapterId,
    this.lastReadAt,
  });

  UserBookInteraction copyWith({
    String? userId,
    String? bookId,
    bool? hasViewed,
    bool? hasRated,
    double? rating,
    DateTime? viewedAt,
    DateTime? ratedAt,
    int? readingCount,
    double? readingProgress,
    String? lastChapterId,
    DateTime? lastReadAt,
  }) {
    return UserBookInteraction(
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      hasViewed: hasViewed ?? this.hasViewed,
      hasRated: hasRated ?? this.hasRated,
      rating: rating ?? this.rating,
      viewedAt: viewedAt ?? this.viewedAt,
      ratedAt: ratedAt ?? this.ratedAt,
      readingCount: readingCount ?? this.readingCount,
      readingProgress: readingProgress ?? this.readingProgress,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  factory UserBookInteraction.fromJson(Map<String, dynamic> json) {
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

    DateTime? lastReadAt;
    if (json['lastReadAt'] != null) {
      if (json['lastReadAt'] is int) {
        lastReadAt = DateTime.fromMillisecondsSinceEpoch(json['lastReadAt']);
      } else if (json['lastReadAt'] is Map) {
        final seconds = json['lastReadAt']['_seconds'] as int?;
        if (seconds != null) {
          lastReadAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }

    return UserBookInteraction(
      userId: json['userId'] as String,
      bookId: json['bookId'] as String,
      hasViewed: json['hasViewed'] as bool? ?? false,
      hasRated: json['hasRated'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble(),
      viewedAt: viewedAt,
      ratedAt: ratedAt,
      readingCount: json['readingCount'] as int? ?? 0,
      readingProgress: (json['readingProgress'] as num?)?.toDouble() ?? 0.0,
      lastChapterId: json['lastChapterId'] as String?,
      lastReadAt: lastReadAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'bookId': bookId,
      'hasViewed': hasViewed,
      'hasRated': hasRated,
      'rating': rating,
      'viewedAt': viewedAt?.millisecondsSinceEpoch,
      'ratedAt': ratedAt?.millisecondsSinceEpoch,
      'readingCount': readingCount,
      'readingProgress': readingProgress,
      'lastChapterId': lastChapterId,
      'lastReadAt': lastReadAt?.millisecondsSinceEpoch,
    };
  }

  @override
  List<Object?> get props => [
        userId,
        bookId,
        hasViewed,
        hasRated,
        rating,
        viewedAt,
        ratedAt,
        readingCount,
        readingProgress,
        lastChapterId,
        lastReadAt,
      ];
}