part of 'vocabulary_upload_cubit.dart';

enum VocabularyUploadOperationType { 
  createVocabulary,
  updateVocabulary,
  deleteVocabulary
}

enum VocabularyUploadOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class VocabularyUploadOperation {
  final VocabularyUploadOperationType? type;
  final VocabularyUploadOperationStatus status;
  final String? message;
  final String? vocabularyId;
  
  const VocabularyUploadOperation({
    this.type,
    required this.status,
    this.message,
    this.vocabularyId,
  });
  
  bool get isInProgress => status == VocabularyUploadOperationStatus.inProgress;
  bool get isCompleted => status == VocabularyUploadOperationStatus.completed;
  bool get isFailed => status == VocabularyUploadOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocabularyUploadOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          vocabularyId == other.vocabularyId;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (vocabularyId?.hashCode ?? 0);
}

class VocabularyUploadState extends BaseState {
  final VocabularyUploadOperation currentOperation;
  final VocabularyItem? createdVocabulary;

  const VocabularyUploadState({
    super.isLoading = false,
    super.error,
    super.errorType,
    required this.currentOperation,
    this.createdVocabulary,
  });

  @override
  VocabularyUploadState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularyUploadState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      currentOperation: currentOperation,
      createdVocabulary: createdVocabulary,
    );
  }

  VocabularyUploadState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    VocabularyUploadOperation? currentOperation,
    VocabularyItem? createdVocabulary,
  }) {
    return VocabularyUploadState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      currentOperation: currentOperation ?? this.currentOperation,
      createdVocabulary: createdVocabulary ?? this.createdVocabulary,
    );
  }

  VocabularyUploadState copyWithOperation(VocabularyUploadOperation operation) {
    return VocabularyUploadState(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      currentOperation: operation,
      createdVocabulary: createdVocabulary,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        currentOperation,
        createdVocabulary,
      ];
}

class VocabularyUploadInitial extends VocabularyUploadState {
  const VocabularyUploadInitial() : super(
    currentOperation: const VocabularyUploadOperation(status: VocabularyUploadOperationStatus.none),
  );
}