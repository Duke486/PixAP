enum NetworkMode {
  compat('compat'),
  ech('ech'),
  standard('standard');

  const NetworkMode(this.code);

  final String code;

  static const List<NetworkMode> selectableValues = [
    NetworkMode.standard,
    NetworkMode.compat,
    NetworkMode.ech,
  ];

  static NetworkMode fromCode(String? code) {
    for (final mode in NetworkMode.values) {
      if (mode.code == code) return mode;
    }
    return NetworkMode.standard;
  }

  bool get usesCompatibleConnection => this != NetworkMode.standard;
  bool get allowsImageSource => this != NetworkMode.standard;
}
