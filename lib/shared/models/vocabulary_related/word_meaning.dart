import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';

class WordMeaning extends Equatable {
  final String id;
  final SupportedLanguage language;
  final String meaning;
  final String? imageUrl;
  final String? imagePath;
  final String? audioUrl;
  final String? audioPath;
  final Map<String, dynamic>? metadata;

  const WordMeaning({
    required this.id,
    required this.language,
    required this.meaning,
    this.imageUrl,
    this.imagePath,
    this.audioUrl,
    this.audioPath,
    this.metadata,
  });

  WordMeaning copyWith({
    String? id,
    SupportedLanguage? language,
    String? meaning,
    String? imageUrl,
    String? imagePath,
    String? audioUrl,
    String? audioPath,
    Map<String, dynamic>? metadata,
  }) {
    return WordMeaning(
      id: id ?? this.id,
      language: language ?? this.language,
      meaning: meaning ?? this.meaning,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioPath: audioPath ?? this.audioPath,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  factory WordMeaning.fromJson(Map<String, dynamic> json) {
    SupportedLanguage language = SupportedLanguage.english;
    if (json['language'] is String) {
      language = SupportedLanguage.values.firstWhere(
        (e) => e.toString().split('.').last == json['language'],
        orElse: () => SupportedLanguage.english,
      );
    }

    return WordMeaning(
      id: json['id'] as String,
      language: language,
      meaning: json['meaning'] as String,
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
      'language': language.toString().split('.').last,
      'meaning': meaning,
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
        language,
        meaning,
        imageUrl,
        imagePath,
        audioUrl,
        audioPath,
        metadata,
      ];
}