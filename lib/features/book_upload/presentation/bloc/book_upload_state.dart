part of 'book_upload_cubit.dart';

enum BookUploadOperationType { 
  createBook,
  updateBook,
  deleteBook
}

enum BookUploadOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class BookUploadOperation {
  final BookUploadOperationType? type;
  final BookUploadOperationStatus status;
  final String? message;
  final String? bookId;
  
  const BookUploadOperation({
    this.type,
    required this.status,
    this.message,
    this.bookId,
  });
  
  bool get isInProgress => status == BookUploadOperationStatus.inProgress;
  bool get isCompleted => status == BookUploadOperationStatus.completed;
  bool get isFailed => status == BookUploadOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookUploadOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          bookId == other.bookId;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (bookId?.hashCode ?? 0);
}

class BookUploadState extends BaseState {
  final BookUploadOperation currentOperation;
  final BookItem? createdBook;

  const BookUploadState({
    super.isLoading = false,
    super.error,
    super.errorType,
    required this.currentOperation,
    this.createdBook,
  });

  @override
  BookUploadState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookUploadState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      currentOperation: currentOperation,
      createdBook: createdBook,
    );
  }

  BookUploadState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    BookUploadOperation? currentOperation,
    BookItem? createdBook,
  }) {
    return BookUploadState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      currentOperation: currentOperation ?? this.currentOperation,
      createdBook: createdBook ?? this.createdBook,
    );
  }

  BookUploadState copyWithOperation(BookUploadOperation operation) {
    return BookUploadState(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      currentOperation: operation,
      createdBook: createdBook,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        currentOperation,
        createdBook,
      ];
}

class BookUploadInitial extends BookUploadState {
  const BookUploadInitial() : super(
    currentOperation: const BookUploadOperation(status: BookUploadOperationStatus.none),
  );
}