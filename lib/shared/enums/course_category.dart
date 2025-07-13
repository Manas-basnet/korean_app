enum CourseCategory {
  all,
  korean,
  nepali,
  test,
  global,
  favorite
}

extension CourseCategoryExtension on CourseCategory {
  String get displayName {
    switch (this) {
      case CourseCategory.all:
        return 'All';
      case CourseCategory.korean:
        return 'Korean';
      case CourseCategory.nepali:
        return 'Nepali';
      case CourseCategory.test:
        return 'Test';
      case CourseCategory.global:
        return 'Global';
      case CourseCategory.favorite:
        return 'Favorite';
    }
  }

  String getDisplayName(String Function({required String korean, required String english}) getLocalizedText) {
    switch (this) {
      case CourseCategory.all:
        return getLocalizedText(korean: '전체', english: 'All');
      case CourseCategory.korean:
        return getLocalizedText(korean: '한국인', english: 'Korean');
      case CourseCategory.nepali:
        return getLocalizedText(korean: '네팔어', english: 'Nepali');
      case CourseCategory.test:
        return getLocalizedText(korean: '시험', english: 'Test');
      case CourseCategory.global:
        return getLocalizedText(korean: '전국', english: 'Global');
      case CourseCategory.favorite:
        return getLocalizedText(korean: '좋아요', english: 'Favorite');
    }
  }
  
  String getFlagAsset() {
    switch (this) {
      case CourseCategory.all://TODO:import assets for all
      case CourseCategory.korean:
        return 'assets/flags/south_korea.png';
      case CourseCategory.nepali:
        return 'assets/flags/nepal.png';
      case CourseCategory.test:
        return 'assets/flags/test_icon.png';
      case CourseCategory.global:
        return 'assets/flags/global.png';
      case CourseCategory.favorite:
        return 'assets/flags/favorite_icon.png';
    }
  }
}