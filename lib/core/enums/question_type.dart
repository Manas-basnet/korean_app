enum QuestionType {
  text,
  image,
  audio,
}

extension QuestionTypeExtension on QuestionType {
  String get displayName {
    switch (this) {
      case QuestionType.text:
        return 'Text';
      case QuestionType.image:
        return 'Image';
      case QuestionType.audio:
        return 'Audio';
    }
  }
}

enum AnswerOptionType {
  text,
  image,
  audio,
}

extension AnswerOptionTypeExtension on AnswerOptionType {
  String get displayName {
    switch (this) {
      case AnswerOptionType.text:
        return 'Text';
      case AnswerOptionType.image:
        return 'Image';
      case AnswerOptionType.audio:
        return 'Audio';
    }
  }
}

class AnswerOption {
  final String text;
  final String? imageUrl;
  final String? imagePath;
  final String? audioUrl;
  final String? audioPath;
  final AnswerOptionType type;
  
  const AnswerOption({
    required this.text,
    this.imageUrl,
    this.imagePath,
    this.audioUrl,
    this.audioPath,
    this.type = AnswerOptionType.text,
  });
  
  bool get isImage => type == AnswerOptionType.image;
  bool get isAudio => type == AnswerOptionType.audio;
  bool get isText => type == AnswerOptionType.text;
  
  factory AnswerOption.fromJson(Map<String, dynamic> json) {
    AnswerOptionType type = AnswerOptionType.text;
    if (json['type'] is String) {
      type = AnswerOptionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AnswerOptionType.text,
      );
    } else if (json['isImage'] == true) {
      type = AnswerOptionType.image;
    }
    
    return AnswerOption(
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioPath: json['audioPath'] as String?,
      type: type,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'audioUrl': audioUrl,
      'audioPath': audioPath,
      'type': type.toString().split('.').last,
      'isImage': isImage,
    };
  }
  
  AnswerOption copyWith({
    String? text,
    String? imageUrl,
    String? imagePath,
    String? audioUrl,
    String? audioPath,
    AnswerOptionType? type,
  }) {
    return AnswerOption(
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioPath: audioPath ?? this.audioPath,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnswerOption &&
        other.text == text &&
        other.imageUrl == imageUrl &&
        other.imagePath == imagePath &&
        other.audioUrl == audioUrl &&
        other.audioPath == audioPath &&
        other.type == type;
  }

  @override
  int get hashCode {
    return text.hashCode ^
        imageUrl.hashCode ^
        imagePath.hashCode ^
        audioUrl.hashCode ^
        audioPath.hashCode ^
        type.hashCode;
  }

  @override
  String toString() {
    return 'AnswerOption(text: $text, imageUrl: $imageUrl, imagePath: $imagePath, audioUrl: $audioUrl, audioPath: $audioPath, type: $type)';
  }
}