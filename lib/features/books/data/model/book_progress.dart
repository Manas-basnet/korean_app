import 'package:flutter/material.dart';
import 'package:korean_language_app/features/books/data/model/chapter_progress.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class BookProgress {
  final String bookId;
  final String bookTitle;
  final BookItem? bookItem;
  final Map<int, ChapterProgress> chapters;
  final DateTime lastReadTime;
  final Duration totalReadingTime;
  final int lastChapterIndex;
  final String? lastChapterTitle;

  const BookProgress({
    required this.bookId,
    required this.bookTitle,
    this.bookItem,
    this.chapters = const {},
    required this.lastReadTime,
    this.totalReadingTime = Duration.zero,
    this.lastChapterIndex = 0,
    this.lastChapterTitle,
  });

  BookProgress copyWith({
    String? bookId,
    String? bookTitle,
    BookItem? bookItem,
    Map<int, ChapterProgress>? chapters,
    DateTime? lastReadTime,
    Duration? totalReadingTime,
    int? lastChapterIndex,
    String? lastChapterTitle,
  }) {
    return BookProgress(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookItem: bookItem ?? this.bookItem,
      chapters: chapters ?? this.chapters,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      totalReadingTime: totalReadingTime ?? this.totalReadingTime,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
    );
  }

  double get overallProgress {
    if (chapters.isEmpty) return 0.0;
    
    final totalProgress = chapters.values.fold(0.0, (sum, chapter) => sum + chapter.progress);
    return (totalProgress / chapters.length).clamp(0.0, 1.0);
  }

  int get completedChapters {
    return chapters.values.where((chapter) => chapter.isCompleted).length;
  }

  String get formattedProgress {
    return '${(overallProgress * 100).toStringAsFixed(1)}%';
  }

  String get formattedReadingTime {
    final hours = totalReadingTime.inHours;
    final minutes = totalReadingTime.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'bookItem': bookItem?.toJson(),
      'chapters': chapters.map((key, value) => MapEntry(key.toString(), value.toJson())),
      'lastReadTime': lastReadTime.millisecondsSinceEpoch,
      'totalReadingTime': totalReadingTime.inMilliseconds,
      'lastChapterIndex': lastChapterIndex,
      'lastChapterTitle': lastChapterTitle,
    };
  }

  factory BookProgress.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as Map<String, dynamic>? ?? {};
    final chapters = <int, ChapterProgress>{};
    
    chaptersJson.forEach((key, value) {
      final chapterIndex = int.tryParse(key);
      if (chapterIndex != null) {
        chapters[chapterIndex] = ChapterProgress.fromJson(value as Map<String, dynamic>);
      }
    });

    BookItem? bookItem;
    if (json['bookItem'] != null) {
      try {
        bookItem = BookItem.fromJson(json['bookItem'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error parsing BookItem from BookProgress: $e');
      }
    }

    return BookProgress(
      bookId: json['bookId'] as String,
      bookTitle: json['bookTitle'] as String,
      bookItem: bookItem,
      chapters: chapters,
      lastReadTime: DateTime.fromMillisecondsSinceEpoch(json['lastReadTime'] as int),
      totalReadingTime: Duration(milliseconds: json['totalReadingTime'] as int? ?? 0),
      lastChapterIndex: json['lastChapterIndex'] as int? ?? 0,
      lastChapterTitle: json['lastChapterTitle'] as String?,
    );
  }
}