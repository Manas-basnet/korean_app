import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_example.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/shared/widgets/audio_recorder.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class ExampleEditorPage extends StatefulWidget {
  final WordExample? example;
  final Function(WordExample) onSave;
  final LanguagePreferenceCubit languageCubit;
  final SnackBarCubit snackBarCubit;

  const ExampleEditorPage({
    super.key,
    this.example,
    required this.onSave,
    required this.languageCubit,
    required this.snackBarCubit,
  });

  @override
  State<ExampleEditorPage> createState() => _ExampleEditorPageState();
}

class _ExampleEditorPageState extends State<ExampleEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _exampleController = TextEditingController();
  final _translationController = TextEditingController();
  
  File? _selectedImage;
  File? _selectedAudio;
  String? _existingImageUrl;
  String? _existingImagePath;
  String? _existingAudioUrl;
  String? _existingAudioPath;
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.example != null) {
      _populateFields(widget.example!);
    }
  }

  void _populateFields(WordExample example) {
    _exampleController.text = example.example;
    _translationController.text = example.translation ?? '';
    _existingImageUrl = example.imageUrl;
    _existingImagePath = example.imagePath;
    _existingAudioUrl = example.audioUrl;
    _existingAudioPath = example.audioPath;
  }

  @override
  void dispose() {
    _exampleController.dispose();
    _translationController.dispose();
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
          widget.example != null 
              ? widget.languageCubit.getLocalizedText(korean: '예문 수정', english: 'Edit Example')
              : widget.languageCubit.getLocalizedText(korean: '새 예문 만들기', english: 'Create Example'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saveExample,
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
              _buildExampleInfoSection(),
              const SizedBox(height: 32),
              _buildMediaSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExampleInfoSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(
            korean: '예문 정보',
            english: 'Example Information',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _exampleController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '예문',
              english: 'Example',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '예: 안녕하세요! 만나서 반가워요.',
              english: 'e.g. Hello! Nice to meet you.',
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return widget.languageCubit.getLocalizedText(
                korean: '예문을 입력해주세요',
                english: 'Please enter an example',
              );
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _translationController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '번역 (선택사항)',
              english: 'Translation (Optional)',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '예: Hello! Nice to meet you.',
              english: 'e.g. 안녕하세요! 만나서 반가워요.',
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
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
        
        const SizedBox(height: 24),
        
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
              korean: '예문 오디오',
              english: 'Example Audio',
            ),
          ),
        ),
      ),
    );
  }

  void _saveExample() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final exampleId = widget.example?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final newExample = WordExample(
      id: exampleId,
      example: _exampleController.text.trim(),
      translation: _translationController.text.trim().isEmpty 
          ? null 
          : _translationController.text.trim(),
      imageUrl: _selectedImage != null ? null : _existingImageUrl,
      imagePath: _selectedImage?.path ?? _existingImagePath,
      audioUrl: _selectedAudio != null ? null : _existingAudioUrl,
      audioPath: _selectedAudio?.path ?? _existingAudioPath,
    );

    widget.onSave(newExample);
    Navigator.pop(context);
  }
}