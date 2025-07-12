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
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/bloc/vocabulary_upload_cubit.dart';
import 'package:korean_language_app/features/vocabulary_upload/presentation/pages/chapter_editor_page.dart';

class VocabularyUploadPage extends StatefulWidget {
  const VocabularyUploadPage({super.key});

  @override
  State<VocabularyUploadPage> createState() => _VocabularyUploadPageState();
}

class _VocabularyUploadPageState extends State<VocabularyUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  BookLevel _selectedLevel = BookLevel.beginner;
  SupportedLanguage _selectedPrimaryLanguage = SupportedLanguage.korean;
  File? _selectedImage;
  bool _isPublished = true;
  
  final List<VocabularyChapter> _chapters = [];
  final List<File> _selectedPdfs = [];
  bool _isUploading = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  VocabularyUploadCubit get _vocabularyUploadCubit => context.read<VocabularyUploadCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();
  AuthCubit get _authCubit => context.read<AuthCubit>();

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
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '새 어휘집 만들기',
            english: 'Create Vocabulary',
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isUploading ? null : _uploadVocabulary,
              style: TextButton.styleFrom(
                backgroundColor: _isUploading ? Colors.grey.shade300 : colorScheme.primary,
                foregroundColor: _isUploading ? Colors.grey.shade600 : colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isUploading
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
                        korean: '업로드',
                        english: 'Upload',
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
              state.currentOperation.type == VocabularyUploadOperationType.createVocabulary) {
            _snackBarCubit.showSuccessLocalized(
              korean: '어휘집이 성공적으로 업로드되었습니다',
              english: 'Vocabulary uploaded successfully',
            );
            context.go(Routes.vocabulary); //TODO: go to vocabulary page
          } else if (state.currentOperation.status == VocabularyUploadOperationStatus.failed) {
            _snackBarCubit.showErrorLocalized(
              korean: state.error ?? '어휘집 업로드에 실패했습니다',
              english: state.error ?? 'Failed to upload vocabulary',
            );
          }
          
          setState(() {
            _isUploading = state.isLoading;
          });
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressSection(),
                const SizedBox(height: 32),
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

  Widget _buildProgressSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    int completedSteps = 0;
    if (_titleController.text.isNotEmpty && _descriptionController.text.isNotEmpty) completedSteps++;
    if (_chapters.isNotEmpty) completedSteps++;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha : 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _languageCubit.getLocalizedText(
                  korean: '진행 상황',
                  english: 'Progress',
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '$completedSteps/2',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completedSteps / 2,
            backgroundColor: colorScheme.onSurfaceVariant.withValues(alpha : 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            borderRadius: BorderRadius.circular(4),
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
            hintText: _languageCubit.getLocalizedText(
              korean: '예: 기초 한국어 어휘',
              english: 'e.g. Basic Korean Vocabulary',
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
          onChanged: (value) => setState(() {}),
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: _languageCubit.getLocalizedText(
              korean: '설명',
              english: 'Description',
            ),
            hintText: _languageCubit.getLocalizedText(
              korean: '어휘집에 대한 설명을 입력하세요',
              english: 'Enter vocabulary description',
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
          onChanged: (value) => setState(() {}),
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
            korean: '커버 이미지 (선택사항)',
            english: 'Cover Image (Optional)',
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
                const SizedBox(height: 8),
                Text(
                  _languageCubit.getLocalizedText(
                    korean: '첫 번째 단원을 추가해보세요',
                    english: 'Add your first chapter to get started',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha : 0.7),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _languageCubit.getLocalizedText(
                korean: 'PDF 자료 (선택사항)',
                english: 'PDF Materials (Optional)',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selectedPdfs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha : 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedPdfs.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_selectedPdfs.isEmpty)
          GestureDetector(
            onTap: _pickPdfs,
            child: Container(
              height: 120,
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
                    Icons.picture_as_pdf_outlined,
                    size: 40,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _languageCubit.getLocalizedText(
                      korean: 'PDF 파일 추가',
                      english: 'Add PDF Files',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
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
                    child: Text(
                      filename,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.error, size: 20),
                    onPressed: () => _removePdf(index),
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

  void _removePdf(int index) {
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

  Future<void> _uploadVocabulary() async {
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

    final authState = _authCubit.state;
    if (authState is! Authenticated) {
      _snackBarCubit.showErrorLocalized(
        korean: '로그인이 필요합니다',
        english: 'Please log in first',
      );
      return;
    }

    try {
      final vocabulary = VocabularyItem(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        primaryLanguage: _selectedPrimaryLanguage,
        chapters: _chapters,
        level: _selectedLevel,
        creatorUid: authState.user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPublished: _isPublished,
        imageUrl: null,
        imagePath: null,
      );

      await _vocabularyUploadCubit.uploadNewVocabulary(
        vocabulary, 
        imageFile: _selectedImage,
        pdfFiles: _selectedPdfs.isNotEmpty ? _selectedPdfs : null,
      );

    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '어휘집 업로드 중 오류가 발생했습니다: $e',
        english: 'Error uploading vocabulary: $e',
      );
    }
  }
}