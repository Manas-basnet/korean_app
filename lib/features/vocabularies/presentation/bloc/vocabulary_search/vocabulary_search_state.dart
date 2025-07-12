
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