part of 'korean_books_cubit.dart';

enum KoreanBooksOperationType { 
  loadBooks, 
  loadMoreBooks, 
  searchBooks, 
  loadPdf, 
  refreshBooks,
  loadAudioTrack,
  preloadAudioTracks,
}

enum KoreanBooksOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class KoreanBooksOperation {
  final KoreanBooksOperationType? type;
  final KoreanBooksOperationStatus status;
  final String? message;
  final String? bookId;
  
  const KoreanBooksOperation({
    this.type,
    required this.status,
    this.message,
    this.bookId,
  });
  
  bool get isInProgress => status == KoreanBooksOperationStatus.inProgress;
  bool get isCompleted => status == KoreanBooksOperationStatus.completed;
  bool get isFailed => status == KoreanBooksOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KoreanBooksOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          bookId == other.bookId;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (bookId?.hashCode ?? 0);
}

class KoreanBooksState extends BaseState {
  final List<BookItem> books;
  final bool hasMore;
  final KoreanBooksOperation currentOperation;
  final File? loadedPdfFile;
  final String? loadedPdfBookId;
  final File? loadedAudioFile;
  final String? loadedAudioTrackId;
  final String? loadedAudioBookId;
  final String? loadedAudioChapterId;

  const KoreanBooksState({
    super.isLoading = false,
    super.error,
    super.errorType,
    this.books = const [],
    this.hasMore = false,
    required this.currentOperation,
    this.loadedPdfFile,
    this.loadedPdfBookId,
    this.loadedAudioFile,
    this.loadedAudioTrackId,
    this.loadedAudioBookId,
    this.loadedAudioChapterId,
  });

  @override
  KoreanBooksState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return KoreanBooksState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      books: books,
      hasMore: hasMore,
      currentOperation: currentOperation,
      loadedPdfFile: loadedPdfFile,
      loadedPdfBookId: loadedPdfBookId,
      loadedAudioFile: loadedAudioFile,
      loadedAudioTrackId: loadedAudioTrackId,
      loadedAudioBookId: loadedAudioBookId,
      loadedAudioChapterId: loadedAudioChapterId,
    );
  }

  KoreanBooksState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    List<BookItem>? books,
    bool? hasMore,
    KoreanBooksOperation? currentOperation,
    File? loadedPdfFile,
    String? loadedPdfBookId,
    File? loadedAudioFile,
    String? loadedAudioTrackId,
    String? loadedAudioBookId,
    String? loadedAudioChapterId,
  }) {
    return KoreanBooksState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      books: books ?? this.books,
      hasMore: hasMore ?? this.hasMore,
      currentOperation: currentOperation ?? this.currentOperation,
      loadedPdfFile: loadedPdfFile ?? this.loadedPdfFile,
      loadedPdfBookId: loadedPdfBookId ?? this.loadedPdfBookId,
      loadedAudioFile: loadedAudioFile ?? this.loadedAudioFile,
      loadedAudioTrackId: loadedAudioTrackId ?? this.loadedAudioTrackId,
      loadedAudioBookId: loadedAudioBookId ?? this.loadedAudioBookId,
      loadedAudioChapterId: loadedAudioChapterId ?? this.loadedAudioChapterId,
    );
  }

  KoreanBooksState copyWithOperation(KoreanBooksOperation operation) {
    return KoreanBooksState(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      books: books,
      hasMore: hasMore,
      currentOperation: operation,
      loadedPdfFile: loadedPdfFile,
      loadedPdfBookId: loadedPdfBookId,
      loadedAudioFile: loadedAudioFile,
      loadedAudioTrackId: loadedAudioTrackId,
      loadedAudioBookId: loadedAudioBookId,
      loadedAudioChapterId: loadedAudioChapterId,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        books,
        hasMore,
        currentOperation,
        loadedPdfFile?.path,
        loadedPdfBookId,
        loadedAudioFile?.path,
        loadedAudioTrackId,
        loadedAudioBookId,
        loadedAudioChapterId,
      ];
}

class KoreanBooksInitial extends KoreanBooksState {
  const KoreanBooksInitial() : super(
    currentOperation: const KoreanBooksOperation(status: KoreanBooksOperationStatus.none),
    loadedAudioFile: null,
    loadedAudioTrackId: null,
    loadedAudioBookId: null,
    loadedAudioChapterId: null,
  );
}