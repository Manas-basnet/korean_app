import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/repositories/book_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/features/books/domain/entities/user_book_interaction.dart';

part 'book_session_state.dart';

class BookSessionCubit extends Cubit<BookSessionState> {
  final BooksRepository booksRepository;
  final AuthService authService;
  
  Timer? _readingTimer;
  
  BookSessionCubit({
    required this.booksRepository,
    required this.authService,
  }) : super(const BookSessionInitial());

  void startReading(BookItem book, {int? startChapterIndex}) {
    try {
      final user = _getCurrentUser();
      if (user == null) {
        emit(const BookSessionError('User not authenticated', FailureType.auth));
        return;
      }

      final initialChapterIndex = startChapterIndex ?? 0;
      if (initialChapterIndex >= book.chapters.length) {
        emit(const BookSessionError('Invalid chapter index', FailureType.validation));
        return;
      }

      final session = BookSession(
        book: book,
        userId: user.uid,
        currentChapterIndex: initialChapterIndex,
        startTime: DateTime.now(),
        lastReadTime: DateTime.now(),
        readingProgress: 0.0,
        chapterProgress: {},
      );

      emit(BookSessionInProgress(session));
      
      _startReadingTimer();
      
      debugPrint('Started reading: ${book.title} for user: ${user.uid}');
    } catch (e) {
      emit(BookSessionError('Failed to start reading: $e', FailureType.unknown));
    }
  }

  void navigateToChapter(int chapterIndex) {
    final currentState = state;
    if (currentState is! BookSessionInProgress) return;

    try {
      final session = currentState.session;
      
      if (chapterIndex >= 0 && chapterIndex < session.book.chapters.length) {
        final updatedSession = session.copyWith(
          currentChapterIndex: chapterIndex,
          lastReadTime: DateTime.now(),
        );

        emit(BookSessionInProgress(updatedSession));
        
        debugPrint('Navigated to chapter ${chapterIndex + 1}/${session.book.chapters.length}');
      }
    } catch (e) {
      emit(BookSessionError('Failed to navigate to chapter: $e', FailureType.unknown));
    }
  }

  void nextChapter() {
    final currentState = state;
    if (currentState is! BookSessionInProgress) return;

    try {
      final session = currentState.session;
      
      if (session.currentChapterIndex < session.book.chapters.length - 1) {
        final nextIndex = session.currentChapterIndex + 1;
        final updatedSession = session.copyWith(
          currentChapterIndex: nextIndex,
          lastReadTime: DateTime.now(),
        );

        emit(BookSessionInProgress(updatedSession));
        
        debugPrint('Moved to chapter ${nextIndex + 1}/${session.book.chapters.length}');
      } else {
        debugPrint('Already on last chapter');
      }
    } catch (e) {
      emit(BookSessionError('Failed to go to next chapter: $e', FailureType.unknown));
    }
  }

  void previousChapter() {
    final currentState = state;
    if (currentState is! BookSessionInProgress) return;

    try {
      final session = currentState.session;
      
      if (session.currentChapterIndex > 0) {
        final prevIndex = session.currentChapterIndex - 1;
        final updatedSession = session.copyWith(
          currentChapterIndex: prevIndex,
          lastReadTime: DateTime.now(),
        );

        emit(BookSessionInProgress(updatedSession));
        
        debugPrint('Moved back to chapter ${prevIndex + 1}/${session.book.chapters.length}');
      } else {
        debugPrint('Already on first chapter');
      }
    } catch (e) {
      emit(BookSessionError('Failed to go to previous chapter: $e', FailureType.unknown));
    }
  }

  void updateChapterProgress(int chapterIndex, double progress) {
    final currentState = state;
    if (currentState is! BookSessionInProgress) return;

    try {
      final session = currentState.session;
      final updatedChapterProgress = Map<int, double>.from(session.chapterProgress);
      updatedChapterProgress[chapterIndex] = progress.clamp(0.0, 1.0);

      final overallProgress = _calculateOverallProgress(updatedChapterProgress, session.book.chapters.length);

      final updatedSession = session.copyWith(
        chapterProgress: updatedChapterProgress,
        readingProgress: overallProgress,
        lastReadTime: DateTime.now(),
      );

      emit(BookSessionInProgress(updatedSession));
      
      debugPrint('Updated chapter $chapterIndex progress: ${(progress * 100).toStringAsFixed(1)}%');
    } catch (e) {
      emit(BookSessionError('Failed to update chapter progress: $e', FailureType.unknown));
    }
  }

  Future<void> saveReadingProgress() async {
    final currentState = state;
    if (currentState is! BookSessionInProgress) return;

    try {
      final session = currentState.session;
      final user = _getCurrentUser();
      if (user == null) return;

      final existingInteraction = await _getExistingInteraction(session.book.id, user.uid);
      
      final updatedInteraction = UserBookInteraction(
        userId: user.uid,
        bookId: session.book.id,
        hasViewed: true,
        hasRated: existingInteraction?.hasRated ?? false,
        rating: existingInteraction?.rating,
        viewedAt: existingInteraction?.viewedAt ?? session.startTime,
        ratedAt: existingInteraction?.ratedAt,
        readingCount: (existingInteraction?.readingCount ?? 0) + 1,
        readingProgress: session.readingProgress,
        lastChapterId: session.book.chapters[session.currentChapterIndex].id,
        lastReadAt: DateTime.now(),
      );

      await booksRepository.completeBookWithViewAndRating(
        session.book.id,
        user.uid,
        null,
        updatedInteraction,
      );

      debugPrint('Saved reading progress: ${(session.readingProgress * 100).toStringAsFixed(1)}%');
    } catch (e) {
      debugPrint('Failed to save reading progress: $e');
    }
  }

  Future<void> rateBook(double rating) async {
    final currentState = state;
    if (currentState is! BookSessionInProgress) return;

    try {
      final session = currentState.session;
      final user = _getCurrentUser();
      if (user == null) return;

      if (rating < 1.0 || rating > 5.0) {
        emit(const BookSessionError('Invalid rating value', FailureType.validation));
        return;
      }

      final existingInteraction = await _getExistingInteraction(session.book.id, user.uid);

      await booksRepository.completeBookWithViewAndRating(
        session.book.id,
        user.uid,
        rating,
        existingInteraction,
      );

      debugPrint('Rated book: $rating stars');
    } catch (e) {
      emit(BookSessionError('Failed to rate book: $e', FailureType.unknown));
    }
  }

  Future<double?> getExistingRating(String bookId) async {
    final user = _getCurrentUser();
    if (user == null) return null;

    try {
      final result = await booksRepository.getUserBookInteraction(bookId, user.uid);
      return result.fold(
        onSuccess: (interaction) => interaction?.rating,
        onFailure: (_, __) => null,
      );
    } catch (e) {
      debugPrint('Failed to get existing rating: $e');
      return null;
    }
  }

  void pauseReading() {
    final currentState = state;
    if (currentState is! BookSessionInProgress) return;

    try {
      _readingTimer?.cancel();
      
      final session = currentState.session;
      final updatedSession = session.copyWith(isPaused: true);
      
      emit(BookSessionPaused(updatedSession));
      
      // Auto-save progress when pausing
      saveReadingProgress();
      
      debugPrint('Reading paused');
    } catch (e) {
      emit(BookSessionError('Failed to pause reading: $e', FailureType.unknown));
    }
  }

  void resumeReading() {
    final currentState = state;
    if (currentState is! BookSessionPaused) return;

    try {
      final session = currentState.session;
      final updatedSession = session.copyWith(
        isPaused: false,
        lastReadTime: DateTime.now(),
      );
      
      emit(BookSessionInProgress(updatedSession));
      
      _startReadingTimer();
      
      debugPrint('Reading resumed');
    } catch (e) {
      emit(BookSessionError('Failed to resume reading: $e', FailureType.unknown));
    }
  }

  void stopReading() {
    try {
      _readingTimer?.cancel();
      
      // Save progress before stopping
      saveReadingProgress();
      
      emit(const BookSessionInitial());
      debugPrint('Reading stopped');
    } catch (e) {
      emit(BookSessionError('Failed to stop reading: $e', FailureType.unknown));
    }
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Auto-save progress every minute during reading
      saveReadingProgress();
    });
  }

  double _calculateOverallProgress(Map<int, double> chapterProgress, int totalChapters) {
    if (totalChapters == 0) return 0.0;
    
    double totalProgress = 0.0;
    for (int i = 0; i < totalChapters; i++) {
      totalProgress += chapterProgress[i] ?? 0.0;
    }
    
    return totalProgress / totalChapters;
  }

  Future<UserBookInteraction?> _getExistingInteraction(String bookId, String userId) async {
    try {
      final result = await booksRepository.getUserBookInteraction(bookId, userId);
      return result.fold(
        onSuccess: (interaction) => interaction,
        onFailure: (_, __) => null,
      );
    } catch (e) {
      debugPrint('Failed to get existing interaction: $e');
      return null;
    }
  }

  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
  }

  @override
  Future<void> close() {
    _readingTimer?.cancel();
    debugPrint('Book session cubit closed');
    return super.close();
  }
}