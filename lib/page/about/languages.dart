import 'dart:ui';

class Language {
  final String language;
  final String name;
  final Locale locale;

  const Language({
    required this.language,
    required this.name,
    required this.locale,
  });
}

// Keep this order aligned with the existing persisted language indexes.
const defaultLanguageIndex = 1;
const Languages = [
  Language(language: 'en-US', name: 'English', locale: Locale('en', 'US')),
  Language(language: 'zh-CN', name: '简体中文', locale: Locale('zh', 'CN')),
  Language(language: 'zh-TW', name: '繁體中文', locale: Locale('zh', 'TW')),
  Language(language: 'ja', name: '日本語', locale: Locale('ja')),
  Language(language: 'ko', name: '한국어', locale: Locale('ko')),
];
