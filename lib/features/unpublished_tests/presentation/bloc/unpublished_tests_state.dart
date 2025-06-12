part of 'unpublished_tests_cubit.dart';

enum UnpublishedTestsOperationType { 
  loadTests, 
  loadMoreTests, 
  searchTests, 
  refreshTests
}

enum UnpublishedTestsOperationStatus { 
  none,
  inProgress, 
  completed, 
  failed 
}

class UnpublishedTestsOperation {
  final UnpublishedTestsOperationType? type;
  final UnpublishedTestsOperationStatus status;
  final String? message;
  final String? testId;
  
  const UnpublishedTestsOperation({
    this.type,
    required this.status,
    this.message,
    this.testId,
  });
  
  bool get isInProgress => status == UnpublishedTestsOperationStatus.inProgress;
  bool get isCompleted => status == UnpublishedTestsOperationStatus.completed;
  bool get isFailed => status == UnpublishedTestsOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnpublishedTestsOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          testId == other.testId;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (testId?.hashCode ?? 0);
}

class UnpublishedTestsState extends BaseState {
  final List<TestItem> tests;
  final bool hasMore;
  final UnpublishedTestsOperation currentOperation;
  final TestItem? selectedTest;

  const UnpublishedTestsState({
    super.isLoading = false,
    super.error,
    super.errorType,
    this.tests = const [],
    this.hasMore = false,
    required this.currentOperation,
    this.selectedTest,
  });

  @override
  UnpublishedTestsState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return UnpublishedTestsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      tests: tests,
      hasMore: hasMore,
      currentOperation: currentOperation,
      selectedTest: selectedTest,
    );
  }

  UnpublishedTestsState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    List<TestItem>? tests,
    bool? hasMore,
    UnpublishedTestsOperation? currentOperation,
    TestItem? selectedTest,
  }) {
    return UnpublishedTestsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      tests: tests ?? this.tests,
      hasMore: hasMore ?? this.hasMore,
      currentOperation: currentOperation ?? this.currentOperation,
      selectedTest: selectedTest ?? this.selectedTest,
    );
  }

  UnpublishedTestsState copyWithOperation(UnpublishedTestsOperation operation) {
    return UnpublishedTestsState(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      tests: tests,
      hasMore: hasMore,
      currentOperation: operation,
      selectedTest: selectedTest,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        tests,
        hasMore,
        currentOperation,
        selectedTest,
      ];
}

class UnpublishedTestsInitial extends UnpublishedTestsState {
  const UnpublishedTestsInitial() : super(
    currentOperation: const UnpublishedTestsOperation(status: UnpublishedTestsOperationStatus.none),
  );
}