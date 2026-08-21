import 'package:flutter/services.dart';

class AppIcons {
  static const _channel = MethodChannel('navi/app_icons');

  static final _cache = <String, Uint8List?>{};

  static Future<Uint8List?> getIcon(String packageName) async {
    if (_cache.containsKey(packageName)) return _cache[packageName];
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      _cache[packageName] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
