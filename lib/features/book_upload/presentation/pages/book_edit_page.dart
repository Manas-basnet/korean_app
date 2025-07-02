import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/shared_book_form_widgets.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/chapter_upload_dialog.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class BookEditPage extends StatefulWidget {
  final BookItem book;
  
  const BookEditPage({
    super.key,
    required this.book,
  });

  @override
  State<BookEditPage> createState() => _BookEditPageState();
}

class _BookEditPageState extends State<BookEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late TextEditingController _chaptersController;
  late TextEditingController _countryController;
  late TextEditingController _categoryController;
  
  late BookLevel _selectedLevel;
  late CourseCategory _selectedCategory;
  late IconData _selectedIcon;
  late BookUploadType _uploadType;
  
  File? _selectedPdfFile;
  String? _pdfFileName;
  bool _pdfSelected = false;
  
  File? _selectedImageFile;
  String? _imageFileName;
  bool _imageSelected = false;

  List<AudioTrackUploadData> _audioTracks = [];
  bool _audioTracksChanged = false;

  List<ChapterUploadData> _chapters = [];
  bool _hasChapterChanges = false;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    context.read<FileUploadCubit>().resetState();
  }
  
  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.book.title);
    _descriptionController = TextEditingController(text: widget.book.description);
    _durationController = TextEditingController(text: widget.book.duration);
    _chaptersController = TextEditingController(text: widget.book.chaptersCount.toString());
    _countryController = TextEditingController(text: widget.book.country);
    _categoryController = TextEditingController(text: widget.book.category);
    
    _selectedLevel = widget.book.level;
    _selectedCategory = widget.book.courseCategory;
    _selectedIcon = widget.book.icon;
    _uploadType = widget.book.uploadType;

    if (_uploadType == BookUploadType.chapterWise && widget.book.chapters.isNotEmpty) {
      _chapters = widget.book.chapters.map((chapter) => ChapterUploadData(
        title: chapter.title,
        description: chapter.description,
        duration: chapter.duration,
        pdfFile: null,
        audioTracks: [],
        order: chapter.order,
        isNewOrModified: false,
        existingId: chapter.id,
      )).toList();
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _chaptersController.dispose();
    _countryController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
  
  Future<void> _pickPdfFile() async {
    final file = await context.read<FileUploadCubit>().pickPdfFile();
    if (file != null) {
      setState(() {
        _selectedPdfFile = file;
        _pdfFileName = file.path.split('/').last;
        _pdfSelected = true;
      });
    }
  }
  
  Future<void> _pickImageFile() async {
    final file = await context.read<FileUploadCubit>().pickImageFile();
    if (file != null) {
      setState(() {
        _selectedImageFile = file;
        _imageFileName = file.path.split('/').last;
        _imageSelected = true;
      });
    }
  }

  void _onAudioTracksChanged(List<AudioTrackUploadData> audioTracks) {
    setState(() {
      _audioTracks = audioTracks;
      _audioTracksChanged = true;
    });
  }

  void _onEditExistingAudio() {
    setState(() {
      _audioTracksChanged = true;
    });
  }

  Future<void> _addChapter() async {
    final result = await showDialog<ChapterUploadData>(
      context: context,
      builder: (context) => ChapterUploadDialog(
        chapterNumber: _chapters.length + 1,
        fileUploadCubit: context.read<FileUploadCubit>(),
        originalChapter: null,
      ),
    );

    if (result != null) {
      setState(() {
        _chapters.add(result);
        _hasChapterChanges = true;
      });
    }
  }

  void _removeChapter(int index) {
    setState(() {
      _chapters.removeAt(index);
      _hasChapterChanges = true;
      for (int i = 0; i < _chapters.length; i++) {
        _chapters[i] = _chapters[i].copyWith(order: i + 1);
      }
    });
  }

  void _editChapter(int index) async {
    final existingChapter = _chapters[index];
    final originalChapter = widget.book.chapters.firstWhere(
      (ch) => ch.id == existingChapter.existingId,
      orElse: () => widget.book.chapters.firstWhere(
        (ch) => ch.order == existingChapter.order,
        orElse: () => widget.book.chapters.first,
      ),
    );

    final result = await showDialog<ChapterUploadData>(
      context: context,
      builder: (context) => ChapterUploadDialog(
        chapterNumber: index + 1,
        fileUploadCubit: context.read<FileUploadCubit>(),
        existingChapter: existingChapter,
        existingAudioTracks: originalChapter.audioTracks,
        originalChapter: originalChapter,
      ),
    );

    if (result != null) {
      setState(() {
        _chapters[index] = result;
        if (!existingChapter.isNewOrModified || 
            existingChapter.title != result.title ||
            existingChapter.description != result.description ||
            existingChapter.duration != result.duration ||
            result.pdfFile != null ||
            result.audioTracks.length != existingChapter.audioTracks.length) {
          _hasChapterChanges = true;
        }
      });
    }
  }
  
  Future<void> _updateBook() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    try {
      final updatedBook = widget.book.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        duration: _durationController.text,
        chaptersCount: _uploadType == BookUploadType.singlePdf 
            ? (int.tryParse(_chaptersController.text) ?? widget.book.chaptersCount)
            : _chapters.length,
        icon: _selectedIcon,
        level: _selectedLevel,
        courseCategory: _selectedCategory,
        country: _countryController.text,
        category: _categoryController.text,
        uploadType: _uploadType,
      );
      
      bool success;
      if (_uploadType == BookUploadType.singlePdf) {
        success = await context.read<FileUploadCubit>().updateBook(
          widget.book.id,
          updatedBook,
          pdfFile: _selectedPdfFile,
          imageFile: _selectedImageFile,
          audioTracks: _audioTracksChanged ? _audioTracks : null,
        );
      } else {
        final chaptersToUpdate = _hasChapterChanges ? _chapters : null;
        success = await context.read<FileUploadCubit>().updateBookWithChapters(
          widget.book.id,
          updatedBook,
          chaptersToUpdate,
          imageFile: _selectedImageFile,
        );
      }
      
      if (success && mounted) {
        context.pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating book: $e')),
      );
    }
  }

  Widget _buildChapterWiseSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories_rounded,
                color: theme.colorScheme.primary,
                size: MediaQuery.of(context).size.width * 0.06,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Expanded(
                child: Text(
                  'Chapters (${_chapters.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isUploading ? null : _addChapter,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.03,
                    vertical: MediaQuery.of(context).size.height * 0.01,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          if (_chapters.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.08),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: MediaQuery.of(context).size.width * 0.12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Text(
                    'No chapters available',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    'Add chapters to update this book',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _chapters.length,
              separatorBuilder: (context, index) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.01,
              ),
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                final isModified = chapter.isNewOrModified;
                
                return Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isModified
                          ? theme.colorScheme.secondary.withValues(alpha: 0.3)
                          : theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isModified
                        ? theme.colorScheme.secondary.withValues(alpha: 0.05)
                        : theme.colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.1,
                        height: MediaQuery.of(context).size.width * 0.1,
                        decoration: BoxDecoration(
                          color: isModified
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outline.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isModified
                                  ? theme.colorScheme.onSecondary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chapter.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isModified)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: MediaQuery.of(context).size.width * 0.02,
                                      vertical: MediaQuery.of(context).size.height * 0.002,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Modified',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (chapter.description != null) ...[
                              SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                              Text(
                                chapter.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                            Row(
                              children: [
                                Text(
                                  chapter.pdfFile != null && chapter.pdfFile!.path.isNotEmpty
                                      ? 'File: ${chapter.pdfFile!.path.split('/').last}'
                                      : 'Using existing chapter file',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (chapter.hasAudio) ...[
                                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: MediaQuery.of(context).size.width * 0.02,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${chapter.audioTrackCount} AUDIO',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.tertiary,
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
                      PopupMenuButton<String>(
                        enabled: !isUploading,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editChapter(index);
                          } else if (value == 'delete') {
                            _removeChapter(index);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Edit Book',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<FileUploadCubit, FileUploadState>(
        listener: (context, state) {
          if (state is FileUploadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book updated successfully')),
            );
            if (state.book != null) {
              context.read<KoreanBooksCubit>().updateBookInState(state.book!);
            }
          } else if (state is FileUploadError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}')),
            );
          }
        },
        builder: (context, state) {
          bool isUploading = state is FileUploading;
          double uploadProgress = isUploading ? (state).progress : 0.0;
          
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.04,
                    vertical: MediaQuery.of(context).size.height * 0.02,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UploadTypeSelectionWidget(
                          uploadType: _uploadType,
                          onUploadTypeChanged: (type) => setState(() => _uploadType = type),
                          isEnabled: !isUploading,
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                        
                        BasicInfoSectionWidget(
                          titleController: _titleController,
                          descriptionController: _descriptionController,
                          isEnabled: !isUploading,
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                        BookDetailsSectionWidget(
                          durationController: _durationController,
                          countryController: _countryController,
                          categoryController: _categoryController,
                          chaptersController: _chaptersController,
                          selectedLevel: _selectedLevel,
                          selectedCategory: _selectedCategory,
                          onLevelChanged: (level) => setState(() => _selectedLevel = level),
                          onCategoryChanged: (category) => setState(() => _selectedCategory = category),
                          uploadType: _uploadType,
                          chaptersCount: _chapters.length,
                          isEnabled: !isUploading,
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                        if (_uploadType == BookUploadType.singlePdf) ...[
                          SinglePdfSectionWidget(
                            selectedPdfFile: _selectedPdfFile,
                            pdfFileName: _pdfFileName,
                            pdfSelected: _pdfSelected,
                            onPickPdf: _pickPdfFile,
                            isEnabled: !isUploading,
                            isEdit: true,
                            existingBook: widget.book,
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                          AudioSectionWidget(
                            audioTracks: _audioTracks,
                            onAudioTracksChanged: _onAudioTracksChanged,
                            isEnabled: !isUploading,
                            isEdit: true,
                            existingAudioTracks: widget.book.audioTracks,
                            audioTracksChanged: _audioTracksChanged,
                            onEditExistingAudio: _onEditExistingAudio,
                          ),
                        ] else
                          _buildChapterWiseSection(context, theme, isUploading),
                        
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                        CoverImageSectionWidget(
                          selectedImageFile: _selectedImageFile,
                          imageFileName: _imageFileName,
                          imageSelected: _imageSelected,
                          onPickImage: _pickImageFile,
                          isEnabled: !isUploading,
                          isEdit: true,
                          existingBook: widget.book,
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (isUploading) 
                ProgressSectionWidget(
                  progress: uploadProgress,
                  isUpdate: true,
                ),
              
              BottomActionButtonWidget(
                onPressed: _updateBook,
                isLoading: isUploading,
                isEnabled: !isUploading,
                label: 'Save Changes',
                loadingLabel: 'Updating...',
                icon: Icons.save_rounded,
                loadingIcon: Icons.hourglass_top_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}