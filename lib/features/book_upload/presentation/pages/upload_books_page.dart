import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/models/chapter_info.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/pages/book_editing_page.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/file_upload_type.dart';
import 'package:korean_language_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/shared/widgets/audio_recorder.dart';
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

  File? _selectedAudioFile;

  List<ChapterUploadData> _chapters = [];
  late TabController _tabController;

  late FileUploadCubit _fileUploadCubit;

  @override
  void initState() {
    super.initState();
    _fileUploadCubit = context.read<FileUploadCubit>();
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

  void _onAudioSelected(File audioFile) {
    setState(() {
      _selectedAudioFile = audioFile;
    });
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

  Future<void> _showBookEditingMode() async {
    final pdfFile = await _fileUploadCubit.pickPdfFile();
    if (pdfFile == null) return;

    if (!mounted) return;

    context.push(
      Routes.bookEditingPage, 
      extra: BookEditingPage(
        sourcePdf: pdfFile,
        onChaptersGenerated: (chapterFiles, chapterInfos) {
          _handleChaptersFromEditor(chapterFiles, chapterInfos);
        },
      ),
    );
  }

  void _handleChaptersFromEditor(List<File> chapterFiles, List<ChapterInfo> chapterInfos) {
    setState(() {
      _chapters.clear();
      for (int i = 0; i < chapterFiles.length && i < chapterInfos.length; i++) {
        final chapterInfo = chapterInfos[i];
        final chapterFile = chapterFiles[i];
        
        _chapters.add(ChapterUploadData(
          title: chapterInfo.title,
          description: chapterInfo.description,
          duration: chapterInfo.duration,
          pdfFile: chapterFile,
          order: chapterInfo.chapterNumber,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${chapterFiles.length} chapters generated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeChapter(int index) {
    setState(() {
      _chapters.removeAt(index);
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
          audioFile: _selectedAudioFile,
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
          context.read<KoreanBooksCubit>().addBookToState(uploadState.book!);
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
      _selectedAudioFile = null;
      _chapters.clear();
    });
    _fileUploadCubit.resetState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Upload New Book',
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
              const SnackBar(content: Text('Book uploaded successfully')),
            );

            if (state.book != null) {
              context.read<KoreanBooksCubit>().addBookToState(state.book!);
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
                        _buildUploadTypeSelection(context, theme),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                        
                        _buildBasicInfoSection(context, theme, isUploading),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                        _buildBookDetailsSection(context, theme, isUploading),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                        if (_uploadType == BookUploadType.singlePdf) ...[
                          _buildSinglePdfSection(context, theme, isUploading),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                          _buildAudioSection(context, theme, isUploading),
                        ] else
                          _buildChapterWiseSection(context, theme, isUploading),
                        
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                        _buildCoverImageSection(context, theme, isUploading),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (isUploading) _buildProgressSection(context, uploadProgress, colorScheme),
              
              _buildBottomUploadButton(context, theme, colorScheme, isUploading),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUploadTypeSelection(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Row(
            children: BookUploadType.values.map((type) {
              final isSelected = _uploadType == type;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: type == BookUploadType.values.first 
                        ? MediaQuery.of(context).size.width * 0.02 
                        : 0,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _uploadType = type),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                            size: MediaQuery.of(context).size.width * 0.08,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                          Text(
                            type.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.005),
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
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
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
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
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
              SizedBox(width: MediaQuery.of(context).size.width * 0.03),
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
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          TextFormField(
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          DropdownButtonFormField<BookLevel>(
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
            isDense: true,
            items: BookLevel.values.map((level) {
              return DropdownMenuItem<BookLevel>(
                value: level,
                child: Text(
                  level.toString().split('.').last,
                  overflow: TextOverflow.ellipsis,
                ),
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          DropdownButtonFormField<CourseCategory>(
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
            isDense: true,
            items: CourseCategory.values.map((category) {
              if (category == CourseCategory.favorite) {
                return null;
              }
              return DropdownMenuItem<CourseCategory>(
                value: category,
                child: Text(
                  category.toString().split('.').last,
                  overflow: TextOverflow.ellipsis,
                ),
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
      ),
    );
  }

  Widget _buildSinglePdfSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                size: MediaQuery.of(context).size.width * 0.06,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                'Book PDF File',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.02,
                  vertical: MediaQuery.of(context).size.height * 0.005,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Required',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          BlocBuilder<FileUploadCubit, FileUploadState>(
            builder: (context, fileState) {
              bool isPdfPickerLoading = fileState is FilePickerLoading &&
                  fileState.fileType == FileUploadType.pdf;

              return Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                          decoration: BoxDecoration(
                            color: _pdfSelected 
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : theme.colorScheme.outline.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _pdfSelected ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                            color: _pdfSelected 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            size: MediaQuery.of(context).size.width * 0.05,
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pdfFileName ?? 'No PDF selected',
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
                                  'PDF file ready for upload',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fileState is FilePickerError && fileState.fileType == FileUploadType.pdf) ...[
                      SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                      Container(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: MediaQuery.of(context).size.width * 0.04,
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
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
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isUploading || isPdfPickerLoading) ? null : _pickPdfFile,
                        icon: isPdfPickerLoading
                            ? SizedBox(
                                width: MediaQuery.of(context).size.width * 0.04,
                                height: MediaQuery.of(context).size.width * 0.04,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(isPdfPickerLoading ? 'Selecting...' : 'Select PDF File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                            vertical: MediaQuery.of(context).size.height * 0.015,
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

  Widget _buildAudioSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                Icons.audiotrack_rounded,
                color: theme.colorScheme.tertiary,
                size: MediaQuery.of(context).size.width * 0.06,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                'Audio Track',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.02,
                  vertical: MediaQuery.of(context).size.height * 0.005,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Optional',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          if (_selectedAudioFile != null) ...[
            AudioPlayerWidget(
              audioPath: _selectedAudioFile!.path,
              label: 'Selected Audio Track',
              onRemove: () => setState(() {
                _selectedAudioFile = null;
              }),
            ),
          ] else ...[
            AudioRecorderWidget(
              onAudioSelected: _onAudioSelected,
              label: 'Record or select audio track for this book',
            ),
          ],
          
          BlocBuilder<FileUploadCubit, FileUploadState>(
            builder: (context, fileState) {
              if (fileState is FilePickerError && fileState.fileType == FileUploadType.audio) {
                return Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.01),
                  child: Container(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: theme.colorScheme.error,
                          size: MediaQuery.of(context).size.width * 0.04,
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.02),
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChapterWiseSection(BuildContext context, ThemeData theme, bool isUploading) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
              if (_chapters.isEmpty) ...[
                ElevatedButton.icon(
                  onPressed: isUploading ? null : _showBookEditingMode,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Smart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
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
                SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              ],
              ElevatedButton.icon(
                onPressed: isUploading ? null : _addChapter,
                icon: const Icon(Icons.add_rounded),
                label: Text(_chapters.isEmpty ? 'Manual' : 'Add'),
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
                    size: MediaQuery.of(context).size.width * 0.12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Text(
                    'No chapters added yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    'Use Smart Editor for automatic extraction\nor add chapters manually',
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
                height: MediaQuery.of(context).size.height * 0.01,
              ),
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.1,
                        height: MediaQuery.of(context).size.width * 0.1,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimary,
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
                            Text(
                              chapter.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (chapter.description != null) ...[
                              SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                              Text(
                                chapter.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                            Row(
                              children: [
                                Text(
                                  'PDF: ${chapter.pdfFile?.path.split('/').last ?? 'None'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                                      color: theme.colorScheme.tertiary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'AUDIO',
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
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                size: MediaQuery.of(context).size.width * 0.06,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                'Cover Image',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.02,
                  vertical: MediaQuery.of(context).size.height * 0.005,
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          BlocBuilder<FileUploadCubit, FileUploadState>(
            builder: (context, fileState) {
              bool isImagePickerLoading = fileState is FilePickerLoading &&
                  fileState.fileType == FileUploadType.image;

              return Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                          height: MediaQuery.of(context).size.height * 0.2,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    ],
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
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
                            size: MediaQuery.of(context).size.width * 0.05,
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _imageFileName ?? 'No image selected',
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
                                  'Image ready for upload',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (fileState is FilePickerError && fileState.fileType == FileUploadType.image) ...[
                      SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                      Container(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: MediaQuery.of(context).size.width * 0.04,
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
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
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isUploading || isImagePickerLoading) ? null : _pickImageFile,
                        icon: isImagePickerLoading
                            ? SizedBox(
                                width: MediaQuery.of(context).size.width * 0.04,
                                height: MediaQuery.of(context).size.width * 0.04,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onSecondary,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(isImagePickerLoading ? 'Selecting...' : 'Select Cover Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          padding: EdgeInsets.symmetric(
                            vertical: MediaQuery.of(context).size.height * 0.015,
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
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                size: MediaQuery.of(context).size.width * 0.05,
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                'Uploading ${(uploadProgress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: uploadProgress,
              backgroundColor: colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: MediaQuery.of(context).size.height * 0.008,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomUploadButton(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isUploading) {
    final canUpload = (_uploadType == BookUploadType.singlePdf && _pdfSelected) ||
        (_uploadType == BookUploadType.chapterWise && _chapters.isNotEmpty);

    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
          height: MediaQuery.of(context).size.height * 0.06,
          child: ElevatedButton.icon(
            onPressed: (isUploading || !canUpload) ? null : _uploadBook,
            icon: Icon(
              isUploading ? Icons.hourglass_top_rounded : Icons.cloud_upload_rounded,
              size: MediaQuery.of(context).size.width * 0.05,
            ),
            label: Text(
              isUploading ? 'Uploading...' : 'Upload Book',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canUpload ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
              foregroundColor: canUpload ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.5),
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
  File? _selectedAudioFile;

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
      _fileName = widget.existingChapter!.pdfFile?.path.split('/').last;
      _selectedAudioFile = widget.existingChapter!.audioFile;
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

  void _onAudioSelected(File audioFile) {
    setState(() {
      _selectedAudioFile = audioFile;
    });
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
      audioFile: _selectedAudioFile,
      order: widget.chapterNumber,
    );

    Navigator.of(context).pop(chapter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.8,
          maxWidth: mediaQuery.size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
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
                    size: mediaQuery.size.width * 0.06,
                  ),
                  SizedBox(width: mediaQuery.size.width * 0.02),
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
                padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
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
                      SizedBox(height: mediaQuery.size.height * 0.02),
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
                      SizedBox(height: mediaQuery.size.height * 0.02),
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
                      SizedBox(height: mediaQuery.size.height * 0.02),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedFile != null
                                ? theme.colorScheme.primary.withOpacity(0.5)
                                : theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _selectedFile != null
                              ? theme.colorScheme.primary.withOpacity(0.05)
                              : theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                                  decoration: BoxDecoration(
                                    color: _selectedFile != null
                                        ? theme.colorScheme.primary.withOpacity(0.1)
                                        : theme.colorScheme.outline.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _selectedFile != null ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                                    color: _selectedFile != null
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withOpacity(0.6),
                                    size: mediaQuery.size.width * 0.05,
                                  ),
                                ),
                                SizedBox(width: mediaQuery.size.width * 0.03),
                                Expanded(
                                  child: Text(
                                    _fileName ?? 'No PDF selected',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: _selectedFile != null
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withOpacity(0.7),
                                      fontWeight: _selectedFile != null ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: mediaQuery.size.height * 0.015),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Select PDF File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: EdgeInsets.symmetric(
                                    vertical: mediaQuery.size.height * 0.015,
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
                      SizedBox(height: mediaQuery.size.height * 0.02),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedAudioFile != null
                                ? theme.colorScheme.tertiary.withOpacity(0.5)
                                : theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _selectedAudioFile != null
                              ? theme.colorScheme.tertiary.withOpacity(0.05)
                              : theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.audiotrack_rounded,
                                  color: theme.colorScheme.tertiary,
                                  size: mediaQuery.size.width * 0.05,
                                ),
                                SizedBox(width: mediaQuery.size.width * 0.02),
                                Expanded(
                                  child: Text(
                                    'Chapter Audio (Optional)',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: mediaQuery.size.height * 0.015),
                            if (_selectedAudioFile != null) ...[
                              AudioPlayerWidget(
                                audioPath: _selectedAudioFile!.path,
                                label: 'Chapter Audio Track',
                                height: 50,
                                onRemove: () => setState(() {
                                  _selectedAudioFile = null;
                                }),
                              ),
                            ] else ...[
                              AudioRecorderWidget(
                                onAudioSelected: _onAudioSelected,
                                label: 'Record or select audio for this chapter',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Container(
              padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
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
                        horizontal: mediaQuery.size.width * 0.04,
                        vertical: mediaQuery.size.height * 0.015,
                      ),
                    ),
                  ),
                  SizedBox(width: mediaQuery.size.width * 0.02),
                  ElevatedButton(
                    onPressed: _selectedFile != null ? _saveChapter : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width * 0.04,
                        vertical: mediaQuery.size.height * 0.015,
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