import 'package:equatable/equatable.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';

class TestQuestion extends Equatable {
  final String id;
  final String question;
  final String? questionImageUrl;
  final String? questionImagePath;
  final String? questionAudioUrl;
  final String? questionAudioPath;
  final QuestionType questionType;
  final List<AnswerOption> options;
  final int correctAnswerIndex;
  final String? explanation;
  final int timeLimit;
  final Map<String, dynamic>? metadata;

  const TestQuestion({
    required this.id,
    required this.question,
    this.questionImageUrl,
    this.questionImagePath,
    this.questionAudioUrl,
    this.questionAudioPath,
    this.questionType = QuestionType.text,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
    this.timeLimit = 0,
    this.metadata,
  });

  TestQuestion copyWith({
    String? id,
    String? question,
    String? questionImageUrl,
    String? questionImagePath,
    String? questionAudioUrl,
    String? questionAudioPath,
    QuestionType? questionType,
    List<AnswerOption>? options,
    int? correctAnswerIndex,
    String? explanation,
    int? timeLimit,
    Map<String, dynamic>? metadata,
  }) {
    return TestQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      questionImageUrl: questionImageUrl ?? this.questionImageUrl,
      questionImagePath: questionImagePath ?? this.questionImagePath,
      questionAudioUrl: questionAudioUrl ?? this.questionAudioUrl,
      questionAudioPath: questionAudioPath ?? this.questionAudioPath,
      questionType: questionType ?? this.questionType,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
      timeLimit: timeLimit ?? this.timeLimit,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasQuestionImage => questionImageUrl != null && questionImageUrl!.isNotEmpty;
  bool get hasQuestionAudio => questionAudioUrl != null && questionAudioUrl!.isNotEmpty;
  bool get hasImageAnswers => options.any((option) => option.isImage);
  bool get hasAudioAnswers => options.any((option) => option.isAudio);
  
  List<String> get textOptions => options.map((option) => option.text).toList();

  factory TestQuestion.fromJson(Map<String, dynamic> json) {
    QuestionType questionType = QuestionType.text;
    if (json['questionType'] is String) {
      questionType = QuestionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['questionType'],
        orElse: () => QuestionType.text,
      );
    }

    List<AnswerOption> options = [];
    if (json['options'] is List) {
      final optionsList = json['options'] as List;
      
      if (optionsList.isNotEmpty) {
        if (optionsList.first is String) {
          options = optionsList.map((option) => AnswerOption(
            text: option as String,
            type: AnswerOptionType.text,
          )).toList();
        } else {
          options = optionsList
              .map((option) => AnswerOption.fromJson(option as Map<String, dynamic>))
              .toList();
        }
      }
    }

    return TestQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      questionImageUrl: json['questionImageUrl'] as String?,
      questionImagePath: json['questionImagePath'] as String?,
      questionAudioUrl: json['questionAudioUrl'] as String?,
      questionAudioPath: json['questionAudioPath'] as String?,
      questionType: questionType,
      options: options,
      correctAnswerIndex: json['correctAnswerIndex'] as int,
      explanation: json['explanation'] as String?,
      timeLimit: json['timeLimit'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'questionImageUrl': questionImageUrl,
      'questionImagePath': questionImagePath,
      'questionAudioUrl': questionAudioUrl,
      'questionAudioPath': questionAudioPath,
      'questionType': questionType.toString().split('.').last,
      'options': options.map((option) => option.toJson()).toList(),
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'timeLimit': timeLimit,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        question,
        questionImageUrl,
        questionImagePath,
        questionAudioUrl,
        questionAudioPath,
        questionType,
        options,
        correctAnswerIndex,
        explanation,
        timeLimit,
        metadata,
      ];
}