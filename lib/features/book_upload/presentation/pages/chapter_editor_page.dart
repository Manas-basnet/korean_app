import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:korean_language_app/shared/models/book_related/audio_track.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/shared/widgets/audio_recorder.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class ChapterEditorPage extends StatefulWidget {
  final BookChapter? chapter;
  final Function(BookChapter) onSave;
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _chapterImage;
  File? _chapterPdf;
  List<AudioTrack> _audioTracks = [];
  
  String? _existingImageUrl;
  String? _existingImagePath;
  String? _existingPdfUrl;
  String? _existingPdfPath;
  
  bool _isPickingPdf = false;
  bool _isPickingImage = false;
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.chapter != null) {
      _populateFields(widget.chapter!);
    }
  }

  void _populateFields(BookChapter chapter) {
    _titleController.text = chapter.title;
    _descriptionController.text = chapter.description;
    
    _existingImageUrl = chapter.imageUrl;
    _existingImagePath = chapter.imagePath;
    _existingPdfUrl = chapter.pdfUrl;
    _existingPdfPath = chapter.pdfPath;
    
    _audioTracks = List.from(chapter.audioTracks);
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
              ? widget.languageCubit.getLocalizedText(korean: '챕터 수정', english: 'Edit Chapter')
              : widget.languageCubit.getLocalizedText(korean: '새 챕터 만들기', english: 'Create Chapter'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 32),
            _buildImageSection(),
            const SizedBox(height: 32),
            _buildPdfSection(),
            const SizedBox(height: 32),
            _buildAudioTracksSection(),
            const SizedBox(height: 100),
          ],
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
          widget.languageCubit.getLocalizedText(korean: '챕터 정보', english: 'Chapter Information'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '챕터 제목',
              english: 'Chapter Title',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '예: 1장 - 기본 인사말',
              english: 'e.g. Chapter 1 - Basic Greetings',
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: widget.languageCubit.getLocalizedText(
              korean: '챕터 설명',
              english: 'Chapter Description',
            ),
            hintText: widget.languageCubit.getLocalizedText(
              korean: '이 챕터에서 다루는 내용을 설명하세요',
              english: 'Describe what this chapter covers',
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
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
            korean: '챕터 이미지 (선택사항)',
            english: 'Chapter Image (Optional)',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_isPickingImage)
          _buildImageLoadingIndicator()
        else if (_chapterImage != null)
          _buildNewImageDisplay()
        else if (_hasExistingImage())
          _buildExistingImageDisplay()
        else
          _buildImagePlaceholder(),
      ],
    );
  }

  Widget _buildPdfSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.languageCubit.getLocalizedText(
            korean: 'PDF 파일',
            english: 'PDF File',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_isPickingPdf)
          _buildPdfLoadingIndicator()
        else if (_chapterPdf != null)
          _buildNewPdfDisplay()
        else if (_hasExistingPdf())
          _buildExistingPdfDisplay()
        else
          _buildPdfPlaceholder(),
      ],
    );
  }

  Widget _buildPdfLoadingIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.languageCubit.getLocalizedText(
              korean: 'PDF 파일을 처리하는 중...',
              english: 'Processing PDF file...',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.languageCubit.getLocalizedText(
              korean: '큰 파일의 경우 시간이 걸릴 수 있습니다',
              english: 'Large files may take longer to process',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageLoadingIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.languageCubit.getLocalizedText(
              korean: '이미지를 처리하는 중...',
              english: 'Processing image...',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTracksSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.languageCubit.getLocalizedText(korean: '오디오 트랙', english: 'Audio Tracks'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _audioTracks.isEmpty 
                    ? colorScheme.errorContainer.withValues(alpha: 0.3)
                    : colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_audioTracks.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _audioTracks.isEmpty 
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_audioTracks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.audiotrack_outlined,
                  size: 40,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.languageCubit.getLocalizedText(
                    korean: '아직 오디오 트랙이 없습니다',
                    english: 'No audio tracks yet',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _addAudioTrack,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    widget.languageCubit.getLocalizedText(
                      korean: '첫 번째 오디오 추가',
                      english: 'Add First Audio',
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...List.generate(_audioTracks.length, (index) {
            final audioTrack = _audioTracks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSecondary,
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
                              audioTrack.title.isNotEmpty 
                                  ? audioTrack.title 
                                  : widget.languageCubit.getLocalizedText(korean: '제목 없음', english: 'Untitled Audio'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (audioTrack.description != null && audioTrack.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                audioTrack.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                        onPressed: () => _editAudioTrack(index),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: colorScheme.error),
                        onPressed: () => _deleteAudioTrack(index),
                      ),
                    ],
                  ),
                  if (audioTrack.hasAudio) ...[
                    const SizedBox(height: 12),
                    AudioPlayerWidget(
                      audioUrl: audioTrack.audioUrl,
                      audioPath: audioTrack.audioPath,
                      label: audioTrack.title,
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addAudioTrack,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                widget.languageCubit.getLocalizedText(
                  korean: '오디오 트랙 추가',
                  english: 'Add Audio Track',
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

  Widget _buildNewImageDisplay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => DialogUtils.showFullScreenImage(context, null, _chapterImage!.path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _chapterImage!,
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
            onTap: () => setState(() => _chapterImage = null),
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
              _buildImageAction(icon: Icons.edit, onTap: _pickImage),
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
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
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
                korean: '이미지 선택',
                english: 'Select Image',
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

  Widget _buildNewPdfDisplay() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.languageCubit.getLocalizedText(korean: '새 PDF 파일', english: 'New PDF File'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _chapterPdf!.path.split('/').last,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                FutureBuilder<int>(
                  future: _chapterPdf!.length(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final sizeInMB = snapshot.data! / (1024 * 1024);
                      return Text(
                        '${sizeInMB.toStringAsFixed(1)} MB',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _chapterPdf = null),
            icon: Icon(Icons.close, color: colorScheme.error),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingPdfDisplay() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.languageCubit.getLocalizedText(korean: '기존 PDF 파일', english: 'Existing PDF File'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.languageCubit.getLocalizedText(korean: 'PDF 문서', english: 'PDF Document'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isPickingPdf ? null : _pickPdf,
            icon: Icon(
              Icons.edit, 
              color: _isPickingPdf ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : colorScheme.primary,
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _existingPdfUrl = null;
              _existingPdfPath = null;
            }),
            icon: Icon(Icons.close, color: colorScheme.error),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPlaceholder() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: _isPickingPdf ? null : _pickPdf,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 40,
              color: _isPickingPdf 
                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              widget.languageCubit.getLocalizedText(
                korean: 'PDF 파일 선택',
                english: 'Select PDF File',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _isPickingPdf 
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : colorScheme.onSurfaceVariant,
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

  bool _hasExistingPdf() {
    return (_existingPdfUrl != null && _existingPdfUrl!.isNotEmpty) ||
           (_existingPdfPath != null && _existingPdfPath!.isNotEmpty);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    
    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final file = File(image.path);
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        setState(() {
          _chapterImage = file;
          _existingImageUrl = null;
          _existingImagePath = null;
        });
      }
    } catch (e) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '이미지 선택 중 오류가 발생했습니다',
        english: 'Error selecting image',
      );
    } finally {
      setState(() {
        _isPickingImage = false;
      });
    }
  }

  Future<void> _pickPdf() async {
    if (_isPickingPdf) return;
    
    setState(() {
      _isPickingPdf = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        
        final fileSize = await file.length();
        if (fileSize > 50 * 1024 * 1024) {
          widget.snackBarCubit.showErrorLocalized(
            korean: 'PDF 파일이 너무 큽니다 (최대 50MB)',
            english: 'PDF file is too large (max 50MB)',
          );
          return;
        }
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        setState(() {
          _chapterPdf = file;
          _existingPdfUrl = null;
          _existingPdfPath = null;
        });
        
        widget.snackBarCubit.showSuccessLocalized(
          korean: 'PDF 파일이 성공적으로 선택되었습니다 (${_formatFileSize(fileSize)})',
          english: 'PDF file selected successfully (${_formatFileSize(fileSize)})',
        );
      }
    } catch (e) {
      widget.snackBarCubit.showErrorLocalized(
        korean: 'PDF 파일 선택 중 오류가 발생했습니다',
        english: 'Error selecting PDF file',
      );
    } finally {
      setState(() {
        _isPickingPdf = false;
      });
    }
  }

  void _addAudioTrack() {
    _showAudioTrackEditor();
  }

  void _editAudioTrack(int index) {
    _showAudioTrackEditor(audioTrack: _audioTracks[index], index: index);
  }

  void _deleteAudioTrack(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.languageCubit.getLocalizedText(
            korean: '오디오 트랙 삭제',
            english: 'Delete Audio Track',
          ),
        ),
        content: Text(
          widget.languageCubit.getLocalizedText(
            korean: '이 오디오 트랙을 삭제하시겠습니까?',
            english: 'Are you sure you want to delete this audio track?',
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
                _audioTracks.removeAt(index);
                for (int i = 0; i < _audioTracks.length; i++) {
                  _audioTracks[i] = _audioTracks[i].copyWith(order: i);
                }
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

  void _showAudioTrackEditor({AudioTrack? audioTrack, int? index}) {
    showDialog(
      context: context,
      builder: (context) => AudioTrackEditorDialog(
        audioTrack: audioTrack,
        onSave: (newAudioTrack) {
          setState(() {
            if (index != null) {
              _audioTracks[index] = newAudioTrack.copyWith(order: index);
            } else {
              _audioTracks.add(newAudioTrack.copyWith(order: _audioTracks.length));
            }
          });
        },
        languageCubit: widget.languageCubit,
        snackBarCubit: widget.snackBarCubit,
      ),
    );
  }

  void _saveChapter() {
    if (_titleController.text.trim().isEmpty) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '챕터 제목을 입력해주세요',
        english: 'Please enter a chapter title',
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '챕터 설명을 입력해주세요',
        english: 'Please enter a chapter description',
      );
      return;
    }

    final newChapter = BookChapter(
      id: widget.chapter?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imagePath: _chapterImage?.path ?? _existingImagePath,
      imageUrl: _existingImageUrl,
      pdfPath: _chapterPdf?.path ?? _existingPdfPath,
      pdfUrl: _existingPdfUrl,
      audioTracks: _audioTracks,
      order: widget.chapter?.order ?? 0,
      createdAt: widget.chapter?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSave(newChapter);
    Navigator.pop(context);
  }
}

class AudioTrackEditorDialog extends StatefulWidget {
  final AudioTrack? audioTrack;
  final Function(AudioTrack) onSave;
  final LanguagePreferenceCubit languageCubit;
  final SnackBarCubit snackBarCubit;

  const AudioTrackEditorDialog({
    super.key,
    this.audioTrack,
    required this.onSave,
    required this.languageCubit,
    required this.snackBarCubit,
  });

  @override
  State<AudioTrackEditorDialog> createState() => _AudioTrackEditorDialogState();
}

class _AudioTrackEditorDialogState extends State<AudioTrackEditorDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _audioFile;
  String? _existingAudioUrl;
  String? _existingAudioPath;

  @override
  void initState() {
    super.initState();
    if (widget.audioTrack != null) {
      _populateFields(widget.audioTrack!);
    }
  }

  void _populateFields(AudioTrack audioTrack) {
    _titleController.text = audioTrack.title;
    _descriptionController.text = audioTrack.description ?? '';
    _existingAudioUrl = audioTrack.audioUrl;
    _existingAudioPath = audioTrack.audioPath;
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

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                widget.audioTrack != null 
                    ? widget.languageCubit.getLocalizedText(korean: '오디오 트랙 수정', english: 'Edit Audio Track')
                    : widget.languageCubit.getLocalizedText(korean: '새 오디오 트랙', english: 'New Audio Track'),
              ),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: widget.languageCubit.getLocalizedText(
                          korean: '오디오 제목',
                          english: 'Audio Title',
                        ),
                        hintText: widget.languageCubit.getLocalizedText(
                          korean: '예: 발음 연습',
                          english: 'e.g. Pronunciation Practice',
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: widget.languageCubit.getLocalizedText(
                          korean: '설명 (선택사항)',
                          english: 'Description (Optional)',
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      widget.languageCubit.getLocalizedText(korean: '오디오 파일', english: 'Audio File'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_audioFile != null)
                      AudioPlayerWidget(
                        audioPath: _audioFile!.path,
                        label: widget.languageCubit.getLocalizedText(korean: '새 오디오', english: 'New Audio'),
                        onRemove: () => setState(() => _audioFile = null),
                        onEdit: () => _showAudioRecorder(),
                      )
                    else if (_hasExistingAudio())
                      AudioPlayerWidget(
                        audioUrl: _existingAudioUrl,
                        audioPath: _existingAudioPath,
                        label: widget.languageCubit.getLocalizedText(korean: '기존 오디오', english: 'Existing Audio'),
                        onRemove: () => setState(() {
                          _existingAudioUrl = null;
                          _existingAudioPath = null;
                        }),
                        onEdit: () => _showAudioRecorder(),
                      )
                    else
                      AudioRecorderWidget(
                        onAudioSelected: (audioFile) {
                          setState(() {
                            _audioFile = audioFile;
                            _existingAudioUrl = null;
                            _existingAudioPath = null;
                          });
                        },
                        label: widget.languageCubit.getLocalizedText(
                          korean: '오디오 녹음 또는 선택',
                          english: 'Record or Select Audio',
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saveAudioTrack,
                        child: Text(
                          widget.languageCubit.getLocalizedText(korean: '저장', english: 'Save'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasExistingAudio() {
    return (_existingAudioUrl != null && _existingAudioUrl!.isNotEmpty) ||
           (_existingAudioPath != null && _existingAudioPath!.isNotEmpty);
  }

  void _showAudioRecorder() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: AudioRecorderWidget(
            onAudioSelected: (audioFile) {
              setState(() {
                _audioFile = audioFile;
                _existingAudioUrl = null;
                _existingAudioPath = null;
              });
              Navigator.pop(context);
            },
            label: widget.languageCubit.getLocalizedText(
              korean: '새 오디오 녹음',
              english: 'Record New Audio',
            ),
          ),
        ),
      ),
    );
  }

  void _saveAudioTrack() {
    if (_titleController.text.trim().isEmpty) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '오디오 제목을 입력해주세요',
        english: 'Please enter an audio title',
      );
      return;
    }

    if (_audioFile == null && !_hasExistingAudio()) {
      widget.snackBarCubit.showErrorLocalized(
        korean: '오디오 파일을 선택해주세요',
        english: 'Please select an audio file',
      );
      return;
    }

    final newAudioTrack = AudioTrack(
      id: widget.audioTrack?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      audioPath: _audioFile?.path ?? _existingAudioPath,
      audioUrl: _existingAudioUrl,
      order: widget.audioTrack?.order ?? 0,
    );

    widget.onSave(newAudioTrack);
    Navigator.pop(context);
  }
}