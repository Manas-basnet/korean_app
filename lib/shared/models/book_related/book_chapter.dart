import 'package:equatable/equatable.dart';
import 'audio_track.dart';

class BookChapter extends Equatable {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? imagePath;
  final String? pdfUrl;
  final String? pdfPath;
  final List<AudioTrack> audioTracks;
  final int order;
  final int duration; // in seconds (total of all audio tracks)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const BookChapter({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imagePath,
    this.pdfUrl,
    this.pdfPath,
    this.audioTracks = const [],
    this.order = 0,
    this.duration = 0,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  BookChapter copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? imagePath,
    String? pdfUrl,
    String? pdfPath,
    List<AudioTrack>? audioTracks,
    int? order,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return BookChapter(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfPath: pdfPath ?? this.pdfPath,
      audioTracks: audioTracks ?? this.audioTracks,
      order: order ?? this.order,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;
  bool get hasAudioTracks => audioTracks.isNotEmpty;
  int get audioTrackCount => audioTracks.length;
  String get formattedDuration => _formatDuration(Duration(seconds: duration));

  int get totalAudioDuration {
    return audioTracks.fold(0, (sum, track) => sum + track.duration);
  }

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

  factory BookChapter.fromJson(Map<String, dynamic> json) {
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

    List<AudioTrack> audioTracks = [];
    if (json['audioTracks'] is List) {
      audioTracks = (json['audioTracks'] as List)
          .map((track) => AudioTrack.fromJson(track as Map<String, dynamic>))
          .toList();
    }

    return BookChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      pdfPath: json['pdfPath'] as String?,
      audioTracks: audioTracks,
      order: json['order'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
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
      'pdfUrl': pdfUrl,
      'pdfPath': pdfPath,
      'audioTracks': audioTracks.map((track) => track.toJson()).toList(),
      'order': order,
      'duration': duration,
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
        pdfUrl,
        pdfPath,
        audioTracks,
        order,
        duration,
        createdAt,
        updatedAt,
        metadata,
      ];
}