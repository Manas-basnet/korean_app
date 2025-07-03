part of 'book_search_cubit.dart';

enum BookSearchOperationType { 
  search, 
  clearSearch,
}

enum BookSearchOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class BookSearchOperation {
  final BookSearchOperationType? type;
  final BookSearchOperationStatus status;
  final String? message;
  final String? query;
  
  const BookSearchOperation({
    this.type,
    required this.status,
    this.message,
    this.query,
  });
  
  bool get isInProgress => status == BookSearchOperationStatus.inProgress;
  bool get isCompleted => status == BookSearchOperationStatus.completed;
  bool get isFailed => status == BookSearchOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookSearchOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          query == other.query;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (query?.hashCode ?? 0);
}

class BookSearchState extends BaseState {
  final List<BookItem> searchResults;
  final String currentQuery;
  final bool isSearching;
  final BookSearchOperation currentOperation;

  const BookSearchState({
    super.isLoading = false,
    super.error,
    super.errorType,
    this.searchResults = const [],
    this.currentQuery = '',
    this.isSearching = false,
    required this.currentOperation,
  });

  @override
  BookSearchState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      searchResults: searchResults,
      currentQuery: currentQuery,
      isSearching: isSearching,
      currentOperation: currentOperation,
    );
  }

  BookSearchState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    List<BookItem>? searchResults,
    String? currentQuery,
    bool? isSearching,
    BookSearchOperation? currentOperation,
  }) {
    return BookSearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      searchResults: searchResults ?? this.searchResults,
      currentQuery: currentQuery ?? this.currentQuery,
      isSearching: isSearching ?? this.isSearching,
      currentOperation: currentOperation ?? this.currentOperation,
    );
  }

  BookSearchState copyWithOperation(BookSearchOperation operation) {
    return BookSearchState(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      searchResults: searchResults,
      currentQuery: currentQuery,
      isSearching: isSearching,
      currentOperation: operation,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        searchResults,
        currentQuery,
        isSearching,
        currentOperation,
      ];
}

class BookSearchInitial extends BookSearchState {
  const BookSearchInitial() : super(
    currentOperation: const BookSearchOperation(status: BookSearchOperationStatus.none),
  );
}