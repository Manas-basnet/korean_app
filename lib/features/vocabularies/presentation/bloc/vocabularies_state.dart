part of 'vocabularies_cubit.dart';

enum VocabulariesOperationType { 
  loadVocabularies, 
  loadMoreVocabularies, 
  refreshVocabularies,
  loadVocabularyById,
  rateVocabulary
}

enum VocabulariesOperationStatus { 
  none, 
  inProgress, 
  completed, 
  failed 
}

class VocabulariesOperation {
  final VocabulariesOperationType? type;
  final VocabulariesOperationStatus status;
  final String? message;
  final String? vocabularyId;
  
  const VocabulariesOperation({
    this.type,
    required this.status,
    this.message,
    this.vocabularyId,
  });
  
  bool get isInProgress => status == VocabulariesOperationStatus.inProgress;
  bool get isCompleted => status == VocabulariesOperationStatus.completed;
  bool get isFailed => status == VocabulariesOperationStatus.failed;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocabulariesOperation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          message == other.message &&
          vocabularyId == other.vocabularyId;
          
  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ (message?.hashCode ?? 0) ^ (vocabularyId?.hashCode ?? 0);
}

class VocabulariesState extends BaseState {
  final List<VocabularyItem> vocabularies;
  final bool hasMore;
  final VocabulariesOperation currentOperation;
  final VocabularyItem? selectedVocabulary;
  final BookLevel? currentLevel;
  final SupportedLanguage? currentLanguage;

  const VocabulariesState({
    super.isLoading = false,
    super.error,
    super.errorType,
    this.vocabularies = const [],
    this.hasMore = false,
    required this.currentOperation,
    this.selectedVocabulary,
    this.currentLevel,
    this.currentLanguage,
  });

  @override
  VocabulariesState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabulariesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      vocabularies: vocabularies,
      hasMore: hasMore,
      currentOperation: currentOperation,
      selectedVocabulary: selectedVocabulary,
      currentLevel: currentLevel,
      currentLanguage: currentLanguage,
    );
  }

  VocabulariesState copyWith({
    bool? isLoading,
    String? error,
    FailureType? errorType,
    List<VocabularyItem>? vocabularies,
    bool? hasMore,
    VocabulariesOperation? currentOperation,
    VocabularyItem? selectedVocabulary,
    BookLevel? currentLevel,
    SupportedLanguage? currentLanguage,
  }) {
    return VocabulariesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
      vocabularies: vocabularies ?? this.vocabularies,
      hasMore: hasMore ?? this.hasMore,
      currentOperation: currentOperation ?? this.currentOperation,
      selectedVocabulary: selectedVocabulary ?? this.selectedVocabulary,
      currentLevel: currentLevel ?? this.currentLevel,
      currentLanguage: currentLanguage ?? this.currentLanguage,
    );
  }

  VocabulariesState copyWithOperation(VocabulariesOperation operation) {
    return VocabulariesState(
      isLoading: isLoading,
      error: error,
      errorType: errorType,
      vocabularies: vocabularies,
      hasMore: hasMore,
      currentOperation: operation,
      selectedVocabulary: selectedVocabulary,
      currentLevel: currentLevel,
      currentLanguage: currentLanguage,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        vocabularies,
        hasMore,
        currentOperation,
        selectedVocabulary,
        currentLevel,
        currentLanguage,
      ];
}

class VocabulariesInitial extends VocabulariesState {
  const VocabulariesInitial() : super(
    currentOperation: const VocabulariesOperation(status: VocabulariesOperationStatus.none),
  );
}