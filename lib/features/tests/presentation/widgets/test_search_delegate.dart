import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/core/shared/models/test_item.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_search/test_search_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_card.dart';

class TestSearchDelegate extends SearchDelegate<TestItem?> {
  final TestSearchCubit testSearchCubit;
  final LanguagePreferenceCubit languageCubit;
  final Function(TestItem) onTestSelected;
  final Future<bool> Function(String) checkEditPermission;
  final Function(TestItem) onEditTest;
  final Function(TestItem) onDeleteTest;
  final Function(TestItem) onViewDetails;

  TestSearchDelegate({
    required this.testSearchCubit,
    required this.languageCubit,
    required this.onTestSelected,
    required this.checkEditPermission,
    required this.onEditTest,
    required this.onDeleteTest,
    required this.onViewDetails,
  });

  @override
  String get searchFieldLabel => languageCubit.getLocalizedText(
        korean: '시험 검색...',
        english: 'Search tests...',
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
            testSearchCubit.clearSearch();
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
        testSearchCubit.clearSearch();
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

    testSearchCubit.searchTests(query.trim());
    
    return BlocBuilder<TestSearchCubit, TestSearchState>(
      bloc: testSearchCubit,
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
          korean: '시험 검색',
          english: 'Search Tests',
        ),
        subtitle: languageCubit.getLocalizedText(
          korean: '시험 제목이나 설명으로 검색하세요',
          english: 'Search by test title or description',
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
              color: colorScheme.primaryContainer.withOpacity(0.3),
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
              color: colorScheme.errorContainer.withOpacity(0.3),
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
            onPressed: () => testSearchCubit.searchTests(query.trim()),
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
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
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

  Widget _buildSearchResults(BuildContext context, List<TestItem> tests) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        return FutureBuilder<bool>(
          future: testSearchCubit.canUserEditTest(test.id),
          builder: (context, snapshot) {
            final canEdit = snapshot.data ?? false;
            
            return TestCard(
              key: ValueKey('search_${test.id}'),
              test: test,
              canEdit: canEdit,
              onTap: () {
                close(context, test);
                onTestSelected(test);
              },
              onEdit: canEdit ? () {
                close(context, test);
                onEditTest(test);
              } : null,
              onDelete: canEdit ? () {
                close(context, test);
                onDeleteTest(test);
              } : null,
              onViewDetails: () {
                close(context, test);
                onViewDetails(test);
              },
            );
          },
        );
      },
    );
  }
}