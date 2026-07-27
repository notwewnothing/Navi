class Sfx {
  static bool _enabled = true;
  static bool get enabled => _enabled;
  static set enabled(bool v) => _enabled = v;
  static Future<void> init() async {}
}
