import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/file_upload_type.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

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

  Future<void> _addChapter() async {
    final result = await showDialog<ChapterUploadData>(
      context: context,
      builder: (context) => _ChapterUploadDialog(
        chapterNumber: _chapters.length + 1,
        fileUploadCubit: context.read<FileUploadCubit>(),
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
    final result = await showDialog<ChapterUploadData>(
      context: context,
      builder: (context) => _ChapterUploadDialog(
        chapterNumber: index + 1,
        fileUploadCubit: context.read<FileUploadCubit>(),
        existingChapter: existingChapter,
      ),
    );

    if (result != null) {
      setState(() {
        _chapters[index] = result;
        if (!existingChapter.isNewOrModified || 
            existingChapter.title != result.title ||
            existingChapter.description != result.description ||
            existingChapter.duration != result.duration ||
            result.pdfFile != null) {
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
            Navigator.of(context).pop(true);
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
                    horizontal: MediaQuery.sizeOf(context).width * 0.04,
                    vertical: MediaQuery.sizeOf(context).height * 0.02,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUploadTypeSelection(context, theme, isUploading),
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),
                        
                        _buildBasicInfoSection(context, theme, isUploading),
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

                        _buildBookDetailsSection(context, theme, isUploading),
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

                        if (_uploadType == BookUploadType.singlePdf)
                          _buildSinglePdfSection(context, theme, isUploading)
                        else
                          _buildChapterWiseSection(context, theme, isUploading),
                        
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),
                        _buildCoverImageSection(context, theme, isUploading),
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.04),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (isUploading) _buildProgressSection(context, uploadProgress, colorScheme),
              
              _buildBottomUpdateButton(context, theme, colorScheme, isUploading),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUploadTypeSelection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Type',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          Row(
            children: BookUploadType.values.map((type) {
              final isSelected = _uploadType == type;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: type == BookUploadType.values.first 
                        ? MediaQuery.sizeOf(context).width * 0.02 
                        : 0,
                  ),
                  child: InkWell(
                    onTap: isUploading ? null : () => setState(() => _uploadType = type),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.3),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.08)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == BookUploadType.singlePdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.auto_stories_rounded,
                            size: MediaQuery.sizeOf(context).width * 0.08,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          SizedBox(height: MediaQuery.sizeOf(context).height * 0.01),
                          Text(
                            type.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: MediaQuery.sizeOf(context).height * 0.005),
                          Text(
                            type.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Book Title',
              hintText: 'Enter book title',
              prefixIcon: const Icon(Icons.book_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            enabled: !isUploading,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Book Description',
              hintText: 'Enter book description',
              prefixIcon: const Icon(Icons.description_rounded),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            enabled: !isUploading,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookDetailsSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _durationController,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    hintText: '30 mins',
                    prefixIcon: const Icon(Icons.timer_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  enabled: !isUploading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * 0.03),
              if (_uploadType == BookUploadType.singlePdf)
                Expanded(
                  child: TextFormField(
                    controller: _chaptersController,
                    decoration: InputDecoration(
                      labelText: 'Chapters',
                      hintText: '1',
                      prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    enabled: !isUploading,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Numbers only';
                      }
                      return null;
                    },
                  ),
                )
              else
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width * 0.04,
                      vertical: MediaQuery.sizeOf(context).height * 0.02,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surface,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_list_numbered_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        SizedBox(width: MediaQuery.sizeOf(context).width * 0.03),
                        Text(
                          'Chapters: ${_chapters.length}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: 'Country',
                    hintText: 'Korea',
                    prefixIcon: const Icon(Icons.public_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  enabled: !isUploading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * 0.03),
              Expanded(
                child: TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: 'Language',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  enabled: !isUploading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<BookLevel>(
                  value: _selectedLevel,
                  decoration: InputDecoration(
                    labelText: 'Level',
                    prefixIcon: const Icon(Icons.bar_chart_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  items: BookLevel.values.map((level) {
                    return DropdownMenuItem<BookLevel>(
                      value: level,
                      child: Text(level.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: isUploading
                      ? null
                      : (BookLevel? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedLevel = newValue;
                            });
                          }
                        },
                ),
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * 0.03),
              Expanded(
                child: DropdownButtonFormField<CourseCategory>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Course Category',
                    prefixIcon: const Icon(Icons.school_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  items: CourseCategory.values.map((category) {
                    if (category == CourseCategory.favorite) {
                      return null;
                    }
                    return DropdownMenuItem<CourseCategory>(
                      value: category,
                      child: Text(category.toString().split('.').last),
                    );
                  }).where((item) => item != null).cast<DropdownMenuItem<CourseCategory>>().toList(),
                  onChanged: isUploading
                      ? null
                      : (CourseCategory? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePdfSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                color: theme.colorScheme.primary,
                size: MediaQuery.sizeOf(context).width * 0.06,
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * 0.02),
              Text(
                'Update PDF File',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width * 0.02,
                  vertical: MediaQuery.sizeOf(context).height * 0.005,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Optional',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          
          BlocBuilder<FileUploadCubit, FileUploadState>(
            builder: (context, fileState) {
              bool isPdfPickerLoading = fileState is FilePickerLoading &&
                  fileState.fileType == FileUploadType.pdf;

              return Container(
                padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _pdfSelected 
                        ? theme.colorScheme.primary.withOpacity(0.5)
                        : theme.colorScheme.outline.withOpacity(0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _pdfSelected 
                      ? theme.colorScheme.primary.withOpacity(0.05)
                      : theme.colorScheme.surface,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.02),
                          decoration: BoxDecoration(
                            color: _pdfSelected 
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : theme.colorScheme.outline.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _pdfSelected ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                            color: _pdfSelected 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            size: MediaQuery.sizeOf(context).width * 0.05,
                          ),
                        ),
                        SizedBox(width: MediaQuery.sizeOf(context).width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pdfFileName ?? 
                                (widget.book.pdfUrl != null 
                                    ? 'Current PDF: ${widget.book.id}.pdf' 
                                    : 'No PDF selected'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _pdfSelected 
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: _pdfSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_pdfSelected)
                                Text(
                                  'New PDF file ready for upload',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary.withOpacity(0.8),
                                  ),
                                )
                              else if (widget.book.pdfUrl != null)
                                Text(
                                  'Keep current PDF or select new one',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fileState is FilePickerError && fileState.fileType == FileUploadType.pdf) ...[
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.01),
                      Container(
                        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.03),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: MediaQuery.sizeOf(context).width * 0.04,
                            ),
                            SizedBox(width: MediaQuery.sizeOf(context).width * 0.02),
                            Expanded(
                              child: Text(
                                fileState.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isUploading || isPdfPickerLoading) ? null : _pickPdfFile,
                        icon: isPdfPickerLoading
                            ? SizedBox(
                                width: MediaQuery.sizeOf(context).width * 0.04,
                                height: MediaQuery.sizeOf(context).width * 0.04,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(isPdfPickerLoading ? 'Selecting...' : 'Select New PDF File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                            vertical: MediaQuery.sizeOf(context).height * 0.015,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
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

  Widget _buildChapterWiseSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
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
                size: MediaQuery.sizeOf(context).width * 0.06,
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * 0.02),
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
                    horizontal: MediaQuery.sizeOf(context).width * 0.03,
                    vertical: MediaQuery.sizeOf(context).height * 0.01,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          
          if (_chapters.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.08),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: MediaQuery.sizeOf(context).width * 0.12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
                  Text(
                    'No chapters available',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.01),
                  Text(
                    'Add chapters to update this book',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                height: MediaQuery.sizeOf(context).height * 0.01,
              ),
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                final isModified = chapter.isNewOrModified;
                
                return Container(
                  padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isModified
                          ? theme.colorScheme.secondary.withOpacity(0.3)
                          : theme.colorScheme.outline.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isModified
                        ? theme.colorScheme.secondary.withOpacity(0.05)
                        : theme.colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: MediaQuery.sizeOf(context).width * 0.1,
                        height: MediaQuery.sizeOf(context).width * 0.1,
                        decoration: BoxDecoration(
                          color: isModified
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outline.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isModified
                                  ? theme.colorScheme.onSecondary
                                  : theme.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.sizeOf(context).width * 0.03),
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
                                      horizontal: MediaQuery.sizeOf(context).width * 0.02,
                                      vertical: MediaQuery.sizeOf(context).height * 0.002,
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
                              SizedBox(height: MediaQuery.sizeOf(context).height * 0.005),
                              Text(
                                chapter.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            SizedBox(height: MediaQuery.sizeOf(context).height * 0.005),
                            Text(
                              chapter.pdfFile != null && chapter.pdfFile!.path.isNotEmpty
                                  ? 'File: ${chapter.pdfFile!.path.split('/').last}'
                                  : 'Using existing chapter file',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !isUploading,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildCoverImageSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_rounded,
                color: theme.colorScheme.secondary,
                size: MediaQuery.sizeOf(context).width * 0.06,
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * 0.02),
              Text(
                'Update Cover Image',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width * 0.02,
                  vertical: MediaQuery.sizeOf(context).height * 0.005,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Optional',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          
          BlocBuilder<FileUploadCubit, FileUploadState>(
            builder: (context, fileState) {
              bool isImagePickerLoading = fileState is FilePickerLoading &&
                  fileState.fileType == FileUploadType.image;

              return Container(
                padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _imageSelected 
                        ? theme.colorScheme.secondary.withOpacity(0.5)
                        : theme.colorScheme.outline.withOpacity(0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _imageSelected 
                      ? theme.colorScheme.secondary.withOpacity(0.05)
                      : theme.colorScheme.surface,
                ),
                child: Column(
                  children: [
                    if (_selectedImageFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImageFile!,
                          height: MediaQuery.sizeOf(context).height * 0.2,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
                    ] else if (widget.book.bookImage != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.book.bookImage!,
                          height: MediaQuery.sizeOf(context).height * 0.2,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: MediaQuery.sizeOf(context).height * 0.2,
                            color: theme.colorScheme.outline.withOpacity(0.1),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: MediaQuery.sizeOf(context).height * 0.2,
                            color: theme.colorScheme.outline.withOpacity(0.1),
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                size: MediaQuery.sizeOf(context).width * 0.12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
                    ],
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.02),
                          decoration: BoxDecoration(
                            color: _imageSelected 
                                ? theme.colorScheme.secondary.withOpacity(0.1)
                                : theme.colorScheme.outline.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _imageSelected ? Icons.check_circle_rounded : Icons.image_rounded,
                            color: _imageSelected 
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            size: MediaQuery.sizeOf(context).width * 0.05,
                          ),
                        ),
                        SizedBox(width: MediaQuery.sizeOf(context).width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _imageFileName ?? 
                                (widget.book.bookImage != null 
                                    ? 'Current cover image' 
                                    : 'No image selected'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _imageSelected 
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: _imageSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_imageSelected)
                                Text(
                                  'New image ready for upload',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary.withOpacity(0.8),
                                  ),
                                )
                              else if (widget.book.bookImage != null)
                                Text(
                                  'Keep current image or select new one',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fileState is FilePickerError && fileState.fileType == FileUploadType.image) ...[
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.01),
                      Container(
                        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.03),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: MediaQuery.sizeOf(context).width * 0.04,
                            ),
                            SizedBox(width: MediaQuery.sizeOf(context).width * 0.02),
                            Expanded(
                              child: Text(
                                fileState.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isUploading || isImagePickerLoading) ? null : _pickImageFile,
                        icon: isImagePickerLoading
                            ? SizedBox(
                                width: MediaQuery.sizeOf(context).width * 0.04,
                                height: MediaQuery.sizeOf(context).width * 0.04,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onSecondary,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(isImagePickerLoading ? 'Selecting...' : 'Select New Cover Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          padding: EdgeInsets.symmetric(
                            vertical: MediaQuery.sizeOf(context).height * 0.015,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
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

  Widget _buildProgressSection(BuildContext context, double uploadProgress, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                color: colorScheme.primary,
                size: MediaQuery.sizeOf(context).width * 0.05,
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width * 0.02),
              Text(
                'Updating ${(uploadProgress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.01),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: uploadProgress,
              backgroundColor: colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: MediaQuery.sizeOf(context).height * 0.008,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomUpdateButton(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.06,
          child: ElevatedButton.icon(
            onPressed: isUploading ? null : _updateBook,
            icon: Icon(
              isUploading ? Icons.hourglass_top_rounded : Icons.save_rounded,
              size: MediaQuery.sizeOf(context).width * 0.05,
            ),
            label: Text(
              isUploading ? 'Updating...' : 'Save Changes',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              disabledBackgroundColor: colorScheme.outline.withOpacity(0.3),
              disabledForegroundColor: colorScheme.onSurface.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterUploadDialog extends StatefulWidget {
  final int chapterNumber;
  final FileUploadCubit fileUploadCubit;
  final ChapterUploadData? existingChapter;

  const _ChapterUploadDialog({
    required this.chapterNumber,
    required this.fileUploadCubit,
    this.existingChapter,
  });

  @override
  State<_ChapterUploadDialog> createState() => _ChapterUploadDialogState();
}

class _ChapterUploadDialogState extends State<_ChapterUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;

  File? _selectedFile;
  String? _fileName;
  bool _fileChanged = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingChapter?.title ?? 'Chapter ${widget.chapterNumber}',
    );
    _descriptionController = TextEditingController(
      text: widget.existingChapter?.description ?? '',
    );
    _durationController = TextEditingController(
      text: widget.existingChapter?.duration ?? '10 mins',
    );

    if (widget.existingChapter != null) {
      _selectedFile = widget.existingChapter!.pdfFile;
      if (_selectedFile != null && _selectedFile!.path.isNotEmpty) {
        _fileName = _selectedFile!.path.split('/').last;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await widget.fileUploadCubit.pickPdfFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _fileName = file.path.split('/').last;
        _fileChanged = true;
      });
    }
  }

  void _saveChapter() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    bool isModified = widget.existingChapter == null ||
        widget.existingChapter!.title != _titleController.text ||
        widget.existingChapter!.description != _descriptionController.text ||
        widget.existingChapter!.duration != _durationController.text ||
        _fileChanged;

    final chapter = ChapterUploadData(
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      duration: _durationController.text.isEmpty ? null : _durationController.text,
      pdfFile: _fileChanged ? _selectedFile : null,
      order: widget.chapterNumber,
      isNewOrModified: isModified,
      existingId: widget.existingChapter?.existingId,
    );

    Navigator.of(context).pop(chapter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.sizeOf(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.height * 0.8,
          maxWidth: mediaQuery.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(mediaQuery.width * 0.04),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: theme.colorScheme.primary,
                    size: mediaQuery.width * 0.06,
                  ),
                  SizedBox(width: mediaQuery.width * 0.02),
                  Expanded(
                    child: Text(
                      widget.existingChapter != null ? 'Edit Chapter' : 'Add Chapter',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(mediaQuery.width * 0.04),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Chapter Title',
                          hintText: 'Enter chapter title',
                          prefixIcon: const Icon(Icons.title_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: mediaQuery.height * 0.02),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Enter chapter description',
                          prefixIcon: const Icon(Icons.description_rounded),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: mediaQuery.height * 0.02),
                      TextFormField(
                        controller: _durationController,
                        decoration: InputDecoration(
                          labelText: 'Duration (Optional)',
                          hintText: '10 mins',
                          prefixIcon: const Icon(Icons.timer_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                      ),
                      SizedBox(height: mediaQuery.height * 0.02),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(mediaQuery.width * 0.04),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _fileChanged
                                ? theme.colorScheme.primary.withOpacity(0.5)
                                : theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _fileChanged
                              ? theme.colorScheme.primary.withOpacity(0.05)
                              : theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(mediaQuery.width * 0.02),
                                  decoration: BoxDecoration(
                                    color: _fileChanged
                                        ? theme.colorScheme.primary.withOpacity(0.1)
                                        : theme.colorScheme.outline.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _fileChanged ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                                    color: _fileChanged
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withOpacity(0.6),
                                    size: mediaQuery.width * 0.05,
                                  ),
                                ),
                                SizedBox(width: mediaQuery.width * 0.03),
                                Expanded(
                                  child: Text(
                                    _fileName ?? (widget.existingChapter != null 
                                        ? 'Use existing chapter file' 
                                        : 'No PDF selected'),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: _fileChanged
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withOpacity(0.7),
                                      fontWeight: _fileChanged ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: mediaQuery.height * 0.015),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: Text(widget.existingChapter != null 
                                    ? 'Change PDF File' 
                                    : 'Select PDF File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: EdgeInsets.symmetric(
                                    vertical: mediaQuery.height * 0.015,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Container(
              padding: EdgeInsets.all(mediaQuery.width * 0.04),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.width * 0.04,
                        vertical: mediaQuery.height * 0.015,
                      ),
                    ),
                  ),
                  SizedBox(width: mediaQuery.width * 0.02),
                  ElevatedButton(
                    onPressed: _saveChapter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.width * 0.04,
                        vertical: mediaQuery.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Save Chapter'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}