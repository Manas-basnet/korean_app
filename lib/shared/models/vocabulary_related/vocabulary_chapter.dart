import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';

class VocabularyChapter extends Equatable {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? imagePath;
  final List<VocabularyWord> words;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const VocabularyChapter({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imagePath,
    this.words = const [],
    this.order = 0,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  VocabularyChapter copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? imagePath,
    List<VocabularyWord>? words,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return VocabularyChapter(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      words: words ?? this.words,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasWords => words.isNotEmpty;
  int get wordCount => words.length;
  int get totalMeanings => words.fold(0, (sum, word) => sum + word.meaningCount);
  int get totalExamples => words.fold(0, (sum, word) => sum + word.exampleCount);

  factory VocabularyChapter.fromJson(Map<String, dynamic> json) {
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

    List<VocabularyWord> words = [];
    if (json['words'] is List) {
      words = (json['words'] as List)
          .map((w) => VocabularyWord.fromJson(w as Map<String, dynamic>))
          .toList();
    }

    return VocabularyChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      words: words,
      order: json['order'] as int? ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'words': words.map((w) => w.toJson()).toList(),
      'order': order,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        imageUrl,
        imagePath,
        words,
        order,
        createdAt,
        updatedAt,
        metadata,
      ];
}