enum WelcomePagePlatform { material }

enum WelcomePageLegacyLayout { material, iosMaterialBeforeRankFix }

enum WelcomePageType {
  home('home'),
  rank('rank'),
  quickView('quick_view'),
  search('search'),
  setting('setting'),
  news('news'),
  bookmark('bookmark'),
  followed('followed');

  const WelcomePageType(this.code);

  final String code;

  static WelcomePageType fromCode(String? code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return WelcomePageType.home;
  }

  WelcomePageType normalizeFor(WelcomePagePlatform platform) {
    switch (platform) {
      case WelcomePagePlatform.material:
        switch (this) {
          case WelcomePageType.news:
          case WelcomePageType.bookmark:
          case WelcomePageType.followed:
            return WelcomePageType.quickView;
          default:
            return this;
        }
    }
  }
}

const List<WelcomePageType> materialWelcomePageTypes = [
  WelcomePageType.home,
  WelcomePageType.rank,
  WelcomePageType.quickView,
  WelcomePageType.search,
  WelcomePageType.setting,
];

extension WelcomePagePlatformX on WelcomePagePlatform {
  List<WelcomePageType> get supportedTypes {
    switch (this) {
      case WelcomePagePlatform.material:
        return materialWelcomePageTypes;
    }
  }

  int indexOf(WelcomePageType type) {
    final normalizedType = type.normalizeFor(this);
    final index = supportedTypes.indexOf(normalizedType);
    return index == -1 ? 0 : index;
  }

  WelcomePageType typeAt(int index) {
    if (index < 0 || index >= supportedTypes.length) {
      return supportedTypes.first;
    }
    return supportedTypes[index];
  }
}

WelcomePageType welcomePageTypeFromLegacyIndex(
  int? legacyValue, {
  required WelcomePageLegacyLayout legacyLayout,
}) {
  if (legacyValue == null) return WelcomePageType.home;

  switch (legacyLayout) {
    case WelcomePageLegacyLayout.material:
      switch (legacyValue) {
        case 1:
          return WelcomePageType.rank;
        case 2:
          return WelcomePageType.quickView;
        case 3:
          return WelcomePageType.search;
        case 4:
          return WelcomePageType.setting;
        default:
          return WelcomePageType.home;
      }
    case WelcomePageLegacyLayout.iosMaterialBeforeRankFix:
      switch (legacyValue) {
        case 1:
          return WelcomePageType.quickView;
        case 2:
          return WelcomePageType.search;
        case 3:
        case 4:
          return WelcomePageType.setting;
        default:
          return WelcomePageType.home;
      }
  }
}
