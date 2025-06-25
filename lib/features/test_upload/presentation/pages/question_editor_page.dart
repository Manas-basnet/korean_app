import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/models/test_question.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/shared/widgets/audio_recorder.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class QuestionEditorPage extends StatefulWidget {
  final TestQuestion? question;
  final Function(TestQuestion) onSave;
  final LanguagePreferenceCubit languageCubit;
  final SnackBarCubit snackBarCubit;

  const QuestionEditorPage({
    super.key, 
    this.question,
    required this.onSave,
    required this.languageCubit,
    required this.snackBarCubit,
  });

  @override
  State<QuestionEditorPage> createState() => _QuestionEditorPageState();
}

class _QuestionEditorPageState extends State<QuestionEditorPage> {
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _optionControllers = List.generate(4, (i) => TextEditingController());
  
  int _correctAnswer = 0;
  File? _questionImage;
  File? _questionAudio;
  final List<File?> _answerImages = List.generate(4, (i) => null);
  final List<File?> _answerAudios = List.generate(4, (i) => null);
  final List<AnswerOption> _options = [];
  QuestionType _questionType = QuestionType.text;
  
  String? _existingQuestionImageUrl;
  String? _existingQuestionImagePath;
  String? _existingQuestionAudioUrl;
  String? _existingQuestionAudioPath;
  final List<String?> _existingAnswerImageUrls = List.generate(4, (i) => null);
  final List<String?> _existingAnswerImagePaths = List.generate(4, (i) => null);
  final List<String?> _existingAnswerAudioUrls = List.generate(4, (i) => null);
  final List<String?> _existingAnswerAudioPaths = List.generate(4, (i) => null);
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _populateFields(widget.question!);
    } else {
      _initializeEmptyOptions();
    }
  }

  void _populateFields(TestQuestion question) {
    _questionController.text = question.question;
    _explanationController.text = question.explanation ?? '';
    _correctAnswer = question.correctAnswerIndex;
    _questionType = question.questionType;
    
    _existingQuestionImageUrl = question.questionImageUrl;
    _existingQuestionImagePath = question.questionImagePath;
    _existingQuestionAudioUrl = question.questionAudioUrl;
    _existingQuestionAudioPath = question.questionAudioPath;
    
    for (int i = 0; i < question.options.length && i < 4; i++) {
      final option = question.options[i];
      _optionControllers[i].text = option.text;
      _options.add(option);
      
      _existingAnswerImageUrls[i] = option.imageUrl;
      _existingAnswerImagePaths[i] = option.imagePath;
      _existingAnswerAudioUrls[i] = option.audioUrl;
      _existingAnswerAudioPaths[i] = option.audioPath;
    }
    
    while (_options.length < 4) {
      _options.add(const AnswerOption(text: '', type: AnswerOptionType.text));
    }
  }

  void _initializeEmptyOptions() {
    for (int i = 0; i < 4; i++) {
      _options.add(const AnswerOption(text: '', type: AnswerOptionType.text));
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          widget.question != null 
              ? widget.languageCubit.getLocalizedText(korean: '문제 수정', english: 'Edit Question')
              : widget.languageCubit.getLocalizedText(korean: '새 문제 만들기', english: 'Create Question'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saveQuestion,
              style: TextButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                widget.languageCubit.getLocalizedText(korean: '저장', english: 'Save'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuestionSection(),
            const SizedBox(height: 32),
            _buildOptionsSection(),
            const SizedBox(height: 32),
            _buildExplanationSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(korean: '문제', english: 'Question'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Text(
              widget.languageCubit.getLocalizedText(korean: '형태:', english: 'Type:'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ToggleButtons(
                isSelected: [
                  _questionType == QuestionType.text,
                  _questionType == QuestionType.image,
                  _questionType == QuestionType.audio,
                ],
                onPressed: (index) {
                  setState(() {
                    switch (index) {
                      case 0:
                        _questionType = QuestionType.text;
                        _questionImage = null;
                        _questionAudio = null;
                        break;
                      case 1:
                        _questionType = QuestionType.image;
                        _questionAudio = null;
                        break;
                      case 2:
                        _questionType = QuestionType.audio;
                        _questionImage = null;
                        break;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: colorScheme.onPrimary,
                fillColor: colorScheme.primary,
                color: colorScheme.onSurfaceVariant,
                constraints: const BoxConstraints(minHeight: 40, minWidth: 60),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.text_fields, size: 16),
                        const SizedBox(width: 6),
                        Text(widget.languageCubit.getLocalizedText(korean: '텍스트', english: 'Text')),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image, size: 16),
                        const SizedBox(width: 6),
                        Text(widget.languageCubit.getLocalizedText(korean: '이미지', english: 'Image')),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.audiotrack, size: 16),
                        const SizedBox(width: 6),
                        Text(widget.languageCubit.getLocalizedText(korean: '오디오', english: 'Audio')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        if (_questionType == QuestionType.image) ...[
          _buildQuestionImageDisplay(),
          const SizedBox(height: 16),
        ] else if (_questionType == QuestionType.audio) ...[
          _buildQuestionAudioDisplay(),
          const SizedBox(height: 16),
        ],
        
        TextField(
          controller: _questionController,
          decoration: InputDecoration(
            labelText: _questionType != QuestionType.text
                ? widget.languageCubit.getLocalizedText(korean: '문제 설명 (선택사항)', english: 'Question Description (Optional)')
                : widget.languageCubit.getLocalizedText(korean: '문제 내용', english: 'Question Content'),
            hintText: _questionType != QuestionType.text
                ? widget.languageCubit.getLocalizedText(korean: '추가 설명', english: 'Additional description')
                : widget.languageCubit.getLocalizedText(korean: '문제를 입력하세요', english: 'Enter your question'),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildQuestionImageDisplay() {
    if (_questionImage != null) {
      return _buildNewImageDisplay(
        image: _questionImage!,
        onRemove: () => setState(() => _questionImage = null),
      );
    } else if (_hasExistingQuestionImage()) {
      return _buildExistingImageDisplay(
        imageUrl: _existingQuestionImageUrl,
        imagePath: _existingQuestionImagePath,
        onEdit: _pickQuestionImage,
        onRemove: () => setState(() {
          _existingQuestionImageUrl = null;
          _existingQuestionImagePath = null;
        }),
      );
    } else {
      return _buildImagePlaceholder(
        onTap: _pickQuestionImage,
        label: widget.languageCubit.getLocalizedText(
          korean: '문제 이미지 선택',
          english: 'Select Question Image',
        ),
      );
    }
  }

  Widget _buildQuestionAudioDisplay() {
    if (_questionAudio != null) {
      return AudioPlayerWidget(
        audioPath: _questionAudio!.path,
        label: widget.languageCubit.getLocalizedText(korean: '새 오디오', english: 'New Audio'),
        onRemove: () => setState(() => _questionAudio = null),
        onEdit: () => _showAudioRecorderDialog(isQuestion: true),
      );
    } else if (_hasExistingQuestionAudio()) {
      return AudioPlayerWidget(
        audioUrl: _existingQuestionAudioUrl,
        audioPath: _existingQuestionAudioPath,
        label: widget.languageCubit.getLocalizedText(korean: '기존 오디오', english: 'Existing Audio'),
        onRemove: () => setState(() {
          _existingQuestionAudioUrl = null;
          _existingQuestionAudioPath = null;
        }),
        onEdit: () => _showAudioRecorderDialog(isQuestion: true),
      );
    } else {
      return AudioRecorderWidget(
        onAudioSelected: (audioFile) {
          setState(() {
            _questionAudio = audioFile;
            _existingQuestionAudioUrl = null;
            _existingQuestionAudioPath = null;
          });
        },
        label: widget.languageCubit.getLocalizedText(
          korean: '문제 오디오 선택',
          english: 'Select Question Audio',
        ),
      );
    }
  }

  Widget _buildOptionsSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(korean: '선택지', english: 'Answer Options'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        ...List.generate(4, (index) => _buildOptionTile(index)),
      ],
    );
  }

  Widget _buildOptionTile(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCorrect = _correctAnswer == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect 
            ? colorScheme.primaryContainer.withValues(alpha : 0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect 
              ? colorScheme.primary.withValues(alpha : 0.5)
              : colorScheme.outlineVariant,
          width: isCorrect ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _correctAnswer = index;
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCorrect ? colorScheme.primary : colorScheme.outline,
                      width: 2,
                    ),
                    color: isCorrect ? colorScheme.primary : Colors.transparent,
                  ),
                  child: isCorrect
                      ? Icon(Icons.check, size: 12, color: colorScheme.onPrimary)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                String.fromCharCode(65 + index),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? colorScheme.primary : null,
                ),
              ),
              if (isCorrect) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.languageCubit.getLocalizedText(korean: '정답', english: 'Correct'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              ToggleButtons(
                isSelected: [
                  _options[index].type == AnswerOptionType.text,
                  _options[index].type == AnswerOptionType.image,
                  _options[index].type == AnswerOptionType.audio,
                ],
                onPressed: (toggleIndex) {
                  setState(() {
                    switch (toggleIndex) {
                      case 0:
                        _setOptionAsText(index);
                        break;
                      case 1:
                        _setOptionAsImage(index);
                        break;
                      case 2:
                        _setOptionAsAudio(index);
                        break;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(6),
                selectedColor: colorScheme.onPrimary,
                fillColor: colorScheme.primary,
                color: colorScheme.onSurfaceVariant,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 50),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.text_fields, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          widget.languageCubit.getLocalizedText(korean: '텍스트', english: 'Text'),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          widget.languageCubit.getLocalizedText(korean: '이미지', english: 'Image'),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.audiotrack, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          widget.languageCubit.getLocalizedText(korean: '오디오', english: 'Audio'),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (_options[index].type == AnswerOptionType.image) ...[
            _buildAnswerImageDisplay(index),
          ] else if (_options[index].type == AnswerOptionType.audio) ...[
            _buildAnswerAudioDisplay(index),
          ] else ...[
            TextField(
              controller: _optionControllers[index],
              decoration: InputDecoration(
                hintText: widget.languageCubit.getLocalizedText(
                  korean: '선택지 텍스트를 입력하세요',
                  english: 'Enter option text',
                ),
                isDense: true,
              ),
              onChanged: (value) {
                _options[index] = _options[index].copyWith(text: value);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerImageDisplay(int index) {
    if (_answerImages[index] != null) {
      return _buildNewImageDisplay(
        image: _answerImages[index]!,
        onRemove: () => setState(() => _answerImages[index] = null),
        height: 100,
      );
    } else if (_hasExistingAnswerImage(index)) {
      return _buildExistingImageDisplay(
        imageUrl: _existingAnswerImageUrls[index],
        imagePath: _existingAnswerImagePaths[index],
        onEdit: () => _pickAnswerImage(index),
        onRemove: () => setState(() {
          _existingAnswerImageUrls[index] = null;
          _existingAnswerImagePaths[index] = null;
        }),
        height: 100,
      );
    } else {
      return _buildImagePlaceholder(
        onTap: () => _pickAnswerImage(index),
        label: widget.languageCubit.getLocalizedText(
          korean: '이미지 선택',
          english: 'Select Image',
        ),
        height: 100,
      );
    }
  }

  Widget _buildAnswerAudioDisplay(int index) {
    if (_answerAudios[index] != null) {
      return AudioPlayerWidget(
        audioPath: _answerAudios[index]!.path,
        label: widget.languageCubit.getLocalizedText(korean: '새 오디오', english: 'New Audio'),
        height: 50,
        onRemove: () => setState(() => _answerAudios[index] = null),
        onEdit: () => _showAudioRecorderDialog(answerIndex: index),
      );
    } else if (_hasExistingAnswerAudio(index)) {
      return AudioPlayerWidget(
        audioUrl: _existingAnswerAudioUrls[index],
        audioPath: _existingAnswerAudioPaths[index],
        label: widget.languageCubit.getLocalizedText(korean: '기존 오디오', english: 'Existing Audio'),
        height: 50,
        onRemove: () => setState(() {
          _existingAnswerAudioUrls[index] = null;
          _existingAnswerAudioPaths[index] = null;
        }),
        onEdit: () => _showAudioRecorderDialog(answerIndex: index),
      );
    } else {
      return AudioRecorderWidget(
        onAudioSelected: (audioFile) {
          setState(() {
            _answerAudios[index] = audioFile;
            _existingAnswerAudioUrls[index] = null;
            _existingAnswerAudioPaths[index] = null;
          });
        },
        label: widget.languageCubit.getLocalizedText(
          korean: '오디오 선택',
          english: 'Select Audio',
        ),
      );
    }
  }

  Widget _buildExplanationSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(korean: '설명 (선택사항)', english: 'Explanation (Optional)'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _explanationController,
          decoration: InputDecoration(
            hintText: widget.languageCubit.getLocalizedText(
              korean: '정답에 대한 설명을 입력하세요',
              english: 'Enter explanation for the correct answer',
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildNewImageDisplay({
    required File image,
    required VoidCallback onRemove,
    double? height,
  }) {
    return Stack(
      children: [
      GestureDetector(
        onTap: () => DialogUtils.showFullScreenImage(context, null, image.path),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            image,
            height: height ?? 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
        Positioned(
          top: 8,
          right: 8,
          child: _buildImageAction(
            icon: Icons.close,
            onTap: onRemove,
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: _buildImageLabel(
            widget.languageCubit.getLocalizedText(korean: '새 이미지', english: 'New Image'),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingImageDisplay({
    required String? imageUrl,
    required String? imagePath,
    required VoidCallback onEdit,
    required VoidCallback onRemove,
    double? height,
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => DialogUtils.showFullScreenImage(context, imageUrl, imagePath, heroTag: imagePath ?? imageUrl ?? ''),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Hero(
              tag: imagePath ?? imageUrl ?? '',
              child: CustomCachedImage(
                imageUrl: imageUrl,
                imagePath: imagePath,
                height: height ?? 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageAction(icon: Icons.edit, onTap: onEdit),
              const SizedBox(width: 8),
              _buildImageAction(icon: Icons.close, onTap: onRemove),
            ],
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: _buildImageLabel(
            widget.languageCubit.getLocalizedText(korean: '기존 이미지', english: 'Existing Image'),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder({
    required VoidCallback onTap,
    required String label,
    double? height,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha : 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha : 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildImageLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  bool _hasExistingQuestionImage() {
    return (_existingQuestionImageUrl != null && _existingQuestionImageUrl!.isNotEmpty) ||
           (_existingQuestionImagePath != null && _existingQuestionImagePath!.isNotEmpty);
  }

  bool _hasExistingQuestionAudio() {
    return (_existingQuestionAudioUrl != null && _existingQuestionAudioUrl!.isNotEmpty) ||
           (_existingQuestionAudioPath != null && _existingQuestionAudioPath!.isNotEmpty);
  }

  bool _hasExistingAnswerImage(int index) {
    return (_existingAnswerImageUrls[index] != null && _existingAnswerImageUrls[index]!.isNotEmpty) ||
           (_existingAnswerImagePaths[index] != null && _existingAnswerImagePaths[index]!.isNotEmpty);
  }

  bool _hasExistingAnswerAudio(int index) {
    return (_existingAnswerAudioUrls[index] != null && _existingAnswerAudioUrls[index]!.isNotEmpty) ||
           (_existingAnswerAudioPaths[index] != null && _existingAnswerAudioPaths[index]!.isNotEmpty);
  }

  void _setOptionAsText(int index) {
    setState(() {
      _options[index] = _options[index].copyWith(type: AnswerOptionType.text);
      _answerImages[index] = null;
      _answerAudios[index] = null;
    });
  }

  void _setOptionAsImage(int index) {
    setState(() {
      _options[index] = _options[index].copyWith(type: AnswerOptionType.image, text: '');
      _optionControllers[index].clear();
      _answerAudios[index] = null;
    });
  }

  void _setOptionAsAudio(int index) {
    setState(() {
      _options[index] = _options[index].copyWith(type: AnswerOptionType.audio, text: '');
      _optionControllers[index].clear();
      _answerImages[index] = null;
    });
  }

  Future<void> _pickQuestionImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _questionImage = File(image.path);
        _existingQuestionImageUrl = null;
        _existingQuestionImagePath = null;
      });
    }
  }

  Future<void> _pickAnswerImage(int index) async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _answerImages[index] = File(image.path);
        _existingAnswerImageUrls[index] = null;
        _existingAnswerImagePaths[index] = null;
      });
    }
  }

  void _showAudioRecorderDialog({bool isQuestion = false, int? answerIndex}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: AudioRecorderWidget(
            onAudioSelected: (audioFile) {
              setState(() {
                if (isQuestion) {
                  _questionAudio = audioFile;
                  _existingQuestionAudioUrl = null;
                  _existingQuestionAudioPath = null;
                } else if (answerIndex != null) {
                  _answerAudios[answerIndex] = audioFile;
                  _existingAnswerAudioUrls[answerIndex] = null;
                  _existingAnswerAudioPaths[answerIndex] = null;
                }
              });
              Navigator.pop(context);
            },
            label: isQuestion 
                ? widget.languageCubit.getLocalizedText(korean: '문제 오디오', english: 'Question Audio')
                : widget.languageCubit.getLocalizedText(korean: '답 오디오', english: 'Answer Audio'),
          ),
        ),
      ),
    );
  }

  void _saveQuestion() {
    if (_questionType == QuestionType.text && _questionController.text.trim().isEmpty) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '문제를 입력해주세요',
        english: 'Please enter a question',
      );
      return;
    }
    
    if (_questionType == QuestionType.image && 
        _questionImage == null && 
        _existingQuestionImageUrl == null && 
        _existingQuestionImagePath == null) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '문제 이미지를 선택해주세요',
        english: 'Please select a question image',
      );
      return;
    }

    if (_questionType == QuestionType.audio && 
        _questionAudio == null && 
        _existingQuestionAudioUrl == null && 
        _existingQuestionAudioPath == null) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '문제 오디오를 선택해주세요',
        english: 'Please select a question audio',
      );
      return;
    }

    for (int i = 0; i < 4; i++) {
      if (_options[i].type == AnswerOptionType.image) {
        if (_answerImages[i] == null && 
            _existingAnswerImageUrls[i] == null && 
            _existingAnswerImagePaths[i] == null) {
          widget.snackBarCubit.showErrorLocalized(
            korean: '모든 이미지 선택지를 선택해주세요',
            english: 'Please select all image options',
          );
          return;
        }
      } else if (_options[i].type == AnswerOptionType.audio) {
        if (_answerAudios[i] == null && 
            _existingAnswerAudioUrls[i] == null && 
            _existingAnswerAudioPaths[i] == null) {
          widget.snackBarCubit.showErrorLocalized(
            korean: '모든 오디오 선택지를 선택해주세요',
            english: 'Please select all audio options',
          );
          return;
        }
      } else {
        if (_optionControllers[i].text.trim().isEmpty) {
          widget.snackBarCubit.showErrorLocalized(
            korean: '모든 텍스트 선택지를 입력해주세요',
            english: 'Please enter all text options',
          );
          return;
        }
      }
    }

    final updatedOptions = <AnswerOption>[];
    for (int i = 0; i < 4; i++) {
      if (_options[i].type == AnswerOptionType.image) {
        updatedOptions.add(AnswerOption(
          text: '',
          type: AnswerOptionType.image,
          imagePath: _answerImages[i]?.path ?? _existingAnswerImagePaths[i],
          imageUrl: _answerImages[i] != null ? null : _existingAnswerImageUrls[i],
        ));
      } else if (_options[i].type == AnswerOptionType.audio) {
        updatedOptions.add(AnswerOption(
          text: '',
          type: AnswerOptionType.audio,
          audioPath: _answerAudios[i]?.path ?? _existingAnswerAudioPaths[i],
          audioUrl: _answerAudios[i] != null ? null : _existingAnswerAudioUrls[i],
        ));
      } else {
        updatedOptions.add(AnswerOption(
          text: _optionControllers[i].text.trim(),
          type: AnswerOptionType.text,
        ));
      }
    }

    final newQuestion = TestQuestion(
      id: widget.question?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      question: _questionController.text.trim(),
      questionType: _questionType,
      questionImagePath: _questionImage?.path ?? _existingQuestionImagePath,
      questionImageUrl: _questionImage != null ? null : _existingQuestionImageUrl,
      questionAudioPath: _questionAudio?.path ?? _existingQuestionAudioPath,
      questionAudioUrl: _questionAudio != null ? null : _existingQuestionAudioUrl,
      options: updatedOptions,
      correctAnswerIndex: _correctAnswer,
      explanation: _explanationController.text.trim().isEmpty 
          ? null 
          : _explanationController.text.trim(),
    );

    widget.onSave(newQuestion);
    Navigator.pop(context);
  }
}