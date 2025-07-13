import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_progress.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_chapter_progress.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabularies_cubit.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_session/vocabulary_session_cubit.dart';

class VocabularyChapterListPage extends StatefulWidget {
  final String vocabularyId;

  const VocabularyChapterListPage({super.key, required this.vocabularyId});

  @override
  State<VocabularyChapterListPage> createState() => _VocabularyChapterListPageState();
}

class _VocabularyChapterListPageState extends State<VocabularyChapterListPage> {
  late VocabulariesCubit _vocabulariesCubit;
  late LanguagePreferenceCubit _languageCubit;
  late SnackBarCubit _snackBarCubit;

  @override
  void initState() {
    super.initState();
    _vocabulariesCubit = context.read<VocabulariesCubit>();
    _languageCubit = context.read<LanguagePreferenceCubit>();
    _snackBarCubit = context.read<SnackBarCubit>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVocabulary();
    });
  }

  Future<void> _loadVocabulary() async {
    final vocabulariesState = _vocabulariesCubit.state;
    
    if (vocabulariesState.selectedVocabulary?.id != widget.vocabularyId) {
      await _vocabulariesCubit.loadVocabularyById(widget.vocabularyId);
      
      final updatedState = _vocabulariesCubit.state;
      if (updatedState.hasError || updatedState.selectedVocabulary == null) {
        _snackBarCubit.showErrorLocalized(
          korean: '단어장을 불러올 수 없습니다',
          english: 'Failed to load vocabulary',
        );
        if (mounted) {
          context.pop();
        }
      }
    }
  }

  void _navigateToChapterStudy(VocabularyItem vocabulary, int chapterIndex) {
    context.push(
      Routes.vocabularyChapterReading(vocabulary.id, chapterIndex),
      extra: vocabulary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VocabulariesCubit, VocabulariesState>(
      builder: (context, state) {
        if (state.isLoading && state.selectedVocabulary == null) {
          return _buildLoadingScreen();
        }

        if (state.hasError && state.selectedVocabulary == null) {
          return _buildErrorScreen();
        }

        final vocabulary = state.selectedVocabulary;
        if (vocabulary == null) {
          return _buildErrorScreen();
        }

        return _buildChapterListScreen(vocabulary);
      },
    );
  }

  Widget _buildLoadingScreen() {
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
              _languageCubit.getLocalizedText(
                korean: '단어장을 불러오고 있습니다...',
                english: 'Loading vocabulary...',
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

  Widget _buildErrorScreen() {
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
                _languageCubit.getLocalizedText(
                  korean: '단어장을 불러올 수 없습니다',
                  english: 'Failed to load vocabulary',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  _languageCubit.getLocalizedText(
                    korean: '돌아가기',
                    english: 'Go Back',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterListScreen(VocabularyItem vocabulary) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildVocabularyHeader(vocabulary, screenSize, colorScheme),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: BlocBuilder<VocabularySessionCubit, VocabularySessionState>(
              builder: (context, sessionState) {
                VocabularyProgress? vocabularyProgress;
                
                if ((sessionState is VocabularySessionActive && sessionState.currentSession.vocabularyId == vocabulary.id) ||
                    (sessionState is VocabularySessionPaused && sessionState.pausedSession.vocabularyId == vocabulary.id)) {
                  vocabularyProgress = sessionState is VocabularySessionActive 
                      ? sessionState.currentVocabularyProgress
                      : (sessionState as VocabularySessionPaused).currentVocabularyProgress;
                } else if (sessionState is VocabularySessionIdle) {
                  vocabularyProgress = sessionState.recentlyStudiedVocabularies
                      .where((progress) => progress.vocabularyId == vocabulary.id)
                      .firstOrNull;
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final chapter = vocabulary.chapters[index];
                      final chapterProgress = vocabularyProgress?.chapters[index];
                      
                      return _buildChapterCard(
                        vocabulary, 
                        chapter, 
                        index, 
                        theme, 
                        colorScheme,
                        chapterProgress,
                      );
                    },
                    childCount: vocabulary.chapters.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyHeader(VocabularyItem vocabulary, Size screenSize, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (vocabulary.imageUrl != null || vocabulary.imagePath != null)
                  Container(
                    width: 80,
                    height: 120,
                    margin: const EdgeInsets.only(right: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomCachedImage(
                        imageUrl: vocabulary.imageUrl,
                        imagePath: vocabulary.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vocabulary.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        vocabulary.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildInfoChip(
                            Icons.book_outlined,
                            '${vocabulary.chapterCount} ${_languageCubit.getLocalizedText(korean: "챕터", english: "chapters")}',
                            colorScheme.primary,
                            theme,
                          ),
                          _buildInfoChip(
                            Icons.translate,
                            '${vocabulary.totalWords} ${_languageCubit.getLocalizedText(korean: "단어", english: "words")}',
                            colorScheme.secondary,
                            theme,
                          ),
                          _buildInfoChip(
                            Icons.language,
                            vocabulary.primaryLanguage.flag,
                            colorScheme.tertiary,
                            theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(
    VocabularyItem vocabulary, 
    VocabularyChapter chapter, 
    int index, 
    ThemeData theme, 
    ColorScheme colorScheme,
    VocabularyChapterProgress? chapterProgress,
  ) {
    final isCompleted = chapterProgress?.isCompleted ?? false;
    final progress = chapterProgress?.progressPercentage ?? 0.0;
    final hasProgress = progress > 0.0;
    final studiedWordsCount = chapterProgress?.studiedWordsCount ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: hasProgress 
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: hasProgress ? 1.0 : 0.5,
          ),
        ),
        child: InkWell(
          onTap: () => _navigateToChapterStudy(vocabulary, index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? Colors.green.withValues(alpha: 0.2)
                            : hasProgress
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.green,
                                size: 24,
                              )
                            : Text(
                                '${index + 1}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: hasProgress 
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapter.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (chapter.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              chapter.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.translate,
                                      size: 12,
                                      color: colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${chapter.wordCount}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (chapter.totalMeanings > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.book,
                                        size: 12,
                                        color: colorScheme.tertiary,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${chapter.totalMeanings}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.tertiary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (hasProgress)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCompleted 
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : colorScheme.primaryContainer.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isCompleted 
                                        ? _languageCubit.getLocalizedText(korean: '완료', english: 'Done')
                                        : '$studiedWordsCount/${chapter.wordCount}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isCompleted ? Colors.green : colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                
                if (hasProgress && !isCompleted) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}