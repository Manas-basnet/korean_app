import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/pages/pdf_reading_page.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';

class ChapterListPage extends StatefulWidget {
  final String bookId;

  const ChapterListPage({super.key, required this.bookId});

  @override
  State<ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  late BooksCubit _booksCubit;
  late LanguagePreferenceCubit _languageCubit;
  late SnackBarCubit _snackBarCubit;
  late BookSessionCubit _bookSessionCubit;

  @override
  void initState() {
    super.initState();
    _booksCubit = context.read<BooksCubit>();
    _languageCubit = context.read<LanguagePreferenceCubit>();
    _snackBarCubit = context.read<SnackBarCubit>();
    _bookSessionCubit = context.read<BookSessionCubit>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBook();
    });
  }

  Future<void> _loadBook() async {
    final booksState = _booksCubit.state;
    
    if (booksState.selectedBook?.id != widget.bookId) {
      await _booksCubit.loadBookById(widget.bookId);
      
      final updatedState = _booksCubit.state;
      if (updatedState.hasError || updatedState.selectedBook == null) {
        _snackBarCubit.showErrorLocalized(
          korean: '도서를 불러올 수 없습니다',
          english: 'Failed to load book',
        );
        if (mounted) {
          context.pop();
        }
      }
    }
  }

  void _navigateToChapterReading(BookItem book, int chapterIndex) {
    final chapter = book.chapters[chapterIndex];
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfReadingPage(
          bookId: book.id,
          bookTitle: book.title,
          chapterTitle: chapter.title,
          chapterIndex: chapterIndex,
          pdfPath: chapter.pdfPath,
          pdfUrl: chapter.pdfUrl,
          audioTracks: chapter.audioTracks,
          totalChapters: book.chapters.length,
          bookItem: book,
          onPreviousChapter: chapterIndex > 0 ? () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => _buildChapterReadingPage(book, chapterIndex - 1),
              ),
            );
          } : null,
          onNextChapter: chapterIndex < book.chapters.length - 1 ? () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => _buildChapterReadingPage(book, chapterIndex + 1),
              ),
            );
          } : null,
        ),
      ),
    );
  }

  PdfReadingPage _buildChapterReadingPage(BookItem book, int chapterIndex) {
    final chapter = book.chapters[chapterIndex];
    
    return PdfReadingPage(
      bookId: book.id,
      bookTitle: book.title,
      chapterTitle: chapter.title,
      chapterIndex: chapterIndex,
      pdfPath: chapter.pdfPath,
      pdfUrl: chapter.pdfUrl,
      audioTracks: chapter.audioTracks,
      totalChapters: book.chapters.length,
      bookItem: book,
      onPreviousChapter: chapterIndex > 0 ? () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => _buildChapterReadingPage(book, chapterIndex - 1),
          ),
        );
      } : null,
      onNextChapter: chapterIndex < book.chapters.length - 1 ? () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => _buildChapterReadingPage(book, chapterIndex + 1),
          ),
        );
      } : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BooksCubit, BooksState>(
      builder: (context, state) {
        if (state.isLoading && state.selectedBook == null) {
          return _buildLoadingScreen();
        }

        if (state.hasError && state.selectedBook == null) {
          return _buildErrorScreen();
        }

        final book = state.selectedBook;
        if (book == null) {
          return _buildErrorScreen();
        }

        return _buildChapterListScreen(book);
      },
    );
  }

  Widget _buildLoadingScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _languageCubit.getLocalizedText(
                korean: '도서를 불러오고 있습니다...',
                english: 'Loading book...',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _languageCubit.getLocalizedText(
                  korean: '도서를 불러올 수 없습니다',
                  english: 'Failed to load book',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  _languageCubit.getLocalizedText(
                    korean: '돌아가기',
                    english: 'Go Back',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterListScreen(BookItem book) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildBookHeader(book, screenSize, colorScheme),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = book.chapters[index];
                  return FutureBuilder<BookProgress?>(
                    future: _bookSessionCubit.getBookProgress(book.id),
                    builder: (context, snapshot) {
                      final bookProgress = snapshot.data;
                      final chapterProgress = bookProgress?.chapters[index];
                      
                      return _buildChapterCard(
                        book, 
                        chapter, 
                        index, 
                        theme, 
                        colorScheme,
                        chapterProgress,
                      );
                    },
                  );
                },
                childCount: book.chapters.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookHeader(BookItem book, Size screenSize, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (book.imageUrl != null || book.imagePath != null)
                  Container(
                    width: 80,
                    height: 120,
                    margin: const EdgeInsets.only(right: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomCachedImage(
                        imageUrl: book.imageUrl,
                        imagePath: book.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildInfoChip(
                            Icons.book_outlined,
                            '${book.chapterCount} ${_languageCubit.getLocalizedText(korean: "챕터", english: "chapters")}',
                            colorScheme.primary,
                            theme,
                          ),
                          if (book.totalDuration > 0)
                            _buildInfoChip(
                              Icons.access_time_rounded,
                              book.formattedDuration,
                              colorScheme.secondary,
                              theme,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(
    BookItem book, 
    BookChapter chapter, 
    int index, 
    ThemeData theme, 
    ColorScheme colorScheme,
    ChapterProgress? chapterProgress,
  ) {
    final isCompleted = chapterProgress?.isCompleted ?? false;
    final progress = chapterProgress?.progress ?? 0.0;
    final hasProgress = progress > 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: hasProgress 
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: hasProgress ? 1.0 : 0.5,
          ),
        ),
        child: InkWell(
          onTap: () => _navigateToChapterReading(book, index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? Colors.green.withValues(alpha: 0.2)
                            : hasProgress
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.green,
                                size: 24,
                              )
                            : Text(
                                '${index + 1}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: hasProgress 
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
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
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (chapter.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              chapter.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (chapter.hasPdf)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 12,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'PDF',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (chapter.hasAudioTracks) ...[
                                if (chapter.hasPdf) const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.headphones_rounded,
                                        size: 12,
                                        color: colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${chapter.audioTracks.length}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.secondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (chapter.duration > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    chapter.formattedDuration,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onTertiaryContainer,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (hasProgress)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCompleted 
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : colorScheme.primaryContainer.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isCompleted 
                                        ? _languageCubit.getLocalizedText(korean: '완료', english: 'Done')
                                        : chapterProgress!.formattedProgress,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isCompleted ? Colors.green : colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                
                if (hasProgress && !isCompleted) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}