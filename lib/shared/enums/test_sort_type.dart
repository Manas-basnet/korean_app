enum TestSortType {
  recent,
  popular,
  rating,
  viewCount,
}

extension TestSortTypeExtension on TestSortType {
  String get name {
    switch (this) {
      case TestSortType.recent:
        return 'recent';
      case TestSortType.popular:
        return 'popular';
      case TestSortType.rating:
        return 'rating';
      case TestSortType.viewCount:
        return 'viewCount';
    }
  }

  String getDisplayName(String Function({required String korean, required String english}) getLocalizedText) {
    switch (this) {
      case TestSortType.recent:
        return getLocalizedText(
          korean: '최근 업로드',
          english: 'Recent',
        );
      case TestSortType.popular:
        return getLocalizedText(
          korean: '인기순',
          english: 'Popular',
        );
      case TestSortType.rating:
        return getLocalizedText(
          korean: '평점순',
          english: 'Rating',
        );
      case TestSortType.viewCount:
        return getLocalizedText(
          korean: '조회수순',
          english: 'Views',
        );
    }
  }
}