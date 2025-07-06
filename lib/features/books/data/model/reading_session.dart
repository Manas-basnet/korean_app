class ReadingSession {
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final int chapterIndex;
  final int currentPage;
  final int totalPages;
  final DateTime startTime;
  final DateTime lastActiveTime;
  final Duration totalReadingTime;
  final bool isActive;

  const ReadingSession({
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    this.currentPage = 1,
    this.totalPages = 0,
    required this.startTime,
    required this.lastActiveTime,
    this.totalReadingTime = Duration.zero,
    this.isActive = false,
  });

  ReadingSession copyWith({
    String? bookId,
    String? bookTitle,
    String? chapterTitle,
    int? chapterIndex,
    int? currentPage,
    int? totalPages,
    DateTime? startTime,
    DateTime? lastActiveTime,
    Duration? totalReadingTime,
    bool? isActive,
  }) {
    return ReadingSession(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      startTime: startTime ?? this.startTime,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      totalReadingTime: totalReadingTime ?? this.totalReadingTime,
      isActive: isActive ?? this.isActive,
    );
  }

  double get chapterProgress {
    if (totalPages <= 0) return 0.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
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
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'startTime': startTime.millisecondsSinceEpoch,
      'lastActiveTime': lastActiveTime.millisecondsSinceEpoch,
      'totalReadingTime': totalReadingTime.inMilliseconds,
      'isActive': isActive,
    };
  }

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      bookId: json['bookId'] as String,
      bookTitle: json['bookTitle'] as String,
      chapterTitle: json['chapterTitle'] as String,
      chapterIndex: json['chapterIndex'] as int,
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      lastActiveTime: DateTime.fromMillisecondsSinceEpoch(json['lastActiveTime'] as int),
      totalReadingTime: Duration(milliseconds: json['totalReadingTime'] as int? ?? 0),
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}