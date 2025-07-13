import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_session/vocabulary_session_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabularies_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/word_study_widget.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/vocabulary_rating_dialog.dart';

class VocabularyStudyPage extends StatefulWidget {
  final String vocabularyId;
  final int chapterIndex;

  const VocabularyStudyPage({
    super.key,
    required this.vocabularyId,
    required this.chapterIndex,
  });

  @override
  State<VocabularyStudyPage> createState() => _VocabularyStudyPageState();
}

class _VocabularyStudyPageState extends State<VocabularyStudyPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _currentWordIndex = 0;
  bool _isControlsVisible = true;
  
  VocabularyItem? _currentVocabularyItem;
  bool _isLoadingVocabulary = true;
  bool _hasError = false;
  String? _errorMessage;

  VocabularyChapter? get currentChapter => _currentVocabularyItem != null && 
      widget.chapterIndex < _currentVocabularyItem!.chapters.length 
      ? _currentVocabularyItem!.chapters[widget.chapterIndex] 
      : null;
  String get vocabularyTitle => _currentVocabularyItem?.title ?? '';
  String get chapterTitle => currentChapter?.title ?? '';
  List<VocabularyWord> get words => currentChapter?.words ?? [];
  int get totalWords => words.length;
  bool get isFirstWord => _currentWordIndex == 0;
  bool get isLastWord => _currentWordIndex == totalWords - 1;
  bool get isFirstChapter => widget.chapterIndex == 0;
  bool get isLastChapter => widget.chapterIndex == (_currentVocabularyItem?.chapters.length ?? 1) - 1;

  late LanguagePreferenceCubit _languageCubit;
  late SnackBarCubit _snackBarCubit;
  late VocabularySessionCubit _vocabularySessionCubit;
  late VocabulariesCubit _vocabulariesCubit;

  @override
  void initState() {
    super.initState();

    _languageCubit = context.read<LanguagePreferenceCubit>();
    _snackBarCubit = context.read<SnackBarCubit>();
    _vocabularySessionCubit = context.read<VocabularySessionCubit>();
    _vocabulariesCubit = context.read<VocabulariesCubit>();

    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVocabularyAndInitializeSession();
    });
  }

  Future<void> _loadVocabularyAndInitializeSession() async {
    try {
      setState(() {
        _isLoadingVocabulary = true;
        _hasError = false;
        _errorMessage = null;
      });

      final vocabulariesState = _vocabulariesCubit.state;
      VocabularyItem? vocabulary;

      if (vocabulariesState.selectedVocabulary?.id == widget.vocabularyId) {
        vocabulary = vocabulariesState.selectedVocabulary;
      } else {
        await _vocabulariesCubit.loadVocabularyById(widget.vocabularyId);
        final updatedState = _vocabulariesCubit.state;
        
        if (updatedState.hasError || updatedState.selectedVocabulary == null) {
          setState(() {
            _hasError = true;
            _errorMessage = updatedState.error ?? _languageCubit.getLocalizedText(
              korean: '단어장을 불러올 수 없습니다',
              english: 'Failed to load vocabulary',
            );
            _isLoadingVocabulary = false;
          });
          return;
        }
        vocabulary = updatedState.selectedVocabulary;
      }

      if (vocabulary == null) {
        setState(() {
          _hasError = true;
          _errorMessage = _languageCubit.getLocalizedText(
            korean: '단어장을 찾을 수 없습니다',
            english: 'Vocabulary not found',
          );
          _isLoadingVocabulary = false;
        });
        return;
      }

      if (widget.chapterIndex >= vocabulary.chapters.length) {
        setState(() {
          _hasError = true;
          _errorMessage = _languageCubit.getLocalizedText(
            korean: '챕터를 찾을 수 없습니다',
            english: 'Chapter not found',
          );
          _isLoadingVocabulary = false;
        });
        return;
      }

      setState(() {
        _currentVocabularyItem = vocabulary;
        _isLoadingVocabulary = false;
      });

      await _initializeSession();

    } catch (e) {
      debugPrint('Error loading vocabulary and initializing session: $e');
      setState(() {
        _hasError = true;
        _errorMessage = _languageCubit.getLocalizedText(
          korean: '오류가 발생했습니다: $e',
          english: 'An error occurred: $e',
        );
        _isLoadingVocabulary = false;
      });
    }
  }

  Future<void> _initializeSession() async {
    if (_currentVocabularyItem == null || currentChapter == null) return;

    await _vocabularySessionCubit.startStudySession(
      widget.vocabularyId,
      vocabularyTitle,
      widget.chapterIndex,
      chapterTitle,
      vocabularyItem: _currentVocabularyItem,
      totalWords: totalWords,
    );

    final lastWordIndex = await _vocabularySessionCubit.loadLastStudyPosition(widget.chapterIndex);
    if (lastWordIndex > 0 && lastWordIndex < totalWords) {
      setState(() {
        _currentWordIndex = lastWordIndex;
      });
      _pageController.jumpToPage(lastWordIndex);
    }
  }

  @override
  void deactivate() {
    if (!_isLoadingVocabulary && !_hasError) {
      _vocabularySessionCubit.updateStudyProgress(
        widget.chapterIndex,
        _currentWordIndex,
        totalWords,
      );
      _vocabularySessionCubit.pauseSession();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    if (_isControlsVisible) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
    }
  }

  void _goToWord(int index) {
    if (index >= 0 && index < totalWords) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToPreviousChapter() {
    if (!isFirstChapter) {
      context.pushReplacement(
        '/vocabulary/${widget.vocabularyId}/chapter/${widget.chapterIndex - 1}/study',
      );
    }
  }

  void _navigateToNextChapter() {
    if (!isLastChapter) {
      context.pushReplacement(
        '/vocabulary/${widget.vocabularyId}/chapter/${widget.chapterIndex + 1}/study',
      );
    } else {
      _showCompletionDialog();
    }
  }

  void _onWordChanged(int index) {
    setState(() {
      _currentWordIndex = index;
    });
    
    if (index < words.length) {
      _vocabularySessionCubit.updateStudyProgress(
        widget.chapterIndex,
        index,
        totalWords,
        studiedWordId: words[index].id,
      );
      
      _vocabularySessionCubit.markWordAsStudied(
        widget.vocabularyId,
        widget.chapterIndex,
        words[index].id,
      );
    }
  }

  void _showWordNavigator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _WordNavigatorDialog(
        currentWordIndex: _currentWordIndex,
        totalWords: totalWords,
        words: words,
        languageCubit: _languageCubit,
        onWordSelected: _goToWord,
      ),
    );
  }

  void _showCompletionDialog() {
    _vocabularySessionCubit.markChapterCompleted(widget.vocabularyId, widget.chapterIndex);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '축하합니다!',
            english: 'Congratulations!',
          ),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '모든 단어장을 완료했습니다. 단어장을 평가해주세요.',
            english: 'You have completed all chapters. Please rate this vocabulary.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '나중에',
                english: 'Later',
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRatingDialog();
            },
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '평가하기',
                english: 'Rate',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    VocabularyRatingDialogHelper.showRatingDialog(
      context,
      vocabularyTitle: vocabularyTitle,
    ).then((rating) {
      if (rating != null) {
        _vocabulariesCubit.rateVocabulary(widget.vocabularyId, rating);
        _snackBarCubit.showSuccessLocalized(
          korean: '평가해주셔서 감사합니다!',
          english: 'Thank you for your rating!',
        );
      }
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingVocabulary) {
      return _LoadingScreen(languageCubit: _languageCubit);
    }

    if (_hasError) {
      return _ErrorScreen(
        languageCubit: _languageCubit,
        errorMessage: _errorMessage ?? 'Unknown error',
        onRetry: _loadVocabularyAndInitializeSession,
      );
    }

    if (words.isEmpty) {
      return _NoWordsScreen(
        chapterTitle: chapterTitle,
        vocabularyTitle: vocabularyTitle,
        languageCubit: _languageCubit,
        isFirstChapter: isFirstChapter,
        isLastChapter: isLastChapter,
        onNavigateToPrevious: _navigateToPreviousChapter,
        onNavigateToNext: _navigateToNextChapter,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: totalWords,
            onPageChanged: _onWordChanged,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleControls,
                child: WordStudyWidget(
                  word: words[index],
                  wordIndex: index,
                  totalWords: totalWords,
                  languageCubit: _languageCubit,
                ),
              );
            },
          ),

          _TopOverlay(
            isVisible: _isControlsVisible,
            fadeAnimation: _fadeAnimation,
            currentWordIndex: _currentWordIndex,
            totalWords: totalWords,
            chapterTitle: chapterTitle,
            onBack: () => Navigator.of(context).pop(),
          ),

          _BottomOverlay(
            isVisible: _isControlsVisible,
            fadeAnimation: _fadeAnimation,
            isFirstWord: isFirstWord,
            isLastWord: isLastWord,
            isFirstChapter: isFirstChapter,
            isLastChapter: isLastChapter,
            languageCubit: _languageCubit,
            onNavigateToPrevious: _navigateToPreviousChapter,
            onNavigateToNext: _navigateToNextChapter,
            onWordNavigator: () => _showWordNavigator(context),
            onPreviousWord: () => _goToWord(_currentWordIndex - 1),
            onNextWord: () => _goToWord(_currentWordIndex + 1),
          ),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final LanguagePreferenceCubit languageCubit;

  const _LoadingScreen({required this.languageCubit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              languageCubit.getLocalizedText(
                korean: '단어장을 준비하고 있습니다...',
                english: 'Preparing vocabulary...',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final LanguagePreferenceCubit languageCubit;
  final String errorMessage;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.languageCubit,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                languageCubit.getLocalizedText(
                  korean: '오류 발생',
                  english: 'Error Occurred',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(
                      languageCubit.getLocalizedText(
                        korean: '돌아가기',
                        english: 'Go Back',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      languageCubit.getLocalizedText(
                        korean: '다시 시도',
                        english: 'Retry',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoWordsScreen extends StatelessWidget {
  final String chapterTitle;
  final String vocabularyTitle;
  final LanguagePreferenceCubit languageCubit;
  final bool isFirstChapter;
  final bool isLastChapter;
  final VoidCallback onNavigateToPrevious;
  final VoidCallback onNavigateToNext;

  const _NoWordsScreen({
    required this.chapterTitle,
    required this.vocabularyTitle,
    required this.languageCubit,
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.onNavigateToPrevious,
    required this.onNavigateToNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(chapterTitle),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.translate,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                languageCubit.getLocalizedText(
                  korean: '단어가 없습니다',
                  english: 'No words available',
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                languageCubit.getLocalizedText(
                  korean: '이 챕터에는 학습할 단어가 없습니다.',
                  english: 'This chapter contains no words to study.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _NavigationBar(
        isFirstChapter: isFirstChapter,
        isLastChapter: isLastChapter,
        languageCubit: languageCubit,
        onNavigateToPrevious: onNavigateToPrevious,
        onNavigateToNext: onNavigateToNext,
      ),
    );
  }
}

class _TopOverlay extends StatelessWidget {
  final bool isVisible;
  final Animation<double> fadeAnimation;
  final int currentWordIndex;
  final int totalWords;
  final String chapterTitle;
  final VoidCallback onBack;

  const _TopOverlay({
    required this.isVisible,
    required this.fadeAnimation,
    required this.currentWordIndex,
    required this.totalWords,
    required this.chapterTitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: isVisible ? fadeAnimation.value : 0.0,
            child: IgnorePointer(
              ignoring: !isVisible,
              child: Container(
                height: MediaQuery.of(context).padding.top + 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              chapterTitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${currentWordIndex + 1} / $totalWords',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  final bool isVisible;
  final Animation<double> fadeAnimation;
  final bool isFirstWord;
  final bool isLastWord;
  final bool isFirstChapter;
  final bool isLastChapter;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onNavigateToPrevious;
  final VoidCallback onNavigateToNext;
  final VoidCallback onWordNavigator;
  final VoidCallback onPreviousWord;
  final VoidCallback onNextWord;

  const _BottomOverlay({
    required this.isVisible,
    required this.fadeAnimation,
    required this.isFirstWord,
    required this.isLastWord,
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.languageCubit,
    required this.onNavigateToPrevious,
    required this.onNavigateToNext,
    required this.onWordNavigator,
    required this.onPreviousWord,
    required this.onNextWord,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: isVisible ? fadeAnimation.value : 0.0,
            child: IgnorePointer(
              ignoring: !isVisible,
              child: Container(
                height: 80 + MediaQuery.of(context).padding.bottom,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!isFirstWord)
                        IconButton(
                          onPressed: onPreviousWord,
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          tooltip: languageCubit.getLocalizedText(
                            korean: '이전 단어',
                            english: 'Previous Word',
                          ),
                        ),
                      if (!isFirstChapter)
                        IconButton(
                          onPressed: onNavigateToPrevious,
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          tooltip: languageCubit.getLocalizedText(
                            korean: '이전 챕터',
                            english: 'Previous Chapter',
                          ),
                        ),
                      IconButton(
                        onPressed: onWordNavigator,
                        icon: const Icon(Icons.list, color: Colors.white),
                        tooltip: languageCubit.getLocalizedText(
                          korean: '단어 목록',
                          english: 'Word List',
                        ),
                      ),
                      if (!isLastChapter)
                        IconButton(
                          onPressed: onNavigateToNext,
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          tooltip: languageCubit.getLocalizedText(
                            korean: '다음 챕터',
                            english: 'Next Chapter',
                          ),
                        ),
                      if (!isLastWord)
                        IconButton(
                          onPressed: onNextWord,
                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                          tooltip: languageCubit.getLocalizedText(
                            korean: '다음 단어',
                            english: 'Next Word',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final bool isFirstChapter;
  final bool isLastChapter;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onNavigateToPrevious;
  final VoidCallback onNavigateToNext;

  const _NavigationBar({
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.languageCubit,
    required this.onNavigateToPrevious,
    required this.onNavigateToNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isFirstChapter) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigateToPrevious,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (!isLastChapter)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNavigateToNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WordNavigatorDialog extends StatefulWidget {
  final int currentWordIndex;
  final int totalWords;
  final List<VocabularyWord> words;
  final LanguagePreferenceCubit languageCubit;
  final Function(int) onWordSelected;

  const _WordNavigatorDialog({
    required this.currentWordIndex,
    required this.totalWords,
    required this.words,
    required this.languageCubit,
    required this.onWordSelected,
  });

  @override
  State<_WordNavigatorDialog> createState() => _WordNavigatorDialogState();
}

class _WordNavigatorDialogState extends State<_WordNavigatorDialog> {
  late int _currentWordIndex;

  @override
  void initState() {
    super.initState();
    _currentWordIndex = widget.currentWordIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AlertDialog(
      title: Text(widget.languageCubit.getLocalizedText(
        korean: '단어 목록',
        english: 'Word List',
      )),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: widget.words.length,
          itemBuilder: (context, index) {
            final word = widget.words[index];
            final isSelected = index == _currentWordIndex;
            
            return Card(
              color: isSelected ? colorScheme.primaryContainer : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? colorScheme.primary : colorScheme.outline,
                  foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  word.word,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colorScheme.onPrimaryContainer : null,
                  ),
                ),
                subtitle: word.pronunciation != null 
                    ? Text(
                        word.pronunciation!,
                        style: TextStyle(
                          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                        ),
                      ) 
                    : null,
                onTap: () {
                  setState(() {
                    _currentWordIndex = index;
                  });
                  widget.onWordSelected(index);
                  Navigator.of(context).pop();
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.languageCubit.getLocalizedText(
            korean: '닫기',
            english: 'Close',
          )),
        ),
      ],
    );
  }
}