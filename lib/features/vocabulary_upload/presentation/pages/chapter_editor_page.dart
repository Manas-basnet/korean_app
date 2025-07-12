import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/pages/word_editor_page.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class ChapterEditorPage extends StatefulWidget {
  final VocabularyChapter? chapter;
  final Function(VocabularyChapter) onSave;
  final LanguagePreferenceCubit languageCubit;
  final SnackBarCubit snackBarCubit;

  const ChapterEditorPage({
    super.key,
    this.chapter,
    required this.onSave,
    required this.languageCubit,
    required this.snackBarCubit,
  });

  @override
  State<ChapterEditorPage> createState() => _ChapterEditorPageState();
}

class _ChapterEditorPageState extends State<ChapterEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _selectedImage;
  String? _existingImageUrl;
  String? _existingImagePath;
  List<VocabularyWord> _words = [];
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.chapter != null) {
      _populateFields(widget.chapter!);
    }
  }

  void _populateFields(VocabularyChapter chapter) {
    _titleController.text = chapter.title;
    _descriptionController.text = chapter.description;
    _existingImageUrl = chapter.imageUrl;
    _existingImagePath = chapter.imagePath;
    _words = List.from(chapter.words);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
          widget.chapter != null 
              ? widget.languageCubit.getLocalizedText(korean: '단원 수정', english: 'Edit Chapter')
              : widget.languageCubit.getLocalizedText(korean: '새 단원 만들기', english: 'Create Chapter'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saveChapter,
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 32),
              _buildImageSection(),
              const SizedBox(height: 32),
              _buildWordsSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(
            korean: '단원 정보',
            english: 'Chapter Information',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '단원 제목',
              english: 'Chapter Title',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '예: 인사말',
              english: 'e.g. Greetings',
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return widget.languageCubit.getLocalizedText(
                korean: '제목을 입력해주세요',
                english: 'Please enter a title',
              );
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '설명',
              english: 'Description',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '단원에 대한 설명을 입력하세요',
              english: 'Enter chapter description',
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return widget.languageCubit.getLocalizedText(
                korean: '설명을 입력해주세요',
                english: 'Please enter a description',
              );
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(
            korean: '단원 이미지 (선택사항)',
            english: 'Chapter Image (Optional)',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_selectedImage != null)
          _buildNewImageDisplay()
        else if (_hasExistingImage())
          _buildExistingImageDisplay()
        else
          _buildImagePlaceholder(),
      ],
    );
  }

  Widget _buildNewImageDisplay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => DialogUtils.showFullScreenImage(context, null, _selectedImage!.path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImage!,
              height: 200,
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
            onTap: () => setState(() => _selectedImage = null),
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

  Widget _buildExistingImageDisplay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => DialogUtils.showFullScreenImage(
            context, 
            _existingImageUrl, 
            _existingImagePath,
            heroTag: _existingImagePath ?? _existingImageUrl ?? '',
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Hero(
              tag: _existingImagePath ?? _existingImageUrl ?? '',
              child: CustomCachedImage(
                imageUrl: _existingImageUrl,
                imagePath: _existingImagePath,
                height: 200,
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
              _buildImageAction(
                icon: Icons.edit, 
                onTap: _pickImage,
              ),
              const SizedBox(width: 8),
              _buildImageAction(
                icon: Icons.close, 
                onTap: () => setState(() {
                  _existingImageUrl = null;
                  _existingImagePath = null;
                }),
              ),
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

  Widget _buildImagePlaceholder() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
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
              widget.languageCubit.getLocalizedText(
                korean: '이미지 추가',
                english: 'Add Image',
              ),
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

  Widget _buildWordsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.languageCubit.getLocalizedText(
                korean: '단어',
                english: 'Words',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _words.isEmpty 
                    ? colorScheme.errorContainer.withValues(alpha : 0.3)
                    : colorScheme.primaryContainer.withValues(alpha : 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_words.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _words.isEmpty 
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_words.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha : 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.translate_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha : 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.languageCubit.getLocalizedText(
                    korean: '아직 단어가 없습니다',
                    english: 'No words yet',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.languageCubit.getLocalizedText(
                    korean: '첫 번째 단어를 추가해보세요',
                    english: 'Add your first word to get started',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha : 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _addWord,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    widget.languageCubit.getLocalizedText(
                      korean: '첫 번째 단어 추가',
                      english: 'Add First Word',
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...List.generate(_words.length, (index) {
            final word = _words[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word.isNotEmpty 
                              ? word.word 
                              : widget.languageCubit.getLocalizedText(korean: '단어 없음', english: 'No word'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${word.meaningCount} ${widget.languageCubit.getLocalizedText(korean: '의미', english: 'meanings')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (word.hasExamples) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• ${word.exampleCount} ${widget.languageCubit.getLocalizedText(korean: '예문', english: 'examples')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            ..._buildWordBadges(word),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                    onPressed: () => _editWord(index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    onPressed: () => _deleteWord(index),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addWord,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                widget.languageCubit.getLocalizedText(
                  korean: '단어 추가',
                  english: 'Add Word',
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildWordBadges(VocabularyWord word) {
    final theme = Theme.of(context);
    final badges = <Widget>[];
    
    if (word.hasImage) {
      badges.add(const SizedBox(width: 8));
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha : 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'IMG',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.blue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }
    
    if (word.hasAudio) {
      badges.add(const SizedBox(width: 8));
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha : 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'AUD',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }
    
    return badges;
  }

  bool _hasExistingImage() {
    return (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) ||
           (_existingImagePath != null && _existingImagePath!.isNotEmpty);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _existingImageUrl = null;
        _existingImagePath = null;
      });
    }
  }

  void _addWord() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordEditorPage(
          onSave: (newWord) {
            setState(() {
              _words.add(newWord);
            });
          },
          languageCubit: widget.languageCubit,
          snackBarCubit: widget.snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _editWord(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordEditorPage(
          word: _words[index],
          onSave: (updatedWord) {
            setState(() {
              _words[index] = updatedWord;
            });
          },
          languageCubit: widget.languageCubit,
          snackBarCubit: widget.snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _deleteWord(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.languageCubit.getLocalizedText(
            korean: '단어 삭제',
            english: 'Delete Word',
          ),
        ),
        content: Text(
          widget.languageCubit.getLocalizedText(
            korean: '이 단어를 삭제하시겠습니까?',
            english: 'Are you sure you want to delete this word?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _words.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(
              widget.languageCubit.getLocalizedText(
                korean: '삭제',
                english: 'Delete',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveChapter() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final chapterId = widget.chapter?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final newChapter = VocabularyChapter(
      id: chapterId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      words: _words,
      order: widget.chapter?.order ?? 0,
      createdAt: widget.chapter?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      imageUrl: _selectedImage != null ? null : _existingImageUrl,
      imagePath: _selectedImage?.path ?? _existingImagePath,
    );

    widget.onSave(newChapter);
    Navigator.pop(context);
  }
}