import 'package:equatable/equatable.dart';

class TestRating extends Equatable {
  final String id;
  final String testId;
  final String userId;
  final int rating; // 1-5 stars
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TestRating({
    required this.id,
    required this.testId,
    required this.userId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  TestRating copyWith({
    String? id,
    String? testId,
    String? userId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TestRating(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TestRating.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    if (json['createdAt'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt']);
    } else if (json['createdAt'] is Map) {
      final seconds = json['createdAt']['_seconds'] as int;
      createdAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } else {
      createdAt = DateTime.now();
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(json['updatedAt']);
      } else if (json['updatedAt'] is Map) {
        final seconds = json['updatedAt']['_seconds'] as int;
        updatedAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    return TestRating(
      id: json['id'] as String,
      testId: json['testId'] as String,
      userId: json['userId'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'testId': testId,
      'userId': userId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  @override
  List<Object?> get props => [
        id,
        testId,
        userId,
        rating,
        comment,
        createdAt,
        updatedAt,
      ];
}