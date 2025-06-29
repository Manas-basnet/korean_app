import 'package:equatable/equatable.dart';

class AudioTrack extends Equatable {
  final String id;
  final String name;
  final String? audioUrl;
  final String? audioPath;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AudioTrack({
    required this.id,
    required this.name,
    this.audioUrl,
    this.audioPath,
    required this.order,
    this.createdAt,
    this.updatedAt,
  });

  AudioTrack copyWith({
    String? id,
    String? name,
    String? audioUrl,
    String? audioPath,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      audioUrl: audioUrl ?? this.audioUrl,
      audioPath: audioPath ?? this.audioPath,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasAudio => (audioUrl != null && audioUrl!.isNotEmpty) || 
                      (audioPath != null && audioPath!.isNotEmpty);

  @override
  List<Object?> get props => [id, name, audioUrl, audioPath, order, createdAt, updatedAt];

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
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

    return AudioTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      audioUrl: json['audioUrl'] as String?,
      audioPath: json['audioPath'] as String?,
      order: json['order'] as int? ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'audioUrl': audioUrl,
      'audioPath': audioPath,
      'order': order,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}