import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VpnPermission {
  static const MethodChannel _channel = MethodChannel('vpn_permission');

  static Future<bool> requestPermission({
    required String providerBundleIdentifier,
    required String groupIdentifier,
    required String localizedDescription,
  }) async {
    try {
      if (Platform.isIOS) {
        return await _channel.invokeMethod('requestVpnPermission', {
          'providerBundleIdentifier': providerBundleIdentifier,
          'groupIdentifier': groupIdentifier,
          'localizedDescription': localizedDescription,
        });
      }
      return await _channel.invokeMethod('requestVpnPermission');
    } on PlatformException catch (e) {
      if (kDebugMode) print("VPN Permission Error: ${e.message}");
      return false;
    }
  }

  static Future<bool> checkPermission({
    required String providerBundleIdentifier,
  }) async {
    try {
      if (Platform.isIOS) {
        return await _channel.invokeMethod('checkVpnPermission', {
          'providerBundleIdentifier': providerBundleIdentifier,
        });
      }
      return await _channel.invokeMethod('checkVpnPermission');
    } on PlatformException {
      return false;
    }
  }
}
