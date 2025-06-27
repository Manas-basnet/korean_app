import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_info.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_editing/book_editing_cubit.dart';
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
            english: 'Book Editor',
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          BlocBuilder<BookEditingCubit, BookEditingState>(
            builder: (context, state) {
              if (state is BookEditingLoaded && state.chapters.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _showGenerateDialog(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
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
      floatingActionButton: BlocBuilder<BookEditingCubit, BookEditingState>(
        builder: (context, state) {
          if (state is BookEditingLoaded && !state.isSelectionMode) {
            return FloatingActionButton.extended(
              onPressed: () => _showChapterManagement(context, state),
              icon: const Icon(Icons.auto_stories),
              label: Text(context.read<LanguagePreferenceCubit>().getLocalizedText(
                korean: '챕터',
                english: 'Chapters',
              )),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
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
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (progress > 0) ...[
              const SizedBox(height: 24),
              Container(
                width: 200,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
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
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              languageCubit.getLocalizedText(
                korean: '오류가 발생했습니다',
                english: 'An error occurred',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
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
        Column(
          children: [
            if (state.chapters.isNotEmpty) _buildChapterSummaryBar(context, state),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),
          ],
        ),
        
        if (state.isSelectionMode)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildSelectionPanel(context, state),
          ),
      ],
    );
  }

  Widget _buildChapterSummaryBar(BuildContext context, BookEditingLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories,
            color: colorScheme.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${state.chapters.length} chapters • ${_getTotalUsedPages(state)} pages assigned',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showChapterManagement(context, state),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionPanel(BuildContext context, BookEditingLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.selectedPageNumbers.length} pages selected',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Creating chapter ${state.currentChapterForSelection ?? 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.read<BookEditingCubit>().clearSelection(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: colorScheme.outline),
                    ),
                    child: Text(
                      languageCubit.getLocalizedText(
                        korean: '취소',
                        english: 'Cancel',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.selectedPageNumbers.isNotEmpty 
                        ? () => _showChapterDetailsDialog(context, state)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      languageCubit.getLocalizedText(
                        korean: '저장',
                        english: 'Save',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
            centerTitle: true,
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

  void _showChapterManagement(BuildContext context, BookEditingLoaded state) {
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ChapterManagementBottomSheet(
          state: state,
          scrollController: scrollController,
          onCreateChapter: (chapterNumber) {
            Navigator.pop(context);
            context.read<BookEditingCubit>().startPageSelection(chapterNumber);
          },
          onEditChapter: (chapterNumber) {
            Navigator.pop(context);
            context.read<BookEditingCubit>().editChapter(chapterNumber);
          },
          onDeleteChapter: (chapterNumber) {
            context.read<BookEditingCubit>().deleteChapter(chapterNumber);
          },
        ),
      ),
    );
  }

  void _showChapterDetailsDialog(BuildContext context, BookEditingLoaded state) {
    final languageCubit = context.read<LanguagePreferenceCubit>();
    final titleController = TextEditingController(
      text: 'Chapter ${state.currentChapterForSelection ?? 1}',
    );
    final descriptionController = TextEditingController();
    final durationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageCubit.getLocalizedText(
            korean: '챕터 세부정보',
            english: 'Chapter Details',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Chapter Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                  hintText: 'e.g., 30 mins',
                ),
              ),
            ],
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
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.of(context).pop();
                context.read<BookEditingCubit>().saveSelectedPagesAsChapter(
                  title: title,
                  description: descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
                  duration: durationController.text.trim().isEmpty 
                      ? null 
                      : durationController.text.trim(),
                );
              }
            },
            child: Text(
              languageCubit.getLocalizedText(
                korean: '저장',
                english: 'Save',
              ),
            ),
          ),
        ],
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

  int _getTotalUsedPages(BookEditingLoaded state) {
    return state.chapters.fold(0, (sum, chapter) => sum + chapter.pageCount);
  }
}

class _ChapterManagementBottomSheet extends StatelessWidget {
  final BookEditingLoaded state;
  final ScrollController scrollController;
  final Function(int chapterNumber) onCreateChapter;
  final Function(int chapterNumber) onEditChapter;
  final Function(int chapterNumber) onDeleteChapter;

  const _ChapterManagementBottomSheet({
    required this.state,
    required this.scrollController,
    required this.onCreateChapter,
    required this.onEditChapter,
    required this.onDeleteChapter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    languageCubit.getLocalizedText(
                      korean: '챕터 관리',
                      english: 'Chapter Management',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final nextChapterNumber = state.chapters.isNotEmpty 
                        ? state.chapters.last.chapterNumber + 1 
                        : 1;
                    onCreateChapter(nextChapterNumber);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    languageCubit.getLocalizedText(
                      korean: '새 챕터',
                      english: 'New Chapter',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.description,
                  label: languageCubit.getLocalizedText(
                    korean: '총 페이지',
                    english: 'Total Pages',
                  ),
                  value: state.pages.length.toString(),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.onPrimaryContainer.withOpacity(0.3),
                ),
                _buildStatItem(
                  context,
                  icon: Icons.auto_stories,
                  label: languageCubit.getLocalizedText(
                    korean: '챕터',
                    english: 'Chapters',
                  ),
                  value: state.chapters.length.toString(),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.onPrimaryContainer.withOpacity(0.3),
                ),
                _buildStatItem(
                  context,
                  icon: Icons.check_circle,
                  label: languageCubit.getLocalizedText(
                    korean: '할당됨',
                    english: 'Assigned',
                  ),
                  value: _getTotalUsedPages().toString(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: state.chapters.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: state.chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = state.chapters[index];
                      return _buildChapterCard(context, chapter);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(
          icon,
          color: colorScheme.onPrimaryContainer,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onPrimaryContainer.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              languageCubit.getLocalizedText(
                korean: '아직 챕터가 없습니다',
                english: 'No chapters yet',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              languageCubit.getLocalizedText(
                korean: '새 챕터를 만들어 페이지를 선택하세요',
                english: 'Create a new chapter and select pages',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterCard(BuildContext context, ChapterInfo chapter) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getChapterColor(chapter.chapterNumber),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        chapter.chapterNumber.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${chapter.pageCount} pages',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEditChapter(chapter.chapterNumber);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context, chapter);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (chapter.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  chapter.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (chapter.duration != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      chapter.duration!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getChapterColor(int chapterNumber) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[(chapterNumber - 1) % colors.length];
  }

  int _getTotalUsedPages() {
    return state.chapters.fold(0, (sum, chapter) => sum + chapter.pageCount);
  }

  void _showDeleteConfirmation(BuildContext context, ChapterInfo chapter) {
    final languageCubit = context.read<LanguagePreferenceCubit>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageCubit.getLocalizedText(
            korean: '챕터 삭제',
            english: 'Delete Chapter',
          ),
        ),
        content: Text(
          languageCubit.getLocalizedText(
            korean: '챕터 "${chapter.title}"를 삭제하시겠습니까?',
            english: 'Are you sure you want to delete chapter "${chapter.title}"?',
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
            onPressed: () {
              Navigator.of(context).pop();
              onDeleteChapter(chapter.chapterNumber);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              languageCubit.getLocalizedText(
                korean: '삭제',
                english: 'Delete',
              ),
            ),
          ),
        ],
      ),
    );
  }
}