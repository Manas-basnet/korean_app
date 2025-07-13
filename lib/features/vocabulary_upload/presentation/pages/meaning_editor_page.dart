import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_meaning.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/shared/widgets/audio_recorder.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class MeaningEditorPage extends StatefulWidget {
  final WordMeaning? meaning;
  final Function(WordMeaning) onSave;
  final LanguagePreferenceCubit languageCubit;
  final SnackBarCubit snackBarCubit;

  const MeaningEditorPage({
    super.key,
    this.meaning,
    required this.onSave,
    required this.languageCubit,
    required this.snackBarCubit,
  });

  @override
  State<MeaningEditorPage> createState() => _MeaningEditorPageState();
}

class _MeaningEditorPageState extends State<MeaningEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _meaningController = TextEditingController();
  
  SupportedLanguage _selectedLanguage = SupportedLanguage.english;
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
    if (widget.meaning != null) {
      _populateFields(widget.meaning!);
    }
  }

  void _populateFields(WordMeaning meaning) {
    _meaningController.text = meaning.meaning;
    _selectedLanguage = meaning.language;
    _existingImageUrl = meaning.imageUrl;
    _existingImagePath = meaning.imagePath;
    _existingAudioUrl = meaning.audioUrl;
    _existingAudioPath = meaning.audioPath;
  }

  @override
  void dispose() {
    _meaningController.dispose();
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
          widget.meaning != null 
              ? widget.languageCubit.getLocalizedText(korean: '의미 수정', english: 'Edit Meaning')
              : widget.languageCubit.getLocalizedText(korean: '새 의미 만들기', english: 'Create Meaning'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _saveMeaning,
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
              _buildMeaningInfoSection(),
              const SizedBox(height: 32),
              _buildMediaSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeaningInfoSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(
            korean: '의미 정보',
            english: 'Meaning Information',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<SupportedLanguage>(
          value: _selectedLanguage,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '언어',
              english: 'Language',
            ),
          ),
          items: SupportedLanguage.values.map((language) {
            return DropdownMenuItem(
              value: language,
              child: Text("${language.flag} (${language.name})"),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedLanguage = value;
              });
            }
          },
          validator: (value) {
            if (value == null) {
              return widget.languageCubit.getLocalizedText(
                korean: '언어를 선택해주세요',
                english: 'Please select a language',
              );
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _meaningController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '의미',
              english: 'Meaning',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '예: hello, greeting',
              english: 'e.g. hello, greeting',
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return widget.languageCubit.getLocalizedText(
                korean: '의미를 입력해주세요',
                english: 'Please enter a meaning',
              );
            }
            return null;
          },
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
              korean: '의미 오디오',
              english: 'Meaning Audio',
            ),
          ),
        ),
      ),
    );
  }

  void _saveMeaning() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final meaningId = widget.meaning?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final newMeaning = WordMeaning(
      id: meaningId,
      language: _selectedLanguage,
      meaning: _meaningController.text.trim(),
      imageUrl: _selectedImage != null ? null : _existingImageUrl,
      imagePath: _selectedImage?.path ?? _existingImagePath,
      audioUrl: _selectedAudio != null ? null : _existingAudioUrl,
      audioPath: _selectedAudio?.path ?? _existingAudioPath,
    );

    widget.onSave(newMeaning);
    Navigator.pop(context);
  }
}