import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_rating_dialog.dart';
import 'package:korean_language_app/features/books/presentation/widgets/chapter_navigation_sheet.dart';
import 'package:korean_language_app/features/books/presentation/widgets/custom_pdf_viewer.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_audio.dart';

class BookReadingPage extends StatefulWidget {
  final String bookId;

  const BookReadingPage({super.key, required this.bookId});

  @override
  State<BookReadingPage> createState() => _BookReadingPageState();
}

class _BookReadingPageState extends State<BookReadingPage>
    with TickerProviderStateMixin {
  late AnimationController _slideAnimationController;
  late Animation<double> _slideAnimation;
  bool _isNavigatingAway = false;
  double _readingProgress = 0.0;

  BookSessionCubit get _sessionCubit => context.read<BookSessionCubit>();
  BooksCubit get _booksCubit => context.read<BooksCubit>();
  LanguagePreferenceCubit get _languageCubit =>
      context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndStartReading();
    });
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadAndStartReading() async {
    final booksState = _booksCubit.state;
    
    if (booksState.selectedBook != null && booksState.selectedBook!.id == widget.bookId) {
      _sessionCubit.startReading(booksState.selectedBook!);
      _slideAnimationController.forward();
    } else {
      _snackBarCubit.showErrorLocalized(
        korean: '도서 데이터를 찾을 수 없습니다',
        english: 'Book data not found',
      );
      if (mounted) {
        context.pop();
      }
    }
  }

  void _nextChapter() {
    _slideAnimationController.reset();
    _sessionCubit.nextChapter();
    _slideAnimationController.forward();
  }

  void _previousChapter() {
    _slideAnimationController.reset();
    _sessionCubit.previousChapter();
    _slideAnimationController.forward();
  }

  void _jumpToChapter(int chapterIndex) {
    _slideAnimationController.reset();
    _sessionCubit.navigateToChapter(chapterIndex);
    _slideAnimationController.forward();
    Navigator.pop(context);
  }

  void _updateProgress(double progress) {
    setState(() {
      _readingProgress = progress;
    });
    
    final sessionState = _sessionCubit.state;
    if (sessionState is BookSessionInProgress) {
      _sessionCubit.updateChapterProgress(
        sessionState.session.currentChapterIndex,
        progress,
      );
    }
  }

  Future<void> _showRatingDialogAndFinish(String bookTitle, String bookId) async {
    double? existingRating;
    try {
      existingRating = await _sessionCubit.getExistingRating(bookId);
    } catch (e) {
      existingRating = null;
    }

    if (!mounted) return;

    final rating = await BookRatingDialogHelper.showRatingDialog(
      context,
      bookTitle: bookTitle,
      existingRating: existingRating,
    );
    
    if (rating != null) {
      await _sessionCubit.rateBook(rating);
    }
    
    _sessionCubit.stopReading();
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookSessionCubit, BookSessionState>(
      listener: (context, state) {
        if (state is BookSessionError && !_isNavigatingAway) {
          _snackBarCubit.showErrorLocalized(
            korean: state.error ?? '오류가 발생했습니다',
            english: state.error ?? 'An error occurred',
          );
        }
      },
      builder: (context, state) {
        if (state is BookSessionInitial) {
          return _buildLoadingScreen();
        }

        if (state is BookSessionInProgress || state is BookSessionPaused) {
          final session = state is BookSessionInProgress
              ? state.session
              : (state as BookSessionPaused).session;
          return _buildReadingScreen(session, state is BookSessionPaused);
        }

        if (state is BookSessionError) {
          return _buildErrorScreen();
        }

        return _buildLoadingScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
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
                korean: '도서를 준비하고 있습니다...',
                english: 'Preparing your book...',
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
                  korean: '오류가 발생했습니다',
                  english: 'Something went wrong',
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
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingScreen(BookSession session, bool isPaused) {
    final currentChapter = session.currentChapter;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildReadingHeader(session, isPaused),
            Expanded(
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - _slideAnimation.value)),
                    child: Opacity(
                      opacity: _slideAnimation.value,
                      child: _buildChapterContent(session, currentChapter),
                    ),
                  );
                },
              ),
            ),
            _buildNavigationButtons(session),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingHeader(BookSession session, bool isPaused) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _showExitConfirmation(session),
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                  minimumSize: const Size(36, 36),
                  padding: const EdgeInsets.all(6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.book.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${session.currentChapterIndex + 1}/${session.totalChapters} - ${session.currentChapter.title}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildHeaderActions(session),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: session.readingProgress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            minHeight: 3,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(BookSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
   
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => ChapterNavigationSheet.show(
            context,
            session,
            _languageCubit,
            _jumpToChapter,
          ),
          icon: const Icon(Icons.list_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: _languageCubit.getLocalizedText(korean: '챕터 목록', english: 'Chapter List'),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => _showRatingDialogAndFinish(session.book.title, session.book.id),
          icon: const Icon(Icons.star_outline_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: _languageCubit.getLocalizedText(korean: '평점', english: 'Rate'),
        ),
      ],
    );
  }


  Widget _buildChapterContent(BookSession session,BookChapter chapter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chapter.hasImage)
            _buildChapterImage(chapter),
          
          _buildChapterHeader(chapter),
          
          if (chapter.hasPdf)
            _buildChapterPdf(chapter),
          
          if (chapter.hasAudioTracks)
            _buildAudioTracks(chapter),
          
          const SizedBox(height: 20),
          _buildChapterDescription(chapter),
          
          const SizedBox(height: 40),
          _buildReadingProgressSlider(),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChapterPdf(BookChapter chapter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: CustomPdfViewer(
        pdfUrl: chapter.pdfUrl,
        pdfPath: chapter.pdfPath,
        label: _languageCubit.getLocalizedText(
          korean: '${chapter.title} - PDF',
          english: '${chapter.title} - PDF',
        ),
        height: 500,
        onError: () {
          _snackBarCubit.showErrorLocalized(
            korean: 'PDF를 불러올 수 없습니다',
            english: 'Failed to load PDF',
          );
        },
      ),
    );
  }

  Widget _buildChapterImage(chapter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 200,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomCachedImage(
          imageUrl: chapter.imageUrl,
          imagePath: chapter.imagePath,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildChapterHeader(chapter) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _languageCubit.getLocalizedText(korean: '챕터', english: 'Chapter'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          chapter.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAudioTracks(chapter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: chapter.audioTracks.map<Widget>((track) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: CustomCachedAudio(
              audioUrl: track.audioUrl,
              audioPath: track.audioPath,
              label: track.title,
              height: 50,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChapterDescription(chapter) {
    final theme = Theme.of(context);
    
    return Text(
      chapter.description,
      style: theme.textTheme.bodyLarge?.copyWith(
        height: 1.6,
        fontSize: 16,
      ),
    );
  }

  Widget _buildReadingProgressSlider() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _languageCubit.getLocalizedText(
                korean: '읽기 진행률',
                english: 'Reading Progress',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(_readingProgress * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: _readingProgress,
            onChanged: _updateProgress,
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(BookSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstChapter = session.isFirstChapter;
    final isLastChapter = session.isLastChapter;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (!isFirstChapter) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousChapter,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(
                  _languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => isLastChapter 
                  ? _showFinishConfirmation(session)
                  : _nextChapter(),
              icon: Icon(
                isLastChapter ? Icons.check_rounded : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                isLastChapter 
                    ? _languageCubit.getLocalizedText(korean: '완료', english: 'Finish')
                    : _languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isLastChapter ? Colors.green : colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BookSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _languageCubit.getLocalizedText(korean: '읽기 종료', english: 'Exit Reading'),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '읽기를 종료하시겠습니까? 진행 상황이 저장됩니다.',
            english: 'Exit reading? Your progress will be saved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageCubit.getLocalizedText(korean: '계속 읽기', english: 'Continue Reading')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _sessionCubit.stopReading();
              context.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(_languageCubit.getLocalizedText(korean: '종료', english: 'Exit')),
          ),
        ],
      ),
    );
  }

  void _showFinishConfirmation(BookSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _languageCubit.getLocalizedText(korean: '읽기 완료', english: 'Finish Reading'),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '도서 읽기를 완료하시겠습니까?',
            english: 'Are you sure you want to finish reading this book?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageCubit.getLocalizedText(korean: '취소', english: 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showRatingDialogAndFinish(session.book.title, session.book.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: Text(_languageCubit.getLocalizedText(korean: '완료', english: 'Finish')),
          ),
        ],
      ),
    );
  }
}