import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceAdminService {
  static const _channel = MethodChannel('navi/device_admin');

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isActiveAdmin() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isActiveAdmin') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestAdmin() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('requestAdmin');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> removeAdmin() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('removeAdmin');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
