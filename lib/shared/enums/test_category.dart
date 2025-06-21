enum TestCategory {
  all,
  topikI,
  topikII,
  practice,
  ubt,
}

extension TestCategoryExtension on TestCategory {
  String get displayName {
    switch (this) {
      case TestCategory.topikI:
        return 'TOPIK I';
      case TestCategory.topikII:
        return 'TOPIK II';
      case TestCategory.practice:
        return 'Practice';
      case TestCategory.ubt:
        return 'UBT';
      case TestCategory.all:
        return 'All';
    }
  }

  String getDisplayName(String Function({required String korean, required String english}) getLocalizedText) {
    switch (this) {
      case TestCategory.all:
        return getLocalizedText(
          korean: '전체',
          english: 'All',
        );
      case TestCategory.practice:
        return getLocalizedText(
          korean: '연습',  
          english: 'Practice',
        );
      case TestCategory.topikI:
        return getLocalizedText(
          korean: 'TOPIK I',
          english: 'TOPIK I',
        );
      case TestCategory.topikII:
        return getLocalizedText(
          korean: 'TOPIK II',
          english: 'TOPIK II',
        );
      case TestCategory.ubt:
        return getLocalizedText(
          korean: 'UBT',
          english: 'UBT',
        );
    }
  }
}