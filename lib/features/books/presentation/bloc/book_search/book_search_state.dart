part of 'book_search_cubit.dart';

enum BookSearchOperationType {
  idle,
  searchBooks,
  clearSearch,
}

enum BookSearchOperationStatus {
  idle,
  inProgress,
  completed,
  failed,
}

class BookSearchOperation {
  final BookSearchOperationType type;
  final BookSearchOperationStatus status;

  const BookSearchOperation({
    required this.type,
    required this.status,
  });

  bool get isInProgress => status == BookSearchOperationStatus.inProgress;
  bool get isCompleted => status == BookSearchOperationStatus.completed;
  bool get isFailed => status == BookSearchOperationStatus.failed;
  bool get isIdle => status == BookSearchOperationStatus.idle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookSearchOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status;

  @override
  int get hashCode => type.hashCode ^ status.hashCode;
}

abstract class BookSearchState extends BaseState {
  final List<BookItem> searchResults;
  final String currentQuery;
  final bool isSearching;
  final BookSearchOperation currentOperation;

  const BookSearchState({
    required this.searchResults,
    required this.currentQuery,
    required this.isSearching,
    required this.currentOperation,
    required super.isLoading,
    required super.error,
    required super.errorType,
  });

  BookSearchState copyWith({
    List<BookItem>? searchResults,
    String? currentQuery,
    bool? isSearching,
    BookSearchOperation? currentOperation,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    if (this is BookSearchInitial) {
      return BookSearchLoaded(
        searchResults: searchResults ?? this.searchResults,
        currentQuery: currentQuery ?? this.currentQuery,
        isSearching: isSearching ?? this.isSearching,
        currentOperation: currentOperation ?? this.currentOperation,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        errorType: errorType ?? this.errorType,
      );
    }

    return BookSearchLoaded(
      searchResults: searchResults ?? this.searchResults,
      currentQuery: currentQuery ?? this.currentQuery,
      isSearching: isSearching ?? this.isSearching,
      currentOperation: currentOperation ?? this.currentOperation,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      errorType: errorType ?? this.errorType,
    );
  }

  @override
  BookSearchState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    BookSearchOperation? currentOperation,
  }) {
    return copyWith(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      currentOperation: currentOperation,
    );
  }

  @override
  List<Object?> get props => [
        searchResults,
        currentQuery,
        isSearching,
        currentOperation,
        isLoading,
        error,
        errorType,
      ];
}

class BookSearchInitial extends BookSearchState {
  const BookSearchInitial()
      : super(
          searchResults: const [],
          currentQuery: '',
          isSearching: false,
          currentOperation: const BookSearchOperation(
            type: BookSearchOperationType.idle,
            status: BookSearchOperationStatus.idle,
          ),
          isLoading: false,
          error: null,
          errorType: null,
        );
}

class BookSearchLoaded extends BookSearchState {
  const BookSearchLoaded({
    required super.searchResults,
    required super.currentQuery,
    required super.isSearching,
    required super.currentOperation,
    required super.isLoading,
    required super.error,
    required super.errorType,
  });

  bool get hasSearchResults => searchResults.isNotEmpty;
  bool get isSearchActive => currentQuery.isNotEmpty;
}