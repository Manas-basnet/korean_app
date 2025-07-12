import 'package:equatable/equatable.dart';

class WordExample extends Equatable {
  final String id;
  final String example;
  final String? translation;
  final String? imageUrl;
  final String? imagePath;
  final String? audioUrl;
  final String? audioPath;
  final Map<String, dynamic>? metadata;

  const WordExample({
    required this.id,
    required this.example,
    this.translation,
    this.imageUrl,
    this.imagePath,
    this.audioUrl,
    this.audioPath,
    this.metadata,
  });

  WordExample copyWith({
    String? id,
    String? example,
    String? translation,
    String? imageUrl,
    String? imagePath,
    String? audioUrl,
    String? audioPath,
    Map<String, dynamic>? metadata,
  }) {
    return WordExample(
      id: id ?? this.id,
      example: example ?? this.example,
      translation: translation ?? this.translation,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioPath: audioPath ?? this.audioPath,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasTranslation => translation != null && translation!.trim().isNotEmpty;

  factory WordExample.fromJson(Map<String, dynamic> json) {
    return WordExample(
      id: json['id'] as String,
      example: json['example'] as String,
      translation: json['translation'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioPath: json['audioPath'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'example': example,
      'translation': translation,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'audioUrl': audioUrl,
      'audioPath': audioPath,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        example,
        translation,
        imageUrl,
        imagePath,
        audioUrl,
        audioPath,
        metadata,
      ];
}