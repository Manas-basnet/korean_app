import 'package:equatable/equatable.dart';

class VocabularyChapterProgress extends Equatable {
  final int chapterIndex;
  final String chapterTitle;
  final int currentWordIndex;
  final int totalWords;
  final DateTime lastStudiedTime;
  final Duration studyTime;
  final bool isCompleted;
  final List<String> studiedWordIds;
  final Map<String, dynamic>? metadata;

  const VocabularyChapterProgress({
    required this.chapterIndex,
    required this.chapterTitle,
    this.currentWordIndex = 0,
    this.totalWords = 0,
    required this.lastStudiedTime,
    this.studyTime = Duration.zero,
    this.isCompleted = false,
    this.studiedWordIds = const [],
    this.metadata,
  });

  VocabularyChapterProgress copyWith({
    int? chapterIndex,
    String? chapterTitle,
    int? currentWordIndex,
    int? totalWords,
    DateTime? lastStudiedTime,
    Duration? studyTime,
    bool? isCompleted,
    List<String>? studiedWordIds,
    Map<String, dynamic>? metadata,
  }) {
    return VocabularyChapterProgress(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      totalWords: totalWords ?? this.totalWords,
      lastStudiedTime: lastStudiedTime ?? this.lastStudiedTime,
      studyTime: studyTime ?? this.studyTime,
      isCompleted: isCompleted ?? this.isCompleted,
      studiedWordIds: studiedWordIds ?? this.studiedWordIds,
      metadata: metadata ?? this.metadata,
    );
  }

  double get progressPercentage {
    if (totalWords == 0) return 0.0;
    return (currentWordIndex / totalWords).clamp(0.0, 1.0);
  }

  int get studiedWordsCount => studiedWordIds.length;

  factory VocabularyChapterProgress.fromJson(Map<String, dynamic> json) {
    return VocabularyChapterProgress(
      chapterIndex: json['chapterIndex'] as int,
      chapterTitle: json['chapterTitle'] as String,
      currentWordIndex: json['currentWordIndex'] as int? ?? 0,
      totalWords: json['totalWords'] as int? ?? 0,
      lastStudiedTime: DateTime.fromMillisecondsSinceEpoch(json['lastStudiedTime'] as int),
      studyTime: Duration(milliseconds: json['studyTime'] as int? ?? 0),
      isCompleted: json['isCompleted'] as bool? ?? false,
      studiedWordIds: (json['studiedWordIds'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'currentWordIndex': currentWordIndex,
      'totalWords': totalWords,
      'lastStudiedTime': lastStudiedTime.millisecondsSinceEpoch,
      'studyTime': studyTime.inMilliseconds,
      'isCompleted': isCompleted,
      'studiedWordIds': studiedWordIds,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        chapterIndex,
        chapterTitle,
        currentWordIndex,
        totalWords,
        lastStudiedTime,
        studyTime,
        isCompleted,
        studiedWordIds,
        metadata,
      ];
}