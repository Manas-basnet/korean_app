// Save this file as: lib/features/home/presentation/widgets/homepage_reading_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/pages/pdf_reading_page.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class HomepageReadingSection extends StatelessWidget {
  const HomepageReadingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookSessionCubit, BookSessionState>(
      builder: (context, state) {
        if (state is BookSessionActive) {
          return Column(
            children: [
              _ContinueReadingCard(session: state.currentSession),
              if (state.recentlyReadBooks.isNotEmpty)
                _RecentBooksSection(recentBooks: state.recentlyReadBooks),
              _ReadingStatsSection(
                currentSession: state.currentSession,
                recentBooks: state.recentlyReadBooks,
              ),
            ],
          );
        } else if (state is BookSessionPaused) {
          return Column(
            children: [
              _ContinueReadingCard(session: state.pausedSession, isPaused: true),
              if (state.recentlyReadBooks.isNotEmpty)
                _RecentBooksSection(recentBooks: state.recentlyReadBooks),
              _ReadingStatsSection(
                pausedSession: state.pausedSession,
                recentBooks: state.recentlyReadBooks,
              ),
            ],
          );
        } else if (state is BookSessionIdle && state.recentlyReadBooks.isNotEmpty) {
          return Column(
            children: [
              _RecentBooksSection(recentBooks: state.recentlyReadBooks),
              _ReadingStatsSection(recentBooks: state.recentlyReadBooks),
            ],
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final ReadingSession session;
  final bool isPaused;

  const _ContinueReadingCard({
    required this.session,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();
    final screenSize = MediaQuery.of(context).size;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageCubit.getLocalizedText(
                  korean: '읽기 계속하기',
                  english: 'Continue Reading',
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/books'),
                child: Text(
                  languageCubit.getLocalizedText(
                    korean: '도서 보기',
                    english: 'View Books',
                  ),
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 3,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: colorScheme.secondary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () => _continueReading(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.secondaryContainer.withValues(alpha: 0.4),
                      colorScheme.secondaryContainer.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: isPaused ? colorScheme.secondary : colorScheme.onPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                languageCubit.getLocalizedText(
                                  korean: isPaused ? '일시정지됨' : '계속',
                                  english: isPaused ? 'Paused' : 'Continue',
                                ),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: isPaused ? colorScheme.secondary : colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (session.totalReadingTime.inMinutes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  session.formattedReadingTime,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<BookItem?>(
                      future: _getBookDetails(context),
                      builder: (context, snapshot) {
                        final book = snapshot.data;
                        return Row(
                          children: [
                            Container(
                              width: 50,
                              height: 70,
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: book?.imageUrl != null || book?.imagePath != null
                                    ? CustomCachedImage(
                                        imageUrl: book?.imageUrl,
                                        imagePath: book?.imagePath,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.library_books_rounded,
                                          color: colorScheme.tertiary,
                                          size: 24,
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
                                    session.bookTitle,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${languageCubit.getLocalizedText(korean: "챕터", english: "Chapter")} ${session.chapterIndex + 1}: ${session.chapterTitle}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (session.totalPages > 0) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: session.chapterProgress,
                                            backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.tertiary),
                                            minHeight: 6,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${session.currentPage}/${session.totalPages}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.tertiary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<BookItem?> _getBookDetails(BuildContext context) async {
    final booksCubit = context.read<BooksCubit>();
    final currentState = booksCubit.state;
    
    if (currentState.selectedBook?.id == session.bookId) {
      return currentState.selectedBook;
    }
    
    try {
      await booksCubit.loadBookById(session.bookId);
      return booksCubit.state.selectedBook;
    } catch (e) {
      return null;
    }
  }

  void _continueReading(BuildContext context) async {
    final booksCubit = context.read<BooksCubit>();
    final bookSessionCubit = context.read<BookSessionCubit>();
    final snackBarCubit = context.read<SnackBarCubit>();
    
    try {
      await booksCubit.loadBookById(session.bookId);
      
      final book = booksCubit.state.selectedBook;
      if (book == null || session.chapterIndex >= book.chapters.length) {
        snackBarCubit.showErrorLocalized(
          korean: '도서 또는 챕터를 찾을 수 없습니다',
          english: 'Book or chapter not found',
        );
        return;
      }

      final chapter = book.chapters[session.chapterIndex];
      
      if (isPaused) {
        await bookSessionCubit.resumeSession();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfReadingPage(
            bookId: session.bookId,
            bookTitle: session.bookTitle,
            chapterTitle: session.chapterTitle,
            chapterIndex: session.chapterIndex,
            pdfPath: chapter.pdfPath,
            pdfUrl: chapter.pdfUrl,
            audioTracks: chapter.audioTracks,
            totalChapters: book.chapters.length,
          ),
        ),
      );
    } catch (e) {
      snackBarCubit.showErrorLocalized(
        korean: '읽기를 계속할 수 없습니다',
        english: 'Cannot continue reading',
      );
    }
  }
}

class _RecentBooksSection extends StatelessWidget {
  final List<BookProgress> recentBooks;

  const _RecentBooksSection({required this.recentBooks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageCubit.getLocalizedText(
                    korean: '최근 읽은 도서',
                    english: 'Recently Read',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/books'),
                  child: Text(
                    languageCubit.getLocalizedText(
                      korean: '모두 보기',
                      english: 'See All',
                    ),
                    style: TextStyle(color: colorScheme.tertiary),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentBooks.take(5).length,
              itemBuilder: (context, index) {
                final bookProgress = recentBooks[index];
                return _RecentBookCard(bookProgress: bookProgress);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBookCard extends StatelessWidget {
  final BookProgress bookProgress;

  const _RecentBookCard({required this.bookProgress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12, left: 4),
      child: Card(
        elevation: 2,
        shadowColor: colorScheme.tertiary.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.tertiary.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: InkWell(
          onTap: () => _openBook(context),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: FutureBuilder<BookItem?>(
                      future: _getBookFromProgress(context),
                      builder: (context, snapshot) {
                        final book = snapshot.data;
                        if (book?.imageUrl != null || book?.imagePath != null) {
                          return CustomCachedImage(
                            imageUrl: book?.imageUrl,
                            imagePath: book?.imagePath,
                            fit: BoxFit.cover,
                          );
                        }
                        return Center(
                          child: Icon(
                            Icons.library_books_rounded,
                            size: 32,
                            color: colorScheme.tertiary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        bookProgress.bookTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: bookProgress.overallProgress,
                            backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              bookProgress.overallProgress >= 1.0 ? colorScheme.tertiary : colorScheme.tertiary.withValues(alpha: 0.8),
                            ),
                            minHeight: 3,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bookProgress.formattedProgress,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<BookItem?> _getBookFromProgress(BuildContext context) async {
    final booksCubit = context.read<BooksCubit>();
    try {
      await booksCubit.loadBookById(bookProgress.bookId);
      return booksCubit.state.selectedBook;
    } catch (e) {
      return null;
    }
  }

  void _openBook(BuildContext context) {
    context.push('/book-chapters/${bookProgress.bookId}');
  }
}

class _ReadingStatsSection extends StatelessWidget {
  final ReadingSession? currentSession;
  final ReadingSession? pausedSession;
  final List<BookProgress> recentBooks;

  const _ReadingStatsSection({
    this.currentSession,
    this.pausedSession,
    required this.recentBooks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    final activeBooks = recentBooks.where((book) => 
      book.overallProgress > 0 && book.overallProgress < 1.0
    ).length;
    
    final completedBooks = recentBooks.where((book) => 
      book.overallProgress >= 1.0
    ).length;

    final totalReadingTime = recentBooks.fold<Duration>(
      Duration.zero, 
      (sum, book) => sum + book.totalReadingTime,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageCubit.getLocalizedText(
              korean: '읽기 통계',
              english: 'Reading Stats',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.auto_stories_rounded,
                  title: languageCubit.getLocalizedText(
                    korean: '읽는 중',
                    english: 'Reading',
                  ),
                  value: activeBooks.toString(),
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  title: languageCubit.getLocalizedText(
                    korean: '완료',
                    english: 'Completed',
                  ),
                  value: completedBooks.toString(),
                  color: colorScheme.tertiary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.access_time_rounded,
                  title: languageCubit.getLocalizedText(
                    korean: '총 시간',
                    english: 'Total Time',
                  ),
                  value: _formatTotalTime(totalReadingTime),
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTotalTime(Duration totalTime) {
    final hours = totalTime.inHours;
    if (hours > 0) {
      return '${hours}h';
    } else {
      final minutes = totalTime.inMinutes;
      return '${minutes}m';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

