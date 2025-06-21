enum TestCategory {
  all,
  topikI,
  topikII,
  practice,
}

extension TestCategoryExtension on TestCategory {

  String get name {
    switch (this) {
      case TestCategory.topikI:
        return 'TOPIK I';
      case TestCategory.topikII:
        return 'TOPIK II';
      case TestCategory.practice:
        return 'Practice';
      case TestCategory.all:
        return 'All';
    }
  }

  // String get getCategoryDisplayName {
  //   switch (this) {
  //     case TestCategory.all:
  //       return _languageCubit.getLocalizedText(
  //         korean: '전체',
  //         english: 'All',
  //       );
  //     case TestCategory.practice:
  //       return _languageCubit.getLocalizedText(
  //         korean: '연습',  
  //         english: 'Practice',
  //       );
  //     case TestCategory.topikI:
  //       return _languageCubit.getLocalizedText(
  //         korean: 'TOPIK I',
  //         english: 'TOPIK I',
  //       );
  //     case TestCategory.topikII:
  //       return _languageCubit.getLocalizedText(
  //         korean: 'TOPIK II',
  //         english: 'TOPIK II',
  //       );
  //   }
  // }

}