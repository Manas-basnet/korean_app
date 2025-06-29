import 'dart:io';

class AudioTrackUploadData {
  final String name;
  final File audioFile;
  final int order;

  const AudioTrackUploadData({
    required this.name,
    required this.audioFile,
    required this.order,
  });

  AudioTrackUploadData copyWith({
    String? name,
    File? audioFile,
    int? order,
  }) {
    return AudioTrackUploadData(
      name: name ?? this.name,
      audioFile: audioFile ?? this.audioFile,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AudioTrackUploadData &&
           other.name == name &&
           other.order == order;
  }

  @override
  int get hashCode => name.hashCode ^ order.hashCode;
}

class ChapterUploadData {
  final String title;
  final String? description;
  final String? duration;
  final File? pdfFile;
  final List<AudioTrackUploadData> audioTracks;
  final int order;
  final bool isNewOrModified;
  final String? existingId;

  const ChapterUploadData({
    required this.title,
    this.description,
    this.duration,
    this.pdfFile,
    this.audioTracks = const [],
    required this.order,
    this.isNewOrModified = true,
    this.existingId,
  });

  ChapterUploadData copyWith({
    String? title,
    String? description,
    String? duration,
    File? pdfFile,
    List<AudioTrackUploadData>? audioTracks,
    int? order,
    bool? isNewOrModified,
    String? existingId,
  }) {
    return ChapterUploadData(
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      pdfFile: pdfFile ?? this.pdfFile,
      audioTracks: audioTracks ?? this.audioTracks,
      order: order ?? this.order,
      isNewOrModified: isNewOrModified ?? this.isNewOrModified,
      existingId: existingId ?? this.existingId,
    );
  }

  bool get hasAudio => audioTracks.isNotEmpty;
  int get audioTrackCount => audioTracks.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ChapterUploadData &&
           other.title == title &&
           other.order == order &&
           other.existingId == existingId;
  }

  @override
  int get hashCode => title.hashCode ^ order.hashCode ^ (existingId?.hashCode ?? 0);
}