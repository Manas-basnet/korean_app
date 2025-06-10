import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korean_language_app/core/enums/question_type.dart';
import 'package:korean_language_app/core/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/core/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/core/shared/models/test_question.dart';
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
  final List<File?> _answerImages = List.generate(4, (i) => null);
  final List<AnswerOption> _options = [];
  bool _isQuestionImage = false;
  
  String? _existingQuestionImageUrl;
  String? _existingQuestionImagePath;
  final List<String?> _existingAnswerImageUrls = List.generate(4, (i) => null);
  final List<String?> _existingAnswerImagePaths = List.generate(4, (i) => null);
  
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
    _isQuestionImage = question.hasQuestionImage;
    
    _existingQuestionImageUrl = question.questionImageUrl;
    _existingQuestionImagePath = question.questionImagePath;
    
    for (int i = 0; i < question.options.length && i < 4; i++) {
      final option = question.options[i];
      _optionControllers[i].text = option.text;
      _options.add(option);
      
      _existingAnswerImageUrls[i] = option.imageUrl;
      _existingAnswerImagePaths[i] = option.imagePath;
    }
    
    while (_options.length < 4) {
      _options.add(const AnswerOption(text: '', isImage: false));
    }
  }

  void _initializeEmptyOptions() {
    for (int i = 0; i < 4; i++) {
      _options.add(const AnswerOption(text: '', isImage: false));
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
        
        // Question Type Toggle
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
                isSelected: [!_isQuestionImage, _isQuestionImage],
                onPressed: (index) {
                  setState(() {
                    _isQuestionImage = index == 1;
                    if (!_isQuestionImage) {
                      _questionImage = null;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: colorScheme.onPrimary,
                fillColor: colorScheme.primary,
                color: colorScheme.onSurfaceVariant,
                constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.text_fields, size: 18),
                        const SizedBox(width: 8),
                        Text(widget.languageCubit.getLocalizedText(korean: '텍스트', english: 'Text')),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image, size: 18),
                        const SizedBox(width: 8),
                        Text(widget.languageCubit.getLocalizedText(korean: '이미지', english: 'Image')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        if (_isQuestionImage) ...[
          _buildQuestionImageDisplay(),
          const SizedBox(height: 16),
        ],
        
        TextField(
          controller: _questionController,
          decoration: InputDecoration(
            labelText: _isQuestionImage
                ? widget.languageCubit.getLocalizedText(korean: '문제 설명 (선택사항)', english: 'Question Description (Optional)')
                : widget.languageCubit.getLocalizedText(korean: '문제 내용', english: 'Question Content'),
            hintText: _isQuestionImage
                ? widget.languageCubit.getLocalizedText(korean: '이미지에 대한 추가 설명', english: 'Additional description for the image')
                : widget.languageCubit.getLocalizedText(korean: '문제를 입력하세요', english: 'Enter your question'),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildQuestionImageDisplay() {
    // Determine what to show: new image, existing image, or placeholder
    if (_questionImage != null) {
      // Show new local image with remove option
      return _buildNewImageDisplay(
        image: _questionImage!,
        onRemove: () => setState(() => _questionImage = null),
      );
    } else if (_hasExistingQuestionImage()) {
      // Show existing image with edit/remove options
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
      // Show placeholder for new image selection
      return _buildImagePlaceholder(
        onTap: _pickQuestionImage,
        label: widget.languageCubit.getLocalizedText(
          korean: '문제 이미지 선택',
          english: 'Select Question Image',
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
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect 
              ? colorScheme.primary.withOpacity(0.5)
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
                isSelected: [!_options[index].isImage, _options[index].isImage],
                onPressed: (toggleIndex) {
                  if (toggleIndex == 0) {
                    _setOptionAsText(index);
                  } else {
                    _setOptionAsImage(index);
                  }
                },
                borderRadius: BorderRadius.circular(6),
                selectedColor: colorScheme.onPrimary,
                fillColor: colorScheme.primary,
                color: colorScheme.onSurfaceVariant,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.text_fields, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.languageCubit.getLocalizedText(korean: '텍스트', english: 'Text'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.languageCubit.getLocalizedText(korean: '이미지', english: 'Image'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (_options[index].isImage) ...[
            _buildAnswerImageDisplay(index),
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
      // Show new local image
      return _buildNewImageDisplay(
        image: _answerImages[index]!,
        onRemove: () => setState(() => _answerImages[index] = null),
        height: 100,
      );
    } else if (_hasExistingAnswerImage(index)) {
      // Show existing image
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
      // Show placeholder
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

  // Helper UI components for cleaner separation
  Widget _buildNewImageDisplay({
    required File image,
    required VoidCallback onRemove,
    double? height,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            image,
            height: height ?? 200,
            width: double.infinity,
            fit: BoxFit.cover,
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
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomCachedImage(
            imageUrl: imageUrl,
            imagePath: imagePath,
            height: height ?? 200,
            width: double.infinity,
            fit: BoxFit.cover,
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
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
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

  // Helper methods for cleaner business logic
  bool _hasExistingQuestionImage() {
    return (_existingQuestionImageUrl != null && _existingQuestionImageUrl!.isNotEmpty) ||
           (_existingQuestionImagePath != null && _existingQuestionImagePath!.isNotEmpty);
  }

  bool _hasExistingAnswerImage(int index) {
    return (_existingAnswerImageUrls[index] != null && _existingAnswerImageUrls[index]!.isNotEmpty) ||
           (_existingAnswerImagePaths[index] != null && _existingAnswerImagePaths[index]!.isNotEmpty);
  }

  void _setOptionAsText(int index) {
    setState(() {
      _options[index] = _options[index].copyWith(isImage: false);
      _answerImages[index] = null;
      // Don't clear existing image info when switching to text
    });
  }

  void _setOptionAsImage(int index) {
    setState(() {
      _options[index] = _options[index].copyWith(isImage: true, text: '');
      _optionControllers[index].clear();
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

  void _saveQuestion() {
    if (!_isQuestionImage && _questionController.text.trim().isEmpty) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '문제를 입력해주세요',
        english: 'Please enter a question',
      );
      return;
    }
    
    if (_isQuestionImage && 
        _questionImage == null && 
        _existingQuestionImageUrl == null && 
        _existingQuestionImagePath == null) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '문제 이미지를 선택해주세요',
        english: 'Please select a question image',
      );
      return;
    }

    for (int i = 0; i < 4; i++) {
      if (_options[i].isImage) {
        if (_answerImages[i] == null && 
            _existingAnswerImageUrls[i] == null && 
            _existingAnswerImagePaths[i] == null) {
          widget.snackBarCubit.showErrorLocalized(
            korean: '모든 이미지 선택지를 선택해주세요',
            english: 'Please select all image options',
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

    // Determine question type based on selections
    QuestionType questionType;
    final hasImageAnswers = _options.any((option) => option.isImage);
    final hasTextAnswers = _options.any((option) => !option.isImage);
    
    if (_isQuestionImage && hasImageAnswers && !hasTextAnswers) {
      questionType = QuestionType.imageQuestion_imageAnswers;
    } else if (_isQuestionImage && hasTextAnswers && !hasImageAnswers) {
      questionType = QuestionType.imageQuestion_textAnswers;
    } else if (!_isQuestionImage && hasImageAnswers && !hasTextAnswers) {
      questionType = QuestionType.textQuestion_imageAnswers;
    } else if (!_isQuestionImage && hasTextAnswers && hasImageAnswers) {
      questionType = QuestionType.textQuestion_mixedAnswers;
    } else {
      questionType = QuestionType.textQuestion_textAnswers;
    }

    // Create updated options
    final updatedOptions = <AnswerOption>[];
    for (int i = 0; i < 4; i++) {
      if (_options[i].isImage) {
        updatedOptions.add(AnswerOption(
          text: '',
          isImage: true,
          imagePath: _answerImages[i]?.path ?? _existingAnswerImagePaths[i],
          imageUrl: _answerImages[i] != null ? null : _existingAnswerImageUrls[i],
        ));
      } else {
        updatedOptions.add(AnswerOption(
          text: _optionControllers[i].text.trim(),
          isImage: false,
        ));
      }
    }

    final newQuestion = TestQuestion(
      id: widget.question?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      question: _questionController.text.trim(),
      questionImagePath: _questionImage?.path ?? _existingQuestionImagePath,
      questionImageUrl: _questionImage != null ? null : _existingQuestionImageUrl,
      options: updatedOptions,
      correctAnswerIndex: _correctAnswer,
      explanation: _explanationController.text.trim().isEmpty 
          ? null 
          : _explanationController.text.trim(),
      questionType: questionType,
    );

    widget.onSave(newQuestion);
    Navigator.pop(context);
  }
}