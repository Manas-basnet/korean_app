import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_search/vocabulary_search_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/vocabulary_card.dart';

class VocabularySearchDelegate extends SearchDelegate<VocabularyItem?> {
  final VocabularySearchCubit vocabularySearchCubit;
  final LanguagePreferenceCubit languageCubit;
  final Function(VocabularyItem) onVocabularySelected;
  final Function(VocabularyItem) onViewDetails;

  VocabularySearchDelegate({
    required this.vocabularySearchCubit,
    required this.languageCubit,
    required this.onVocabularySelected,
    required this.onViewDetails,
  });

  @override
  String get searchFieldLabel => languageCubit.getLocalizedText(
        korean: '단어장 검색...',
        english: 'Search vocabularies...',
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: theme.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.normal,
        ),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
            vocabularySearchCubit.clearSearch();
            showSuggestions(context);
          },
          icon: const Icon(Icons.clear_rounded),
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return IconButton(
      onPressed: () {
        vocabularySearchCubit.clearSearch();
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back_rounded),
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().length < 2) {
      return _buildEmptyState(
        context,
        icon: Icons.search_rounded,
        title: languageCubit.getLocalizedText(
          korean: '검색어를 입력하세요',
          english: 'Enter search terms',
        ),
        subtitle: languageCubit.getLocalizedText(
          korean: '최소 2글자 이상 입력해주세요',
          english: 'Please enter at least 2 characters',
        ),
      );
    }

    vocabularySearchCubit.searchVocabularies(query.trim());
    
    return BlocBuilder<VocabularySearchCubit, VocabularySearchState>(
      bloc: vocabularySearchCubit,
      builder: (context, state) {
        if (state.isLoading && state.searchResults.isEmpty) {
          return _buildLoadingState(context);
        }

        if (state.hasError && state.searchResults.isEmpty) {
          return _buildErrorState(context, state.error ?? 'Search failed');
        }

        if (state.searchResults.isEmpty && state.isSearching) {
          return _buildEmptyState(
            context,
            icon: Icons.search_off_rounded,
            title: languageCubit.getLocalizedText(
              korean: '검색 결과가 없습니다',
              english: 'No results found',
            ),
            subtitle: languageCubit.getLocalizedText(
              korean: '다른 검색어를 시도해보세요',
              english: 'Try different search terms',
            ),
          );
        }

        return _buildSearchResults(context, state.searchResults);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.search_rounded,
        title: languageCubit.getLocalizedText(
          korean: '단어장 검색',
          english: 'Search Vocabularies',
        ),
        subtitle: languageCubit.getLocalizedText(
          korean: '단어장 제목이나 설명으로 검색하세요',
          english: 'Search by vocabulary title or description',
        ),
      );
    }

    if (query.trim().length < 2) {
      return _buildEmptyState(
        context,
        icon: Icons.search_rounded,
        title: languageCubit.getLocalizedText(
          korean: '검색어를 입력하세요',
          english: 'Enter search terms',
        ),
        subtitle: languageCubit.getLocalizedText(
          korean: '최소 2글자 이상 입력해주세요',
          english: 'Please enter at least 2 characters',
        ),
      );
    }

    return buildResults(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: colorScheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            languageCubit.getLocalizedText(
              korean: '검색 중...',
              english: 'Searching...',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            languageCubit.getLocalizedText(
              korean: '검색 오류',
              english: 'Search Error',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => vocabularySearchCubit.searchVocabularies(query.trim()),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              languageCubit.getLocalizedText(
                korean: '다시 시도',
                english: 'Try Again',
              ),
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, List<VocabularyItem> vocabularies) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: vocabularies.length,
      itemBuilder: (context, index) {
        final vocabulary = vocabularies[index];
        
        return VocabularyCard(
          key: ValueKey('search_${vocabulary.id}'),
          vocabulary: vocabulary,
          canEdit: false,
          onTap: () {
            close(context, vocabulary);
            onVocabularySelected(vocabulary);
          },
          onLongPress: () {
            onViewDetails(vocabulary);
          },
          onViewDetails: () {
            onViewDetails(vocabulary);
          },
        );
      },
    );
  }
}