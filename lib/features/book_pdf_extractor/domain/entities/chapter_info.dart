import 'package:equatable/equatable.dart';

class ChapterInfo extends Equatable {
  final int chapterNumber;
  final String title;
  final String? description;
  final List<int> pageNumbers;
  final String? duration;

  const ChapterInfo({
    required this.chapterNumber,
    required this.title,
    this.description,
    required this.pageNumbers,
    this.duration,
  });

  ChapterInfo copyWith({
    int? chapterNumber,
    String? title,
    String? description,
    List<int>? pageNumbers,
    String? duration,
  }) {
    return ChapterInfo(
      chapterNumber: chapterNumber ?? this.chapterNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      pageNumbers: pageNumbers ?? this.pageNumbers,
      duration: duration ?? this.duration,
    );
  }

  int get pageCount => pageNumbers.length;

  @override
  List<Object?> get props => [chapterNumber, title, description, pageNumbers, duration];
}