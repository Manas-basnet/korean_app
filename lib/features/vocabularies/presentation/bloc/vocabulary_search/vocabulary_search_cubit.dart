import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/search_vocabularies_usecase.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

part 'vocabulary_search_state.dart';

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

class VocabularySearchCubit extends Cubit<VocabularySearchState> {
  final SearchVocabulariesUseCase searchVocabulariesUseCase;
  
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);
  String _lastSearchQuery = '';
  final Stopwatch _operationStopwatch = Stopwatch();
  
  VocabularySearchCubit({
    required this.searchVocabulariesUseCase,
  }) : super(const VocabularySearchInitial());

  void searchVocabularies(String query) {
    _searchDebounceTimer?.cancel();
    
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.length < 2) {
      debugPrint('Search query too short, clearing search results');
      _lastSearchQuery = '';
      
      emit(state.copyWith(
        searchResults: [],
        currentQuery: '',
        isSearching: false,
        isLoading: false,
        error: null,
        errorType: null,
        currentOperation: const VocabularySearchOperation(
          type: VocabularySearchOperationType.clearSearch,
          status: VocabularySearchOperationStatus.completed,
        ),
      ));
      _clearOperationAfterDelay();
      return;
    }
    
    if (trimmedQuery == _lastSearchQuery && state.searchResults.isNotEmpty) {
      debugPrint('Duplicate search query, skipping');
      return;
    }
    
    _searchDebounceTimer = Timer(_searchDebounceDelay, () {
      _performSearch(trimmedQuery);
    });
  }
  
  Future<void> _performSearch(String query) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Search operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    _lastSearchQuery = query;
    
    try {
      emit(state.copyWith(
        isLoading: true,
        isSearching: true,
        currentQuery: query,
        error: null,
        errorType: null,
        currentOperation: VocabularySearchOperation(
          type: VocabularySearchOperationType.search,
          status: VocabularySearchOperationStatus.inProgress,
          query: query,
        ),
      ));
      
      final result = await searchVocabulariesUseCase.execute(
        SearchVocabulariesParams(query: query, limit: 20)
      );
      
      result.fold(
        onSuccess: (searchResult) {
          final uniqueSearchResults = _removeDuplicates(searchResult.vocabularies);
          
          _operationStopwatch.stop();
          debugPrint('Search completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueSearchResults.length} results for query: "$query"');
          
          emit(state.copyWith(
            searchResults: uniqueSearchResults,
            currentQuery: query,
            isSearching: true,
            isLoading: false,
            error: null,
            errorType: null,
            currentOperation: VocabularySearchOperation(
              type: VocabularySearchOperationType.search,
              status: VocabularySearchOperationStatus.completed,
              query: query,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Search failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(VocabularySearchOperation(
            type: VocabularySearchOperationType.search,
            status: VocabularySearchOperationStatus.failed,
            query: query,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error searching vocabularies after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to search vocabularies: $e', VocabularySearchOperationType.search, query);
    }
  }

  void clearSearch() {
    debugPrint('Clearing search results');
    _searchDebounceTimer?.cancel();
    _lastSearchQuery = '';
    
    emit(state.copyWith(
      searchResults: [],
      currentQuery: '',
      isSearching: false,
      isLoading: false,
      error: null,
      errorType: null,
      currentOperation: const VocabularySearchOperation(
        type: VocabularySearchOperationType.clearSearch,
        status: VocabularySearchOperationStatus.completed,
      ),
    ));
    _clearOperationAfterDelay();
  }

  List<VocabularyItem> _removeDuplicates(List<VocabularyItem> vocabularies) {
    final Set<String> seenIds = <String>{};
    return vocabularies.where((vocabulary) => seenIds.add(vocabulary.id)).toList();
  }

  void _handleError(String message, VocabularySearchOperationType operationType, [String? query]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(VocabularySearchOperation(
      type: operationType,
      status: VocabularySearchOperationStatus.failed,
      message: message,
      query: query,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 2), () {
      if (!isClosed && state.currentOperation.status != VocabularySearchOperationStatus.none) {
        emit(state.copyWithOperation(
          const VocabularySearchOperation(status: VocabularySearchOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing VocabularySearchCubit...');
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}