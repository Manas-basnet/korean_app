import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class SortBottomSheet extends StatelessWidget {
  final TestSortType selectedSortType;
  final LanguagePreferenceCubit languageCubit;
  final Function(TestSortType) onSortTypeChanged;

  const SortBottomSheet({
    super.key,
    required this.selectedSortType,
    required this.languageCubit,
    required this.onSortTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    final maxHeight = screenSize.height * 0.6;
    final headerHeight = screenSize.height * 0.08;
    final availableContentHeight = maxHeight - headerHeight - bottomPadding;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: screenSize.width,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: screenSize.height * 0.01,
              bottom: screenSize.height * 0.005,
            ),
            width: screenSize.width * 0.1,
            height: screenSize.height * 0.005,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Container(
            height: headerHeight,
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.05,
              vertical: screenSize.height * 0.01,
            ),
            child: Row(
              children: [
                Text(
                  languageCubit.getLocalizedText(
                    korean: '정렬',
                    english: 'Sort',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: screenSize.width * 0.05,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    size: screenSize.width * 0.06,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    padding: EdgeInsets.all(screenSize.width * 0.02),
                  ),
                ),
              ],
            ),
          ),
          
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: availableContentHeight,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: screenSize.width * 0.02,
                  right: screenSize.width * 0.02,
                  bottom: screenSize.height * 0.02 + bottomPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: TestSortType.values.map((sortType) {
                    final isSelected = selectedSortType == sortType;
                    return Container(
                      margin: EdgeInsets.symmetric(
                        vertical: screenSize.height * 0.002,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: screenSize.width * 0.04,
                          vertical: screenSize.height * 0.005,
                        ),
                        leading: Icon(
                          _getSortTypeIcon(sortType),
                          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          size: screenSize.width * 0.06,
                        ),
                        title: Text(
                          sortType.getDisplayName(languageCubit.getLocalizedText),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                            fontSize: screenSize.width * 0.04,
                          ),
                        ),
                        trailing: isSelected 
                            ? Icon(
                                Icons.check_rounded, 
                                color: colorScheme.primary,
                                size: screenSize.width * 0.05,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onSortTypeChanged(sortType);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSortTypeIcon(TestSortType sortType) {
    switch (sortType) {
      case TestSortType.recent:
        return Icons.schedule_rounded;
      case TestSortType.popular:
        return Icons.trending_up_rounded;
      case TestSortType.rating:
        return Icons.star_rounded;
      case TestSortType.viewCount:
        return Icons.visibility_rounded;
    }
  }

  static void show(
    BuildContext context, {
    required TestSortType selectedSortType,
    required LanguagePreferenceCubit languageCubit,
    required Function(TestSortType) onSortTypeChanged,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SortBottomSheet(
        selectedSortType: selectedSortType,
        languageCubit: languageCubit,
        onSortTypeChanged: onSortTypeChanged,
      ),
    );
  }
}