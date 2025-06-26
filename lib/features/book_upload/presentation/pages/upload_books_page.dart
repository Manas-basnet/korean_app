import 'package:flutter/material.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/file_upload_type.dart';
import 'package:korean_language_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

class BookUploadPage extends StatefulWidget {
  const BookUploadPage({super.key});

  @override
  State<BookUploadPage> createState() => _BookUploadPageState();
}

class _BookUploadPageState extends State<BookUploadPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30 mins');
  final _countryController = TextEditingController(text: 'Korea');
  final _categoryController = TextEditingController(text: 'Language');

  BookLevel _selectedLevel = BookLevel.beginner;
  CourseCategory _selectedCategory = CourseCategory.korean;
  IconData _selectedIcon = Icons.book;
  BookUploadType _uploadType = BookUploadType.singlePdf;

  File? _selectedPdfFile;
  String? _pdfFileName;
  bool _pdfSelected = false;

  File? _selectedImageFile;
  String? _imageFileName;
  bool _imageSelected = false;

  // Chapter-wise upload data
  List<ChapterUploadData> _chapters = [];
  late TabController _tabController;

  late KoreanBooksCubit _koreanBooksCubit;
  late FileUploadCubit _fileUploadCubit;

  @override
  void initState() {
    super.initState();
    _fileUploadCubit = context.read<FileUploadCubit>();
    _koreanBooksCubit = context.read<KoreanBooksCubit>();
    _tabController = TabController(length: 2, vsync: this);
    initialize();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _countryController.dispose();
    _categoryController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  initialize() {
    _fileUploadCubit.resetState();
  }

  Future<void> _pickPdfFile() async {
    final file = await _fileUploadCubit.pickPdfFile();
    if (file != null) {
      setState(() {
        _selectedPdfFile = file;
        _pdfFileName = file.path.split('/').last;
        _pdfSelected = true;
      });
    }
  }

  Future<void> _pickImageFile() async {
    final file = await _fileUploadCubit.pickImageFile();
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
        fileUploadCubit: _fileUploadCubit,
      ),
    );

    if (result != null) {
      setState(() {
        _chapters.add(result);
      });
    }
  }

  void _removeChapter(int index) {
    setState(() {
      _chapters.removeAt(index);
      // Update order for remaining chapters
      for (int i = 0; i < _chapters.length; i++) {
        _chapters[i] = _chapters[i].copyWith(order: i + 1);
      }
    });
  }

  void _editChapter(int index) async {
    final result = await showDialog<ChapterUploadData>(
      context: context,
      builder: (context) => _ChapterUploadDialog(
        chapterNumber: index + 1,
        fileUploadCubit: _fileUploadCubit,
        existingChapter: _chapters[index],
      ),
    );

    if (result != null) {
      setState(() {
        _chapters[index] = result;
      });
    }
  }

  Future<void> _uploadBook() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_uploadType == BookUploadType.singlePdf && _selectedPdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file')),
      );
      return;
    }

    if (_uploadType == BookUploadType.chapterWise && _chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one chapter')),
      );
      return;
    }

    try {
      final authState = context.read<AuthCubit>().state;
      String? creatorUid;

      if (authState is Authenticated) {
        creatorUid = authState.user.uid;
      }

      final book = BookItem(
        id: '',
        title: _titleController.text,
        description: _descriptionController.text,
        bookImage: null,
        pdfUrl: null,
        duration: _durationController.text,
        chaptersCount: _uploadType == BookUploadType.singlePdf ? 1 : _chapters.length,
        icon: _selectedIcon,
        level: _selectedLevel,
        courseCategory: _selectedCategory,
        country: _countryController.text,
        category: _categoryController.text,
        creatorUid: creatorUid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        uploadType: _uploadType,
        chapters: [],
      );

      bool success;
      if (_uploadType == BookUploadType.singlePdf) {
        success = await _fileUploadCubit.uploadBook(
          book,
          _selectedPdfFile!,
          _selectedImageFile,
        );
      } else {
        success = await _fileUploadCubit.uploadBookWithChapters(
          book,
          _chapters,
          _selectedImageFile,
        );
      }

      if (success) {
        final uploadState = _fileUploadCubit.state;
        if (uploadState is FileUploadSuccess && uploadState.book != null) {
          _koreanBooksCubit.addBookToState(uploadState.book!);
        }

        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book uploaded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating upload: $e')),
      );
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _durationController.text = '30 mins';
    _countryController.text = 'Korea';
    _categoryController.text = 'Language';
    setState(() {
      _selectedLevel = BookLevel.beginner;
      _selectedCategory = CourseCategory.korean;
      _selectedIcon = Icons.book;
      _uploadType = BookUploadType.singlePdf;
      _selectedPdfFile = null;
      _pdfFileName = null;
      _pdfSelected = false;
      _selectedImageFile = null;
      _imageFileName = null;
      _imageSelected = false;
      _chapters.clear();
    });
    _fileUploadCubit.resetState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Upload New Book',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: BlocConsumer<FileUploadCubit, FileUploadState>(
        listener: (context, state) {
          if (state is FileUploadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book uploaded successfully')),
            );

            if (state.book != null) {
              _koreanBooksCubit.addBookToState(state.book!);
            }

            _resetForm();
          } else if (state is FileUploadError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}')),
            );
          }
        },
        builder: (context, state) {
          bool isUploading = state is FileUploading;
          double uploadProgress = isUploading ? (state).progress : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUploadTypeSelection(theme),
                  const SizedBox(height: 24),
                  
                  _buildBasicInfoSection(theme, isUploading),
                  const SizedBox(height: 24),

                  _buildBookDetailsSection(theme, isUploading),
                  const SizedBox(height: 24),

                  if (_uploadType == BookUploadType.singlePdf)
                    _buildSinglePdfSection(theme, isUploading)
                  else
                    _buildChapterWiseSection(theme, isUploading),
                  
                  const SizedBox(height: 24),
                  _buildCoverImageSection(theme, isUploading),
                  const SizedBox(height: 32),

                  if (isUploading) _buildProgressSection(uploadProgress, colorScheme),

                  _buildUploadButton(theme, colorScheme, isUploading),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadTypeSelection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Type',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: BookUploadType.values.map((type) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _uploadType = type),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _uploadType == type
                                ? theme.colorScheme.primary
                                : Colors.grey.withOpacity(0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _uploadType == type
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              type == BookUploadType.singlePdf
                                  ? Icons.picture_as_pdf
                                  : Icons.auto_stories,
                              size: 32,
                              color: _uploadType == type
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              type.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _uploadType == type
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.description,
                              style: theme.textTheme.bodySmall,
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
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme, bool isUploading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Book Title',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.book),
          ),
          enabled: !isUploading,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Book Description',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
            alignLabelWithHint: true,
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
    );
  }

  Widget _buildBookDetailsSection(ThemeData theme, bool isUploading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Book Details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
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
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
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
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<BookLevel>(
                value: _selectedLevel,
                decoration: const InputDecoration(
                  labelText: 'Level',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bar_chart),
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
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<CourseCategory>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Course Category',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.school),
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
      ],
    );
  }

  Widget _buildSinglePdfSection(ThemeData theme, bool isUploading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Book PDF File (Required)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        BlocBuilder<FileUploadCubit, FileUploadState>(
          builder: (context, fileState) {
            bool isPdfPickerLoading = fileState is FilePickerLoading &&
                fileState.fileType == FileUploadType.pdf;

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _pdfSelected ? Colors.green : Colors.grey,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _pdfSelected ? Icons.check_circle : Icons.picture_as_pdf,
                        color: _pdfSelected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pdfFileName ?? 'No PDF selected',
                          style: TextStyle(
                            color: _pdfSelected ? Colors.green : Colors.grey,
                            fontWeight: _pdfSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (fileState is FilePickerError && fileState.fileType == FileUploadType.pdf)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        fileState.message,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isUploading || isPdfPickerLoading) ? null : _pickPdfFile,
                      icon: isPdfPickerLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(isPdfPickerLoading ? 'Selecting...' : 'Select PDF File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChapterWiseSection(ThemeData theme, bool isUploading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chapters (${_chapters.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: isUploading ? null : _addChapter,
              icon: const Icon(Icons.add),
              label: const Text('Add Chapter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
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
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_stories, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No chapters added yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add chapters by clicking the "Add Chapter" button above',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final chapter = _chapters[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chapter.description != null)
                        Text(chapter.description!),
                      Text(
                        'File: ${chapter.pdfFile.path.split('/').last}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    enabled: !isUploading,
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
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCoverImageSection(ThemeData theme, bool isUploading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Book Cover Image (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        BlocBuilder<FileUploadCubit, FileUploadState>(
          builder: (context, fileState) {
            bool isImagePickerLoading = fileState is FilePickerLoading &&
                fileState.fileType == FileUploadType.image;

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _imageSelected ? Colors.green : Colors.grey,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedImageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImageFile!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (_selectedImageFile != null) const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        _imageSelected ? Icons.check_circle : Icons.image,
                        color: _imageSelected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _imageFileName ?? 'No image selected',
                          style: TextStyle(
                            color: _imageSelected ? Colors.green : Colors.grey,
                            fontWeight: _imageSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (fileState is FilePickerError && fileState.fileType == FileUploadType.image)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        fileState.message,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isUploading || isImagePickerLoading) ? null : _pickImageFile,
                      icon: isImagePickerLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(isImagePickerLoading ? 'Selecting...' : 'Select Cover Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressSection(double uploadProgress, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: uploadProgress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading ${(uploadProgress * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: colorScheme.primary),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUploadButton(ThemeData theme, ColorScheme colorScheme, bool isUploading) {
    final canUpload = (_uploadType == BookUploadType.singlePdf && _pdfSelected) ||
        (_uploadType == BookUploadType.chapterWise && _chapters.isNotEmpty);

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: (isUploading || !canUpload) ? null : _uploadBook,
        icon: Icon(isUploading ? Icons.hourglass_top : Icons.cloud_upload),
        label: Text(isUploading ? 'Uploading...' : 'Upload Book'),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: Colors.grey,
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
      _fileName = widget.existingChapter!.pdfFile.path.split('/').last;
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
      });
    }
  }

  void _saveChapter() {
    if (_formKey.currentState?.validate() != true || _selectedFile == null) {
      return;
    }

    final chapter = ChapterUploadData(
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      duration: _durationController.text.isEmpty ? null : _durationController.text,
      pdfFile: _selectedFile!,
      order: widget.chapterNumber,
    );

    Navigator.of(context).pop(chapter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.existingChapter != null ? 'Edit Chapter' : 'Add Chapter'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Chapter Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _selectedFile != null ? Icons.check_circle : Icons.picture_as_pdf,
                          color: _selectedFile != null ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fileName ?? 'No PDF selected',
                            style: TextStyle(
                              color: _selectedFile != null ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Select PDF File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedFile != null ? _saveChapter : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}