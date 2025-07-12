import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/bloc/vocabulary_upload_cubit.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/pages/chapter_editor_page.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabularies_cubit.dart';

class VocabularyEditPage extends StatefulWidget {
  final String vocabularyId;

  const VocabularyEditPage({super.key, required this.vocabularyId});

  @override
  State<VocabularyEditPage> createState() => _VocabularyEditPageState();
}

class _VocabularyEditPageState extends State<VocabularyEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  BookLevel _selectedLevel = BookLevel.beginner;
  SupportedLanguage _selectedPrimaryLanguage = SupportedLanguage.korean;
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isPublished = true;
  
  List<VocabularyChapter> _chapters = [];
  List<File> _selectedPdfs = [];
  List<String> _existingPdfUrls = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  VocabularyItem? _originalVocabulary;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  VocabulariesCubit get _vocabulariesCubit => context.read<VocabulariesCubit>();
  VocabularyUploadCubit get _vocabularyUploadCubit => context.read<VocabularyUploadCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadVocabulary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _vocabulariesCubit.loadVocabularyById(widget.vocabularyId);
      
      final vocabulariesState = _vocabulariesCubit.state;
      if (vocabulariesState.selectedVocabulary != null) {
        _originalVocabulary = vocabulariesState.selectedVocabulary!;
        _populateFields(_originalVocabulary!);
      } else {
        _snackBarCubit.showErrorLocalized(
          korean: '어휘집을 찾을 수 없습니다',
          english: 'Vocabulary not found',
        );
        context.pop();
      }
    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '어휘집을 불러오는 중 오류가 발생했습니다',
        english: 'Error loading vocabulary',
      );
      context.pop();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _populateFields(VocabularyItem vocabulary) {
    _titleController.text = vocabulary.title;
    _descriptionController.text = vocabulary.description;
    
    setState(() {
      _selectedLevel = vocabulary.level;
      _selectedPrimaryLanguage = vocabulary.primaryLanguage;
      _currentImageUrl = vocabulary.imageUrl;
      _isPublished = vocabulary.isPublished;
      _chapters = List.from(vocabulary.chapters);
      _existingPdfUrls = List.from(vocabulary.pdfUrls);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _languageCubit.getLocalizedText(
              korean: '어휘집 편집',
              english: 'Edit Vocabulary',
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                _languageCubit.getLocalizedText(
                  korean: '어휘집을 불러오는 중...',
                  english: 'Loading vocabulary...',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageCubit.getLocalizedText(
                korean: '어휘집 편집',
                english: 'Edit Vocabulary',
              ),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (_originalVocabulary != null)
              Text(
                _originalVocabulary!.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isUpdating ? null : _updateVocabulary,
              style: TextButton.styleFrom(
                backgroundColor: _isUpdating ? Colors.grey.shade300 : colorScheme.primary,
                foregroundColor: _isUpdating ? Colors.grey.shade600 : colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isUpdating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                      ),
                    )
                  : Text(
                      _languageCubit.getLocalizedText(
                        korean: '저장',
                        english: 'Save',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
      body: BlocListener<VocabularyUploadCubit, VocabularyUploadState>(
        listener: (context, state) {
          if (state.currentOperation.status == VocabularyUploadOperationStatus.completed &&
              state.currentOperation.type == VocabularyUploadOperationType.updateVocabulary) {
            _snackBarCubit.showSuccessLocalized(
              korean: '어휘집이 성공적으로 수정되었습니다',
              english: 'Vocabulary updated successfully',
            );
            context.pop(true);
          } else if (state.currentOperation.status == VocabularyUploadOperationStatus.failed) {
            _snackBarCubit.showErrorLocalized(
              korean: state.error ?? '어휘집 수정에 실패했습니다',
              english: state.error ?? 'Failed to update vocabulary',
            );
          }
          
          setState(() {
            _isUpdating = state.isLoading;
          });
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEditNotice(),
                const SizedBox(height: 24),
                _buildBasicInfoSection(),
                const SizedBox(height: 32),
                _buildSettingsSection(),
                const SizedBox(height: 32),
                _buildImageSection(),
                const SizedBox(height: 32),
                _buildChaptersSection(),
                const SizedBox(height: 32),
                _buildPdfsSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditNotice() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha : 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '기존 어휘집을 편집하고 있습니다',
                english: 'Editing existing vocabulary',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageCubit.getLocalizedText(
            korean: '기본 정보',
            english: 'Basic Information',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: _languageCubit.getLocalizedText(
              korean: '어휘집 제목',
              english: 'Vocabulary Title',
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return _languageCubit.getLocalizedText(
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
            labelText: _languageCubit.getLocalizedText(
              korean: '설명',
              english: 'Description',
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return _languageCubit.getLocalizedText(
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

  Widget _buildSettingsSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageCubit.getLocalizedText(
            korean: '어휘집 설정',
            english: 'Vocabulary Settings',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<SupportedLanguage>(
                value: _selectedPrimaryLanguage,
                decoration: InputDecoration(
                  labelText: _languageCubit.getLocalizedText(
                    korean: '주요 언어',
                    english: 'Primary Language',
                  ),
                ),
                items: SupportedLanguage.values.map((language) {
                  return DropdownMenuItem(
                    value: language,
                    child: Row(
                      children: [
                        Text(language.flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(language.displayName)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPrimaryLanguage = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<BookLevel>(
                value: _selectedLevel,
                decoration: InputDecoration(
                  labelText: _languageCubit.getLocalizedText(
                    korean: '난이도',
                    english: 'Level',
                  ),
                ),
                items: BookLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level.getName(_languageCubit)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLevel = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        SwitchListTile(
          title: Text(
            _languageCubit.getLocalizedText(
              korean: '어휘집 공개',
              english: 'Publish Vocabulary',
            ),
          ),
          subtitle: Text(
            _languageCubit.getLocalizedText(
              korean: '다른 사용자가 이 어휘집을 볼 수 있습니다',
              english: 'Other users can access this vocabulary',
            ),
          ),
          value: _isPublished,
          onChanged: (value) {
            setState(() {
              _isPublished = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageCubit.getLocalizedText(
            korean: '커버 이미지',
            english: 'Cover Image',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_selectedImage != null)
          Stack(
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
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          )
        else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
          Stack(
            children: [
              GestureDetector(
                onTap: () => DialogUtils.showFullScreenImage(
                  context,
                  _currentImageUrl!,
                  null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _currentImageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Icon(Icons.broken_image)),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentImageUrl = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha : 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha : 0.3),
                  style: BorderStyle.solid,
                ),
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
                    _languageCubit.getLocalizedText(
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
          ),
      ],
    );
  }

  Widget _buildChaptersSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _languageCubit.getLocalizedText(
                korean: '단원',
                english: 'Chapters',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _chapters.isEmpty 
                    ? colorScheme.errorContainer.withValues(alpha : 0.3)
                    : colorScheme.primaryContainer.withValues(alpha : 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_chapters.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _chapters.isEmpty 
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_chapters.isEmpty)
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
                  Icons.library_books_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha : 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  _languageCubit.getLocalizedText(
                    korean: '아직 단원이 없습니다',
                    english: 'No chapters yet',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _addChapter,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    _languageCubit.getLocalizedText(
                      korean: '첫 번째 단원 추가',
                      english: 'Add First Chapter',
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...List.generate(_chapters.length, (index) {
            final chapter = _chapters[index];
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
                          chapter.title.isNotEmpty 
                              ? chapter.title 
                              : _languageCubit.getLocalizedText(korean: '제목 없는 단원', english: 'Untitled Chapter'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${chapter.wordCount} ${_languageCubit.getLocalizedText(korean: '단어', english: 'words')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (chapter.hasImage) ...[
                              const SizedBox(width: 8),
                              Container(
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
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                    onPressed: () => _editChapter(index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    onPressed: () => _deleteChapter(index),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addChapter,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                _languageCubit.getLocalizedText(
                  korean: '단원 추가',
                  english: 'Add Chapter',
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

  Widget _buildPdfsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allPdfs = [..._existingPdfUrls, ..._selectedPdfs.map((f) => f.path.split('/').last)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _languageCubit.getLocalizedText(
                korean: 'PDF 자료',
                english: 'PDF Materials',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (allPdfs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha : 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${allPdfs.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (allPdfs.isEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickPdfs,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                _languageCubit.getLocalizedText(
                  korean: 'PDF 파일 추가',
                  english: 'Add PDF Files',
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        else ...[
          ...List.generate(_existingPdfUrls.length, (index) {
            final pdfUrl = _existingPdfUrls[index];
            final filename = pdfUrl.split('/').last.split('?').first;
            
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
                  Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filename.isNotEmpty ? filename : 'PDF Document',
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _languageCubit.getLocalizedText(korean: '기존 파일', english: 'Existing File'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.error, size: 20),
                    onPressed: () => _removeExistingPdf(index),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            );
          }),
          ...List.generate(_selectedPdfs.length, (index) {
            final pdf = _selectedPdfs[index];
            final filename = pdf.path.split('/').last;
            
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
                  Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filename,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _languageCubit.getLocalizedText(korean: '새 파일', english: 'New File'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.error, size: 20),
                    onPressed: () => _removeNewPdf(index),
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
              onPressed: _pickPdfs,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                _languageCubit.getLocalizedText(
                  korean: 'PDF 추가',
                  english: 'Add PDF',
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

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _currentImageUrl = null;
      });
    }
  }

  Future<void> _pickPdfs() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final newPdfs = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();
      
      setState(() {
        _selectedPdfs.addAll(newPdfs);
      });
    }
  }

  void _removeExistingPdf(int index) {
    setState(() {
      _existingPdfUrls.removeAt(index);
    });
  }

  void _removeNewPdf(int index) {
    setState(() {
      _selectedPdfs.removeAt(index);
    });
  }

  void _addChapter() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterEditorPage(
          onSave: (newChapter) {
            setState(() {
              _chapters.add(newChapter);
            });
          },
          languageCubit: _languageCubit,
          snackBarCubit: _snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _editChapter(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterEditorPage(
          chapter: _chapters[index],
          onSave: (updatedChapter) {
            setState(() {
              _chapters[index] = updatedChapter;
            });
          },
          languageCubit: _languageCubit,
          snackBarCubit: _snackBarCubit,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _deleteChapter(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '단원 삭제',
            english: 'Delete Chapter',
          ),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '이 단원을 삭제하시겠습니까?',
            english: 'Are you sure you want to delete this chapter?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _chapters.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '삭제',
                english: 'Delete',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateVocabulary() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_chapters.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '최소 1개의 단원을 추가해주세요',
        english: 'Please add at least one chapter',
      );
      return;
    }

    try {
      final updatedVocabulary = _originalVocabulary!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        primaryLanguage: _selectedPrimaryLanguage,
        chapters: _chapters,
        level: _selectedLevel,
        isPublished: _isPublished,
        updatedAt: DateTime.now(),
        imageUrl: _selectedImage != null ? null : _currentImageUrl,
        imagePath: _selectedImage != null ? null : _originalVocabulary!.imagePath,
        pdfUrls: _existingPdfUrls,
      );

      await _vocabularyUploadCubit.updateExistingVocabulary(
        widget.vocabularyId, 
        updatedVocabulary, 
        imageFile: _selectedImage,
        pdfFiles: _selectedPdfs.isNotEmpty ? _selectedPdfs : null,
      );

    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '어휘집 수정 중 오류가 발생했습니다: $e',
        english: 'Error updating vocabulary: $e',
      );
    }
  }
}