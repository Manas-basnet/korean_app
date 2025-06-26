import 'dart:io';

class ChapterUploadData {
  final String title;
  final String? description;
  final String? duration;
  final File pdfFile;
  final int order;

  const ChapterUploadData({
    required this.title,
    this.description,
    this.duration,
    required this.pdfFile,
    required this.order,
  });

  ChapterUploadData copyWith({
    String? title,
    String? description,
    String? duration,
    File? pdfFile,
    int? order,
  }) {
    return ChapterUploadData(
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      pdfFile: pdfFile ?? this.pdfFile,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ChapterUploadData &&
           other.title == title &&
           other.order == order &&
           other.pdfFile.path == pdfFile.path;
  }

  @override
  int get hashCode => title.hashCode ^ order.hashCode ^ pdfFile.path.hashCode;
}