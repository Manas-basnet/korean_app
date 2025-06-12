part of 'test_search_cubit.dart';

enum TestSearchOperationType { 
  search, 
  clearSearch,
}

enum TestSearchOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class TestSearchOperation {
  final TestSearchOperationType? type;
  final TestSearchOperationStatus status;
  final String? message;
  final String? query;
  
  const TestSearchOperation({
    this.type,
    required this.status,
    this.message,
    this.query,
  });
  
  bool get isInProgress => status == TestSearchOperationStatus.inProgress;
  bool get isCompleted => status == TestSearchOperationStatus.completed;
  bool get isFailed => status == TestSearchOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestSearchOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          query == other.query;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (query?.hashCode ?? 0);
}

class TestSearchState extends BaseState {
  final List<TestItem> searchResults;
  final String currentQuery;
  final bool isSearching;
  final TestSearchOperation currentOperation;

  const TestSearchState({
    super.isLoading = false,
    super.error,
    super.errorType,
    this.searchResults = const [],
    this.currentQuery = '',
    this.isSearching = false,
    required this.currentOperation,
  });

  @override
  TestSearchState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return TestSearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      searchResults: searchResults,
      currentQuery: currentQuery,
      isSearching: isSearching,
      currentOperation: currentOperation,
    );
  }

  TestSearchState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    List<TestItem>? searchResults,
    String? currentQuery,
    bool? isSearching,
    TestSearchOperation? currentOperation,
  }) {
    return TestSearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      searchResults: searchResults ?? this.searchResults,
      currentQuery: currentQuery ?? this.currentQuery,
      isSearching: isSearching ?? this.isSearching,
      currentOperation: currentOperation ?? this.currentOperation,
    );
  }

  TestSearchState copyWithOperation(TestSearchOperation operation) {
    return TestSearchState(
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

class TestSearchInitial extends TestSearchState {
  const TestSearchInitial() : super(
    currentOperation: const TestSearchOperation(status: TestSearchOperationStatus.none),
  );
}