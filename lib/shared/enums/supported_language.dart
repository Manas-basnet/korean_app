enum SupportedLanguage {
  korean,
  japanese,
  chinese,
  nepali,
  english,
  hindi,
}

extension SupportedLanguageExtension on SupportedLanguage {
  String get name {
    switch (this) {
      case SupportedLanguage.korean:
        return 'korean';
      case SupportedLanguage.japanese:
        return 'japanese';
      case SupportedLanguage.chinese:
        return 'chinese';
      case SupportedLanguage.nepali:
        return 'nepali';
      case SupportedLanguage.english:
        return 'english';
      case SupportedLanguage.hindi:
        return 'hindi';
    }
  }
  
  String get displayName {
    switch (this) {
      case SupportedLanguage.korean:
        return '한국어 (Korean)';
      case SupportedLanguage.japanese:
        return '日本語 (Japanese)';
      case SupportedLanguage.chinese:
        return '中文 (Chinese)';
      case SupportedLanguage.nepali:
        return 'नेपाली (Nepali)';
      case SupportedLanguage.english:
        return 'English';
      case SupportedLanguage.hindi:
        return 'हिन्दी (Hindi)';
    }
  }
  
  String get flag {
    switch (this) {
      case SupportedLanguage.korean:
        return '🇰🇷';
      case SupportedLanguage.japanese:
        return '🇯🇵';
      case SupportedLanguage.chinese:
        return '🇨🇳';
      case SupportedLanguage.nepali:
        return '🇳🇵';
      case SupportedLanguage.english:
        return '🇺🇸';
      case SupportedLanguage.hindi:
        return '🇮🇳';
    }
  }
}