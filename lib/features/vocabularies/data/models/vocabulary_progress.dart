import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

import 'vocabulary_chapter_progress.dart';

class VocabularyProgress extends Equatable {
  final String vocabularyId;
  final String vocabularyTitle;
  final VocabularyItem? vocabularyItem;
  final Map<int, VocabularyChapterProgress> chapters;
  final DateTime lastStudiedTime;
  final Duration totalStudyTime;
  final int lastChapterIndex;
  final String lastChapterTitle;
  final Map<String, dynamic>? metadata;

  const VocabularyProgress({
    required this.vocabularyId,
    required this.vocabularyTitle,
    this.vocabularyItem,
    this.chapters = const {},
    required this.lastStudiedTime,
    this.totalStudyTime = Duration.zero,
    this.lastChapterIndex = 0,
    this.lastChapterTitle = '',
    this.metadata,
  });

  VocabularyProgress copyWith({
    String? vocabularyId,
    String? vocabularyTitle,
    VocabularyItem? vocabularyItem,
    Map<int, VocabularyChapterProgress>? chapters,
    DateTime? lastStudiedTime,
    Duration? totalStudyTime,
    int? lastChapterIndex,
    String? lastChapterTitle,
    Map<String, dynamic>? metadata,
  }) {
    return VocabularyProgress(
      vocabularyId: vocabularyId ?? this.vocabularyId,
      vocabularyTitle: vocabularyTitle ?? this.vocabularyTitle,
      vocabularyItem: vocabularyItem ?? this.vocabularyItem,
      chapters: chapters ?? this.chapters,
      lastStudiedTime: lastStudiedTime ?? this.lastStudiedTime,
      totalStudyTime: totalStudyTime ?? this.totalStudyTime,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
      metadata: metadata ?? this.metadata,
    );
  }

  double get overallProgress {
    if (chapters.isEmpty) return 0.0;
    
    final totalProgress = chapters.values.fold<double>(
      0.0,
      (sum, chapter) => sum + chapter.progressPercentage,
    );
    
    return (totalProgress / chapters.length).clamp(0.0, 1.0);
  }

  int get completedChaptersCount => chapters.values.where((c) => c.isCompleted).length;
  int get totalChaptersCount => chapters.length;
  int get totalStudiedWords => chapters.values.fold(0, (sum, c) => sum + c.studiedWordsCount);

  bool get isCompleted => chapters.isNotEmpty && chapters.values.every((c) => c.isCompleted);

  factory VocabularyProgress.fromJson(Map<String, dynamic> json) {
    final chaptersMap = <int, VocabularyChapterProgress>{};
    if (json['chapters'] is Map) {
      final chaptersJson = json['chapters'] as Map<String, dynamic>;
      for (final entry in chaptersJson.entries) {
        final index = int.tryParse(entry.key);
        if (index != null) {
          chaptersMap[index] = VocabularyChapterProgress.fromJson(
            entry.value as Map<String, dynamic>
          );
        }
      }
    }

    VocabularyItem? vocabularyItem;
    if (json['vocabularyItem'] is Map) {
      vocabularyItem = VocabularyItem.fromJson(json['vocabularyItem'] as Map<String, dynamic>);
    }

    return VocabularyProgress(
      vocabularyId: json['vocabularyId'] as String,
      vocabularyTitle: json['vocabularyTitle'] as String,
      vocabularyItem: vocabularyItem,
      chapters: chaptersMap,
      lastStudiedTime: DateTime.fromMillisecondsSinceEpoch(json['lastStudiedTime'] as int),
      totalStudyTime: Duration(milliseconds: json['totalStudyTime'] as int? ?? 0),
      lastChapterIndex: json['lastChapterIndex'] as int? ?? 0,
      lastChapterTitle: json['lastChapterTitle'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final chaptersJson = <String, dynamic>{};
    for (final entry in chapters.entries) {
      chaptersJson[entry.key.toString()] = entry.value.toJson();
    }

    return {
      'vocabularyId': vocabularyId,
      'vocabularyTitle': vocabularyTitle,
      'vocabularyItem': vocabularyItem?.toJson(),
      'chapters': chaptersJson,
      'lastStudiedTime': lastStudiedTime.millisecondsSinceEpoch,
      'totalStudyTime': totalStudyTime.inMilliseconds,
      'lastChapterIndex': lastChapterIndex,
      'lastChapterTitle': lastChapterTitle,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        vocabularyId,
        vocabularyTitle,
        vocabularyItem,
        chapters,
        lastStudiedTime,
        totalStudyTime,
        lastChapterIndex,
        lastChapterTitle,
        metadata,
      ];
}