class ChapterProgress {
  final int chapterIndex;
  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final DateTime lastReadTime;
  final Duration readingTime;
  final bool isCompleted;

  const ChapterProgress({
    required this.chapterIndex,
    required this.chapterTitle,
    this.currentPage = 1,
    this.totalPages = 0,
    required this.lastReadTime,
    this.readingTime = Duration.zero,
    this.isCompleted = false,
  });

  ChapterProgress copyWith({
    int? chapterIndex,
    String? chapterTitle,
    int? currentPage,
    int? totalPages,
    DateTime? lastReadTime,
    Duration? readingTime,
    bool? isCompleted,
  }) {
    return ChapterProgress(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      readingTime: readingTime ?? this.readingTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  double get progress {
    if (totalPages <= 0) return 0.0;
    if (isCompleted) return 1.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  String get formattedProgress {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'lastReadTime': lastReadTime.millisecondsSinceEpoch,
      'readingTime': readingTime.inMilliseconds,
      'isCompleted': isCompleted,
    };
  }

  factory ChapterProgress.fromJson(Map<String, dynamic> json) {
    return ChapterProgress(
      chapterIndex: json['chapterIndex'] as int,
      chapterTitle: json['chapterTitle'] as String,
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 0,
      lastReadTime: DateTime.fromMillisecondsSinceEpoch(json['lastReadTime'] as int),
      readingTime: Duration(milliseconds: json['readingTime'] as int? ?? 0),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}