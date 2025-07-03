import 'package:equatable/equatable.dart';

class AudioTrack extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? audioUrl;
  final String? audioPath;
  final int duration; // in seconds
  final int order;
  final Map<String, dynamic>? metadata;

  const AudioTrack({
    required this.id,
    required this.title,
    this.description,
    this.audioUrl,
    this.audioPath,
    this.duration = 0,
    this.order = 0,
    this.metadata,
  });

  AudioTrack copyWith({
    String? id,
    String? title,
    String? description,
    String? audioUrl,
    String? audioPath,
    int? duration,
    int? order,
    Map<String, dynamic>? metadata,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      audioPath: audioPath ?? this.audioPath,
      duration: duration ?? this.duration,
      order: order ?? this.order,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  String get formattedDuration => _formatDuration(Duration(seconds: duration));

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

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioPath: json['audioPath'] as String?,
      duration: json['duration'] as int? ?? 0,
      order: json['order'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'audioPath': audioPath,
      'duration': duration,
      'order': order,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        audioUrl,
        audioPath,
        duration,
        order,
        metadata,
      ];
}