import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_upload_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/pages/chapter_editor_page.dart';

class BookEditPage extends StatefulWidget {
  final String bookId;

  const BookEditPage({super.key, required this.bookId});

  @override
  State<BookEditPage> createState() => _BookEditPageState();
}

class _BookEditPageState extends State<BookEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  BookLevel _selectedLevel = BookLevel.beginner;
  CourseCategory _selectedCategory = CourseCategory.korean;
  String _selectedLanguage = 'Korean';
  IconData _selectedIcon = Icons.book;
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isPublished = true;
  
  List<BookChapter> _chapters = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  BookItem? _originalBook;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  BooksCubit get _booksCubit => context.read<BooksCubit>();
  BookUploadCubit get _bookUploadCubit => context.read<BookUploadCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _booksCubit.loadBookById(widget.bookId);
      
      final booksState = _booksCubit.state;
      if (booksState.selectedBook != null) {
        _originalBook = booksState.selectedBook!;
        _populateFields(_originalBook!);
      } else {
        _snackBarCubit.showErrorLocalized(
          korean: '도서를 찾을 수 없습니다',
          english: 'Book not found',
        );
        context.pop();
      }
    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '도서를 불러오는 중 오류가 발생했습니다',
        english: 'Error loading book',
      );
      context.pop();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _populateFields(BookItem book) {
    _titleController.text = book.title;
    _descriptionController.text = book.description;
    
    setState(() {
      _selectedLevel = book.level;
      _selectedCategory = book.category;
      _selectedLanguage = book.language;
      _selectedIcon = book.icon;
      _currentImageUrl = book.imageUrl;
      _isPublished = book.isPublished;
      _chapters = List.from(book.chapters);
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
              korean: '도서 편집',
              english: 'Edit Book',
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
                  korean: '도서를 불러오는 중...',
                  english: 'Loading book...',
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
                korean: '도서 편집',
                english: 'Edit Book',
              ),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (_originalBook != null)
              Text(
                _originalBook!.title,
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
              onPressed: _isUpdating ? null : _updateBook,
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
      body: BlocListener<BookUploadCubit, BookUploadState>(
        listener: (context, state) {
          if (state.currentOperation.status == BookUploadOperationStatus.completed &&
              state.currentOperation.type == BookUploadOperationType.updateBook) {
            _snackBarCubit.showSuccessLocalized(
              korean: '도서가 성공적으로 수정되었습니다',
              english: 'Book updated successfully',
            );
            context.pop(true);
          } else if (state.currentOperation.status == BookUploadOperationStatus.failed) {
            _snackBarCubit.showErrorLocalized(
              korean: state.error ?? '도서 수정에 실패했습니다',
              english: state.error ?? 'Failed to update book',
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
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '기존 도서를 편집하고 있습니다',
                english: 'Editing existing book',
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
              korean: '도서 제목',
              english: 'Book Title',
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
            korean: '도서 설정',
            english: 'Book Settings',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
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
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<CourseCategory>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: _languageCubit.getLocalizedText(
                    korean: '카테고리',
                    english: 'Category',
                  ),
                ),
                items: CourseCategory.values
                    .where((cat) => cat != TestCategory.all)
                    .map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
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
              korean: '도서 공개',
              english: 'Publish Book',
            ),
          ),
          subtitle: Text(
            _languageCubit.getLocalizedText(
              korean: '다른 사용자가 이 도서를 볼 수 있습니다',
              english: 'Other users can access this book',
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
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
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
                korean: '챕터',
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
                    ? colorScheme.errorContainer.withValues(alpha: 0.3)
                    : colorScheme.primaryContainer.withValues(alpha: 0.3),
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
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  _languageCubit.getLocalizedText(
                    korean: '아직 챕터가 없습니다',
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
                      korean: '첫 번째 챕터 추가',
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
                              : _languageCubit.getLocalizedText(korean: '제목 없음', english: 'Untitled Chapter'),
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
                              '${chapter.audioTrackCount} ${_languageCubit.getLocalizedText(korean: '오디오', english: 'audio')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            ..._buildChapterBadges(chapter),
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
                  korean: '챕터 추가',
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

  List<Widget> _buildChapterBadges(BookChapter chapter) {
    final theme = Theme.of(context);
    final badges = <Widget>[];
    
    if (chapter.hasImage) {
      badges.add(const SizedBox(width: 8));
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
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
    
    if (chapter.hasPdf) {
      badges.add(const SizedBox(width: 8));
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'PDF',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }
    
    return badges;
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

  void _addChapter() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterEditorPage(
          onSave: (newChapter) {
            setState(() {
              _chapters.add(newChapter.copyWith(order: _chapters.length));
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
              _chapters[index] = updatedChapter.copyWith(order: index);
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
            korean: '챕터 삭제',
            english: 'Delete Chapter',
          ),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '이 챕터를 삭제하시겠습니까?',
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
                // Update order for remaining chapters
                for (int i = 0; i < _chapters.length; i++) {
                  _chapters[i] = _chapters[i].copyWith(order: i);
                }
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

  Future<void> _updateBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_chapters.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '최소 1개의 챕터를 추가해주세요',
        english: 'Please add at least one chapter',
      );
      return;
    }

    try {
      final updatedBook = _originalBook!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        chapters: _chapters,
        level: _selectedLevel,
        category: _selectedCategory,
        language: _selectedLanguage,
        icon: _selectedIcon,
        isPublished: _isPublished,
        updatedAt: DateTime.now(),
        imageUrl: _selectedImage != null ? null : _currentImageUrl,
        imagePath: _selectedImage != null ? null : _originalBook!.imagePath,
      );

      await _bookUploadCubit.updateExistingBook(
        widget.bookId, 
        updatedBook, 
        imageFile: _selectedImage,
      );

    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '도서 수정 중 오류가 발생했습니다: $e',
        english: 'Error updating book: $e',
      );
    }
  }
}