class Chapter {
  final String id;
  final String title;
  final String? description;
  final String? pdfUrl;
  final String? pdfPath;
  final String? audioUrl;
  final String? audioPath;
  final int order;
  final String? duration;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Chapter({
    required this.id,
    required this.title,
    this.description,
    this.pdfUrl,
    this.pdfPath,
    this.audioUrl,
    this.audioPath,
    required this.order,
    this.duration,
    this.createdAt,
    this.updatedAt,
  });

  Chapter copyWith({
    String? id,
    String? title,
    String? description,
    String? pdfUrl,
    String? pdfPath,
    String? audioUrl,
    String? audioPath,
    int? order,
    String? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfPath: pdfPath ?? this.pdfPath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioPath: audioPath ?? this.audioPath,
      order: order ?? this.order,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasAudio => (audioUrl != null && audioUrl!.isNotEmpty) || 
                      (audioPath != null && audioPath!.isNotEmpty);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Chapter && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  factory Chapter.fromJson(Map<String, dynamic> json) {
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

    return Chapter(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      pdfPath: json['pdfPath'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioPath: json['audioPath'] as String?,
      order: json['order'] as int,
      duration: json['duration'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'pdfUrl': pdfUrl,
      'pdfPath': pdfPath,
      'audioUrl': audioUrl,
      'audioPath': audioPath,
      'order': order,
      'duration': duration,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}