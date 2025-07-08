import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/chapter_info.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/bloc/pdf_extractor_cubit.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/widgets/pdf_page_grid_view.dart';
import 'package:korean_language_app/features/book_pdf_extractor/presentation/widgets/chapter_details_dialog.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';

class PdfExtractorPage extends StatefulWidget {
  final File sourcePdf;
  final Function(List<BookChapter> bookChapters) onChaptersGenerated;

  const PdfExtractorPage({
    super.key,
    required this.sourcePdf,
    required this.onChaptersGenerated,
  });

  @override
  State<PdfExtractorPage> createState() => _PdfExtractorPageState();
}

class _PdfExtractorPageState extends State<PdfExtractorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PdfExtractorCubit>().loadPdfForEditing(widget.sourcePdf);
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
            korean: 'PDF 챕터 편집기',
            english: 'PDF Chapter Editor',
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          BlocBuilder<PdfExtractorCubit, PdfExtractorState>(
            builder: (context, state) {
              if (state is PdfExtractorLoaded && state.chapters.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _showGenerateDialog(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      languageCubit.getLocalizedText(
                        korean: '완료',
                        english: 'Done',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<PdfExtractorCubit, PdfExtractorState>(
        listener: (context, state) {
          if (state is PdfExtractorError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PdfExtractorInitial || state is PdfExtractorLoading) {
            return _buildLoadingView(context, state);
          } else if (state is PdfExtractorError) {
            return _buildErrorView(context, state);
          } else if (state is PdfExtractorLoaded) {
            return _buildEditingView(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: BlocBuilder<PdfExtractorCubit, PdfExtractorState>(
        builder: (context, state) {
          if (state is PdfExtractorLoaded && !state.isSelectionMode) {
            return FloatingActionButton.extended(
              heroTag: 'add_chapter',
              onPressed: () => _showChapterManagement(context, state),
              icon: const Icon(Icons.auto_stories),
              label: Text(
                languageCubit.getLocalizedText(
                  korean: '챕터',
                  english: 'Chapters',
                ),
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context, PdfExtractorState state) {
    final theme = Theme.of(context);
    final languageCubit = context.read<LanguagePreferenceCubit>();

    String message = languageCubit.getLocalizedText(
      korean: 'PDF 로딩 중...',
      english: 'Loading PDF...',
    );
    double progress = 0.0;

    if (state is PdfExtractorLoading) {
      message = state.message;
      progress = state.progress;
    }

    // Create more descriptive progress messages based on progress value
    String detailedMessage = message;
    String subMessage = '';
    
    if (state is PdfExtractorLoading) {
      if (progress < 0.15) {
        detailedMessage = languageCubit.getLocalizedText(
          korean: 'PDF 파일 읽는 중...',
          english: 'Reading PDF file...',
        );
        subMessage = languageCubit.getLocalizedText(
          korean: 'PDF 구조를 분석하고 있습니다',
          english: 'Analyzing PDF structure',
        );
      } else if (progress < 0.25) {
        detailedMessage = languageCubit.getLocalizedText(
          korean: 'PDF 정보 확인 중...',
          english: 'Checking PDF information...',
        );
        subMessage = languageCubit.getLocalizedText(
          korean: '페이지 수와 내용을 확인하고 있습니다',
          english: 'Verifying page count and content',
        );
      } else if (progress < 0.35) {
        detailedMessage = languageCubit.getLocalizedText(
          korean: '캐시 확인 중...',
          english: 'Checking cache...',
        );
        subMessage = languageCubit.getLocalizedText(
          korean: '이전에 생성된 썸네일이 있는지 확인합니다',
          english: 'Looking for previously generated thumbnails',
        );
      } else if (progress < 0.9) {
        final thumbnailProgress = ((progress - 0.4) / 0.5 * 100).round();
        detailedMessage = languageCubit.getLocalizedText(
          korean: '페이지 썸네일 생성 중...',
          english: 'Generating page thumbnails...',
        );
        subMessage = languageCubit.getLocalizedText(
          korean: '진행률: $thumbnailProgress% - 잠시만 기다려주세요',
          english: 'Progress: $thumbnailProgress% - Please wait',
        );
      } else {
        detailedMessage = languageCubit.getLocalizedText(
          korean: '마무리 중...',
          english: 'Finalizing...',
        );
        subMessage = languageCubit.getLocalizedText(
          korean: '페이지 데이터를 준비하고 있습니다',
          english: 'Preparing page data',
        );
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main loading indicator with progress
            Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 4,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Main message
            Text(
              detailedMessage,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Sub message with additional details
            if (subMessage.isNotEmpty)
              Text(
                subMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            
            const SizedBox(height: 32),
            
            // Progress bar with detailed progress
            Container(
              width: 280,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Progress steps indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildProgressStep(
                        context,
                        languageCubit.getLocalizedText(korean: '읽기', english: 'Read'),
                        progress >= 0.2,
                        progress < 0.2,
                      ),
                      _buildProgressStep(
                        context,
                        languageCubit.getLocalizedText(korean: '분석', english: 'Analyze'),
                        progress >= 0.4,
                        progress >= 0.2 && progress < 0.4,
                      ),
                      _buildProgressStep(
                        context,
                        languageCubit.getLocalizedText(korean: '생성', english: 'Generate'),
                        progress >= 0.9,
                        progress >= 0.4 && progress < 0.9,
                      ),
                      _buildProgressStep(
                        context,
                        languageCubit.getLocalizedText(korean: '완료', english: 'Done'),
                        progress >= 1.0,
                        progress >= 0.9 && progress < 1.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Additional info
            Text(
              languageCubit.getLocalizedText(
                korean: 'PDF 크기에 따라 시간이 소요될 수 있습니다',
                english: 'Processing time depends on PDF size',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(BuildContext context, String label, bool completed, bool active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color stepColor;
    if (completed) {
      stepColor = colorScheme.primary;
    } else if (active) {
      stepColor = colorScheme.secondary;
    } else {
      stepColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    }
    
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: stepColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: stepColor,
            fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, PdfExtractorError state) {
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
            // const SizedBox(height: 16),
            // Text(
            //   state.message,
            //   style: theme.textTheme.bodyMedium?.copyWith(
            //     color: colorScheme.onSurfaceVariant,
            //   ),
            //   textAlign: TextAlign.center,
            // ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

  Widget _buildEditingView(BuildContext context, PdfExtractorLoaded state) {
    return Column(
      children: [
        if (state.chapters.isNotEmpty)
          _buildCompactChapterSummaryBar(context, state),
        if (state.isSelectionMode) _buildSelectionTopBar(context, state),
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
                  context
                      .read<PdfExtractorCubit>()
                      .togglePageSelection(pageNumber);
                }
              },
              onPageLongPress: (pageNumber) =>
                  _showFullScreenPage(context, pageNumber, state),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactChapterSummaryBar(
      BuildContext context, PdfExtractorLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories,
            color: colorScheme.onPrimaryContainer,
            size: 18,
          ),
          const SizedBox(width: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTopBar(BuildContext context, PdfExtractorLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.check,
              color: colorScheme.onPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.selectedPageNumbers.length} pages selected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'For: ${state.pendingChapterTitle ?? 'Chapter ${state.currentChapterForSelection ?? 1}'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.read<PdfExtractorCubit>().clearSelection(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(color: colorScheme.outline),
            ),
            child: Text(
              languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: state.selectedPageNumbers.isNotEmpty
                ? () => _saveSelectedPages(context, state)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
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

  void _saveSelectedPages(BuildContext context, PdfExtractorLoaded state) {
    context.read<PdfExtractorCubit>().saveSelectedPagesAsChapter(
          title: state.pendingChapterTitle ??
              'Chapter ${state.currentChapterForSelection ?? 1}',
          description: state.pendingChapterDescription,
          duration: state.pendingChapterDuration,
        );
  }

  void _showFullScreenPage(
      BuildContext context, int pageNumber, PdfExtractorLoaded state) {
    final page = state.pages.firstWhere((p) => p.pageNumber == pageNumber);
    DialogUtils.showFullScreenImage(context, null, page.thumbnailPath);
  }

  void _showChapterManagement(BuildContext context, PdfExtractorLoaded state) {
    final pdfExtractorCubit = context.read<PdfExtractorCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => BlocProvider.value(
        value: pdfExtractorCubit,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => _ChapterManagementSheet(
            state: state,
            scrollController: scrollController,
            onCreateChapter: () async {
              Navigator.pop(context);
              await _showChapterDetailsDialog(context, null);
            },
            onEditChapter: (chapterNumber) async {
              Navigator.pop(context);
              final chapter = state.chapters
                  .firstWhere((c) => c.chapterNumber == chapterNumber);
              await _showChapterDetailsDialog(context, chapter);
            },
            onDeleteChapter: (chapterNumber) {
              context.read<PdfExtractorCubit>().deleteChapter(chapterNumber);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showChapterDetailsDialog(
      BuildContext context, ChapterInfo? existingChapter) async {
    if (!mounted) return;

    final languageCubit = context.read<LanguagePreferenceCubit>();
    final pdfExtractorCubit = context.read<PdfExtractorCubit>();
    final isEditing = existingChapter != null;
    final nextChapterNumber = isEditing
        ? existingChapter.chapterNumber
        : (pdfExtractorCubit.state as PdfExtractorLoaded).chapters.length + 1;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => ChapterDetailsDialog(
        isEditing: isEditing,
        existingChapter: existingChapter,
        nextChapterNumber: nextChapterNumber,
        languageCubit: languageCubit,
      ),
    );

    if (!mounted || result == null) return;

    final title = result['title'] as String;
    final description = result['description'] as String?;
    final duration = result['duration'] as String?;
    final action = result['action'] as String;

    if (action == 'save_only' && isEditing) {
      pdfExtractorCubit.updateChapterDetails(
        existingChapter.chapterNumber,
        title: title,
        description: description?.isEmpty == true ? null : description,
        duration: duration?.isEmpty == true ? null : duration,
      );
    } else if (action == 'select_pages') {
      pdfExtractorCubit.startPageSelectionWithDetails(
        chapterNumber: nextChapterNumber,
        title: title,
        description: description?.isEmpty == true ? null : description,
        duration: duration?.isEmpty == true ? null : duration,
      );
    }
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
            korean: '선택한 페이지들로 책 챕터들을 생성하시겠습니까?',
            english:
                'Do you want to generate book chapters from the selected pages?',
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
      final cubit = context.read<PdfExtractorCubit>();
      
      final bookChapters = await cubit.generateBookChapters();
      widget.onChaptersGenerated(bookChapters);

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

  int _getTotalUsedPages(PdfExtractorLoaded state) {
    return state.chapters.fold(0, (sum, chapter) => sum + chapter.pageCount);
  }
}

class _ChapterManagementSheet extends StatelessWidget {
  final PdfExtractorLoaded state;
  final ScrollController scrollController;
  final VoidCallback onCreateChapter;
  final Function(int chapterNumber) onEditChapter;
  final Function(int chapterNumber) onDeleteChapter;

  const _ChapterManagementSheet({
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
                  onPressed: onCreateChapter,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    languageCubit.getLocalizedText(
                      korean: '새 챕터',
                      english: 'New Chapter',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.chapters.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getChapterColor(chapter.chapterNumber),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    chapter.chapterNumber.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                      chapter.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${chapter.pageCount} pages',
                      style: theme.textTheme.bodySmall?.copyWith(
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
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
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
            english:
                'Are you sure you want to delete chapter "${chapter.title}"?',
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