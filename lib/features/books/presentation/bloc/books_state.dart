part of 'books_cubit.dart';

enum BooksOperationType { 
  loadBooks, 
  loadMoreBooks, 
  refreshBooks,
  loadBookById,
  createBook,
  updateBook,
  deleteBook
}

enum BooksOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class BooksOperation {
  final BooksOperationType? type;
  final BooksOperationStatus status;
  final String? message;
  final String? bookId;
  
  const BooksOperation({
    this.type,
    required this.status,
    this.message,
    this.bookId,
  });
  
  bool get isInProgress => status == BooksOperationStatus.inProgress;
  bool get isCompleted => status == BooksOperationStatus.completed;
  bool get isFailed => status == BooksOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BooksOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          bookId == other.bookId;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (bookId?.hashCode ?? 0);
}

class BooksState extends BaseState {
  final List<BookItem> books;
  final bool hasMore;
  final BooksOperation currentOperation;
  final BookItem? selectedBook;
  final TestSortType currentSortType;

  const BooksState({
    super.isLoading = false,
    super.error,
    super.errorType,
    this.books = const [],
    this.hasMore = false,
    required this.currentOperation,
    this.selectedBook,
    this.currentSortType = TestSortType.recent,
  });

  @override
  BooksState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BooksState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      books: books,
      hasMore: hasMore,
      currentOperation: currentOperation,
      selectedBook: selectedBook,
      currentSortType: currentSortType,
    );
  }

  BooksState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    List<BookItem>? books,
    bool? hasMore,
    BooksOperation? currentOperation,
    BookItem? selectedBook,
    TestSortType? currentSortType,
  }) {
    return BooksState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      books: books ?? this.books,
      hasMore: hasMore ?? this.hasMore,
      currentOperation: currentOperation ?? this.currentOperation,
      selectedBook: selectedBook ?? this.selectedBook,
      currentSortType: currentSortType ?? this.currentSortType,
    );
  }

  BooksState copyWithOperation(BooksOperation operation) {
    return BooksState(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      books: books,
      hasMore: hasMore,
      currentOperation: operation,
      selectedBook: selectedBook,
      currentSortType: currentSortType,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        books,
        hasMore,
        currentOperation,
        selectedBook,
        currentSortType,
      ];
}

class BooksInitial extends BooksState {
  const BooksInitial() : super(
    currentOperation: const BooksOperation(status: BooksOperationStatus.none),
  );
}