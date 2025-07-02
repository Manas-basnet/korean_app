import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/models/book_related/chapter.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';

class BookItem {
  final String id;
  final String title;
  final String description;
  final String? bookImage;
  final String? pdfUrl;
  final String? bookImagePath;
  final String? pdfPath;
  final List<AudioTrack> audioTracks;
  final String duration;
  final int chaptersCount;
  final IconData icon;
  final BookLevel level;
  final CourseCategory courseCategory;
  final String country;
  final String category;
  final String? creatorUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  final BookUploadType uploadType;
  final List<Chapter> chapters;

  const BookItem({
    required this.id,
    required this.title,
    required this.description,
    this.bookImage,
    this.pdfUrl,
    this.bookImagePath,
    this.pdfPath,
    this.audioTracks = const [],
    required this.duration,
    required this.chaptersCount,
    required this.icon,
    required this.level,
    required this.courseCategory,
    required this.country,
    required this.category,
    this.creatorUid,
    this.createdAt,
    this.updatedAt,
    this.uploadType = BookUploadType.singlePdf,
    this.chapters = const [],
  });

  BookItem copyWith({
    String? id,
    String? title,
    String? description,
    String? bookImage,
    String? pdfUrl,
    String? bookImagePath,
    String? pdfPath,
    List<AudioTrack>? audioTracks,
    String? duration,
    int? chaptersCount,
    IconData? icon,
    BookLevel? level,
    CourseCategory? courseCategory,
    String? country,
    String? category,
    String? creatorUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    BookUploadType? uploadType,
    List<Chapter>? chapters,
  }) {
    return BookItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      bookImage: bookImage ?? this.bookImage,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      bookImagePath: bookImagePath ?? this.bookImagePath,
      pdfPath: pdfPath ?? this.pdfPath,
      audioTracks: audioTracks ?? this.audioTracks,
      duration: duration ?? this.duration,
      chaptersCount: chaptersCount ?? this.chaptersCount,
      icon: icon ?? this.icon,
      level: level ?? this.level,
      courseCategory: courseCategory ?? this.courseCategory,
      country: country ?? this.country,
      category: category ?? this.category,
      creatorUid: creatorUid ?? this.creatorUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploadType: uploadType ?? this.uploadType,
      chapters: chapters ?? this.chapters,
    );
  }

  bool get hasAudio => audioTracks.isNotEmpty;
  bool get hasChapterAudio => chapters.any((chapter) => chapter.hasAudio);
  int get totalAudioTracks => audioTracks.length + chapters.fold(0, (sum, chapter) => sum + chapter.audioTrackCount);

  // Legacy compatibility for old single audio fields
  String? get audioUrl => audioTracks.isNotEmpty ? audioTracks.first.audioUrl : null;
  String? get audioPath => audioTracks.isNotEmpty ? audioTracks.first.audioPath : null;

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
    
    CourseCategory courseCategory;
    if (json['courseCategory'] is int) {
      courseCategory = CourseCategory.values[json['courseCategory']];
    } else if (json['courseCategory'] is String) {
      courseCategory = CourseCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['courseCategory'],
        orElse: () => CourseCategory.korean,
      );
    } else {
      courseCategory = CourseCategory.korean;
    }

    BookUploadType uploadType = BookUploadType.singlePdf;
    if (json['uploadType'] is String) {
      uploadType = BookUploadType.values.firstWhere(
        (e) => e.toString().split('.').last == json['uploadType'],
        orElse: () => BookUploadType.singlePdf,
      );
    }

    List<Chapter> chapters = [];
    if (json['chapters'] is List) {
      chapters = (json['chapters'] as List)
          .map((chapterJson) => Chapter.fromJson(chapterJson))
          .toList();
    }

    List<AudioTrack> audioTracks = [];
    
    // Handle new multiple audio tracks format
    if (json['audioTracks'] is List) {
      audioTracks = (json['audioTracks'] as List)
          .map((trackJson) => AudioTrack.fromJson(trackJson))
          .toList();
    }
    // Handle legacy single audio format for backward compatibility
    else if (json['audioUrl'] != null || json['audioPath'] != null) {
      audioTracks = [
        AudioTrack(
          id: '${json['id']}_legacy_audio',
          name: 'Audio Track',
          audioUrl: json['audioUrl'] as String?,
          audioPath: json['audioPath'] as String?,
          order: 0,
        ),
      ];
    }
    
    IconData icon;
    if (json['iconCodePoint'] != null) {
      icon = _iconMapping[json['iconCodePoint']] ?? Icons.book;
    } else if (json['icon'] is int) {
      icon = _iconMapping[json['icon']] ?? Icons.book;
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

    return BookItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      bookImage: json['bookImage'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      bookImagePath: json['bookImagePath'] as String?,
      pdfPath: json['pdfPath'] as String?,
      audioTracks: audioTracks,
      duration: json['duration'] as String? ?? '30 mins',
      chaptersCount: json['chaptersCount'] as int? ?? (chapters.isNotEmpty ? chapters.length : 1),
      icon: icon,
      level: level,
      courseCategory: courseCategory,
      country: json['country'] as String? ?? 'Korea',
      category: json['category'] as String? ?? 'Language',
      creatorUid: json['creatorUid'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      uploadType: uploadType,
      chapters: chapters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'bookImage': bookImage,
      'pdfUrl': pdfUrl,
      'bookImagePath': bookImagePath,
      'pdfPath': pdfPath,
      'audioTracks': audioTracks.map((track) => track.toJson()).toList(),
      'duration': duration,
      'chaptersCount': chaptersCount,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'level': level.toString().split('.').last,
      'courseCategory': courseCategory.toString().split('.').last,
      'country': country,
      'category': category,
      'creatorUid': creatorUid,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'uploadType': uploadType.toString().split('.').last,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      // Legacy fields for backward compatibility
      'audioUrl': audioTracks.isNotEmpty ? audioTracks.first.audioUrl : null,
      'audioPath': audioTracks.isNotEmpty ? audioTracks.first.audioPath : null,
    };
  }

  static final Map<int, IconData> _iconMapping = {
    Icons.menu_book.codePoint: Icons.menu_book,
    Icons.quiz.codePoint: Icons.quiz,
    Icons.business.codePoint: Icons.business,
    Icons.theater_comedy.codePoint: Icons.theater_comedy,
    Icons.record_voice_over.codePoint: Icons.record_voice_over,
    Icons.auto_stories.codePoint: Icons.auto_stories,
    Icons.history_edu.codePoint: Icons.history_edu,
    Icons.music_note.codePoint: Icons.music_note,
    Icons.movie.codePoint: Icons.movie,
    Icons.edit.codePoint: Icons.edit,
    Icons.forum.codePoint: Icons.forum,
    Icons.book.codePoint: Icons.book,
    Icons.help_outline.codePoint: Icons.help_outline,
  };
}