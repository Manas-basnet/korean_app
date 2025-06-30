import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/shared_book_form_widgets.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/chapter_upload_dialog.dart';
import 'package:korean_language_app/shared/models/chapter_info.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/pages/book_editing_page.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
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

class _BookUploadPageState extends State<BookUploadPage> {
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

  List<AudioTrackUploadData> _audioTracks = [];
  List<ChapterUploadData> chapters = [];

  late FileUploadCubit _fileUploadCubit;

  @override
  void initState() {
    super.initState();
    _fileUploadCubit = context.read<FileUploadCubit>();
    _initialize();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _countryController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _initialize() {
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

  void _onAudioTracksChanged(List<AudioTrackUploadData> audioTracks) {
    setState(() {
      _audioTracks = audioTracks;
    });
  }

  Future<void> _addChapter() async {
    final result = await showDialog<ChapterUploadData>(
      context: context,
      builder: (context) => ChapterUploadDialog(
        chapterNumber: chapters.length + 1,
        fileUploadCubit: _fileUploadCubit,
      ),
    );

    if (result != null) {
      setState(() {
        chapters.add(result);
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
      chapters.clear();
      for (int i = 0; i < chapterFiles.length && i < chapterInfos.length; i++) {
        final chapterInfo = chapterInfos[i];
        final chapterFile = chapterFiles[i];
        
        chapters.add(ChapterUploadData(
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
      chapters.removeAt(index);
      for (int i = 0; i < chapters.length; i++) {
        chapters[i] = chapters[i].copyWith(order: i + 1);
      }
    });
  }

  void _editChapter(int index) async {
    final result = await showDialog<ChapterUploadData>(
      context: context,
      builder: (context) => ChapterUploadDialog(
        chapterNumber: index + 1,
        fileUploadCubit: _fileUploadCubit,
        existingChapter: chapters[index],
      ),
    );

    if (result != null) {
      setState(() {
        chapters[index] = result;
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

    if (_uploadType == BookUploadType.chapterWise && chapters.isEmpty) {
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
        chaptersCount: _uploadType == BookUploadType.singlePdf ? 1 : chapters.length,
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
          audioTracks: _audioTracks.isNotEmpty ? _audioTracks : null,
        );
      } else {
        success = await _fileUploadCubit.uploadBookWithChapters(
          book,
          chapters,
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
      _audioTracks.clear();
      chapters.clear();
    });
    _fileUploadCubit.resetState();
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
                  'Chapters (${chapters.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (chapters.isEmpty) ...[
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
                label: Text(chapters.isEmpty ? 'Manual' : 'Add'),
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
          
          if (chapters.isEmpty)
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
                    'No chapters added yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Text(
                    'Use Smart Editor for automatic extraction\nor add chapters manually',
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
              itemCount: chapters.length,
              separatorBuilder: (context, index) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.01,
              ),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
                                  'PDF: ${chapter.pdfFile?.path.split('/').last ?? 'None'}',
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
          final canUpload = (_uploadType == BookUploadType.singlePdf && _pdfSelected) ||
              (_uploadType == BookUploadType.chapterWise && chapters.isNotEmpty);

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
                          selectedLevel: _selectedLevel,
                          selectedCategory: _selectedCategory,
                          onLevelChanged: (level) => setState(() => _selectedLevel = level),
                          onCategoryChanged: (category) => setState(() => _selectedCategory = category),
                          uploadType: _uploadType,
                          chaptersCount: chapters.length,
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
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                          AudioSectionWidget(
                            audioTracks: _audioTracks,
                            onAudioTracksChanged: _onAudioTracksChanged,
                            isEnabled: !isUploading,
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
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (isUploading) 
                ProgressSectionWidget(progress: uploadProgress),
              
              BottomActionButtonWidget(
                onPressed: canUpload ? _uploadBook : null,
                isLoading: isUploading,
                isEnabled: canUpload,
                label: 'Upload Book',
                loadingLabel: 'Uploading...',
                icon: Icons.cloud_upload_rounded,
                loadingIcon: Icons.hourglass_top_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}