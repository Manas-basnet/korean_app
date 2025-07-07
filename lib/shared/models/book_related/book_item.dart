import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'book_chapter.dart';

class BookItem {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? imagePath;
  final List<BookChapter> chapters;
  final int duration;
  final BookLevel level;
  final CourseCategory category;
  final String language;
  final String? creatorUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPublished;
  final Map<String, dynamic>? metadata;
  
  final int viewCount;
  final double rating;
  final int ratingCount;
  final double popularity;

  const BookItem({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imagePath,
    required this.chapters,
    this.duration = 0,
    required this.level,
    required this.category,
    this.language = 'Korean',
    this.creatorUid,
    this.createdAt,
    this.updatedAt,
    this.isPublished = true,
    this.metadata,
    this.viewCount = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.popularity = 0.0,
  });

  BookItem copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? imagePath,
    List<BookChapter>? chapters,
    int? duration,
    BookLevel? level,
    CourseCategory? category,
    String? language,
    String? creatorUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublished,
    Map<String, dynamic>? metadata,
    int? viewCount,
    double? rating,
    int? ratingCount,
    double? popularity,
  }) {
    return BookItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      chapters: chapters ?? this.chapters,
      duration: duration ?? this.duration,
      level: level ?? this.level,
      category: category ?? this.category,
      language: language ?? this.language,
      creatorUid: creatorUid ?? this.creatorUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublished: isPublished ?? this.isPublished,
      metadata: metadata ?? this.metadata,
      viewCount: viewCount ?? this.viewCount,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      popularity: popularity ?? this.popularity,
    );
  }

  int get chapterCount => chapters.length;
  int get totalDuration {
    return chapters.fold(0, (sum, chapter) => sum + chapter.totalAudioDuration);
  }
  String get formattedDuration => _formatDuration(Duration(seconds: totalDuration));
  String get formattedRating => rating.isNaN || rating <= 0 ? '0.0' : rating.toStringAsFixed(1);
  String get formattedViewCount => viewCount > 999 ? '${(viewCount / 1000).toStringAsFixed(1)}k' : viewCount.toString();

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      String twoDigitHours = twoDigits(duration.inHours);
      return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  static double _sanitizeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) {
      return value.isNaN || value.isInfinite ? 0.0 : value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.isNaN == false && parsed?.isInfinite == false ? parsed! : 0.0;
    }
    return 0.0;
  }

  factory BookItem.fromJson(Map<String, dynamic> json) {
    BookLevel level;
    if (json['level'] is int) {
      level = BookLevel.values[json['level']];
    } else if (json['level'] is String) {
      level = BookLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['level'],
        orElse: () => BookLevel.beginner,
      );
    } else {
      level = BookLevel.beginner;
    }

    CourseCategory category;
    if (json['category'] is int) {
      category = CourseCategory.values[json['category']];
    } else if (json['category'] is String) {
      category = CourseCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => CourseCategory.korean,
      );
    } else {
      category = CourseCategory.korean;
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt']);
      } else if (json['createdAt'] is Map) {
        final seconds = json['createdAt']['_seconds'] as int?;
        if (seconds != null) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(json['updatedAt']);
      } else if (json['updatedAt'] is Map) {
        final seconds = json['updatedAt']['_seconds'] as int?;
        if (seconds != null) {
          updatedAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }

    List<BookChapter> chapters = [];
    if (json['chapters'] is List) {
      chapters = (json['chapters'] as List)
          .map((c) => BookChapter.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return BookItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      chapters: chapters,
      duration: json['duration'] as int? ?? 0,
      level: level,
      category: category,
      language: json['language'] as String? ?? 'Korean',
      creatorUid: json['creatorUid'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPublished: json['isPublished'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
      viewCount: json['viewCount'] as int? ?? 0,
      rating: _sanitizeDouble(json['rating']),
      ratingCount: json['ratingCount'] as int? ?? 0,
      popularity: _sanitizeDouble(json['popularity']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'duration': duration,
      'level': level.toString().split('.').last,
      'category': category.toString().split('.').last,
      'language': language,
      'creatorUid': creatorUid,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'isPublished': isPublished,
      'metadata': metadata,
      'viewCount': viewCount,
      'rating': rating.isNaN || rating.isInfinite ? 0.0 : rating,
      'ratingCount': ratingCount,
      'popularity': popularity.isNaN || popularity.isInfinite ? 0.0 : popularity,
    };
  }
}