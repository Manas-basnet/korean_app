import 'package:equatable/equatable.dart';

class VocabularyStudySession extends Equatable {
  final String vocabularyId;
  final String vocabularyTitle;
  final String chapterTitle;
  final int chapterIndex;
  final int currentWordIndex;
  final int totalWords;
  final DateTime startTime;
  final DateTime lastActiveTime;
  final Duration totalStudyTime;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const VocabularyStudySession({
    required this.vocabularyId,
    required this.vocabularyTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    this.currentWordIndex = 0,
    this.totalWords = 0,
    required this.startTime,
    required this.lastActiveTime,
    this.totalStudyTime = Duration.zero,
    this.isActive = true,
    this.metadata,
  });

  VocabularyStudySession copyWith({
    String? vocabularyId,
    String? vocabularyTitle,
    String? chapterTitle,
    int? chapterIndex,
    int? currentWordIndex,
    int? totalWords,
    DateTime? startTime,
    DateTime? lastActiveTime,
    Duration? totalStudyTime,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return VocabularyStudySession(
      vocabularyId: vocabularyId ?? this.vocabularyId,
      vocabularyTitle: vocabularyTitle ?? this.vocabularyTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      totalWords: totalWords ?? this.totalWords,
      startTime: startTime ?? this.startTime,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      totalStudyTime: totalStudyTime ?? this.totalStudyTime,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  double get progressPercentage {
    if (totalWords == 0) return 0.0;
    return (currentWordIndex / totalWords).clamp(0.0, 1.0);
  }

  bool get isCompleted => currentWordIndex >= totalWords && totalWords > 0;

  factory VocabularyStudySession.fromJson(Map<String, dynamic> json) {
    return VocabularyStudySession(
      vocabularyId: json['vocabularyId'] as String,
      vocabularyTitle: json['vocabularyTitle'] as String,
      chapterTitle: json['chapterTitle'] as String,
      chapterIndex: json['chapterIndex'] as int,
      currentWordIndex: json['currentWordIndex'] as int? ?? 0,
      totalWords: json['totalWords'] as int? ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      lastActiveTime: DateTime.fromMillisecondsSinceEpoch(json['lastActiveTime'] as int),
      totalStudyTime: Duration(milliseconds: json['totalStudyTime'] as int? ?? 0),
      isActive: json['isActive'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vocabularyId': vocabularyId,
      'vocabularyTitle': vocabularyTitle,
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex,
      'currentWordIndex': currentWordIndex,
      'totalWords': totalWords,
      'startTime': startTime.millisecondsSinceEpoch,
      'lastActiveTime': lastActiveTime.millisecondsSinceEpoch,
      'totalStudyTime': totalStudyTime.inMilliseconds,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        vocabularyId,
        vocabularyTitle,
        chapterTitle,
        chapterIndex,
        currentWordIndex,
        totalWords,
        startTime,
        lastActiveTime,
        totalStudyTime,
        isActive,
        metadata,
      ];
}



