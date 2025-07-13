import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/simple_audio_player.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_meaning.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_example.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_session/vocabulary_session_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabularies_cubit.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  int _currentWordIndex = 0;
  bool _showMeanings = false;
  bool _showExamples = false;
  final Set<int> _studiedWords = {};
  String _searchQuery = '';
  
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
  VocabularyWord? get currentWord => _currentWordIndex < words.length ? words[_currentWordIndex] : null;

  late LanguagePreferenceCubit _languageCubit;
  late SnackBarCubit _snackBarCubit;
  late VocabularySessionCubit _vocabularySessionCubit;
  late VocabulariesCubit _vocabulariesCubit;

  List<VocabularyWord> get _filteredWords {
    if (_searchQuery.isEmpty) return words;
    return words.where((word) {
      return word.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (word.pronunciation?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    _languageCubit = context.read<LanguagePreferenceCubit>();
    _snackBarCubit = context.read<SnackBarCubit>();
    _vocabularySessionCubit = context.read<VocabularySessionCubit>();
    _vocabulariesCubit = context.read<VocabulariesCubit>();

    _pageController = PageController();

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
  void dispose() {
    _pageController.dispose();
    
    if (!_isLoadingVocabulary && !_hasError) {
      _vocabularySessionCubit.updateStudyProgress(
        widget.chapterIndex,
        _currentWordIndex,
        totalWords,
      );
      _vocabularySessionCubit.pauseSession();
    }
    super.dispose();
  }

  void _onWordChanged(int index) {
    setState(() {
      _currentWordIndex = index;
      _showMeanings = false;
      _showExamples = false;
      _studiedWords.add(index);
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

  void _toggleMeanings() {
    setState(() {
      _showMeanings = !_showMeanings;
      if (_showMeanings) _showExamples = false;
    });
  }

  void _toggleExamples() {
    setState(() {
      _showExamples = !_showExamples;
      if (_showExamples) _showMeanings = false;
    });
  }

  void _nextWord() {
    if (_currentWordIndex < totalWords - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showCompletionDialog();
    }
  }

  void _previousWord() {
    if (_currentWordIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToWord(int index) {
    Navigator.of(context).pop();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
            korean: '모든 단어를 완료했습니다. 단어장을 평가해주세요.',
            english: 'You have completed all words. Please rate this vocabulary.',
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
        languageCubit: _languageCubit,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.surface,
      endDrawer: _buildWordListDrawer(theme, colorScheme),
      onEndDrawerChanged: (isOpened) {
        if (!isOpened) {
          setState(() {
            _searchQuery = '';
          });
        }
      },
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < -300) {
            _scaffoldKey.currentState?.openEndDrawer();
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme, colorScheme),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalWords,
                  onPageChanged: _onWordChanged,
                  itemBuilder: (context, index) {
                    return _buildWordCard(words[index], theme, colorScheme);
                  },
                ),
              ),
              _buildBottomControls(theme, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  chapterTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_currentWordIndex + 1} / $totalWords',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.list),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildWordListDrawer(ThemeData theme, ColorScheme colorScheme) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Icon(
                    Icons.list,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _languageCubit.getLocalizedText(
                        korean: '단어 목록',
                        english: 'Word List',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: _languageCubit.getLocalizedText(
                  korean: '단어 검색...',
                  english: 'Search words...',
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () => setState(() => _searchQuery = ''),
                        icon: const Icon(Icons.clear, size: 20),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredWords.length,
              itemBuilder: (context, index) {
                final word = _filteredWords[index];
                final originalIndex = words.indexOf(word);
                final isStudied = _studiedWords.contains(originalIndex);
                final isCurrent = originalIndex == _currentWordIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? colorScheme.primary
                            : isStudied
                                ? Colors.green.withOpacity(0.2)
                                : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: isCurrent
                            ? Icon(
                                Icons.play_arrow,
                                color: colorScheme.onPrimary,
                                size: 18,
                              )
                            : isStudied
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 18,
                                  )
                                : Text(
                                    '${originalIndex + 1}',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                      ),
                    ),
                    title: Text(
                      word.word,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrent
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    subtitle: word.pronunciation != null
                        ? Text(
                            word.pronunciation!,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: word.hasAudio
                        ? Icon(
                            Icons.volume_up,
                            color: colorScheme.onSurfaceVariant,
                            size: 16,
                          )
                        : null,
                    onTap: () => _goToWord(originalIndex),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tileColor: isCurrent
                        ? colorScheme.primaryContainer.withOpacity(0.3)
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(VocabularyWord word, ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMainWordSection(word, theme, colorScheme),
          const SizedBox(height: 24),
          _buildActionButtons(word, theme, colorScheme),
          const SizedBox(height: 16),
          _buildExpandableSections(word, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildMainWordSection(VocabularyWord word, ThemeData theme, ColorScheme colorScheme) {
    return SimpleAudioPlayer(
      audioUrl: word.audioUrl,
      audioPath: word.audioPath,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            if (word.hasImage) ...[
              _buildWordImage(word, colorScheme),
              const SizedBox(height: 16),
            ],
            
            Text(
              word.word,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                fontSize: 36,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (word.hasPronunciation) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  word.pronunciation!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWordImage(VocabularyWord word, ColorScheme colorScheme) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _buildImageContent(word, colorScheme),
      ),
    );
  }

  Widget _buildImageContent(VocabularyWord word, ColorScheme colorScheme) {
    if (word.imagePath != null && word.imagePath!.isNotEmpty) {
      return Image.file(
        File(word.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
            return _buildNetworkImage(word.imageUrl!);
          }
          return _buildImagePlaceholder(colorScheme);
        },
      );
    }
    
    if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
      return _buildNetworkImage(word.imageUrl!);
    }
    
    return _buildImagePlaceholder(colorScheme);
  }

  Widget _buildNetworkImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => _buildImagePlaceholder(
        Theme.of(context).colorScheme,
      ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildActionButtons(VocabularyWord word, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            onTap: _toggleMeanings,
            icon: Icons.lightbulb_outline,
            label: _languageCubit.getLocalizedText(
              korean: '의미',
              english: 'Meanings',
            ),
            count: word.meanings.length,
            isActive: _showMeanings,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            onTap: _toggleExamples,
            icon: Icons.format_quote,
            label: _languageCubit.getLocalizedText(
              korean: '예문',
              english: 'Examples',
            ),
            count: word.examples.length,
            isActive: _showExamples,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive 
              ? colorScheme.primary 
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? colorScheme.primary 
                : colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive 
                      ? colorScheme.onPrimary.withOpacity(0.2)
                      : colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive ? colorScheme.onPrimary : colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSections(VocabularyWord word, ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        if (_showMeanings && word.meanings.isNotEmpty)
          _buildMeaningsSection(word.meanings, theme, colorScheme),
        if (_showExamples && word.examples.isNotEmpty)
          _buildExamplesSection(word.examples, theme, colorScheme),
      ],
    );
  }

  Widget _buildMeaningsSection(List<WordMeaning> meanings, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _languageCubit.getLocalizedText(
                  korean: '의미',
                  english: 'Meanings',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...meanings.asMap().entries.map((entry) {
            final index = entry.key;
            final meaning = entry.value;
            return _buildMeaningCard(meaning, index, theme, colorScheme);
          }),
        ],
      ),
    );
  }

  Widget _buildMeaningCard(WordMeaning meaning, int index, ThemeData theme, ColorScheme colorScheme) {
    return SimpleAudioPlayer(
      audioUrl: meaning.audioUrl,
      audioPath: meaning.audioPath,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        meaning.language.flag,
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        meaning.language.name.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              meaning.meaning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamplesSection(List<WordExample> examples, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                color: colorScheme.tertiary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _languageCubit.getLocalizedText(
                  korean: '예문',
                  english: 'Examples',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...examples.asMap().entries.map((entry) {
            final index = entry.key;
            final example = entry.value;
            return _buildExampleCard(example, index, theme, colorScheme);
          }),
        ],
      ),
    );
  }

  Widget _buildExampleCard(WordExample example, int index, ThemeData theme, ColorScheme colorScheme) {
    return SimpleAudioPlayer(
      audioUrl: example.audioUrl,
      audioPath: example.audioPath,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.format_quote,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                example.example,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (example.hasTranslation) ...[
              const SizedBox(height: 6),
              Text(
                example.translation!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _currentWordIndex > 0 ? _previousWord : null,
              icon: const Icon(Icons.chevron_left),
              iconSize: 28,
              style: IconButton.styleFrom(
                backgroundColor: _currentWordIndex > 0 
                    ? colorScheme.surfaceContainerHighest 
                    : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                foregroundColor: _currentWordIndex > 0 
                    ? colorScheme.onSurface 
                    : colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _nextWord,
                icon: Icon(_currentWordIndex == totalWords - 1 ? Icons.check : Icons.chevron_right),
                label: Text(
                  _currentWordIndex == totalWords - 1
                      ? _languageCubit.getLocalizedText(korean: '완료', english: 'Complete')
                      : _languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: colorScheme.primary,
              strokeWidth: 3,
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
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
                    icon: const Icon(Icons.arrow_back),
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
                    icon: const Icon(Icons.refresh),
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
  final LanguagePreferenceCubit languageCubit;

  const _NoWordsScreen({
    required this.chapterTitle,
    required this.languageCubit,
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
    );
  }
}