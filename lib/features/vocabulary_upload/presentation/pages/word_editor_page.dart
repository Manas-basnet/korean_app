import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_meaning.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_example.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/shared/widgets/audio_recorder.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/pages/meaning_editor_page.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/pages/example_editor_page.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class WordEditorPage extends StatefulWidget {
  final VocabularyWord? word;
  final Function(VocabularyWord) onSave;
  final LanguagePreferenceCubit languageCubit;
  final SnackBarCubit snackBarCubit;

  const WordEditorPage({
    super.key,
    this.word,
    required this.onSave,
    required this.languageCubit,
    required this.snackBarCubit,
  });

  @override
  State<WordEditorPage> createState() => _WordEditorPageState();
}

class _WordEditorPageState extends State<WordEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _pronunciationController = TextEditingController();
  
  File? _selectedImage;
  File? _selectedAudio;
  String? _existingImageUrl;
  String? _existingImagePath;
  String? _existingAudioUrl;
  String? _existingAudioPath;
  
  List<WordMeaning> _meanings = [];
  List<WordExample> _examples = [];
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.word != null) {
      _populateFields(widget.word!);
    }
  }

  void _populateFields(VocabularyWord word) {
    _wordController.text = word.word;
    _pronunciationController.text = word.pronunciation ?? '';
    _existingImageUrl = word.imageUrl;
    _existingImagePath = word.imagePath;
    _existingAudioUrl = word.audioUrl;
    _existingAudioPath = word.audioPath;
    _meanings = List.from(word.meanings);
    _examples = List.from(word.examples);
  }

  @override
  void dispose() {
    _wordController.dispose();
    _pronunciationController.dispose();
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
          widget.word != null 
              ? widget.languageCubit.getLocalizedText(korean: '단어 수정', english: 'Edit Word')
              : widget.languageCubit.getLocalizedText(korean: '새 단어 만들기', english: 'Create Word'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saveWord,
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
              _buildWordInfoSection(),
              const SizedBox(height: 32),
              _buildMediaSection(),
              const SizedBox(height: 32),
              _buildMeaningsSection(),
              const SizedBox(height: 32),
              _buildExamplesSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordInfoSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(
            korean: '단어 정보',
            english: 'Word Information',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _wordController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '단어',
              english: 'Word',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '예: 안녕하세요',
              english: 'e.g. hello',
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return widget.languageCubit.getLocalizedText(
                korean: '단어를 입력해주세요',
                english: 'Please enter a word',
              );
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _pronunciationController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '발음 (선택사항)',
              english: 'Pronunciation (Optional)',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '예: [an-nyeong-ha-se-yo]',
              english: 'e.g. [hə-ˈloʊ]',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(
            korean: '미디어 (선택사항)',
            english: 'Media (Optional)',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.languageCubit.getLocalizedText(
                      korean: '이미지',
                      english: 'Image',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildImageDisplay(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.languageCubit.getLocalizedText(
                      korean: '오디오',
                      english: 'Audio',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAudioDisplay(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageDisplay() {
    if (_selectedImage != null) {
      return _buildNewImageDisplay();
    } else if (_hasExistingImage()) {
      return _buildExistingImageDisplay();
    } else {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildAudioDisplay() {
    if (_selectedAudio != null) {
      return AudioPlayerWidget(
        audioPath: _selectedAudio!.path,
        label: widget.languageCubit.getLocalizedText(korean: '새 오디오', english: 'New Audio'),
        onRemove: () => setState(() => _selectedAudio = null),
        onEdit: () => _showAudioRecorderDialog(),
        height: 60,
      );
    } else if (_hasExistingAudio()) {
      return AudioPlayerWidget(
        audioUrl: _existingAudioUrl,
        audioPath: _existingAudioPath,
        label: widget.languageCubit.getLocalizedText(korean: '기존 오디오', english: 'Existing Audio'),
        onRemove: () => setState(() {
          _existingAudioUrl = null;
          _existingAudioPath = null;
        }),
        onEdit: () => _showAudioRecorderDialog(),
        height: 60,
      );
    } else {
      return AudioRecorderWidget(
        onAudioSelected: (audioFile) {
          setState(() {
            _selectedAudio = audioFile;
            _existingAudioUrl = null;
            _existingAudioPath = null;
          });
        },
        label: widget.languageCubit.getLocalizedText(
          korean: '오디오 선택',
          english: 'Select Audio',
        ),
      );
    }
  }

  Widget _buildNewImageDisplay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => DialogUtils.showFullScreenImage(context, null, _selectedImage!.path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _buildImageAction(
            icon: Icons.close,
            onTap: () => setState(() => _selectedImage = null),
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
            borderRadius: BorderRadius.circular(8),
            child: Hero(
              tag: _existingImagePath ?? _existingImageUrl ?? '',
              child: CustomCachedImage(
                imageUrl: _existingImageUrl,
                imagePath: _existingImagePath,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageAction(
                icon: Icons.edit, 
                onTap: _pickImage,
              ),
              const SizedBox(width: 4),
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
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha : 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withValues(alpha : 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 24,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              widget.languageCubit.getLocalizedText(
                korean: '이미지',
                english: 'Image',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
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
          size: 14,
        ),
      ),
    );
  }

  Widget _buildMeaningsSection() {
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
                korean: '의미',
                english: 'Meanings',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _meanings.isEmpty 
                    ? colorScheme.errorContainer.withValues(alpha : 0.3)
                    : colorScheme.primaryContainer.withValues(alpha : 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_meanings.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _meanings.isEmpty 
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_meanings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha : 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.translate_outlined,
                  size: 32,
                  color: colorScheme.onSurfaceVariant.withValues(alpha : 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.languageCubit.getLocalizedText(
                    korean: '아직 의미가 없습니다',
                    english: 'No meanings yet',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _addMeaning,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    widget.languageCubit.getLocalizedText(
                      korean: '첫 번째 의미 추가',
                      english: 'Add First Meaning',
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...List.generate(_meanings.length, (index) {
            final meaning = _meanings[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      meaning.language.flag,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      meaning.meaning,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (meaning.hasImage)
                        const Icon(Icons.image, size: 16, color: Colors.blue),
                      if (meaning.hasAudio) ...[
                        if (meaning.hasImage) const SizedBox(width: 4),
                        const Icon(Icons.audiotrack, size: 16, color: Colors.green),
                      ],
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                    onPressed: () => _editMeaning(index),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                    onPressed: () => _deleteMeaning(index),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addMeaning,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                widget.languageCubit.getLocalizedText(
                  korean: '의미 추가',
                  english: 'Add Meaning',
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

  Widget _buildExamplesSection() {
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
                korean: '예문 (선택사항)',
                english: 'Examples (Optional)',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_examples.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha : 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_examples.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_examples.isEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addExample,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                widget.languageCubit.getLocalizedText(
                  korean: '예문 추가',
                  english: 'Add Example',
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        else ...[
          ...List.generate(_examples.length, (index) {
            final example = _examples[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
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
                          example.example,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (example.hasTranslation) ...[
                          const SizedBox(height: 2),
                          Text(
                            example.translation!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (example.hasImage)
                        const Icon(Icons.image, size: 16, color: Colors.blue),
                      if (example.hasAudio) ...[
                        if (example.hasImage) const SizedBox(width: 4),
                        const Icon(Icons.audiotrack, size: 16, color: Colors.green),
                      ],
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                    onPressed: () => _editExample(index),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                    onPressed: () => _deleteExample(index),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addExample,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                widget.languageCubit.getLocalizedText(
                  korean: '예문 추가',
                  english: 'Add Example',
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

  bool _hasExistingImage() {
    return (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) ||
           (_existingImagePath != null && _existingImagePath!.isNotEmpty);
  }

  bool _hasExistingAudio() {
    return (_existingAudioUrl != null && _existingAudioUrl!.isNotEmpty) ||
           (_existingAudioPath != null && _existingAudioPath!.isNotEmpty);
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

  void _showAudioRecorderDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: AudioRecorderWidget(
            onAudioSelected: (audioFile) {
              setState(() {
                _selectedAudio = audioFile;
                _existingAudioUrl = null;
                _existingAudioPath = null;
              });
              Navigator.pop(context);
            },
            label: widget.languageCubit.getLocalizedText(
              korean: '단어 오디오',
              english: 'Word Audio',
            ),
          ),
        ),
      ),
    );
  }

  void _addMeaning() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MeaningEditorPage(
          onSave: (newMeaning) {
            setState(() {
              _meanings.add(newMeaning);
            });
          },
          languageCubit: widget.languageCubit,
          snackBarCubit: widget.snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _editMeaning(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MeaningEditorPage(
          meaning: _meanings[index],
          onSave: (updatedMeaning) {
            setState(() {
              _meanings[index] = updatedMeaning;
            });
          },
          languageCubit: widget.languageCubit,
          snackBarCubit: widget.snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _deleteMeaning(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.languageCubit.getLocalizedText(
            korean: '의미 삭제',
            english: 'Delete Meaning',
          ),
        ),
        content: Text(
          widget.languageCubit.getLocalizedText(
            korean: '이 의미를 삭제하시겠습니까?',
            english: 'Are you sure you want to delete this meaning?',
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
                _meanings.removeAt(index);
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

  void _addExample() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExampleEditorPage(
          onSave: (newExample) {
            setState(() {
              _examples.add(newExample);
            });
          },
          languageCubit: widget.languageCubit,
          snackBarCubit: widget.snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _editExample(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExampleEditorPage(
          example: _examples[index],
          onSave: (updatedExample) {
            setState(() {
              _examples[index] = updatedExample;
            });
          },
          languageCubit: widget.languageCubit,
          snackBarCubit: widget.snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _deleteExample(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.languageCubit.getLocalizedText(
            korean: '예문 삭제',
            english: 'Delete Example',
          ),
        ),
        content: Text(
          widget.languageCubit.getLocalizedText(
            korean: '이 예문을 삭제하시겠습니까?',
            english: 'Are you sure you want to delete this example?',
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
                _examples.removeAt(index);
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

  void _saveWord() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_meanings.isEmpty) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '최소 1개의 의미를 추가해주세요',
        english: 'Please add at least one meaning',
      );
      return;
    }

    final wordId = widget.word?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final newWord = VocabularyWord(
      id: wordId,
      word: _wordController.text.trim(),
      pronunciation: _pronunciationController.text.trim().isEmpty 
          ? null 
          : _pronunciationController.text.trim(),
      meanings: _meanings,
      examples: _examples,
      order: widget.word?.order ?? 0,
      createdAt: widget.word?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      imageUrl: _selectedImage != null ? null : _existingImageUrl,
      imagePath: _selectedImage?.path ?? _existingImagePath,
      audioUrl: _selectedAudio != null ? null : _existingAudioUrl,
      audioPath: _selectedAudio?.path ?? _existingAudioPath,
    );

    widget.onSave(newWord);
    Navigator.pop(context);
  }
}