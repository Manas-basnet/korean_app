import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/load_vocabularies_usecase.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/get_vocabulary_by_id_usecase.dart';
import 'package:korean_language_app/features/vocabularies/domain/usecases/rate_vocabulary_usecase.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

part 'vocabularies_state.dart';

class VocabulariesCubit extends Cubit<VocabulariesState> {
  final LoadVocabulariesUseCase loadVocabulariesUseCase;
  final GetVocabularyByIdUseCase getVocabularyByIdUseCase;
  final RateVocabularyUseCase rateVocabularyUseCase;
  final NetworkInfo networkInfo;
  
  int _currentPage = 0;
  static const int _pageSize = 20;
  BookLevel? _currentLevel;
  SupportedLanguage? _currentLanguage;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  Timer? _loadMoreDebounceTimer;
  static const Duration _loadMoreDebounceDelay = Duration(milliseconds: 300);
  
  VocabulariesCubit({
    required this.loadVocabulariesUseCase,
    required this.getVocabularyByIdUseCase,
    required this.rateVocabularyUseCase,
    required this.networkInfo,
  }) : super(const VocabulariesInitial()) {
    _initializeConnectivityListener();
  }

  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      
      if (isConnected && (state.vocabularies.isEmpty || state.hasError)) {
        debugPrint('Connection restored, reloading vocabularies...');
        if (_currentLevel != null) {
          loadVocabulariesByLevel(_currentLevel!);
        } else if (_currentLanguage != null) {
          loadVocabulariesByLanguage(_currentLanguage!);
        } else {
          loadInitialVocabularies();
        }
      }
    });
  }
  
  Future<void> loadInitialVocabularies() async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load operation already in progress, skipping...');
      return;
    }
    
    _currentLevel = null;
    _currentLanguage = null;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const VocabulariesOperation(
          type: VocabulariesOperationType.loadVocabularies,
          status: VocabulariesOperationStatus.inProgress,
        ),
      ));
      
      final result = await loadVocabulariesUseCase.execute(LoadVocabulariesParams(
        page: 0,
        pageSize: _pageSize,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          _operationStopwatch.stop();
          debugPrint('loadInitialVocabularies completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.vocabularies.length} vocabularies');
          
          emit(VocabulariesState(
            vocabularies: loadResult.vocabularies,
            hasMore: loadResult.hasMore,
            currentOperation: const VocabulariesOperation(
              type: VocabulariesOperationType.loadVocabularies,
              status: VocabulariesOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadInitialVocabularies failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const VocabulariesOperation(
            type: VocabulariesOperationType.loadVocabularies,
            status: VocabulariesOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading initial vocabularies after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load vocabularies: $e', VocabulariesOperationType.loadVocabularies);
    }
  }

  Future<void> loadVocabulariesByLevel(BookLevel level) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load operation already in progress, skipping...');
      return;
    }
    
    _currentLevel = level;
    _currentLanguage = null;
    _currentPage = 0;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const VocabulariesOperation(
          type: VocabulariesOperationType.loadVocabularies,
          status: VocabulariesOperationStatus.inProgress,
        ),
      ));

      final result = await loadVocabulariesUseCase.execute(LoadVocabulariesParams(
        page: 0,
        pageSize: _pageSize,
        level: level,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          _operationStopwatch.stop();
          debugPrint('loadVocabulariesByLevel completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.vocabularies.length} vocabularies');
          
          emit(VocabulariesState(
            vocabularies: loadResult.vocabularies,
            hasMore: loadResult.hasMore,
            currentLevel: level,
            currentOperation: const VocabulariesOperation(
              type: VocabulariesOperationType.loadVocabularies,
              status: VocabulariesOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadVocabulariesByLevel failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const VocabulariesOperation(
            type: VocabulariesOperationType.loadVocabularies,
            status: VocabulariesOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading vocabularies by level after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load vocabularies: $e', VocabulariesOperationType.loadVocabularies);
    }
  }

  Future<void> loadVocabulariesByLanguage(SupportedLanguage language) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load operation already in progress, skipping...');
      return;
    }
    
    _currentLevel = null;
    _currentLanguage = language;
    _currentPage = 0;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const VocabulariesOperation(
          type: VocabulariesOperationType.loadVocabularies,
          status: VocabulariesOperationStatus.inProgress,
        ),
      ));

      final result = await loadVocabulariesUseCase.execute(LoadVocabulariesParams(
        page: 0,
        pageSize: _pageSize,
        language: language,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          _operationStopwatch.stop();
          debugPrint('loadVocabulariesByLanguage completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.vocabularies.length} vocabularies');
          
          emit(VocabulariesState(
            vocabularies: loadResult.vocabularies,
            hasMore: loadResult.hasMore,
            currentLanguage: language,
            currentOperation: const VocabulariesOperation(
              type: VocabulariesOperationType.loadVocabularies,
              status: VocabulariesOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadVocabulariesByLanguage failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const VocabulariesOperation(
            type: VocabulariesOperationType.loadVocabularies,
            status: VocabulariesOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading vocabularies by language after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load vocabularies: $e', VocabulariesOperationType.loadVocabularies);
    }
  }
  
  void requestLoadMoreVocabularies() {
    _loadMoreDebounceTimer?.cancel();
    _loadMoreDebounceTimer = Timer(_loadMoreDebounceDelay, () {
      _performLoadMoreVocabularies();
    });
  }
  
  Future<void> _performLoadMoreVocabularies() async {
    final currentState = state;
    
    if (!currentState.hasMore || currentState.currentOperation.isInProgress) {
      return;
    }
    
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) {
      debugPrint('loadMoreVocabularies skipped - not connected');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(currentState.copyWith(
        currentOperation: const VocabulariesOperation(
          type: VocabulariesOperationType.loadMoreVocabularies,
          status: VocabulariesOperationStatus.inProgress,
        ),
      ));
      
      final nextPage = _currentPage + 1;
      
      final result = await loadVocabulariesUseCase.execute(LoadVocabulariesParams(
        page: nextPage,
        pageSize: _pageSize,
        level: _currentLevel,
        language: _currentLanguage,
        loadMore: true,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          if (loadResult.vocabularies.isNotEmpty) {
            final allVocabularies = [...state.vocabularies, ...loadResult.vocabularies];
            _currentPage = nextPage;
            
            _operationStopwatch.stop();
            debugPrint('loadMoreVocabularies completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.vocabularies.length} new vocabularies');
            
            emit(state.copyWith(
              vocabularies: allVocabularies,
              hasMore: loadResult.hasMore,
              currentOperation: const VocabulariesOperation(
                type: VocabulariesOperationType.loadMoreVocabularies,
                status: VocabulariesOperationStatus.completed,
              ),
            ));
          } else {
            emit(state.copyWith(
              hasMore: false,
              currentOperation: const VocabulariesOperation(
                type: VocabulariesOperationType.loadMoreVocabularies,
                status: VocabulariesOperationStatus.completed,
              ),
            ));
          }
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadMoreVocabularies failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message, 
            errorType: type
          ).copyWithOperation(const VocabulariesOperation(
            type: VocabulariesOperationType.loadMoreVocabularies,
            status: VocabulariesOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading more vocabularies after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load more vocabularies: $e', VocabulariesOperationType.loadMoreVocabularies);
    }
  }
  
  Future<void> hardRefresh() async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Refresh operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const VocabulariesOperation(
          type: VocabulariesOperationType.refreshVocabularies,
          status: VocabulariesOperationStatus.inProgress,
        ),
      ));
      
      _currentPage = 0;

      final result = await loadVocabulariesUseCase.execute(LoadVocabulariesParams(
        page: 0,
        pageSize: _pageSize,
        level: _currentLevel,
        language: _currentLanguage,
        forceRefresh: true,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          
          _operationStopwatch.stop();
          debugPrint('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.vocabularies.length} vocabularies');
          
          emit(VocabulariesState(
            vocabularies: loadResult.vocabularies,
            hasMore: loadResult.hasMore,
            currentLevel: _currentLevel,
            currentLanguage: _currentLanguage,
            currentOperation: const VocabulariesOperation(
              type: VocabulariesOperationType.refreshVocabularies,
              status: VocabulariesOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('hardRefresh failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const VocabulariesOperation(
            type: VocabulariesOperationType.refreshVocabularies,
            status: VocabulariesOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error refreshing vocabularies after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to refresh vocabularies: $e', VocabulariesOperationType.refreshVocabularies);
    }
  }

  BookLevel? get currentLevel => _currentLevel;
  SupportedLanguage? get currentLanguage => _currentLanguage;

  Future<void> loadVocabularyById(String vocabularyId) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load vocabulary operation already in progress, skipping...');
      return;
    }

    try {
      emit(state.copyWith(
        selectedVocabulary: null,
        currentOperation: VocabulariesOperation(
          type: VocabulariesOperationType.loadVocabularyById,
          status: VocabulariesOperationStatus.inProgress,
          vocabularyId: vocabularyId,
        ),
      ));

      final result = await getVocabularyByIdUseCase.execute(GetVocabularyByIdParams(
        vocabularyId: vocabularyId,
        recordView: true,
      ));

      result.fold(
        onSuccess: (vocabulary) {
          emit(state.copyWith(
            selectedVocabulary: vocabulary,
            currentOperation: VocabulariesOperation(
              type: VocabulariesOperationType.loadVocabularyById,
              status: VocabulariesOperationStatus.completed,
              vocabularyId: vocabularyId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
          ).copyWithOperation(VocabulariesOperation(
            type: VocabulariesOperationType.loadVocabularyById,
            status: VocabulariesOperationStatus.failed,
            vocabularyId: vocabularyId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _handleError('Failed to load vocabulary: $e', VocabulariesOperationType.loadVocabularyById, vocabularyId);
    }
  }

  Future<void> rateVocabulary(String vocabularyId, double rating) async {
    try {
      emit(state.copyWith(
        currentOperation: VocabulariesOperation(
          type: VocabulariesOperationType.rateVocabulary,
          status: VocabulariesOperationStatus.inProgress,
          vocabularyId: vocabularyId,
        ),
      ));

      final result = await rateVocabularyUseCase.execute(RateVocabularyParams(
        vocabularyId: vocabularyId,
        rating: rating,
      ));

      result.fold(
        onSuccess: (_) {
          debugPrint('Successfully rated vocabulary $vocabularyId with $rating stars');
          
          emit(state.copyWith(
            currentOperation: VocabulariesOperation(
              type: VocabulariesOperationType.rateVocabulary,
              status: VocabulariesOperationStatus.completed,
              vocabularyId: vocabularyId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
          ).copyWithOperation(VocabulariesOperation(
            type: VocabulariesOperationType.rateVocabulary,
            status: VocabulariesOperationStatus.failed,
            vocabularyId: vocabularyId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _handleError('Failed to rate vocabulary: $e', VocabulariesOperationType.rateVocabulary, vocabularyId);
    }
  }
  
  void _handleError(String message, VocabulariesOperationType operationType, [String? vocabularyId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(VocabulariesOperation(
      type: operationType,
      status: VocabulariesOperationStatus.failed,
      message: message,
      vocabularyId: vocabularyId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 2), () {
      if (!isClosed && state.currentOperation.status != VocabulariesOperationStatus.none) {
        emit(state.copyWithOperation(
          const VocabulariesOperation(status: VocabulariesOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing VocabulariesCubit...');
    _connectivitySubscription?.cancel();
    _loadMoreDebounceTimer?.cancel();
    return super.close();
  }
}