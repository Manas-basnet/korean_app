import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';

class VocabularyItem extends Equatable {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? imagePath;
  final SupportedLanguage primaryLanguage;
  final List<VocabularyChapter> chapters;
  final List<String> pdfUrls;
  final List<String> pdfPaths;
  final BookLevel level;
  final String? creatorUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPublished;
  final Map<String, dynamic>? metadata;
  
  final int viewCount;
  final double rating;
  final int ratingCount;
  final double popularity;

  const VocabularyItem({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imagePath,
    required this.primaryLanguage,
    this.chapters = const [],
    this.pdfUrls = const [],
    this.pdfPaths = const [],
    required this.level,
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

  VocabularyItem copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? imagePath,
    SupportedLanguage? primaryLanguage,
    List<VocabularyChapter>? chapters,
    List<String>? pdfUrls,
    List<String>? pdfPaths,
    BookLevel? level,
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
    return VocabularyItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      chapters: chapters ?? this.chapters,
      pdfUrls: pdfUrls ?? this.pdfUrls,
      pdfPaths: pdfPaths ?? this.pdfPaths,
      level: level ?? this.level,
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

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasChapters => chapters.isNotEmpty;
  bool get hasPdfs => pdfUrls.isNotEmpty || pdfPaths.isNotEmpty;
  int get chapterCount => chapters.length;
  int get totalWords => chapters.fold(0, (sum, chapter) => sum + chapter.wordCount);
  int get totalMeanings => chapters.fold(0, (sum, chapter) => sum + chapter.totalMeanings);
  int get totalExamples => chapters.fold(0, (sum, chapter) => sum + chapter.totalExamples);
  String get formattedRating => rating.isNaN || rating <= 0 ? '0.0' : rating.toStringAsFixed(1);
  String get formattedViewCount => viewCount > 999 ? '${(viewCount / 1000).toStringAsFixed(1)}k' : viewCount.toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VocabularyItem && other.id == id;
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

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    SupportedLanguage primaryLanguage = SupportedLanguage.english;
    if (json['primaryLanguage'] is String) {
      primaryLanguage = SupportedLanguage.values.firstWhere(
        (e) => e.toString().split('.').last == json['primaryLanguage'],
        orElse: () => SupportedLanguage.english,
      );
    }

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

    List<VocabularyChapter> chapters = [];
    if (json['chapters'] is List) {
      chapters = (json['chapters'] as List)
          .map((c) => VocabularyChapter.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    List<String> pdfUrls = [];
    if (json['pdfUrls'] is List) {
      pdfUrls = (json['pdfUrls'] as List).cast<String>();
    }

    List<String> pdfPaths = [];
    if (json['pdfPaths'] is List) {
      pdfPaths = (json['pdfPaths'] as List).cast<String>();
    }

    return VocabularyItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      primaryLanguage: primaryLanguage,
      chapters: chapters,
      pdfUrls: pdfUrls,
      pdfPaths: pdfPaths,
      level: level,
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
      'primaryLanguage': primaryLanguage.toString().split('.').last,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'pdfUrls': pdfUrls,
      'pdfPaths': pdfPaths,
      'level': level.toString().split('.').last,
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

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        imageUrl,
        imagePath,
        primaryLanguage,
        chapters,
        pdfUrls,
        pdfPaths,
        level,
        creatorUid,
        createdAt,
        updatedAt,
        isPublished,
        metadata,
        viewCount,
        rating,
        ratingCount,
        popularity,
      ];
}