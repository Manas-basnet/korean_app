import 'package:flutter/material.dart';
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
  final int duration; // total duration in seconds
  final BookLevel level;
  final CourseCategory category;
  final String language;
  final IconData icon;
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
    this.icon = Icons.book,
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
    IconData? icon,
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
      icon: icon ?? this.icon,
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
  String get formattedRating => rating > 0 ? rating.toStringAsFixed(1) : '0.0';
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

    IconData icon;
    if (json['iconCodePoint'] != null) {
      icon = _iconMapping[json['iconCodePoint']] ?? Icons.book;
    } else {
      icon = Icons.book;
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
      icon: icon,
      creatorUid: json['creatorUid'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPublished: json['isPublished'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
      viewCount: json['viewCount'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
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
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'creatorUid': creatorUid,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'isPublished': isPublished,
      'metadata': metadata,
      'viewCount': viewCount,
      'rating': rating,
      'ratingCount': ratingCount,
      'popularity': popularity,
    };
  }

  static final Map<int, IconData> _iconMapping = {
    Icons.book.codePoint: Icons.book,
    Icons.library_books.codePoint: Icons.library_books,
    Icons.menu_book.codePoint: Icons.menu_book,
    Icons.auto_stories.codePoint: Icons.auto_stories,
    Icons.chrome_reader_mode.codePoint: Icons.chrome_reader_mode,
    Icons.import_contacts.codePoint: Icons.import_contacts,
    Icons.book_outlined.codePoint: Icons.book_outlined,
  };
}