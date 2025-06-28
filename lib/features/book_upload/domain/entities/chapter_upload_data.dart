import 'dart:io';

class ChapterUploadData {
  final String title;
  final String? description;
  final String? duration;
  final File? pdfFile;
  final File? audioFile;
  final int order;
  final bool isNewOrModified;
  final String? existingId;

  const ChapterUploadData({
    required this.title,
    this.description,
    this.duration,
    this.pdfFile,
    this.audioFile,
    required this.order,
    this.isNewOrModified = true,
    this.existingId,
  });

  ChapterUploadData copyWith({
    String? title,
    String? description,
    String? duration,
    File? pdfFile,
    File? audioFile,
    int? order,
    bool? isNewOrModified,
    String? existingId,
  }) {
    return ChapterUploadData(
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      pdfFile: pdfFile ?? this.pdfFile,
      audioFile: audioFile ?? this.audioFile,
      order: order ?? this.order,
      isNewOrModified: isNewOrModified ?? this.isNewOrModified,
      existingId: existingId ?? this.existingId,
    );
  }

  bool get hasAudio => audioFile != null && audioFile!.existsSync();

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