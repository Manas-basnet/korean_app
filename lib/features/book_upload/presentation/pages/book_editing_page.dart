// lib/features/book_upload/presentation/pages/book_editing_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_info.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_editing/book_editing_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/chapter_management_panel.dart';
import 'package:korean_language_app/features/book_upload/presentation/widgets/pdf_page_grid_view.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class BookEditingPage extends StatefulWidget {
  final File sourcePdf;
  final Function(List<File> chapterFiles, List<ChapterInfo> chapters) onChaptersGenerated;

  const BookEditingPage({
    super.key,
    required this.sourcePdf,
    required this.onChaptersGenerated,
  });

  @override
  State<BookEditingPage> createState() => _BookEditingPageState();
}

class _BookEditingPageState extends State<BookEditingPage> {
  bool _showChapterPanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookEditingCubit>().loadPdfForEditing(widget.sourcePdf);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          languageCubit.getLocalizedText(
            korean: '책 편집 모드',
            english: 'Book Editing Mode',
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _showChapterPanel = !_showChapterPanel),
            icon: Icon(
              _showChapterPanel ? Icons.grid_view : Icons.list,
              color: colorScheme.primary,
            ),
            tooltip: languageCubit.getLocalizedText(
              korean: '챕터 관리',
              english: 'Manage Chapters',
            ),
          ),
          BlocBuilder<BookEditingCubit, BookEditingState>(
            builder: (context, state) {
              if (state is BookEditingLoaded && state.chapters.isNotEmpty) {
                return IconButton(
                  onPressed: () => _showGenerateDialog(context),
                  icon: Icon(
                    Icons.check_circle,
                    color: colorScheme.primary,
                  ),
                  tooltip: languageCubit.getLocalizedText(
                    korean: '챕터 생성',
                    english: 'Generate Chapters',
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<BookEditingCubit, BookEditingState>(
        listener: (context, state) {
          if (state is BookEditingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: colorScheme.error,
              ),
            );
          } else if (state is BookEditingChapterSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  languageCubit.getLocalizedText(
                    korean: '챕터 "${state.chapter.title}" 저장됨',
                    english: 'Chapter "${state.chapter.title}" saved',
                  ),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is BookEditingInitial || state is BookEditingLoading) {
            return _buildLoadingView(context, state);
          } else if (state is BookEditingError) {
            return _buildErrorView(context, state);
          } else if (state is BookEditingLoaded) {
            return _buildEditingView(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context, BookEditingState state) {
    final theme = Theme.of(context);
    final languageCubit = context.read<LanguagePreferenceCubit>();
    
    String message = languageCubit.getLocalizedText(
      korean: 'PDF 로딩 중...',
      english: 'Loading PDF...',
    );
    double progress = 0.0;

    if (state is BookEditingLoading) {
      message = state.message;
      progress = state.progress;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (progress > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, BookEditingError state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              languageCubit.getLocalizedText(
                korean: '오류가 발생했습니다',
                english: 'An error occurred',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                languageCubit.getLocalizedText(
                  korean: '돌아가기',
                  english: 'Go Back',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditingView(BuildContext context, BookEditingLoaded state) {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: _showChapterPanel ? 2 : 1,
              child: PdfPageGridView(
                pages: state.pages,
                chapters: state.chapters,
                selectedPageNumbers: state.selectedPageNumbers,
                isSelectionMode: state.isSelectionMode,
                onPageTap: (pageNumber) {
                  if (state.isSelectionMode) {
                    context.read<BookEditingCubit>().togglePageSelection(pageNumber);
                  }
                },
                onPageLongPress: (pageNumber) => _showFullScreenPage(context, pageNumber, state),
              ),
            ),
            
            if (_showChapterPanel)
              Expanded(
                flex: 1,
                child: ChapterManagementPanel(
                  chapters: state.chapters,
                  totalPages: state.pages.length,
                  onCreateChapter: (chapterNumber) {
                    context.read<BookEditingCubit>().startPageSelection(chapterNumber);
                  },
                  onEditChapter: (chapterNumber) {
                    context.read<BookEditingCubit>().editChapter(chapterNumber);
                  },
                  onDeleteChapter: (chapterNumber) {
                    context.read<BookEditingCubit>().deleteChapter(chapterNumber);
                  },
                ),
              ),
          ],
        ),
        
        if (state.isSelectionMode)
          Positioned(
            bottom: 16,
            left: 16,
            right: _showChapterPanel ? null : 16,
            child: PageSelectionFloatingPanel(
              selectedCount: state.selectedPageNumbers.length,
              chapterNumber: state.currentChapterForSelection,
              onCancel: () => context.read<BookEditingCubit>().clearSelection(),
              onSave: (title, description, duration) {
                context.read<BookEditingCubit>().saveSelectedPagesAsChapter(
                  title: title,
                  description: description,
                  duration: duration,
                );
              },
            ),
          ),
      ],
    );
  }

  void _showFullScreenPage(BuildContext context, int pageNumber, BookEditingLoaded state) {
    final page = state.pages.firstWhere((p) => p.pageNumber == pageNumber);
    
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text('Page $pageNumber'),
          ),
          body: Center(
            child: page.thumbnailPath != null
                ? InteractiveViewer(
                    child: Image.file(
                      File(page.thumbnailPath!),
                      fit: BoxFit.contain,
                    ),
                  )
                : const Icon(Icons.image_not_supported, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _showGenerateDialog(BuildContext context) {
    final languageCubit = context.read<LanguagePreferenceCubit>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageCubit.getLocalizedText(
            korean: '챕터 생성',
            english: 'Generate Chapters',
          ),
        ),
        content: Text(
          languageCubit.getLocalizedText(
            korean: '선택한 페이지들로 챕터 PDF 파일들을 생성하시겠습니까?',
            english: 'Do you want to generate chapter PDF files from the selected pages?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _generateChapters();
            },
            child: Text(
              languageCubit.getLocalizedText(
                korean: '생성',
                english: 'Generate',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateChapters() async {
    try {
      final cubit = context.read<BookEditingCubit>();
      final state = cubit.state as BookEditingLoaded;
      
      final chapterFiles = await cubit.generateChapterPdfs();
      widget.onChaptersGenerated(chapterFiles, state.chapters);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate chapters: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}