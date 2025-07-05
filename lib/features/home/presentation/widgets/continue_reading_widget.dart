import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';
import 'package:korean_language_app/features/books/presentation/pages/pdf_reading_page.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';

class ContinueReadingWidget extends StatelessWidget {
  const ContinueReadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final languageCubit = context.read<LanguagePreferenceCubit>();
    
    return BlocBuilder<BookSessionCubit, BookSessionState>(
      builder: (context, state) {
        if (state is BookSessionActive) {
          return _ContinueActiveSessionCard(
            session: state.currentSession,
            languageCubit: languageCubit,
          );
        } else if (state is BookSessionPaused) {
          return _ContinueActiveSessionCard(
            session: state.pausedSession,
            languageCubit: languageCubit,
            isPaused: true,
          );
        } else if (state is BookSessionIdle && state.recentlyReadBooks.isNotEmpty) {
          return _RecentlyReadBooksSection(
            recentBooks: state.recentlyReadBooks,
            languageCubit: languageCubit,
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
}

class _ContinueActiveSessionCard extends StatelessWidget {
  final ReadingSession session;
  final LanguagePreferenceCubit languageCubit;
  final bool isPaused;

  const _ContinueActiveSessionCard({
    required this.session,
    required this.languageCubit,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.05,
        vertical: screenSize.height * 0.015,
      ),
      child: Card(
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => _continueReading(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(screenSize.width * 0.04),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.3),
                  colorScheme.primaryContainer.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.03,
                        vertical: screenSize.height * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: isPaused 
                            ? colorScheme.secondaryContainer
                            : colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: screenSize.width * 0.04,
                            color: isPaused ? colorScheme.secondary : colorScheme.primary,
                          ),
                          SizedBox(width: screenSize.width * 0.01),
                          Text(
                            languageCubit.getLocalizedText(
                              korean: isPaused ? '일시 정지됨' : '읽는 중',
                              english: isPaused ? 'Paused' : 'Reading',
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isPaused ? colorScheme.secondary : colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: screenSize.width * 0.03,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (session.totalReadingTime.inMinutes > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenSize.width * 0.025,
                          vertical: screenSize.height * 0.006,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          session.formattedReadingTime,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: screenSize.width * 0.025,
                          ),
                        ),
                      ),
                  ],
                ),
                
                SizedBox(height: screenSize.height * 0.015),
                
                Text(
                  session.bookTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    fontSize: screenSize.width * 0.045,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: screenSize.height * 0.008),
                
                Text(
                  '${languageCubit.getLocalizedText(korean: "챕터", english: "Chapter")} ${session.chapterIndex + 1}: ${session.chapterTitle}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: screenSize.width * 0.035,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (session.totalPages > 0) ...[
                  SizedBox(height: screenSize.height * 0.015),
                  
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: session.chapterProgress,
                          backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      SizedBox(width: screenSize.width * 0.03),
                      Text(
                        '${session.currentPage}/${session.totalPages}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: screenSize.width * 0.03,
                        ),
                      ),
                    ],
                  ),
                ],
                
                SizedBox(height: screenSize.height * 0.02),
                
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _continueReading(context),
                    icon: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                      size: screenSize.width * 0.05,
                    ),
                    label: Text(
                      languageCubit.getLocalizedText(
                        korean: isPaused ? '계속 읽기' : '이어서 읽기',
                        english: isPaused ? 'Resume Reading' : 'Continue Reading',
                      ),
                      style: TextStyle(
                        fontSize: screenSize.width * 0.035,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _continueReading(BuildContext context) async {
    final booksCubit = context.read<BooksCubit>();
    final bookSessionCubit = context.read<BookSessionCubit>();
    final snackBarCubit = context.read<SnackBarCubit>();
    
    try {
      // Load the book details first
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
            onPreviousChapter: session.chapterIndex > 0 ? () {
              // Navigate to previous chapter
            } : null,
            onNextChapter: session.chapterIndex < book.chapters.length - 1 ? () {
              // Navigate to next chapter
            } : null,
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

class _RecentlyReadBooksSection extends StatelessWidget {
  final List<BookProgress> recentBooks;
  final LanguagePreferenceCubit languageCubit;

  const _RecentlyReadBooksSection({
    required this.recentBooks,
    required this.languageCubit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.05,
        vertical: screenSize.height * 0.015,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: colorScheme.primary,
                size: screenSize.width * 0.05,
              ),
              SizedBox(width: screenSize.width * 0.02),
              Text(
                languageCubit.getLocalizedText(
                  korean: '최근 읽은 도서',
                  english: 'Recently Read',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: screenSize.width * 0.045,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/books'),
                child: Text(
                  languageCubit.getLocalizedText(
                    korean: '전체 보기',
                    english: 'View All',
                  ),
                  style: TextStyle(
                    fontSize: screenSize.width * 0.032,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: screenSize.height * 0.015),
          
          SizedBox(
            height: screenSize.height * 0.22,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.01),
              itemCount: recentBooks.take(5).length,
              itemBuilder: (context, index) {
                final bookProgress = recentBooks[index];
                return _RecentBookCard(
                  bookProgress: bookProgress,
                  languageCubit: languageCubit,
                  screenSize: screenSize,
                );
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
  final LanguagePreferenceCubit languageCubit;
  final Size screenSize;

  const _RecentBookCard({
    required this.bookProgress,
    required this.languageCubit,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardWidth = screenSize.width * 0.35;

    return Container(
      width: cardWidth,
      margin: EdgeInsets.only(right: screenSize.width * 0.03),
      child: Card(
        elevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _continueFromLastRead(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(screenSize.width * 0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.book_rounded,
                        size: screenSize.width * 0.08,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: screenSize.height * 0.01),
                
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookProgress.bookTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontSize: screenSize.width * 0.032,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: screenSize.height * 0.008),
                      
                      if (bookProgress.lastChapterTitle != null)
                        Text(
                          '${languageCubit.getLocalizedText(korean: "챕터", english: "Ch.")} ${bookProgress.lastChapterIndex + 1}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: screenSize.width * 0.028,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const Spacer(),
                      
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: bookProgress.overallProgress,
                              backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          SizedBox(width: screenSize.width * 0.02),
                          Text(
                            bookProgress.formattedProgress,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: screenSize.width * 0.025,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _continueFromLastRead(BuildContext context) async {
    final booksCubit = context.read<BooksCubit>();
    final bookSessionCubit = context.read<BookSessionCubit>();
    final snackBarCubit = context.read<SnackBarCubit>();
    
    try {
      await booksCubit.loadBookById(bookProgress.bookId);
      
      final book = booksCubit.state.selectedBook;
      if (book == null || bookProgress.lastChapterIndex >= book.chapters.length) {
        snackBarCubit.showErrorLocalized(
          korean: '도서 또는 챕터를 찾을 수 없습니다',
          english: 'Book or chapter not found',
        );
        return;
      }

      final chapter = book.chapters[bookProgress.lastChapterIndex];
      
      await bookSessionCubit.startReadingSession(
        bookProgress.bookId,
        bookProgress.bookTitle,
        bookProgress.lastChapterIndex,
        bookProgress.lastChapterTitle ?? chapter.title,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfReadingPage(
            bookId: bookProgress.bookId,
            bookTitle: bookProgress.bookTitle,
            chapterTitle: bookProgress.lastChapterTitle ?? chapter.title,
            chapterIndex: bookProgress.lastChapterIndex,
            pdfPath: chapter.pdfPath,
            pdfUrl: chapter.pdfUrl,
            audioTracks: chapter.audioTracks,
            totalChapters: book.chapters.length,
            onPreviousChapter: bookProgress.lastChapterIndex > 0 ? () {
              // Navigate to previous chapter
            } : null,
            onNextChapter: bookProgress.lastChapterIndex < book.chapters.length - 1 ? () {
              // Navigate to next chapter
            } : null,
          ),
        ),
      );
    } catch (e) {
      snackBarCubit.showErrorLocalized(
        korean: '읽기를 시작할 수 없습니다',
        english: 'Cannot start reading',
      );
    }
  }
}