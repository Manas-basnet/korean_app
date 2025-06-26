import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/usecases/load_favorite_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/search_favorite_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/toggle_favorite_book_usecase.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

part 'favorite_books_state.dart';

class FavoriteBooksCubit extends Cubit<FavoriteBooksState> {
  final LoadFavoriteBooksUseCase loadFavoriteBooksUseCase;
  final SearchFavoriteBooksUseCase searchFavoriteBooksUseCase;
  final ToggleFavoriteBookUseCase toggleFavoriteBookUseCase;
  
  final Stopwatch _operationStopwatch = Stopwatch();
  
  FavoriteBooksCubit({
    required this.loadFavoriteBooksUseCase,
    required this.searchFavoriteBooksUseCase,
    required this.toggleFavoriteBookUseCase,
  }) : super(const FavoriteBooksInitial());
  
  Future<void> loadInitialBooks() async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Favorite books load operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const FavoriteBooksOperation(
          type: FavoriteBooksOperationType.loadBooks,
          status: FavoriteBooksOperationStatus.inProgress,
        ),
      ));
      
      final params = LoadFavoriteBooksParams(
        category: CourseCategory.favorite,
        page: 0,
        pageSize: 50, // Load all favorites since it's local
      );
      
      final result = await loadFavoriteBooksUseCase.execute(params);
      
      result.fold(
        onSuccess: (loadResult) {
          _operationStopwatch.stop();
          debugPrint('loadFavoriteBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.books.length} books');
          
          emit(FavoriteBooksState(
            books: loadResult.books,
            hasMore: loadResult.hasMore,
            currentOperation: const FavoriteBooksOperation(
              type: FavoriteBooksOperationType.loadBooks,
              status: FavoriteBooksOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadFavoriteBooks failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const FavoriteBooksOperation(
            type: FavoriteBooksOperationType.loadBooks,
            status: FavoriteBooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading favorite books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load favorite books: $e', FavoriteBooksOperationType.loadBooks);
    }
  }
  
  Future<void> hardRefresh() async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Favorite books refresh operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const FavoriteBooksOperation(
          type: FavoriteBooksOperationType.refreshBooks,
          status: FavoriteBooksOperationStatus.inProgress,
        ),
      ));
      
      final params = LoadFavoriteBooksParams(
        category: CourseCategory.favorite,
        page: 0,
        pageSize: 50, // Load all favorites since it's local
      );
      
      final result = await loadFavoriteBooksUseCase.execute(params);
      
      result.fold(
        onSuccess: (loadResult) {
          _operationStopwatch.stop();
          debugPrint('refreshFavoriteBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.books.length} books');
          
          emit(FavoriteBooksState(
            books: loadResult.books,
            hasMore: loadResult.hasMore,
            currentOperation: const FavoriteBooksOperation(
              type: FavoriteBooksOperationType.refreshBooks,
              status: FavoriteBooksOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('refreshFavoriteBooks failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const FavoriteBooksOperation(
            type: FavoriteBooksOperationType.refreshBooks,
            status: FavoriteBooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error refreshing favorite books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to refresh favorite books: $e', FavoriteBooksOperationType.refreshBooks);
    }
  }
  
  Future<void> searchBooks(String query) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Favorite books search operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        currentOperation: const FavoriteBooksOperation(
          type: FavoriteBooksOperationType.searchBooks,
          status: FavoriteBooksOperationStatus.inProgress,
        ),
      ));
      
      final params = SearchFavoriteBooksParams(
        category: CourseCategory.favorite,
        query: query,
      );
      
      final result = await searchFavoriteBooksUseCase.execute(params);
      
      result.fold(
        onSuccess: (searchResults) {
          _operationStopwatch.stop();
          debugPrint('searchFavoriteBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${searchResults.length} results for query: "$query"');
          
          emit(state.copyWith(
            books: searchResults,
            hasMore: false, // No pagination for search results
            isLoading: false,
            error: null,
            errorType: null,
            currentOperation: const FavoriteBooksOperation(
              type: FavoriteBooksOperationType.searchBooks,
              status: FavoriteBooksOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('searchFavoriteBooks failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const FavoriteBooksOperation(
            type: FavoriteBooksOperationType.searchBooks,
            status: FavoriteBooksOperationStatus.failed,
          ))); 
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error searching favorite books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to search favorite books: $e', FavoriteBooksOperationType.searchBooks);
    }
  }

  Future<void> toggleFavorite(BookItem bookItem) async {
    if (state.currentOperation.type == FavoriteBooksOperationType.toggleFavorite && 
        state.currentOperation.isInProgress) {
      debugPrint('Toggle favorite operation already in progress for book: ${bookItem.id}');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        currentOperation: const FavoriteBooksOperation(
          type: FavoriteBooksOperationType.toggleFavorite,
          status: FavoriteBooksOperationStatus.inProgress,
        ),
      ));
      
      final params = ToggleFavoriteBookParams(
        book: bookItem,
        currentFavorites: state.books,
      );
      
      final result = await toggleFavoriteBookUseCase.execute(params);
      
      result.fold(
        onSuccess: (toggleResult) {
          _operationStopwatch.stop();
          debugPrint('toggleFavorite completed in ${_operationStopwatch.elapsedMilliseconds}ms for book: ${bookItem.title} (${toggleResult.wasAdded ? 'added' : 'removed'})');
          
          emit(state.copyWith(
            books: toggleResult.updatedFavorites,
            hasMore: toggleResult.hasMore,
            currentOperation: const FavoriteBooksOperation(
              type: FavoriteBooksOperationType.toggleFavorite,
              status: FavoriteBooksOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('toggleFavorite failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(error: message, errorType: type));
          
          // Reload the original favorites to recover from error
          Future.delayed(const Duration(milliseconds: 100), () {
            loadInitialBooks();
          });
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error toggling favorite after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      
      emit(state.copyWithBaseState(error: 'Failed to toggle favorite status: $e'));
      
      // Reload the original favorites to recover from error
      loadInitialBooks();
    }
  }

  void _handleError(String message, FavoriteBooksOperationType operationType) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(FavoriteBooksOperation(
      type: operationType,
      status: FavoriteBooksOperationStatus.failed,
      message: message,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (state.currentOperation.status != FavoriteBooksOperationStatus.none) {
        emit(state.copyWithOperation(const FavoriteBooksOperation(status: FavoriteBooksOperationStatus.none)));
      }
    });
  }
}