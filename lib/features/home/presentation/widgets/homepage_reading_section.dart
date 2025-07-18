import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/features/books/data/model/book_progress.dart';
import 'package:korean_language_app/features/books/data/model/reading_session.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';
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
              _ContinueReadingCard(
                session: state.currentSession,
                bookProgress: state.currentBookProgress,
              ),
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
              _ContinueReadingCard(
                session: state.pausedSession,
                bookProgress: state.currentBookProgress,
                isPaused: true,
              ),
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
  final BookProgress? bookProgress;
  final bool isPaused;

  const _ContinueReadingCard({
    required this.session,
    this.bookProgress,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 12),
          Card(
            elevation: 0,
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.secondaryContainer.withValues(alpha: 0.4),
                      colorScheme.secondaryContainer.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    if (bookProgress?.bookItem?.imageUrl != null || bookProgress?.bookItem?.imagePath != null)
                      Container(
                        width: 60,
                        height: 90,
                        margin: const EdgeInsets.only(right: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CustomCachedImage(
                            imageUrl: bookProgress?.bookItem?.imageUrl,
                            imagePath: bookProgress?.bookItem?.imagePath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: colorScheme.onSecondary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                languageCubit.getLocalizedText(
                                  korean: isPaused ? '일시정지됨' : '계속 읽기',
                                  english: isPaused ? 'Paused' : 'Continue',
                                ),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 12),
                          if (session.totalPages > 0)
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: session.chapterProgress,
                                    backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${session.currentPage}/${session.totalPages}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                session.formattedReadingTime,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatLastReadTime(session.lastActiveTime, languageCubit),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
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
        ],
      ),
    );
  }

  void _continueReading(BuildContext context) async {
    final bookSessionCubit = context.read<BookSessionCubit>();
    
    try {
      if (isPaused) {
        await bookSessionCubit.resumeSession();
      }

      if (bookProgress?.bookItem != null) {
        context.push(
          Routes.bookChapterReading(session.bookId, session.chapterIndex),
          extra: bookProgress!.bookItem,
        );
      } else {
        context.push(Routes.bookChapters(session.bookId));
      }
    } catch (e) {
      final snackBarCubit = context.read<SnackBarCubit>();
      snackBarCubit.showErrorLocalized(
        korean: '읽기를 계속할 수 없습니다',
        english: 'Cannot continue reading',
      );
    }
  }

  String _formatLastReadTime(DateTime lastRead, LanguagePreferenceCubit languageCubit) {
    final now = DateTime.now();
    final difference = now.difference(lastRead);

    if (difference.inDays > 0) {
      return languageCubit.getLocalizedText(
        korean: '${difference.inDays}일 전',
        english: '${difference.inDays}d ago',
      );
    } else if (difference.inHours > 0) {
      return languageCubit.getLocalizedText(
        korean: '${difference.inHours}시간 전',
        english: '${difference.inHours}h ago',
      );
    } else {
      return languageCubit.getLocalizedText(
        korean: '방금 전',
        english: 'Just now',
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
      margin: const EdgeInsets.symmetric(vertical: 16),
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
                  onPressed: () => context.push('/reading-history'),
                  child: Text(
                    languageCubit.getLocalizedText(
                      korean: '더보기',
                      english: 'See All',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
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

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12, left: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _openBook(context),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _buildBookImage(colorScheme),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: bookProgress.overallProgress,
                        backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          bookProgress.overallProgress >= 1.0 ? Colors.green : colorScheme.primary,
                        ),
                        minHeight: 3,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bookProgress.formattedProgress,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: bookProgress.overallProgress >= 1.0 ? Colors.green : colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildBookImage(ColorScheme colorScheme) {
    final bookItem = bookProgress.bookItem;
    
    if (bookItem?.imageUrl != null || bookItem?.imagePath != null) {
      return CustomCachedImage(
        imageUrl: bookItem?.imageUrl,
        imagePath: bookItem?.imagePath,
        fit: BoxFit.cover,
      );
    }
    
    return Icon(
      Icons.library_books_rounded,
      size: 40,
      color: colorScheme.onSurfaceVariant,
    );
  }

  void _openBook(BuildContext context) {
    if (bookProgress.bookItem != null) {
      final chapterIndex = bookProgress.lastChapterIndex;
      context.push(
        Routes.bookChapterReading(bookProgress.bookId, chapterIndex),
        extra: bookProgress.bookItem,
      );
    } else {
      context.push(Routes.bookChapters(bookProgress.bookId));
    }
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

    final inProgressBooks = recentBooks.where((book) => 
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
      margin: const EdgeInsets.all(20),
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
                  value: inProgressBooks.toString(),
                  color: colorScheme.primary,
                  theme: theme,
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
                  color: Colors.green,
                  theme: theme,
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
                  color: colorScheme.tertiary,
                  theme: theme,
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
      return '${totalTime.inMinutes}m';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
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
          ),
        ],
      ),
    );
  }
}