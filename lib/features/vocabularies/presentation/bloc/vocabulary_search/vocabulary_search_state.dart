
part of 'vocabulary_search_cubit.dart';

enum VocabularySearchOperationType { 
  search, 
  clearSearch,
}

enum VocabularySearchOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class VocabularySearchOperation {
  final VocabularySearchOperationType? type;
  final VocabularySearchOperationStatus status;
  final String? message;
  final String? query;
  
  const VocabularySearchOperation({
    this.type,
    required this.status,
    this.message,
    this.query,
  });
  
  bool get isInProgress => status == VocabularySearchOperationStatus.inProgress;
  bool get isCompleted => status == VocabularySearchOperationStatus.completed;
  bool get isFailed => status == VocabularySearchOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocabularySearchOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          query == other.query;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (query?.hashCode ?? 0);
}

class VocabularySearchState extends BaseState {
  final List<VocabularyItem> searchResults;
  final String currentQuery;
  final bool isSearching;
  final VocabularySearchOperation currentOperation;

  const VocabularySearchState({
    super.isLoading = false,
    super.error,
    super.errorType,
    this.searchResults = const [],
    this.currentQuery = '',
    this.isSearching = false,
    required this.currentOperation,
  });

  @override
  VocabularySearchState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      searchResults: searchResults,
      currentQuery: currentQuery,
      isSearching: isSearching,
      currentOperation: currentOperation,
    );
  }

  VocabularySearchState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    List<VocabularyItem>? searchResults,
    String? currentQuery,
    bool? isSearching,
    VocabularySearchOperation? currentOperation,
  }) {
    return VocabularySearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      searchResults: searchResults ?? this.searchResults,
      currentQuery: currentQuery ?? this.currentQuery,
      isSearching: isSearching ?? this.isSearching,
      currentOperation: currentOperation ?? this.currentOperation,
    );
  }

  VocabularySearchState copyWithOperation(VocabularySearchOperation operation) {
    return VocabularySearchState(
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

class VocabularySearchInitial extends VocabularySearchState {
  const VocabularySearchInitial() : super(
    currentOperation: const VocabularySearchOperation(status: VocabularySearchOperationStatus.none),
  );
}