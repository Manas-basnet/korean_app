import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_meaning.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_example.dart';

class VocabularyWord extends Equatable {
  final String id;
  final String word;
  final String? pronunciation;
  final String? imageUrl;
  final String? imagePath;
  final String? audioUrl;
  final String? audioPath;
  final List<WordMeaning> meanings;
  final List<WordExample> examples;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const VocabularyWord({
    required this.id,
    required this.word,
    this.pronunciation,
    this.imageUrl,
    this.imagePath,
    this.audioUrl,
    this.audioPath,
    this.meanings = const [],
    this.examples = const [],
    this.order = 0,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  VocabularyWord copyWith({
    String? id,
    String? word,
    String? pronunciation,
    String? imageUrl,
    String? imagePath,
    String? audioUrl,
    String? audioPath,
    List<WordMeaning>? meanings,
    List<WordExample>? examples,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return VocabularyWord(
      id: id ?? this.id,
      word: word ?? this.word,
      pronunciation: pronunciation ?? this.pronunciation,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioPath: audioPath ?? this.audioPath,
      meanings: meanings ?? this.meanings,
      examples: examples ?? this.examples,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasPronunciation => pronunciation != null && pronunciation!.trim().isNotEmpty;
  bool get hasMeanings => meanings.isNotEmpty;
  bool get hasExamples => examples.isNotEmpty;
  int get meaningCount => meanings.length;
  int get exampleCount => examples.length;

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
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

    List<WordMeaning> meanings = [];
    if (json['meanings'] is List) {
      meanings = (json['meanings'] as List)
          .map((m) => WordMeaning.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    List<WordExample> examples = [];
    if (json['examples'] is List) {
      examples = (json['examples'] as List)
          .map((e) => WordExample.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return VocabularyWord(
      id: json['id'] as String,
      word: json['word'] as String,
      pronunciation: json['pronunciation'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioPath: json['audioPath'] as String?,
      meanings: meanings,
      examples: examples,
      order: json['order'] as int? ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'pronunciation': pronunciation,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'audioUrl': audioUrl,
      'audioPath': audioPath,
      'meanings': meanings.map((m) => m.toJson()).toList(),
      'examples': examples.map((e) => e.toJson()).toList(),
      'order': order,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        word,
        pronunciation,
        imageUrl,
        imagePath,
        audioUrl,
        audioPath,
        meanings,
        examples,
        order,
        createdAt,
        updatedAt,
        metadata,
      ];
}